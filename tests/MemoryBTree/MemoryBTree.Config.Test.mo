// @testmode wasi
/// Test file for comparing MemoryBTree configurations
/// Outputs results in a table format for easy comparison
/// 
/// Run: mops test --testmode wasi btree.config

import { test; suite } "mo:test";
import Debug "mo:base@0.14.13/Debug";
import Iter "mo:base@0.14.13/Iter";
import Buffer "mo:base@0.14.13/Buffer";
import Nat "mo:base@0.14.13/Nat";
import Float "mo:base@0.14.13/Float";
import Text "mo:base@0.14.13/Text";

import Fuzz "mo:fuzz";

import MemoryBTree "../../src/MemoryBTree/Base";
import TypeUtils "../../src/TypeUtils";

// Test data size
let DATA_SIZE = 10_000;

// Node capacities to test
let NODE_CAPACITIES : [Nat] = [16, 32, 64, 128, 256, 512, 1024, 2048, 4096];

// Merge thresholds to test
let MERGE_THRESHOLDS : [Float] = [0.5, 0.25, 0.125];

let fuzz = Fuzz.fromSeed(0xdeadbeef);

let MAX_KEY_LEN = 30;
let MAX_PREFIX_LEN = 15;
let PREFIX_REUSE_RATE = 30; // 30% chance to reuse an existing prefix

// Generate random Text keys (fully random - not ideal for tail compression)
// Appends index to ensure uniqueness
func generate_random_text_keys(count : Nat) : Buffer.Buffer<(Text, Text)> {
    let buffer = Buffer.Buffer<(Text, Text)>(count);
    for (i in Iter.range(0, count - 1)) {
        let indexStr = Nat.toText(i);
        let maxRandomLen = MAX_KEY_LEN - indexStr.size() - 1; // -1 for separator
        let randomLen = fuzz.nat.randomRange(1, maxRandomLen);
        let key = fuzz.text.randomAlphanumeric(randomLen) # "_" # indexStr;
        buffer.add((key, key));
    };
    buffer;
};

// Generate Text keys with shared prefixes (better for tail compression)
// - Maintains a pool of prefixes (max 15 chars each)
// - 30% chance to reuse an existing prefix from pool
// - 70% chance to generate a new prefix and add to pool
// - Appends index to ensure uniqueness
func generate_prefixed_text_keys(count : Nat) : Buffer.Buffer<(Text, Text)> {
    let buffer = Buffer.Buffer<(Text, Text)>(count);
    let prefixes = Buffer.Buffer<Text>(64);
    
    for (i in Iter.range(0, count - 1)) {
        let prefix = if (prefixes.size() > 0 and fuzz.nat.randomRange(1, 100) <= PREFIX_REUSE_RATE) {
            // 30% chance: reuse a random existing prefix
            let idx = fuzz.nat.randomRange(0, prefixes.size() - 1);
            prefixes.get(idx);
        } else {
            // 70% chance: generate new prefix and add to pool
            let prefixLen = fuzz.nat.randomRange(3, MAX_PREFIX_LEN);
            let newPrefix = fuzz.text.randomAlphanumeric(prefixLen);
            prefixes.add(newPrefix);
            newPrefix;
        };
        
        // Append index for uniqueness
        let indexStr = Nat.toText(i);
        let remainingLen = MAX_KEY_LEN - prefix.size() - indexStr.size() - 1; // -1 for separator
        let suffixLen = if (remainingLen > 0) fuzz.nat.randomRange(0, remainingLen) else 1;
        let suffix = if (suffixLen > 0) fuzz.text.randomAlphanumeric(suffixLen) else "";
        
        let key = prefix # suffix # "_" # indexStr;
        buffer.add((key, key));
    };
    buffer;
};

// Collect stats into a record
type StatsRecord = {
    nodeCapacity : Nat;
    entryCount : Nat;
    depth : Nat;
    leafCount : Nat;
    branchCount : Nat;
    allocatedBytes : Nat;
    usedBytes : Nat;
    dataBytes : Nat;
    metadataBytes : Nat;
    keyBytes : Nat;
    valueBytes : Nat;
};

func collect_stats(btree : MemoryBTree.MemoryBTree) : StatsRecord {
    let stats = MemoryBTree.stats(btree);
    {
        nodeCapacity = btree.node_capacity;
        entryCount = MemoryBTree.size(btree);
        depth = btree.depth;
        leafCount = stats.leafCount;
        branchCount = stats.branchCount;
        allocatedBytes = stats.allocatedBytes;
        usedBytes = stats.usedBytes;
        dataBytes = stats.dataBytes;
        metadataBytes = stats.metadataBytes;
        keyBytes = stats.keyBytes;
        valueBytes = stats.valueBytes;
    };
};

