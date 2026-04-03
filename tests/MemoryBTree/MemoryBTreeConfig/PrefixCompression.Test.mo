// @testmode wasi
/// Test file for Prefix Compression performance
/// 
/// Run: mops test --testmode wasi btree.config

import { test; suite } "mo:test";
import Debug "mo:core@2.4/Debug";
import Nat "mo:core@2.4/Nat";
import Float "mo:core@2.4/Float";
import Iter "mo:core@2.4/Iter";
import Buffer "mo:base@0.16/Buffer";

import Fuzz "mo:fuzz";
import MemoryBTree "../../../src/MemoryBTree/Base";
import Utils "./Utils";

suite(
    "Prefix Compression Tests",
    func() {
        let fuzz = Fuzz.fromSeed(0xdeadbeef);
        
                let data = Utils.generate_prefixed_text_keys(fuzz, Utils.DATA_SIZE);
        test(
            "Node Capacity Comparison (Prefix Compression DISABLED)",
            func() {
                
                Utils.print_table_header(
                    "Node Capacity Stats - Prefix Compression: DISABLED (" # Nat.toText(Utils.DATA_SIZE) # " entries)",
                    ["Depth", "Leaves", "Branches", "Allocated", "Used", "Key Bytes", "Metadata"]
                );
                
                for (capacity in Utils.NODE_CAPACITIES.vals()) {
                    let btree = MemoryBTree.newWithOptions({ 
                        MemoryBTree.defaultOptions with 
                        node_capacity = ?capacity; 
                        is_prefix_compression_enabled = ?false 
                    });
                    Utils.fill_btree(btree, data);
                    let stats = Utils.collect_stats(btree);
                    Utils.print_stats_row("capacity=" # Nat.toText(capacity), stats);
                    
                    // Verify correctness
                    assert MemoryBTree.size(btree) == data.size();
                };
                
                Debug.print("");
            },
        );

        test(
            "Node Capacity Comparison (Prefix Compression ENABLED)",
            func() {
                
                Utils.print_table_header(
                    "Node Capacity Stats - Prefix Compression: ENABLED (" # Nat.toText(Utils.DATA_SIZE) # " entries)",
                    ["Depth", "Leaves", "Branches", "Allocated", "Used", "Key Bytes", "Metadata"]
                );
                
                for (capacity in Utils.NODE_CAPACITIES.vals()) {
                    let btree = MemoryBTree.newWithOptions({ 
                        MemoryBTree.defaultOptions with 
                        node_capacity = ?capacity; 
                        is_prefix_compression_enabled = ?true 
                    });
                    Utils.fill_btree(btree, data);
                    let stats = Utils.collect_stats(btree);
                    Utils.print_stats_row("capacity=" # Nat.toText(capacity), stats);
                    
                    // Verify correctness
                    assert MemoryBTree.size(btree) == data.size();
                };
                
                Debug.print("");
            },
        );

        test(
            "Merge Threshold Comparison (Prefix Compression DISABLED)",
            func() {
                
                Debug.print("\n");
                Debug.print("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓");
                Debug.print("┃ Merge Threshold Stats - Prefix Compression: DISABLED (After Insert + Remove Half) ┃");
                Debug.print("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛");
                Debug.print("");
                
                let test_capacity = 256;
                
                var header = "| " # Utils.pad_left("merge_threshold", 20) # " |";
                let cols = ["Depth", "Leaves", "Branches", "Allocated", "Used", "Key Bytes", "Metadata"];
                for (col in cols.vals()) {
                    header := header # " " # Utils.pad_right(col, 12) # " |";
                };
                
                Debug.print("After Insert (" # Nat.toText(Utils.DATA_SIZE) # " entries, capacity=" # Nat.toText(test_capacity) # "):");
                Debug.print(header);
                var separator = "|" # Utils.repeat_char('-', 22) # "|";
                for (_ in cols.vals()) {
                    separator := separator # Utils.repeat_char('-', 14) # "|";
                };
                Debug.print(separator);
                
                let btrees = Buffer.Buffer<(Float, MemoryBTree.MemoryBTree)>(3);
                
                for (threshold in Utils.MERGE_THRESHOLDS.vals()) {
                    let btree = MemoryBTree.newWithOptions({ 
                        MemoryBTree.defaultOptions with 
                        node_capacity = ?test_capacity;
                        merge_threshold = ?threshold;
                        is_prefix_compression_enabled = ?false 
                    });
                    Utils.fill_btree(btree, data);
                    let stats = Utils.collect_stats(btree);
                    Utils.print_stats_row("threshold=" # Float.toText(threshold), stats);
                    btrees.add((threshold, btree));
                };
                
                Debug.print("");
                Debug.print("After Remove Half (" # Nat.toText(Utils.DATA_SIZE / 2) # " entries remaining):");
                Debug.print(header);
                Debug.print(separator);
                
                for ((threshold, btree) in btrees.vals()) {
                    Utils.remove_half(btree, data);
                    let stats = Utils.collect_stats(btree);
                    Utils.print_stats_row("threshold=" # Float.toText(threshold), stats);
                    assert MemoryBTree.size(btree) == data.size() / 2;
                };
                
                Debug.print("");
            },
        );

        test(
            "Merge Threshold Comparison (Prefix Compression ENABLED)",
            func() {
                
                Debug.print("\n");
                Debug.print("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓");
                Debug.print("┃ Merge Threshold Stats - Prefix Compression: ENABLED (After Insert + Remove Half) ┃");
                Debug.print("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛");
                Debug.print("");
                
                let test_capacity = 256;
                
                var header = "| " # Utils.pad_left("merge_threshold", 20) # " |";
                let cols = ["Depth", "Leaves", "Branches", "Allocated", "Used", "Key Bytes", "Metadata"];
                for (col in cols.vals()) {
                    header := header # " " # Utils.pad_right(col, 12) # " |";
                };
                
                Debug.print("After Insert (" # Nat.toText(Utils.DATA_SIZE) # " entries, capacity=" # Nat.toText(test_capacity) # "):");
                Debug.print(header);
                var separator = "|" # Utils.repeat_char('-', 22) # "|";
                for (_ in cols.vals()) {
                    separator := separator # Utils.repeat_char('-', 14) # "|";
                };
                Debug.print(separator);
                
                let btrees = Buffer.Buffer<(Float, MemoryBTree.MemoryBTree)>(3);
                
                for (threshold in Utils.MERGE_THRESHOLDS.vals()) {
                    let btree = MemoryBTree.newWithOptions({ 
                        MemoryBTree.defaultOptions with 
                        node_capacity = ?test_capacity;
                        merge_threshold = ?threshold;
                        is_prefix_compression_enabled = ?true 
                    });
                    Utils.fill_btree(btree, data);
                    let stats = Utils.collect_stats(btree);
                    Utils.print_stats_row("threshold=" # Float.toText(threshold), stats);
                    btrees.add((threshold, btree));
                };
                
                Debug.print("");
                Debug.print("After Remove Half (" # Nat.toText(Utils.DATA_SIZE / 2) # " entries remaining):");
                Debug.print(header);
                Debug.print(separator);
                
                for ((threshold, btree) in btrees.vals()) {
                    Utils.remove_half(btree, data);
                    let stats = Utils.collect_stats(btree);
                    Utils.print_stats_row("threshold=" # Float.toText(threshold), stats);
                    assert MemoryBTree.size(btree) == data.size() / 2;
                };
                
                Debug.print("");
            },
        );
    },
);
