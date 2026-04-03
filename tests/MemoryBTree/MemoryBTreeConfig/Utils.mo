/// Shared utilities for MemoryBTree configuration tests
import Debug "mo:core@2.4/Debug";
import Iter "mo:core@2.4/Iter";
import Buffer "mo:base@0.16/Buffer";
import Nat "mo:core@2.4/Nat";
import Text "mo:core@2.4/Text";

import Fuzz "mo:fuzz";
import Itertools "mo:itertools@0.2/Iter";

import MemoryBTree "../../../src/MemoryBTree/Base";
import TypeUtils "../../../src/TypeUtils";

module {
    // Test data size
    public let DATA_SIZE = 10_000;

    // Node capacities to test
    public let NODE_CAPACITIES : [Nat] = [16, 32, 64, 128, 256, 512, 1024, 2048, 4096];

    // Merge thresholds to test
    public let MERGE_THRESHOLDS : [Float] = [0.5, 0.25, 0.125];

    public let MAX_KEY_LEN = 100;
    public let MAX_PREFIX_LEN = 60;
    public let PREFIX_REUSE_RATE = 99; // 100% chance to reuse an existing prefix
    public let PREFIX_TRUNCATE_RATE = 20; // 20% chance to truncate a reused prefix

    // Collect stats into a record
    public type StatsRecord = {
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

    // Generate random Text keys (fully random)
    // Appends index to ensure uniqueness
    public func generate_random_text_keys(fuzz : Fuzz.Fuzzer, count : Nat) : Buffer.Buffer<(Text, Text)> {
        let buffer = Buffer.Buffer<(Text, Text)>(count);
        for (i in Nat.rangeInclusive(0, count - 1)) {
            let indexStr = Nat.toText(i);
            let maxRandomLen = MAX_KEY_LEN - indexStr.size() - 1; // -1 for separator
            let randomLen = fuzz.nat.randomRange(1, maxRandomLen);
            let key = fuzz.text.randomAlphanumeric(randomLen) # "_" # indexStr;
            buffer.add((key, key));
        };
        buffer;
    };

    // Generate Text keys with shared prefixes
    // - Maintains a pool of prefixes (max 15 chars each)
    // - 30% chance to reuse an existing prefix from pool
    // - 70% chance to generate a new prefix and add to pool
    // - Appends index to ensure uniqueness
    public func generate_prefixed_text_keys(fuzz : Fuzz.Fuzzer, count : Nat) : Buffer.Buffer<(Text, Text)> {
        let buffer = Buffer.Buffer<(Text, Text)>(count);
        let prefixes = Buffer.Buffer<Text>(64);
        
        for (i in Nat.rangeInclusive(0, count - 1)) {
            let prefix = if (prefixes.size() > 0 and fuzz.nat.randomRange(1, 100) <= PREFIX_REUSE_RATE) {
                // Reuse a random existing prefix (possibly truncated)
                let prefixSize = prefixes.size();
                let idx = if (prefixSize == 1) { 0 } else { fuzz.nat.randomRange(0, prefixSize - 1) };
                let selectedPrefix = prefixes.get(idx);
                
                // Optionally truncate the prefix to create variation
                if (selectedPrefix.size() > 3 and fuzz.nat.randomRange(1, 100) <= PREFIX_TRUNCATE_RATE) {
                    let truncateLen = fuzz.nat.randomRange(3, selectedPrefix.size());
                    Text.fromIter(Itertools.take(selectedPrefix.chars(), truncateLen));
                } else {
                    selectedPrefix;
                };
            } else {
                // Generate new prefix and add to pool
                let prefixLen = fuzz.nat.randomRange(3, MAX_PREFIX_LEN);
                let newPrefix = fuzz.text.randomAlphanumeric(prefixLen);
                prefixes.add(newPrefix);
                newPrefix;
            };
            
            // Append index for uniqueness
            let indexStr = Nat.toText(i);
            let remainingLen = MAX_KEY_LEN - prefix.size() - indexStr.size() - 1; // -1 for separator
            let suffixLen = if (remainingLen > 0) { fuzz.nat.randomRange(0, remainingLen) } else { 1 };
            let suffix = if (suffixLen > 0) { fuzz.text.randomAlphanumeric(suffixLen) } else { "" };
            
            let key = prefix # suffix # "_" # indexStr;
            buffer.add((key, key));
        };
        
        // Calculate and print statistics
        var totalPrefixSize = 0;
        for (prefix in prefixes.vals()) {
            totalPrefixSize += prefix.size();
        };
        
        var totalKeySize = 0;
        for ((key, _) in buffer.vals()) {
            totalKeySize += key.size();
        };
        
        let avgPrefixSize = if (prefixes.size() > 0) {
            totalPrefixSize / prefixes.size()
        } else { 0 };
        
        let avgKeySize = if (buffer.size() > 0) {
            totalKeySize / buffer.size()
        } else { 0 };
        
        Debug.print("\n📊 Data Generation Stats:");
        Debug.print("   • Total keys generated: " # Nat.toText(buffer.size()));
        Debug.print("   • Unique prefixes: " # Nat.toText(prefixes.size()));
        Debug.print("   • Average prefix size: " # Nat.toText(avgPrefixSize) # " chars");
        Debug.print("   • Average key size: " # Nat.toText(avgKeySize) # " chars");
        Debug.print("   • Prefix reuse rate: " # Nat.toText(PREFIX_REUSE_RATE) # "%");
        Debug.print("   • Prefix truncate rate: " # Nat.toText(PREFIX_TRUNCATE_RATE) # "%");
        Debug.print("");
        
        buffer;
    };

    public func collect_stats(btree : MemoryBTree.MemoryBTree) : StatsRecord {
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
    public func format_num(n : Nat) : Text {
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
    public func pad_right(text : Text, width : Nat) : Text {
        let len = text.size();
        if (len >= width) return text;
        var padding = "";
        for (_ in Nat.rangeInclusive(0, width - len - 1)) {
            padding := padding # " ";
        };
        padding # text;
    };

    // Pad text to fixed width (left-aligned for labels)
    public func pad_left(text : Text, width : Nat) : Text {
        let len = text.size();
        if (len >= width) return text;
        var padding = "";
        for (_ in Nat.rangeInclusive(0, width - len - 1)) {
            padding := padding # " ";
        };
        text # padding;
    };

    public func repeat_char(c : Char, n : Nat) : Text {
        var result = "";
        for (_ in Nat.rangeInclusive(0, n - 1)) {
            result := result # Text.fromChar(c);
        };
        result;
    };

    // Print table header
    public func print_table_header(title : Text, cols : [Text]) {
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
    public func print_stats_row(row_label : Text, s : StatsRecord) {
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
    public func fill_btree(btree : MemoryBTree.MemoryBTree, data : Buffer.Buffer<(Text, Text)>) {
        let btree_utils = MemoryBTree.createUtils(TypeUtils.Text, TypeUtils.Text);
        for ((k, v) in data.vals()) {
            ignore MemoryBTree.insert(btree, btree_utils, k, v);
        };
    };

    // Remove half the entries
    public func remove_half(btree : MemoryBTree.MemoryBTree, data : Buffer.Buffer<(Text, Text)>) {
        let btree_utils = MemoryBTree.createUtils(TypeUtils.Text, TypeUtils.Text);
        let half = data.size() / 2;
        for (i in Nat.rangeInclusive(0, half - 1)) {
            let (k, _) = data.get(i);
            ignore MemoryBTree.remove(btree, btree_utils, k);
        };
    };
}