// Format number with thousands separator
func format_num(n : Nat) : Text {
    let str = Nat.toText(n);
    let len = str.size();
    if (len <= 3) return str;
    
    var result = "";
    var count = 0;
    let chars = Iter.toArray(Text.toIter(str));
    var i = len;
    while (i > 0) {
        i -= 1;
        if (count > 0 and count % 3 == 0) {
            result := "," # result;
        };
        result := Text.fromChar(chars[i]) # result;
        count += 1;
    };
    result;
};

// Pad text to fixed width (right-aligned for numbers)
func pad_right(text : Text, width : Nat) : Text {
    let len = text.size();
    if (len >= width) return text;
    var padding = "";
    for (_ in Iter.range(0, width - len - 1)) {
        padding := padding # " ";
    };
    padding # text;
};

// Pad text to fixed width (left-aligned for labels)
func pad_left(text : Text, width : Nat) : Text {
    let len = text.size();
    if (len >= width) return text;
    var padding = "";
    for (_ in Iter.range(0, width - len - 1)) {
        padding := padding # " ";
    };
    text # padding;
};

func repeat_char(c : Char, n : Nat) : Text {
    var result = "";
    for (_ in Iter.range(0, n - 1)) {
        result := result # Text.fromChar(c);
    };
    result;
};

