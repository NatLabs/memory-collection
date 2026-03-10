// @testmode wasi
import { test; suite } "mo:test";
import Debug "mo:base@0.14.13/Debug";
import Iter "mo:base@0.14.13/Iter";
import Nat "mo:base@0.14.13/Nat";
import Blob "mo:base@0.14.13/Blob";
import Text "mo:base@0.14.13/Text";

import MemoryBTree "../../../src/MemoryBTree/Base";
import Leaf "../../../src/MemoryBTree/modules/Leaf";
import MemoryBlock "../../../src/MemoryBTree/modules/MemoryBlock";
import Common "../../../src/MemoryBTree/modules/Common";

/// Helper to convert text to blob for test keys
func textToBlob(t : Text) : Blob {
    Text.encodeUtf8(t);
};

/// Helper to insert a key-value pair into a leaf
func insertKey(btree : MemoryBTree.MemoryBTree, leaf_address : Nat, index : Nat, key : Text, val : Text) {
    let id = MemoryBlock.store(btree, textToBlob(key), textToBlob(val));
    Leaf.insert(btree, leaf_address, index, id);
};

suite(
    "Leaf Module Tests",
    func() {
        suite(
            "get_optimal_split_position",
            func() {
                test(
                    "finds split with smallest prefix (aaa09 vs aaa10 boundary)",
                    func() {
                        // Setup: 16 keys where aaa00-aaa09 share "aaa0" prefix, aaa10-aaa15 share "aaa1"
                        // The smallest prefix is between aaa09 and aaa10 (only "aaa" in common)
                        let btree = MemoryBTree.new(?16);
                        let leaf_address = Leaf.new(btree);

                        let keys = [
                            "aaa00",
                            "aaa01",
                            "aaa02",
                            "aaa03",
                            "aaa04",
                            "aaa05",
                            "aaa06",
                            "aaa07",
                            "aaa08",
                            "aaa09",
                            "aaa10",
                            "aaa11",
                            "aaa12",
                            "aaa13",
                            "aaa14",
                            "aaa15",
                        ];
                        let vals = [
                            "v00",
                            "v01",
                            "v02",
                            "v03",
                            "v04",
                            "v05",
                            "v06",
                            "v07",
                            "v08",
                            "v09",
                            "v10",
                            "v11",
                            "v12",
                            "v13",
                            "v14",
                            "v15",
                        ];

                        for (i in Iter.range(0, 15)) {
                            insertKey(btree, leaf_address, i, keys[i], vals[i]);
                        };

                        // New key "aaa08x" would be inserted at position 9 (after aaa08, before aaa09)
                        let new_key = textToBlob("aaa08x");
                        let elem_index = 9;

                        let optimal = Leaf.get_optimal_split_position(btree, leaf_address, elem_index, new_key);

                        // Virtual layout: aaa00..aaa08, aaa08x(NEW), aaa09, aaa10..aaa15
                        // Best split is between aaa09 (virtual 10) and aaa10 (virtual 11) - prefix "aaa" (3 chars)
                        // Returns virtual index 11 (left gets 11 elements, right gets 6)
                        Debug.print("optimal (virtual index): " # debug_show (optimal));
                        assert optimal == 11;
                    },
                );

                test(
                    "prefers split at prefix boundary (aaa vs bbb)",
                    func() {
                        // Setup: 8 "aaa" keys followed by 8 "bbb" keys
                        let btree = MemoryBTree.new(?16);
                        let leaf_address = Leaf.new(btree);

                        let keys = [
                            "aaa00",
                            "aaa01",
                            "aaa02",
                            "aaa03",
                            "aaa04",
                            "aaa05",
                            "aaa06",
                            "aaa07",
                            "bbb08",
                            "bbb09",
                            "bbb10",
                            "bbb11",
                            "bbb12",
                            "bbb13",
                            "bbb14",
                            "bbb15",
                        ];
                        let vals = [
                            "v00",
                            "v01",
                            "v02",
                            "v03",
                            "v04",
                            "v05",
                            "v06",
                            "v07",
                            "v08",
                            "v09",
                            "v10",
                            "v11",
                            "v12",
                            "v13",
                            "v14",
                            "v15",
                        ];

                        for (i in Iter.range(0, 15)) {
                            insertKey(btree, leaf_address, i, keys[i], vals[i]);
                        };

                        // New key "aaa05x" inserted at position 6 (after aaa05, before aaa06)
                        let new_key = textToBlob("aaa05x");
                        let elem_index = 6;

                        let optimal = Leaf.get_optimal_split_position(btree, leaf_address, elem_index, new_key);

                        // The best split is between "aaa07" and "bbb08" (prefix length = 0)
                        // Virtual index 9 is where bbb08 starts (after aaa00-aaa07 + new_key)
                        // Returns virtual index 9 (left gets 9 elements, right gets 8)
                        Debug.print("optimal (virtual index): " # debug_show (optimal));
                        assert optimal == 9;
                    },
                );

                test(
                    "prefers split at prefix boundary with aaa08 insertion",
                    func() {
                        // Setup: 8 "aaa" keys followed by 8 "bbb" keys
                        let btree = MemoryBTree.new(?16);
                        let leaf_address = Leaf.new(btree);

                        let keys = [
                            "aaa00",
                            "aaa01",
                            "aaa02",
                            "aaa03",
                            "aaa04",
                            "aaa05",
                            "aaa06",
                            "aaa07",
                            "bbb08",
                            "bbb09",
                            "bbb10",
                            "bbb11",
                            "bbb12",
                            "bbb13",
                            "bbb14",
                            "bbb15",
                        ];
                        let vals = [
                            "v00",
                            "v01",
                            "v02",
                            "v03",
                            "v04",
                            "v05",
                            "v06",
                            "v07",
                            "v08",
                            "v09",
                            "v10",
                            "v11",
                            "v12",
                            "v13",
                            "v14",
                            "v15",
                        ];

                        for (i in Iter.range(0, 15)) {
                            insertKey(btree, leaf_address, i, keys[i], vals[i]);
                        };

                        // New key "aaa08" inserted at position 8 (after aaa07, before bbb08)
                        let new_key = textToBlob("aaa08");
                        let elem_index = 8;

                        let optimal = Leaf.get_optimal_split_position(btree, leaf_address, elem_index, new_key);

                        // Virtual: aaa00-aaa07, aaa08(NEW), bbb08-bbb15
                        // Best split is between aaa08 (virtual 8) and bbb08 (virtual 9) - prefix length = 0
                        // Returns virtual index 9 (left gets 9 elements, right gets 8)
                        Debug.print("optimal (virtual index): " # debug_show (optimal));
                        assert optimal == 9;
                    },
                );

                test(
                    "prefers split at prefix boundary with bbb07 insertion",
                    func() {
                        // Setup: 8 "aaa" keys followed by 8 "bbb" keys
                        let btree = MemoryBTree.new(?16);
                        let leaf_address = Leaf.new(btree);

                        let keys = [
                            "aaa00",
                            "aaa01",
                            "aaa02",
                            "aaa03",
                            "aaa04",
                            "aaa05",
                            "aaa06",
                            "aaa07",
                            "bbb08",
                            "bbb09",
                            "bbb10",
                            "bbb11",
                            "bbb12",
                            "bbb13",
                            "bbb14",
                            "bbb15",
                        ];
                        let vals = [
                            "v00",
                            "v01",
                            "v02",
                            "v03",
                            "v04",
                            "v05",
                            "v06",
                            "v07",
                            "v08",
                            "v09",
                            "v10",
                            "v11",
                            "v12",
                            "v13",
                            "v14",
                            "v15",
                        ];

                        for (i in Iter.range(0, 15)) {
                            insertKey(btree, leaf_address, i, keys[i], vals[i]);
                        };

                        // New key "bbb07" inserted at position 8 (after aaa07, before bbb08)
                        let new_key = textToBlob("bbb07");
                        let elem_index = 8;

                        let optimal = Leaf.get_optimal_split_position(btree, leaf_address, elem_index, new_key);

                        // Virtual: aaa00-aaa07, bbb07(NEW), bbb08-bbb15
                        // Best split is between aaa07 (virtual 7) and bbb07 (virtual 8) - prefix length = 0
                        // Returns virtual index 8 (left gets 8 elements, right gets 9)
                        Debug.print("optimal (virtual index): " # debug_show (optimal));
                        assert optimal == 8;
                    },
                );

                test(
                    "handles new key at beginning (elem_index = 0)",
                    func() {
                        let btree = MemoryBTree.new(?16);
                        let leaf_address = Leaf.new(btree);

                        // All keys have same structure, smallest prefix is at bbb09/bbb10 boundary
                        let keys = [
                            "bbb00",
                            "bbb01",
                            "bbb02",
                            "bbb03",
                            "bbb04",
                            "bbb05",
                            "bbb06",
                            "bbb07",
                            "bbb08",
                            "bbb09",
                            "bbb10",
                            "bbb11",
                            "bbb12",
                            "bbb13",
                            "bbb14",
                            "bbb15",
                        ];
                        let vals = [
                            "v00",
                            "v01",
                            "v02",
                            "v03",
                            "v04",
                            "v05",
                            "v06",
                            "v07",
                            "v08",
                            "v09",
                            "v10",
                            "v11",
                            "v12",
                            "v13",
                            "v14",
                            "v15",
                        ];

                        for (i in Iter.range(0, 15)) {
                            insertKey(btree, leaf_address, i, keys[i], vals[i]);
                        };

                        // New key "aaa00" at beginning (elem_index = 0)
                        let new_key = textToBlob("aaa00");
                        let elem_index = 0;

                        let optimal = Leaf.get_optimal_split_position(btree, leaf_address, elem_index, new_key);

                        // Virtual: aaa00(NEW), bbb00..bbb09, bbb10..bbb15
                        // Best split between bbb09 (virtual 10) and bbb10 (virtual 11)
                        // Returns virtual index 11 (left gets 11 elements, right gets 6)
                        Debug.print("optimal (virtual index): " # debug_show (optimal));
                        assert optimal == 11;
                    },
                );

                test(
                    "handles new key at end (elem_index = 16)",
                    func() {
                        let btree = MemoryBTree.new(?16);
                        let leaf_address = Leaf.new(btree);

                        let keys = [
                            "key00",
                            "key01",
                            "key02",
                            "key03",
                            "key04",
                            "key05",
                            "key06",
                            "key07",
                            "key08",
                            "key09",
                            "key10",
                            "key11",
                            "key12",
                            "key13",
                            "key14",
                            "key15",
                        ];
                        let vals = [
                            "v00",
                            "v01",
                            "v02",
                            "v03",
                            "v04",
                            "v05",
                            "v06",
                            "v07",
                            "v08",
                            "v09",
                            "v10",
                            "v11",
                            "v12",
                            "v13",
                            "v14",
                            "v15",
                        ];

                        for (i in Iter.range(0, 15)) {
                            insertKey(btree, leaf_address, i, keys[i], vals[i]);
                        };

                        // New key "zzz99" at end (elem_index = 16)
                        let new_key = textToBlob("zzz99");
                        let elem_index = 16;

                        let optimal = Leaf.get_optimal_split_position(btree, leaf_address, elem_index, new_key);

                        // Virtual: key00..key09, key10..key15, zzz99(NEW)
                        // Best split between key09 (virtual 9) and key10 (virtual 10) - prefix "key" (3 chars)
                        // Returns virtual index 10 (left gets 10 elements, right gets 7)
                        Debug.print("optimal (virtual index): " # debug_show (optimal));
                        assert optimal == 10;
                    },
                );

                test(
                    "single transition point (aaa vs bbb boundary)",
                    func() {
                        // Based on discussion example 1: single clear transition
                        let btree = MemoryBTree.newWithOptions({ MemoryBTree.defaultOptions with merge_threshold = ?0.25; node_capacity = ?8});
                        let leaf_address = Leaf.new(btree);

                        let keys = ["aaa", "aab", "aba", "abb", "baa", "bab", "bba", "bbb"];
                        let vals = ["v0", "v1", "v2", "v3", "v4", "v5", "v6", "v7"];

                        for (i in Iter.range(0, 7)) {
                            insertKey(btree, leaf_address, i, keys[i], vals[i]);
                        };

                        // Insert "axz" at position 2 (after "aab", before "aba")
                        let new_key = textToBlob("axz");
                        let elem_index = 2;

                        let optimal = Leaf.get_optimal_split_position(btree, leaf_address, elem_index, new_key);

                        // Virtual: aaa, aab, axz(NEW), aba, abb, baa, bab, bba, bbb
                        // Best split is between aba (virtual 3) and abb (virtual 4)
                        // With default 25% threshold: merge_threshold_count = ceil(8 * 0.25) = 2
                        // min_split = 3, max_split = 9 - 2 = 7
                        // Returns virtual index 4 (left gets 4, right gets 5)
                        Debug.print("optimal (virtual index): " # debug_show (optimal));
                        assert optimal == 5;
                    },
                );

                test(
                    "multiple optimal positions (prefer leftmost)",
                    func() {
                        // Based on discussion example 2: multiple positions with same prefix length
                        let btree = MemoryBTree.newWithOptions({ MemoryBTree.defaultOptions with merge_threshold = ?0.25; node_capacity = ?8});
                        let leaf_address = Leaf.new(btree);

                        let keys = ["aa", "ab", "ba", "bb", "ca", "cb", "da", "db"];
                        let vals = ["v0", "v1", "v2", "v3", "v4", "v5", "v6", "v7"];

                        for (i in Iter.range(0, 7)) {
                            insertKey(btree, leaf_address, i, keys[i], vals[i]);
                        };

                        // Insert "ax" at position 2 (after "ab", before "ba")
                        let new_key = textToBlob("ax");
                        let elem_index = 2;

                        let optimal = Leaf.get_optimal_split_position(btree, leaf_address, elem_index, new_key);

                        // Virtual: aa, ab, ax(NEW), ba, bb, ca, cb, da, db
                        // Splits with prefix length 0: between ax-ba, bb-ca, cb-da
                        // Algorithm should prefer leftmost valid position
                        // With default 25% threshold: min_split = 3, max_split = 7
                        // Returns virtual index 4 (left gets 4, right gets 5)
                        Debug.print("optimal (virtual index): " # debug_show (optimal));
                        assert optimal == 3;
                    },
                );

                test(
                    "uniform prefix distribution",
                    func() {
                        // Based on discussion example 3: all keys share common prefix
                        let btree = MemoryBTree.newWithOptions({ MemoryBTree.defaultOptions with merge_threshold = ?0.25; node_capacity = ?8});
                        let leaf_address = Leaf.new(btree);

                        let keys = ["aaa", "aab", "aac", "aad", "aae", "aaf", "aag", "aah"];
                        let vals = ["v0", "v1", "v2", "v3", "v4", "v5", "v6", "v7"];

                        for (i in Iter.range(0, 7)) {
                            insertKey(btree, leaf_address, i, keys[i], vals[i]);
                        };

                        // Insert "aax" at position 2 (after "aab", before "aac")
                        let new_key = textToBlob("aax");
                        let elem_index = 2;

                        let optimal = Leaf.get_optimal_split_position(btree, leaf_address, elem_index, new_key);

                        // Virtual: aaa, aab, aax(NEW), aac, aad, aae, aaf, aag, aah
                        // All adjacent pairs have prefix "aa" (length 2)
                        // Algorithm will converge to leftmost valid position
                        // With default 25% threshold: min_split = 3, max_split = 7
                        // Should return virtual index 2 (left gets 2, right gets 7)
                        Debug.print("optimal (virtual index): " # debug_show (optimal));
                        assert optimal == 3;
                    },
                );

                test(
                    "mixed prefix patterns",
                    func() {
                        // Based on discussion example 4: combination of patterns
                        let btree = MemoryBTree.newWithOptions({ MemoryBTree.defaultOptions with merge_threshold = ?0.25; node_capacity = ?8});
                        let leaf_address = Leaf.new(btree);

                        let keys = ["aaa", "aab", "aac", "baa", "bab", "bac", "bad", "bae"];
                        let vals = ["v0", "v1", "v2", "v3", "v4", "v5", "v6", "v7"];

                        for (i in Iter.range(0, 7)) {
                            insertKey(btree, leaf_address, i, keys[i], vals[i]);
                        };

                        // Insert "aax" at position 3 (after "aac", before "baa")
                        let new_key = textToBlob("aax");
                        let elem_index = 3;

                        let optimal = Leaf.get_optimal_split_position(btree, leaf_address, elem_index, new_key);

                        // Virtual: aaa, aab, aac, aax(NEW), baa, bab, bac, bad, bae
                        // Best split is between aax (virtual 3) and baa (virtual 4) - prefix length 0
                        // With default 25% threshold: min_split = 3, max_split = 7
                        // Returns virtual index 4 (left gets 4, right gets 5)
                        Debug.print("optimal (virtual index): " # debug_show (optimal));
                        assert optimal == 4;
                    },
                );

                test(
                     "respects 50% merge threshold bounds",
                    func() {
                        // Verify binary search gives same result as linear scan would
                        let btree = MemoryBTree.newWithOptions({ MemoryBTree.defaultOptions with merge_threshold = ?0.5; node_capacity = ?16});
                        let leaf_address = Leaf.new(btree);

                        let keys = [
                            "key00",
                            "key01",
                            "key02",
                            "key03",
                            "key04",
                            "key05",
                            "key06",
                            "key07",
                            "key08",
                            "key09",
                            "key10",
                            "key11",
                            "key12",
                            "key13",
                            "key14",
                            "key15",
                        ];
                        let vals = [
                            "v00",
                            "v01",
                            "v02",
                            "v03",
                            "v04",
                            "v05",
                            "v06",
                            "v07",
                            "v08",
                            "v09",
                            "v10",
                            "v11",
                            "v12",
                            "v13",
                            "v14",
                            "v15",
                        ];

                        for (i in Iter.range(0, 15)) {
                            insertKey(btree, leaf_address, i, keys[i], vals[i]);
                        };

                        let new_key = textToBlob("key08x");
                        let elem_index = 8;

                        let optimal = Leaf.get_optimal_split_position(btree, leaf_address, elem_index, new_key );

                        // With 50% threshold: merge_threshold_count = ceil(16 * 0.5) = 8
                        // min_split = 9, max_split = 17 - 8 = 9
                        // Only valid virtual position is 9
                        // Returns virtual index 9 (left gets 9 elements, right gets 8)
                        Debug.print("optimal (virtual index): " # debug_show (optimal));
                        assert optimal == 9;
                    },
                );

                test(
                    "Common.get_prefix_length works correctly",
                    func() {
                        assert Common.get_prefix_length(textToBlob("hello"), textToBlob("help")) == 3;
                        assert Common.get_prefix_length(textToBlob("abc"), textToBlob("abc")) == 3;
                        assert Common.get_prefix_length(textToBlob("abc"), textToBlob("xyz")) == 0;
                        assert Common.get_prefix_length(textToBlob(""), textToBlob("abc")) == 0;
                        assert Common.get_prefix_length(textToBlob("prefix_a"), textToBlob("prefix_b")) == 7;
                    },
                );

                test(
                    "split preserves all 17 keys after split",
                    func() {
                        let btree = MemoryBTree.new(?16);
                        let leaf_address = Leaf.new(btree);

                        let keys = [
                            "key00",
                            "key01",
                            "key02",
                            "key03",
                            "key04",
                            "key05",
                            "key06",
                            "key07",
                            "key08",
                            "key09",
                            "key10",
                            "key11",
                            "key12",
                            "key13",
                            "key14",
                            "key15",
                        ];
                        let vals = [
                            "v00",
                            "v01",
                            "v02",
                            "v03",
                            "v04",
                            "v05",
                            "v06",
                            "v07",
                            "v08",
                            "v09",
                            "v10",
                            "v11",
                            "v12",
                            "v13",
                            "v14",
                            "v15",
                        ];

                        for (i in Iter.range(0, 15)) {
                            insertKey(btree, leaf_address, i, keys[i], vals[i]);
                        };

                        // Insert "key07x" at position 8 (after key07, before key08)
                        let new_key = textToBlob("key07x");
                        let new_val = textToBlob("vNEW");
                        let new_id = MemoryBlock.store(btree, new_key, new_val);
                        let elem_index = 8;

                        let right_leaf = Leaf.split(btree, leaf_address, elem_index, new_id);

                        let left_count = Leaf.get_count(btree, leaf_address);
                        let right_count = Leaf.get_count(btree, right_leaf);

                        Debug.print("left_count: " # debug_show (left_count));
                        Debug.print("right_count: " # debug_show (right_count));

                        // Optimal split returns virtual index 11 (between key09 and key10)
                        // This means: left gets 11 elements, right gets 6 elements
                        // elem_index 8 < median 11, so new element goes to left
                        // Left: key00-key09 (10 original) + key07x (1 new) = 11 elements
                        // Right: key10-key15 = 6 elements
                        assert left_count == 11;
                        assert right_count == 6;

                        // Total must be 17 (16 original + 1 new)
                        assert left_count + right_count == 17;
                    },
                );
            },
        );
    },
);
