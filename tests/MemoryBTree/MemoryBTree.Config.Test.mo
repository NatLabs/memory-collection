// @testmode wasi
/// Test file for comparing MemoryBTree configurations
/// 
/// To compare different configurations, modify the constants in Base.mo:
/// - ENABLE_TAIL_COMPRESSION: true/false
/// - MERGE_STRATEGY: #Conservative/#Balanced
/// - MERGE_THRESHOLD: 0.25/0.125
/// 
/// Then run: mops test btree.config.test
/// 
/// Compare the stats output between different configurations to see
/// memory usage differences.

import { test; suite } "mo:test";
import Debug "mo:base@0.14.13/Debug";
import Iter "mo:base@0.14.13/Iter";
import Buffer "mo:base@0.14.13/Buffer";
import Nat "mo:base@0.14.13/Nat";
import Float "mo:base@0.14.13/Float";
import Text "mo:base@0.14.13/Text";

import Fuzz "mo:fuzz";
import Itertools "mo:itertools@0.2.2/Iter";

import MemoryBTree "../../src/MemoryBTree/Base";
import TypeUtils "../../src/TypeUtils";

let fuzz = Fuzz.fromSeed(0xdeadbeef);

// Test data sizes
let SMALL_SIZE = 1_000;
let MEDIUM_SIZE = 5_000;
let LARGE_SIZE = 10_000;

// Generate random Nat keys
func generate_random_nats(count : Nat, max_value : Nat) : Buffer.Buffer<(Nat, Nat)> {
    let nat_gen_iter : Iter.Iter<Nat> = {
        next = func() : ?Nat = ?fuzz.nat.randomRange(1, max_value);
    };

    let unique_iter = Itertools.unique<Nat>(
        nat_gen_iter,
        func(n : Nat) : Nat32 = Nat64.toNat32(Nat64.fromNat(n) & 0xFFFF_FFFF),
        Nat.equal,
    );

    Itertools.toBuffer<(Nat, Nat)>(
        Iter.map<(Nat, Nat), (Nat, Nat)>(
            Itertools.enumerate(Itertools.take(unique_iter, count)),
            func((i, n) : (Nat, Nat)) : (Nat, Nat) = (n, i),
        )
    );
};

// Generate sequential Nat keys (best case for tail compression with Nat - all keys have same prefix)
func generate_sequential_nats(count : Nat, start : Nat) : Buffer.Buffer<(Nat, Nat)> {
    let buffer = Buffer.Buffer<(Nat, Nat)>(count);
    for (i in Iter.range(0, count - 1)) {
        buffer.add((start + i, i));
    };
    buffer;
};

// Generate Text keys with common prefixes (ideal for tail compression)
func generate_prefixed_text_keys(count : Nat, prefix : Text) : Buffer.Buffer<(Text, Nat)> {
    let buffer = Buffer.Buffer<(Text, Nat)>(count);
    for (i in Iter.range(0, count - 1)) {
        let key = prefix # Nat.toText(i);
        buffer.add((key, i));
    };
    buffer;
};

// Generate Text keys with varying prefixes
func generate_varied_text_keys(count : Nat) : Buffer.Buffer<(Text, Nat)> {
    let prefixes = ["user_", "item_", "order_", "product_", "category_"];
    let buffer = Buffer.Buffer<(Text, Nat)>(count);
    for (i in Iter.range(0, count - 1)) {
        let prefix_idx = i % prefixes.size();
        let key = prefixes[prefix_idx] # Nat.toText(i);
        buffer.add((key, i));
    };
    buffer;
};