// Print table header
func print_table_header(title : Text, cols : [Text]) {
    Debug.print("\n");
    Debug.print("┏" # repeat_char('━', title.size() + 2) # "┓");
    Debug.print("┃ " # title # " ┃");
    Debug.print("┗" # repeat_char('━', title.size() + 2) # "┛");
    Debug.print("");
    
    var header = "| " # pad_left("Config", 20) # " |";
    for (col in cols.vals()) {
        header := header # " " # pad_right(col, 12) # " |";
    };
    Debug.print(header);
    
    var separator = "|" # repeat_char('-', 22) # "|";
    for (_ in cols.vals()) {
        separator := separator # repeat_char('-', 14) # "|";
    };
    Debug.print(separator);
};

// Print a stats row
func print_stats_row(row_label : Text, s : StatsRecord) {
    let row = "| " # pad_left(row_label, 20) # " |" #
        " " # pad_right(Nat.toText(s.depth), 12) # " |" #
        " " # pad_right(format_num(s.leafCount), 12) # " |" #
        " " # pad_right(format_num(s.branchCount), 12) # " |" #
        " " # pad_right(format_num(s.allocatedBytes), 12) # " |" #
        " " # pad_right(format_num(s.usedBytes), 12) # " |" #
        " " # pad_right(format_num(s.keyBytes), 12) # " |" #
        " " # pad_right(format_num(s.metadataBytes), 12) # " |";
    Debug.print(row);
};

// Fill BTree with data
func fill_btree(btree : MemoryBTree.MemoryBTree, data : Buffer.Buffer<(Text, Text)>) {
    let btree_utils = MemoryBTree.createUtils(TypeUtils.Text, TypeUtils.Text);
    for ((k, v) in data.vals()) {
        ignore MemoryBTree.insert(btree, btree_utils, k, v);
    };
};

// Remove half the entries
func remove_half(btree : MemoryBTree.MemoryBTree, data : Buffer.Buffer<(Text, Text)>) {
    let btree_utils = MemoryBTree.createUtils(TypeUtils.Text, TypeUtils.Text);
    let half = data.size() / 2;
    var removed = 0;
    var notFound = 0;
    for (i in Iter.range(0, half - 1)) {
        let (k, _) = data.get(i);
        let result = MemoryBTree.remove(btree, btree_utils, k);
        if (result == null) {
            notFound += 1;
            Debug.print("DEBUG key not found: i=" # Nat.toText(i) # " key=\"" # k # "\"");
        } else {
            removed += 1;
        };
    };
    Debug.print("DEBUG remove_half: removed=" # Nat.toText(removed) # " notFound=" # Nat.toText(notFound));
};

suite(
    "MemoryBTree Configuration Comparison",
    func() {
        
        test(
            "Node Capacity Comparison (Tail Compression DISABLED)",
            func() {
                let data = generate_random_text_keys(DATA_SIZE);
                
                print_table_header(
                    "Node Capacity Stats - Tail Compression: DISABLED (" # Nat.toText(DATA_SIZE) # " entries)",
                    ["Depth", "Leaves", "Branches", "Allocated", "Used", "Key Bytes", "Metadata"]
                );
                
                for (capacity in NODE_CAPACITIES.vals()) {
                    let btree = MemoryBTree.newWithOptions({ 
                        MemoryBTree.defaultOptions with 
                        node_capacity = ?capacity; 
                        is_tail_compression_enabled = ?false 
                    });
                    fill_btree(btree, data);
                    let stats = collect_stats(btree);
                    print_stats_row("capacity=" # Nat.toText(capacity), stats);
                    
                    // Verify correctness
                    assert MemoryBTree.size(btree) == data.size();
                };
                
                Debug.print("");
            },
        );

        test(
            "Node Capacity Comparison (Tail Compression ENABLED)",
            func() {
                let data = generate_random_text_keys(DATA_SIZE);
                
                print_table_header(
                    "Node Capacity Stats - Tail Compression: ENABLED (" # Nat.toText(DATA_SIZE) # " entries)",
                    ["Depth", "Leaves", "Branches", "Allocated", "Used", "Key Bytes", "Metadata"]
                );
                
                for (capacity in NODE_CAPACITIES.vals()) {
                    let btree = MemoryBTree.newWithOptions({ 
                        MemoryBTree.defaultOptions with 
                        node_capacity = ?capacity; 
                        is_tail_compression_enabled = ?true 
                    });
                    fill_btree(btree, data);
                    let stats = collect_stats(btree);
                    print_stats_row("capacity=" # Nat.toText(capacity), stats);
                    
                    // Verify correctness
                    assert MemoryBTree.size(btree) == data.size();
                };
                
                Debug.print("");
            },
        );

        test(
            "Merge Threshold Comparison (Tail Compression DISABLED)",
            func() {
                let data = generate_random_text_keys(DATA_SIZE);
                
                Debug.print("\n");
                Debug.print("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓");
                Debug.print("┃ Merge Threshold Stats - Tail Compression: DISABLED (After Insert + Remove Half) ┃");
                Debug.print("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛");
                Debug.print("");
                
                // Use capacity 256 for merge threshold comparison
                let test_capacity = 256;
                
                // Header for "After Insert" section
                var header = "| " # pad_left("merge_threshold", 20) # " |";
                let cols = ["Depth", "Leaves", "Branches", "Allocated", "Used", "Key Bytes", "Metadata"];
                for (col in cols.vals()) {
                    header := header # " " # pad_right(col, 12) # " |";
                };
                
                Debug.print("After Insert (" # Nat.toText(DATA_SIZE) # " entries, capacity=" # Nat.toText(test_capacity) # "):");
                Debug.print(header);
                var separator = "|" # repeat_char('-', 22) # "|";
                for (_ in cols.vals()) {
                    separator := separator # repeat_char('-', 14) # "|";
                };
                Debug.print(separator);
                
                // Store btrees for removal test
                let btrees = Buffer.Buffer<(Float, MemoryBTree.MemoryBTree)>(3);
                
                for (threshold in MERGE_THRESHOLDS.vals()) {
                    let btree = MemoryBTree.newWithOptions({ 
                        MemoryBTree.defaultOptions with 
                        node_capacity = ?test_capacity;
                        merge_threshold = ?threshold;
                        is_tail_compression_enabled = ?false 
                    });
                    fill_btree(btree, data);
                    Debug.print("DEBUG after insert: size=" # Nat.toText(MemoryBTree.size(btree)) # " data.size=" # Nat.toText(data.size()));
                    let stats = collect_stats(btree);
                    print_stats_row("threshold=" # Float.toText(threshold), stats);
                    btrees.add((threshold, btree));
                };
                
                Debug.print("");
                Debug.print("After Remove Half (" # Nat.toText(DATA_SIZE / 2) # " entries remaining):");
                Debug.print(header);
                Debug.print(separator);
                
                for ((threshold, btree) in btrees.vals()) {
                    remove_half(btree, data);
                    let stats = collect_stats(btree);
                    print_stats_row("threshold=" # Float.toText(threshold), stats);
                    
                    // Verify correctness
                    Debug.print("DEBUG: size=" # Nat.toText(MemoryBTree.size(btree)) # " expected=" # Nat.toText(data.size() / 2));
                    assert MemoryBTree.size(btree) == data.size() / 2;
                };
                
                Debug.print("");
            },
        );

        test(
            "Merge Threshold Comparison (Tail Compression ENABLED)",
            func() {
                let data = generate_random_text_keys(DATA_SIZE);
                
                Debug.print("\n");
                Debug.print("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓");
                Debug.print("┃ Merge Threshold Stats - Tail Compression: ENABLED (After Insert + Remove Half) ┃");
                Debug.print("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛");
                Debug.print("");
                
                // Use capacity 256 for merge threshold comparison
                let test_capacity = 256;
                
                // Header
                var header = "| " # pad_left("merge_threshold", 20) # " |";
                let cols = ["Depth", "Leaves", "Branches", "Allocated", "Used", "Key Bytes", "Metadata"];
                for (col in cols.vals()) {
                    header := header # " " # pad_right(col, 12) # " |";
                };
                
                Debug.print("After Insert (" # Nat.toText(DATA_SIZE) # " entries, capacity=" # Nat.toText(test_capacity) # "):");
                Debug.print(header);
                var separator = "|" # repeat_char('-', 22) # "|";
                for (_ in cols.vals()) {
                    separator := separator # repeat_char('-', 14) # "|";
                };
                Debug.print(separator);
                
                // Store btrees for removal test
                let btrees = Buffer.Buffer<(Float, MemoryBTree.MemoryBTree)>(3);
                
                for (threshold in MERGE_THRESHOLDS.vals()) {
                    let btree = MemoryBTree.newWithOptions({ 
                        MemoryBTree.defaultOptions with 
                        node_capacity = ?test_capacity;
                        merge_threshold = ?threshold;
                        is_tail_compression_enabled = ?true 
                    });
                    fill_btree(btree, data);
                    let stats = collect_stats(btree);
                    print_stats_row("threshold=" # Float.toText(threshold), stats);
                    btrees.add((threshold, btree));
                };
                
                Debug.print("");
                Debug.print("After Remove Half (" # Nat.toText(DATA_SIZE / 2) # " entries remaining):");
                Debug.print(header);
                Debug.print(separator);
                
                for ((threshold, btree) in btrees.vals()) {
                    remove_half(btree, data);
                    let stats = collect_stats(btree);
                    print_stats_row("threshold=" # Float.toText(threshold), stats);
                    
                    // Verify correctness                    Debug.print("DEBUG: size=" # Nat.toText(MemoryBTree.size(btree)) # " expected=" # Nat.toText(data.size() / 2));                    assert MemoryBTree.size(btree) == data.size() / 2;
                };
                
                Debug.print("");
            },
        );

        test(
            "Side-by-Side: Tail Compression ON vs OFF",
            func() {
                let data = generate_random_text_keys(DATA_SIZE);
                
                Debug.print("\n");
                Debug.print("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓");
                Debug.print("┃ Tail Compression Comparison: Key & Used Bytes (" # Nat.toText(DATA_SIZE) # " entries)                    ┃");
                Debug.print("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛");
                Debug.print("");
                
                let header = "| " # pad_left("Node Capacity", 15) # " |" #
                    " " # pad_right("TC=OFF Keys", 12) # " |" #
                    " " # pad_right("TC=ON Keys", 12) # " |" #
                    " " # pad_right("Key Savings", 12) # " |" #
                    " " # pad_right("TC=OFF Used", 12) # " |" #
                    " " # pad_right("TC=ON Used", 12) # " |" #
                    " " # pad_right("Used Savings", 12) # " |";
                Debug.print(header);
                Debug.print("|" # repeat_char('-', 17) # "|" # 
                    repeat_char('-', 14) # "|" # 
                    repeat_char('-', 14) # "|" # 
                    repeat_char('-', 14) # "|" #
                    repeat_char('-', 14) # "|" # 
                    repeat_char('-', 14) # "|" # 
                    repeat_char('-', 14) # "|");
                
                for (capacity in NODE_CAPACITIES.vals()) {
                    // Without tail compression
                    let btree_off = MemoryBTree.newWithOptions({ 
                        MemoryBTree.defaultOptions with 
                        node_capacity = ?capacity; 
                        is_tail_compression_enabled = ?false 
                    });
                    fill_btree(btree_off, data);
                    let stats_off = collect_stats(btree_off);
                    
                    // With tail compression
                    let btree_on = MemoryBTree.newWithOptions({ 
                        MemoryBTree.defaultOptions with 
                        node_capacity = ?capacity; 
                        is_tail_compression_enabled = ?true 
                    });
                    fill_btree(btree_on, data);
                    let stats_on = collect_stats(btree_on);
                    
                    // Calculate savings (safe because we check > first)
                    let key_savings = if (stats_off.keyBytes > stats_on.keyBytes) {
                        let diff : Nat = stats_off.keyBytes - stats_on.keyBytes : Nat;
                        let pct = Float.fromInt(diff) / Float.fromInt(stats_off.keyBytes) * 100.0;
                        Float.toText(pct) # "%";
                    } else { "0%" };
                    
                    let used_savings = if (stats_off.usedBytes > stats_on.usedBytes) {
                        let diff : Nat = stats_off.usedBytes - stats_on.usedBytes : Nat;
                        let pct = Float.fromInt(diff) / Float.fromInt(stats_off.usedBytes) * 100.0;
                        Float.toText(pct) # "%";
                    } else { "0%" };
                    
                    let row = "| " # pad_left(Nat.toText(capacity), 15) # " |" #
                        " " # pad_right(format_num(stats_off.keyBytes), 12) # " |" #
                        " " # pad_right(format_num(stats_on.keyBytes), 12) # " |" #
                        " " # pad_right(key_savings, 12) # " |" #
                        " " # pad_right(format_num(stats_off.usedBytes), 12) # " |" #
                        " " # pad_right(format_num(stats_on.usedBytes), 12) # " |" #
                        " " # pad_right(used_savings, 12) # " |";
                    Debug.print(row);
                };
                
                Debug.print("");
            },
        );

        test(
            "Tail Compression: Random Keys vs Prefixed Keys",
            func() {
                let random_data = generate_random_text_keys(DATA_SIZE);
                let prefixed_data = generate_prefixed_text_keys(DATA_SIZE);
                
                Debug.print("\n");
                Debug.print("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓");
                Debug.print("┃ Random Keys vs Prefixed Keys: Where Tail Compression Shines (" # Nat.toText(DATA_SIZE) # " entries) ┃");
                Debug.print("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛");
                Debug.print("");
                
                let header = "| " # pad_left("Key Type", 20) # " |" #
                    " " # pad_right("TC=OFF Keys", 12) # " |" #
                    " " # pad_right("TC=ON Keys", 12) # " |" #
                    " " # pad_right("Key Savings", 12) # " |" #
                    " " # pad_right("TC=OFF Used", 12) # " |" #
                    " " # pad_right("TC=ON Used", 12) # " |" #
                    " " # pad_right("Used Savings", 12) # " |";
                Debug.print(header);
                Debug.print("|" # repeat_char('-', 22) # "|" # 
                    repeat_char('-', 14) # "|" # 
                    repeat_char('-', 14) # "|" # 
                    repeat_char('-', 14) # "|" #
                    repeat_char('-', 14) # "|" # 
                    repeat_char('-', 14) # "|" # 
                    repeat_char('-', 14) # "|");
                
                // Use capacity 64 for this comparison
                let capacity = 64;
                
                // Random keys without tail compression
                let btree_random_off = MemoryBTree.newWithOptions({ 
                    MemoryBTree.defaultOptions with 
                    node_capacity = ?capacity; 
                    is_tail_compression_enabled = ?false 
                });
                fill_btree(btree_random_off, random_data);
                let stats_random_off = collect_stats(btree_random_off);
                
                // Random keys with tail compression
                let btree_random_on = MemoryBTree.newWithOptions({ 
                    MemoryBTree.defaultOptions with 
                    node_capacity = ?capacity; 
                    is_tail_compression_enabled = ?true 
                });
                fill_btree(btree_random_on, random_data);
                let stats_random_on = collect_stats(btree_random_on);
                
                // Calculate random key savings
                let random_key_savings = if (stats_random_off.keyBytes > stats_random_on.keyBytes) {
                    let diff : Nat = stats_random_off.keyBytes - stats_random_on.keyBytes : Nat;
                    let pct = Float.fromInt(diff) / Float.fromInt(stats_random_off.keyBytes) * 100.0;
                    Float.toText(pct) # "%";
                } else { "0%" };
                
                let random_used_savings = if (stats_random_off.usedBytes > stats_random_on.usedBytes) {
                    let diff : Nat = stats_random_off.usedBytes - stats_random_on.usedBytes : Nat;
                    let pct = Float.fromInt(diff) / Float.fromInt(stats_random_off.usedBytes) * 100.0;
                    Float.toText(pct) # "%";
                } else { "0%" };
                
                let row_random = "| " # pad_left("Random (10 chars)", 20) # " |" #
                    " " # pad_right(format_num(stats_random_off.keyBytes), 12) # " |" #
                    " " # pad_right(format_num(stats_random_on.keyBytes), 12) # " |" #
                    " " # pad_right(random_key_savings, 12) # " |" #
                    " " # pad_right(format_num(stats_random_off.usedBytes), 12) # " |" #
                    " " # pad_right(format_num(stats_random_on.usedBytes), 12) # " |" #
                    " " # pad_right(random_used_savings, 12) # " |";
                Debug.print(row_random);
                
                // Prefixed keys without tail compression
                let btree_prefix_off = MemoryBTree.newWithOptions({ 
                    MemoryBTree.defaultOptions with 
                    node_capacity = ?capacity; 
                    is_tail_compression_enabled = ?false 
                });
                fill_btree(btree_prefix_off, prefixed_data);
                let stats_prefix_off = collect_stats(btree_prefix_off);
                
                // Prefixed keys with tail compression
                let btree_prefix_on = MemoryBTree.newWithOptions({ 
                    MemoryBTree.defaultOptions with 
                    node_capacity = ?capacity; 
                    is_tail_compression_enabled = ?true 
                });
                fill_btree(btree_prefix_on, prefixed_data);
                let stats_prefix_on = collect_stats(btree_prefix_on);
                
                // Calculate prefixed key savings
                let prefix_key_savings = if (stats_prefix_off.keyBytes > stats_prefix_on.keyBytes) {
                    let diff : Nat = stats_prefix_off.keyBytes - stats_prefix_on.keyBytes : Nat;
                    let pct = Float.fromInt(diff) / Float.fromInt(stats_prefix_off.keyBytes) * 100.0;
                    Float.toText(pct) # "%";
                } else { "0%" };
                
                let prefix_used_savings = if (stats_prefix_off.usedBytes > stats_prefix_on.usedBytes) {
                    let diff : Nat = stats_prefix_off.usedBytes - stats_prefix_on.usedBytes : Nat;
                    let pct = Float.fromInt(diff) / Float.fromInt(stats_prefix_off.usedBytes) * 100.0;
                    Float.toText(pct) # "%";
                } else { "0%" };
                
                let row_prefix = "| " # pad_left("Prefixed (18+ chars)", 20) # " |" #
                    " " # pad_right(format_num(stats_prefix_off.keyBytes), 12) # " |" #
                    " " # pad_right(format_num(stats_prefix_on.keyBytes), 12) # " |" #
                    " " # pad_right(prefix_key_savings, 12) # " |" #
                    " " # pad_right(format_num(stats_prefix_off.usedBytes), 12) # " |" #
                    " " # pad_right(format_num(stats_prefix_on.usedBytes), 12) # " |" #
                    " " # pad_right(prefix_used_savings, 12) # " |";
                Debug.print(row_prefix);
                
                Debug.print("");
                Debug.print("Note: Prefixed keys use 'user_profile_data_' + number, showing tail compression benefits");
                Debug.print("");
            },
        );

        test(
            "Summary",
            func() {
                Debug.print("\n");
                Debug.print("╔════════════════════════════════════════════════════════════════════════════════╗");
                Debug.print("║                         Configuration Test Complete                           ║");
                Debug.print("╠════════════════════════════════════════════════════════════════════════════════╣");
                Debug.print("║ Key Observations:                                                              ║");
                Debug.print("║                                                                                ║");
                Debug.print("║ 1. Node Capacity:                                                              ║");
                Debug.print("║    - Smaller capacities = deeper trees, more nodes, more metadata overhead    ║");
                Debug.print("║    - Larger capacities = shallower trees, fewer nodes, better memory density  ║");
                Debug.print("║                                                                                ║");
                Debug.print("║ 2. Tail Compression:                                                           ║");
                Debug.print("║    - Reduces separator key storage in branch nodes                            ║");
                Debug.print("║    - Most effective with keys that share common prefixes                      ║");
                Debug.print("║    - Savings visible in 'Key Bytes' column                                    ║");
                Debug.print("║                                                                                ║");
                Debug.print("║ 3. Merge Threshold:                                                            ║");
                Debug.print("║    - Higher threshold (0.5) = more aggressive merging after removals          ║");
                Debug.print("║    - Lower threshold (0.125) = less merging, potentially sparser nodes        ║");
                Debug.print("║    - Trade-off between memory efficiency and merge operation costs            ║");
                Debug.print("╚════════════════════════════════════════════════════════════════════════════════╝");
                Debug.print("\n");
            },
        );
    },
);