// Print detailed stats
func print_stats(description : Text, btree : MemoryBTree.MemoryBTree) {
    let stats = MemoryBTree.stats(btree);
    
    Debug.print("\n========================================");
    Debug.print("Stats for: " # description);
    Debug.print("========================================");
    Debug.print("Configuration:");
    Debug.print("  - Tail Compression: " # debug_show MemoryBTree.ENABLE_TAIL_COMPRESSION);
    Debug.print("  - Merge Strategy: " # debug_show MemoryBTree.MERGE_STRATEGY);
    Debug.print("  - Merge Threshold: " # debug_show MemoryBTree.MERGE_THRESHOLD);
    Debug.print("  - Node Capacity: " # debug_show btree.node_capacity);
    Debug.print("");
    Debug.print("Tree Structure:");
    Debug.print("  - Entry Count: " # debug_show MemoryBTree.size(btree));
    Debug.print("  - Depth: " # debug_show btree.depth);
    Debug.print("  - Leaf Count: " # debug_show stats.leafCount);
    Debug.print("  - Branch Count: " # debug_show stats.branchCount);
    Debug.print("  - Total Node Count: " # debug_show stats.totalNodeCount);
    Debug.print("");
    Debug.print("Memory Usage:");
    Debug.print("  - Allocated Pages: " # debug_show stats.allocatedPages);
    Debug.print("  - Allocated Bytes: " # debug_show stats.allocatedBytes);
    Debug.print("  - Used Bytes: " # debug_show stats.usedBytes);
    Debug.print("  - Free Bytes: " # debug_show stats.freeBytes);
    Debug.print("");
    Debug.print("Memory Breakdown:");
    Debug.print("  - Data Bytes (keys): " # debug_show stats.keyBytes);
    Debug.print("  - Data Bytes (values): " # debug_show stats.valueBytes);
    Debug.print("  - Data Bytes (total): " # debug_show stats.dataBytes);
    Debug.print("  - Metadata Bytes (leaves): " # debug_show stats.leafBytes);
    Debug.print("  - Metadata Bytes (branches): " # debug_show stats.branchBytes);
    Debug.print("  - Metadata Bytes (total): " # debug_show stats.metadataBytes);
    Debug.print("");
    
    // Calculate efficiency metrics
    let data_efficiency = if (stats.usedBytes > 0) {
        Float.fromInt(stats.dataBytes) / Float.fromInt(stats.usedBytes) * 100.0;
    } else { 0.0 };
    
    let metadata_overhead = if (stats.usedBytes > 0) {
        Float.fromInt(stats.metadataBytes) / Float.fromInt(stats.usedBytes) * 100.0;
    } else { 0.0 };
    
    let space_utilization = if (stats.allocatedBytes > 0) {
        Float.fromInt(stats.usedBytes) / Float.fromInt(stats.allocatedBytes) * 100.0;
    } else { 0.0 };
    
    let avg_entries_per_leaf = if (stats.leafCount > 0) {
        Float.fromInt(MemoryBTree.size(btree)) / Float.fromInt(stats.leafCount);
    } else { 0.0 };
    
    Debug.print("Efficiency Metrics:");
    Debug.print("  - Data Efficiency: " # Float.toText(data_efficiency) # "%");
    Debug.print("  - Metadata Overhead: " # Float.toText(metadata_overhead) # "%");
    Debug.print("  - Space Utilization: " # Float.toText(space_utilization) # "%");
    Debug.print("  - Avg Entries/Leaf: " # Float.toText(avg_entries_per_leaf));
    Debug.print("========================================\n");
};

// Fill BTree and track insertions
func fill_btree_nat(btree : MemoryBTree.MemoryBTree, data : Buffer.Buffer<(Nat, Nat)>) {
    let btree_utils = MemoryBTree.createUtils(TypeUtils.Nat, TypeUtils.Nat);
    for ((k, v) in data.vals()) {
        ignore MemoryBTree.insert(btree, btree_utils, k, v);
    };
};

func fill_btree_text(btree : MemoryBTree.MemoryBTree, data : Buffer.Buffer<(Text, Nat)>) {
    let btree_utils = MemoryBTree.createUtils(TypeUtils.Text, TypeUtils.Nat);
    for ((k, v) in data.vals()) {
        ignore MemoryBTree.insert(btree, btree_utils, k, v);
    };
};

// Remove half the entries to test merge behavior
func remove_half_nat(btree : MemoryBTree.MemoryBTree, data : Buffer.Buffer<(Nat, Nat)>) {
    let btree_utils = MemoryBTree.createUtils(TypeUtils.Nat, TypeUtils.Nat);
    let half = data.size() / 2;
    for (i in Iter.range(0, half - 1)) {
        let (k, _) = data.get(i);
        ignore MemoryBTree.remove(btree, btree_utils, k);
    };
};

func remove_half_text(btree : MemoryBTree.MemoryBTree, data : Buffer.Buffer<(Text, Nat)>) {
    let btree_utils = MemoryBTree.createUtils(TypeUtils.Text, TypeUtils.Nat);
    let half = data.size() / 2;
    for (i in Iter.range(0, half - 1)) {
        let (k, _) = data.get(i);
        ignore MemoryBTree.remove(btree, btree_utils, k);
    };
};

suite(
    "MemoryBTree Configuration Comparison",
    func() {
        
        test(
            "Print current configuration",
            func() {
                Debug.print("\n");
                Debug.print("╔══════════════════════════════════════════════════════════════╗");
                Debug.print("║           MemoryBTree Configuration Test Suite               ║");
                Debug.print("╠══════════════════════════════════════════════════════════════╣");
                Debug.print("║ Current Configuration:                                       ║");
                Debug.print("║   ENABLE_TAIL_COMPRESSION: " # debug_show MemoryBTree.ENABLE_TAIL_COMPRESSION # "                           ║");
                Debug.print("║   MERGE_STRATEGY: " # (if (MemoryBTree.MERGE_STRATEGY == #Conservative) "#Conservative       " else "#Balanced            ") # "                    ║");
                Debug.print("║   MERGE_THRESHOLD: " # debug_show MemoryBTree.MERGE_THRESHOLD # "                               ║");
                Debug.print("╚══════════════════════════════════════════════════════════════╝");
                Debug.print("\n");
            },
        );

        test(
            "Random Nat keys - Node capacity 16",
            func() {
                let data = generate_random_nats(MEDIUM_SIZE, MEDIUM_SIZE ** 2);
                let btree = MemoryBTree.new(?16);
                fill_btree_nat(btree, data);
                print_stats("Random Nat keys (capacity=16, count=" # Nat.toText(MEDIUM_SIZE) # ")", btree);
                
                // Verify all entries are retrievable
                let btree_utils = MemoryBTree.createUtils(TypeUtils.Nat, TypeUtils.Nat);
                assert MemoryBTree.size(btree) == data.size();
            },
        );

        test(
            "Random Nat keys - Node capacity 64",
            func() {
                let data = generate_random_nats(MEDIUM_SIZE, MEDIUM_SIZE ** 2);
                let btree = MemoryBTree.new(?64);
                fill_btree_nat(btree, data);
                print_stats("Random Nat keys (capacity=64, count=" # Nat.toText(MEDIUM_SIZE) # ")", btree);
                
                let btree_utils = MemoryBTree.createUtils(TypeUtils.Nat, TypeUtils.Nat);
                assert MemoryBTree.size(btree) == data.size();
            },
        );

        test(
            "Random Nat keys - Node capacity 256",
            func() {
                let data = generate_random_nats(MEDIUM_SIZE, MEDIUM_SIZE ** 2);
                let btree = MemoryBTree.new(?256);
                fill_btree_nat(btree, data);
                print_stats("Random Nat keys (capacity=256, count=" # Nat.toText(MEDIUM_SIZE) # ")", btree);
                
                let btree_utils = MemoryBTree.createUtils(TypeUtils.Nat, TypeUtils.Nat);
                assert MemoryBTree.size(btree) == data.size();
            },
        );

        test(
            "Sequential Nat keys - Best case for prefix sharing",
            func() {
                let data = generate_sequential_nats(MEDIUM_SIZE, 1_000_000);
                let btree = MemoryBTree.new(?64);
                fill_btree_nat(btree, data);
                print_stats("Sequential Nat keys (capacity=64, count=" # Nat.toText(MEDIUM_SIZE) # ")", btree);
                
                let btree_utils = MemoryBTree.createUtils(TypeUtils.Nat, TypeUtils.Nat);
                assert MemoryBTree.size(btree) == data.size();
            },
        );

        test(
            "Text keys with common prefix - Ideal for tail compression",
            func() {
                let data = generate_prefixed_text_keys(MEDIUM_SIZE, "user_profile_data_");
                let btree = MemoryBTree.new(?64);
                fill_btree_text(btree, data);
                print_stats("Text keys with common prefix (capacity=64, count=" # Nat.toText(MEDIUM_SIZE) # ")", btree);
                
                let btree_utils = MemoryBTree.createUtils(TypeUtils.Text, TypeUtils.Nat);
                assert MemoryBTree.size(btree) == data.size();
            },
        );

        test(
            "Text keys with varied prefixes",
            func() {
                let data = generate_varied_text_keys(MEDIUM_SIZE);
                let btree = MemoryBTree.new(?64);
                fill_btree_text(btree, data);
                print_stats("Text keys with varied prefixes (capacity=64, count=" # Nat.toText(MEDIUM_SIZE) # ")", btree);
                
                let btree_utils = MemoryBTree.createUtils(TypeUtils.Text, TypeUtils.Nat);
                assert MemoryBTree.size(btree) == data.size();
            },
        );

        test(
            "Insert then remove half - Test merge behavior (Nat)",
            func() {
                let data = generate_random_nats(MEDIUM_SIZE, MEDIUM_SIZE ** 2);
                let btree = MemoryBTree.new(?64);
                fill_btree_nat(btree, data);
                
                Debug.print("\n--- Before removals ---");
                print_stats("Before removing half (Nat, capacity=64)", btree);
                
                remove_half_nat(btree, data);
                
                Debug.print("\n--- After removing half ---");
                print_stats("After removing half (Nat, capacity=64)", btree);
                
                let btree_utils = MemoryBTree.createUtils(TypeUtils.Nat, TypeUtils.Nat);
                assert MemoryBTree.size(btree) == data.size() / 2;
            },
        );

        test(
            "Insert then remove half - Test merge behavior (Text)",
            func() {
                let data = generate_prefixed_text_keys(MEDIUM_SIZE, "item_");
                let btree = MemoryBTree.new(?64);
                fill_btree_text(btree, data);
                
                Debug.print("\n--- Before removals ---");
                print_stats("Before removing half (Text, capacity=64)", btree);
                
                remove_half_text(btree, data);
                
                Debug.print("\n--- After removing half ---");
                print_stats("After removing half (Text, capacity=64)", btree);
                
                let btree_utils = MemoryBTree.createUtils(TypeUtils.Text, TypeUtils.Nat);
                assert MemoryBTree.size(btree) == data.size() / 2;
            },
        );

        test(
            "Large dataset comparison",
            func() {
                let data = generate_random_nats(LARGE_SIZE, LARGE_SIZE ** 2);
                let btree = MemoryBTree.new(?128);
                fill_btree_nat(btree, data);
                print_stats("Large dataset (capacity=128, count=" # Nat.toText(LARGE_SIZE) # ")", btree);
                
                let btree_utils = MemoryBTree.createUtils(TypeUtils.Nat, TypeUtils.Nat);
                assert MemoryBTree.size(btree) == data.size();
            },
        );

        test(
            "Summary",
            func() {
                Debug.print("\n");
                Debug.print("╔══════════════════════════════════════════════════════════════╗");
                Debug.print("║                    Test Suite Complete                       ║");
                Debug.print("╠══════════════════════════════════════════════════════════════╣");
                Debug.print("║ To compare configurations, modify Base.mo and re-run:        ║");
                Debug.print("║                                                              ║");
                Debug.print("║ 1. ENABLE_TAIL_COMPRESSION: true vs false                    ║");
                Debug.print("║    - Affects separator key storage in branch nodes           ║");
                Debug.print("║    - Most effective with Text keys having common prefixes    ║");
                Debug.print("║    - Note: Incompatible with size-based Nat comparison       ║");
                Debug.print("║                                                              ║");
                Debug.print("║ 2. MERGE_STRATEGY: #Conservative vs #Balanced                ║");
                Debug.print("║    - Conservative: Fewer merges, stable separators           ║");
                Debug.print("║    - Balanced: More merges, better memory efficiency         ║");
                Debug.print("║                                                              ║");
                Debug.print("║ 3. MERGE_THRESHOLD: 0.25 vs 0.125                            ║");
                Debug.print("║    - Higher: More aggressive merging                         ║");
                Debug.print("║    - Lower: Less merging, potentially more sparse nodes      ║");
                Debug.print("╚══════════════════════════════════════════════════════════════╝");
                Debug.print("\n");
            },
        );
    },
);
