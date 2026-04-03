import { test; suite } "mo:test";
import Debug "mo:core@2.4/Debug";
import Iter "mo:core@2.4/Iter";
import Buffer "mo:base@0.16/Buffer";
import Nat "mo:core@2.4/Nat";
import Text "mo:core@2.4/Text";
import Order "mo:core@2.4/Order";

import Fuzz "mo:fuzz";
import Itertools "mo:itertools@0.2/Iter";
import Map "mo:map/Map";
import MemoryRegion "mo:memory-region@1.5/MemoryRegion";

import MemoryBTree "../../../src/MemoryBTree/Base";
import TypeUtils "../../../src/TypeUtils";
import Utils "../../../src/Utils";
import Branch "../../../src/MemoryBTree/modules/Branch";
import Leaf "../../../src/MemoryBTree/modules/Leaf";
import Methods "../../../src/MemoryBTree/modules/Methods";
import ConfigUtils "../MemoryBTreeConfig/Utils";

module NodeCapacityTest {
    type Buffer<A> = Buffer.Buffer<A>;
    type Iter<A> = Iter.Iter<A>;
    type Order = Order.Order;
    type MemoryBlock = MemoryBTree.MemoryBlock;

    public type Input = {random: Buffer.Buffer<(Text, Text)>; sorted: Buffer.Buffer<(Text, Text)>};

    public func generate_random_input(limit: Nat): Input {
        let fuzz = Fuzz.fromSeed(0xdeadbeef);
        let random = ConfigUtils.generate_random_text_keys(fuzz, limit);
        let sorted = Buffer.clone(random);
        sorted.sort(func(a : (Text, Text), b : (Text, Text)) : Order = Text.compare(a.0, b.0));
        { random; sorted };
    };

    public func generate_prefixed_input(limit: Nat): Input {
        let fuzz = Fuzz.fromSeed(0xdeadbeef);
        let random = ConfigUtils.generate_prefixed_text_keys(fuzz, limit);
        let sorted = Buffer.clone(random);
        sorted.sort(func(a : (Text, Text), b : (Text, Text)) : Order = Text.compare(a.0, b.0));
        { random; sorted };
    };


    public func btree_tests(limit: Nat, input: Input, memory_btree_options : MemoryBTree.BTreeOptions) {
        let fuzz = Fuzz.fromSeed(0xdeadbeef);
        
        let btree_utils = MemoryBTree.createUtils(TypeUtils.Text, TypeUtils.Text);

        let btree = MemoryBTree.newWithOptions(memory_btree_options);
        let is_prefix_compression_enabled = switch (memory_btree_options.is_prefix_compression_enabled) {
            case (?enabled) enabled;
            case (null) false;
        };
        Debug.print("BTree config: " # debug_show MemoryBTree.config(btree));

        suite(
            "MemoryBTree",
            func() {
                func insert_random() {
                    test(
                        "insert random",
                        func() {
                            let map = Map.new<Text, Text>();
                            // assert btree.order == 4;

                            Debug.print("Starting insert_random, btree size=" # debug_show MemoryBTree.size(btree));
                            label for_loop for ((idx, (k, v)) in Itertools.enumerate(input.random.vals())) {
                                // Debug.print("inserting " # debug_show k # " at index " # debug_show idx);

                                ignore Map.put(map, Map.thash, k, v);
                                ignore MemoryBTree.insert(btree, btree_utils, k, v);
                                assert MemoryBTree.size(btree) == idx + 1;

                                // Debug.print("keys " # debug_show MemoryBTree.toNodeKeys(btree, btree_utils));
                                // Debug.print("leafs " # debug_show MemoryBTree.toLeafNodes(btree, btree_utils));

                                let subtree_size = if (btree.is_root_a_leaf) Leaf.get_count(btree, btree.root) else Branch.get_subtree_size(btree, btree.root);

                                // Debug.print("subtree_size " # debug_show subtree_size);
                                assert subtree_size == MemoryBTree.size(btree);

                                // Debug.print("(idx, k, v) -> " # debug_show (idx, k, MemoryBTree.get(btree, btree_utils, k)));
                                if (?v != MemoryBTree.get(btree, btree_utils, k)) {
                                    Debug.print("mismatch: " # debug_show (k, (?v, MemoryBTree.get(btree, btree_utils, k))) # " at index " # debug_show idx);
                                    assert false;
                                };

                            };

                            Debug.print("About to validate after all inserts: size=" # debug_show MemoryBTree.size(btree) # ", leaf_count=" # debug_show MemoryBTree.leafCount(btree) # ", branch_count=" # debug_show MemoryBTree.branchCount(btree));
                            assert Methods.validate_memory(btree, btree_utils);

                            // Debug.print("entries: " # debug_show Iter.toArray(MemoryBTree.entries(btree, btree_utils)));

                            let entries = MemoryBTree.entries(btree, btree_utils);
                            let entry = Utils.unwrap(entries.next(), "expected key");
                            var prev = entry.0;

                            for ((i, (key, val)) in Itertools.enumerate(entries)) {
                                if (prev > key) {
                                    Debug.print("mismatch: " # debug_show (prev, key) # " at index " # debug_show i);
                                    assert false;
                                };

                                let expected = Map.get(map, Map.thash, key);
                                if (expected != ?val) {
                                    Debug.print("mismatch: " # debug_show (key, (expected, val)) # " at index " # debug_show (i + 1));
                                    assert false;
                                };

                                if (?val != MemoryBTree.get(btree, btree_utils, key)) {
                                    Debug.print("mismatch: " # debug_show (key, (expected, MemoryBTree.get(btree, btree_utils, key))) # " at index " # debug_show (i + 1));
                                    assert false;
                                };

                                prev := key;
                            };

                            assert Methods.validate_memory(btree, btree_utils);
                        },
                    );
                };

                insert_random();
                test(
                    "get()",
                    func() {
                        var i = 0;
                        for ((key, val) in input.random.vals()) {
                            let got = MemoryBTree.get(btree, btree_utils, key);
                            if (?val != got) {
                                Debug.print("mismatch: " # debug_show (val, got) # " at index " # debug_show i);
                                assert false;
                            };
                            i += 1;
                        };
                    },
                );

                test(
                    "getIndex",
                    func() {

                        for (i in Itertools.range(0, input.sorted.size())) {
                            let (key, _) = input.sorted.get(i);

                            let expected = i;
                            let rank = MemoryBTree.getIndex(btree, btree_utils, key);
                            if (not (rank == expected)) {
                                Debug.print("mismatch for key:" # debug_show key);
                                Debug.print("expected != rank: " # debug_show (expected, rank));
                                assert false;
                            };
                        };
                    },
                );

                test(
                    "getExpectedIndex",
                    func() {

                        for (i in Itertools.range(0, input.sorted.size())) {
                            let (key, _) = input.sorted.get(i);

                            let expected = #Found(i);
                            let rank = MemoryBTree.getExpectedIndex(btree, btree_utils, key);

                            if (not (rank == expected)) {
                                Debug.print("getIndex -> " # debug_show (MemoryBTree.getIndex(btree, btree_utils, key)));
                                Debug.print("mismatch for key:" # debug_show key);
                                Debug.print("expected != rank: " # debug_show (expected, rank));
                                assert false;
                            };
                        };
                    },
                );

                test(
                    "getFromIndex",
                    func() {
                        for (i in Itertools.range(0, input.sorted.size())) {
                            let expected = input.sorted.get(i);
                            let received = MemoryBTree.getFromIndex(btree, btree_utils, i);

                            if (not (expected == received)) {
                                Debug.print("mismatch at rank:" # debug_show i);
                                Debug.print("expected != received: " # debug_show (expected, received));
                                assert false;
                            };
                        };
                    },
                );

                test(
                    "getFloor()",
                    func() {

                        for (i in Itertools.range(0, input.sorted.size())) {
                            let (key, _) = input.sorted.get(i);

                            let expected = input.sorted.get(i);
                            let received = MemoryBTree.getFloor(btree, btree_utils, key);

                            if (not (?expected == received)) {
                                Debug.print("equality check failed");
                                Debug.print("mismatch at key:" # debug_show key);
                                Debug.print("expected != received: " # debug_show (expected, received));
                                assert false;
                            };
                        };
                    },
                );

                test(
                    "getCeiling()",
                    func() {
                        for (i in Itertools.range(0, input.sorted.size())) {
                            let key = input.sorted.get(i).0;

                            let expected = input.sorted.get(i);
                            let received = MemoryBTree.getCeiling<Text, Text>(btree, btree_utils, key);

                            if (not (?expected == received)) {
                                Debug.print("equality check failed");
                                Debug.print("mismatch at key:" # debug_show key);
                                Debug.print("expected != received: " # debug_show (expected, received));
                                assert false;
                            };
                        };
                    },
                );
                test(
                    "entries()",
                    func() {
                        var i = 0;
                        for ((a, b) in Itertools.zip(MemoryBTree.entries(btree, btree_utils), input.sorted.vals())) {
                            if (a != b) {
                                Debug.print("mismatch: " # debug_show (a, b) # " at index " # debug_show i);
                                assert false;
                            };
                            i += 1;
                        };

                        assert i == input.sorted.size();

                        assert Methods.validate_memory(btree, btree_utils);

                    },
                );

                test(
                    "scan",
                    func() {
                        let sliding_tuples = Itertools.range(0, MemoryBTree.size(btree))
                        |> Iter.map<Nat, Nat>(_, func(n : Nat) : Nat = n * 100)
                        |> Itertools.takeWhile(_, func(n : Nat) : Bool = n < MemoryBTree.size(btree))
                        |> Itertools.slidingTuples(_);

                        for ((i, j) in sliding_tuples) {
                            let start_key = input.sorted.get(i).0;
                            let end_key = input.sorted.get(j).0;

                            var index = i;

                            for ((k, v) in MemoryBTree.scan<Text, Text>(btree, btree_utils, ?start_key, ?end_key)) {
                                let expected = input.sorted.get(index).0;

                                if (not (expected == k)) {
                                    Debug.print("mismatch: " # debug_show (expected, k));
                                    Debug.print("scan " # debug_show Iter.toArray(MemoryBTree.scan(btree, btree_utils, ?start_key, ?end_key)));

                                    let expected_vals = Nat.rangeInclusive(i, j)
                                    |> Iter.map<Nat, Text>(_, func(n : Nat) : Text = input.sorted.get(n).1);
                                    Debug.print("expected " # debug_show Iter.toArray(expected_vals));
                                    assert false;
                                };

                                index += 1;
                            };
                        };
                    },
                );

                test(
                    "range",
                    func() {
                        let sliding_tuples = Itertools.range(0, MemoryBTree.size(btree))
                        |> Iter.map<Nat, Nat>(_, func(n : Nat) : Nat = n * 100)
                        |> Itertools.takeWhile(_, func(n : Nat) : Bool = n < MemoryBTree.size(btree))
                        |> Itertools.slidingTuples(_);

                        let sorted_array = Buffer.toArray(input.sorted);

                        for ((i, j) in sliding_tuples) {

                            if (
                                not Itertools.equal<(Text, Text)>(
                                    MemoryBTree.range(btree, btree_utils, i, j),
                                    Itertools.fromArraySlice<(Text, Text)>(sorted_array, i, j),
                                    func(a : (Text, Text), b : (Text, Text)) : Bool = a == b,
                                )
                            ) {
                                Debug.print("mismatch: " # debug_show (i, j));
                                Debug.print("range " # debug_show Iter.toArray(MemoryBTree.range(btree, btree_utils, i, j)));
                                Debug.print("expected " # debug_show Iter.toArray(Itertools.fromArraySlice(sorted_array, i, j)));
                                assert false;
                            };
                        };
                    },
                );

                test(
                        "replace",
                        func() {
                            let size = MemoryBTree.size(btree);

                            for ((key, prev_val) in input.random.vals()) {

                                let new_val = "rep_" # prev_val;

                                assert ?prev_val == MemoryBTree.get(btree, btree_utils, key);
                                assert ?prev_val == MemoryBTree.insert(btree, btree_utils, key, new_val);
                                assert ?new_val == MemoryBTree.get(btree, btree_utils, key);

                                assert MemoryBTree.size(btree) == size;
                            };

                            assert Methods.validate_memory(btree, btree_utils);

                            var i = 0;
                            for ((key, _val) in input.random.vals()) {
                                let val = "rep_" # _val;
                                let received = MemoryBTree.get(btree, btree_utils, key);
                                if (?val != received) {
                                    Debug.print("mismatch (recieved, expected) " # debug_show (received, val) # " at index " # debug_show i);
                                    assert false;
                                };
                                i += 1;
                            };
                        },
                    );

                test(
                    "remove() random",
                    func() {

                        assert Methods.validate_memory(btree, btree_utils);

                        for ((idx, (key, v)) in Itertools.enumerate(input.random.vals())) {

                            // Debug.print("node keys: " # debug_show MemoryBTree.toNodeKeys(btree, btree_utils));
                            // Debug.print("btree.leaf_count before toLeafNodes: " # debug_show MemoryBTree.leafCount(btree));

                            // Debug.print("removing " # debug_show key);
                            let expected_val = "rep_" # v;

                            let result = MemoryBTree.get(btree, btree_utils, key);
                            assert ?expected_val == result;

                            let val = MemoryBTree.remove(btree, btree_utils, key);
                            // Debug.print("(idx, val): " # debug_show (idx, val));

                            assert ?expected_val == val;

                            assert MemoryBTree.size(btree) == input.random.size() - idx - 1;
                            // Debug.print("node keys after: " # debug_show MemoryBTree.toNodeKeys(btree, btree_utils));
                            // Debug.print("leaf nodes after: " # debug_show Iter.toArray(MemoryBTree.leafNodes(btree, btree_utils)));


                        };

                        assert Methods.validate_memory(btree, btree_utils);

                        assert MemoryBTree.size(btree) == 0;

                    },

                );

                test(
                    "check for memory leaks",
                    func() {

                        Debug.print("Final memory regions stats:");
                        Debug.print("data: " # debug_show MemoryRegion.memoryInfo(btree.data));
                        Debug.print("values: " # debug_show MemoryRegion.memoryInfo(btree.values));
                        Debug.print("leaves: " # debug_show MemoryRegion.memoryInfo(btree.leaves));
                        Debug.print("branches: " # debug_show MemoryRegion.memoryInfo(btree.branches));

                        // Check `allocated` (not `size`) because MemoryRegion doesn't shrink when memory is deallocated
                        // - `size` = high-water mark (total memory ever used, includes deallocated holes)
                        // - `allocated` = currently in-use memory (what we care about for leak detection)
                        assert MemoryRegion.allocated(btree.data) == MemoryBTree.MC.REGION_HEADER_SIZE;
                        assert MemoryRegion.allocated(btree.values) == MemoryBTree.MC.REGION_HEADER_SIZE;
                        assert MemoryRegion.allocated(btree.leaves) == MemoryBTree.MC.REGION_HEADER_SIZE + MemoryBTree.Leaf.get_memory_size(btree.node_capacity);
                        assert MemoryRegion.allocated(btree.branches) == MemoryBTree.MC.REGION_HEADER_SIZE;

                    },
                );

                test(
                    "clear()",
                    func() {
                        MemoryBTree.clear(btree);
                        assert MemoryBTree.size(btree) == 0;

                        assert Methods.validate_memory(btree, btree_utils);

                        MemoryBTree.clear(btree);
                        assert MemoryBTree.size(btree) == 0;

                        assert Methods.validate_memory(btree, btree_utils);

                        // Check `allocated` (not `size`) - see "check for memory leaks" test for explanation
                        assert MemoryRegion.allocated(btree.data) == MemoryBTree.MC.REGION_HEADER_SIZE;
                        assert MemoryRegion.allocated(btree.values) == MemoryBTree.MC.REGION_HEADER_SIZE;
                        assert MemoryRegion.allocated(btree.leaves) == MemoryBTree.MC.REGION_HEADER_SIZE + MemoryBTree.Leaf.get_memory_size(btree.node_capacity);
                        assert MemoryRegion.allocated(btree.branches) == MemoryBTree.MC.REGION_HEADER_SIZE;

                    },
                );

                 test(
                    "insert random",
                    func() {
                        let map = Map.new<Text, Text>();
                        // assert btree.order == 4;

                        Debug.print("Starting insert_random, btree size=" # debug_show MemoryBTree.size(btree));
                        label for_loop for ((idx, (k, v)) in Itertools.enumerate(input.random.vals())) {
                            // Debug.print("inserting " # debug_show k # " at index " # debug_show idx);

                            ignore Map.put(map, Map.thash, k, v);
                            ignore MemoryBTree.insert(btree, btree_utils, k, v);
                            assert MemoryBTree.size(btree) == idx + 1;

                            // Debug.print("keys " # debug_show MemoryBTree.toNodeKeys(btree, btree_utils));
                            // Debug.print("leafs " # debug_show MemoryBTree.toLeafNodes(btree, btree_utils));

                            let subtree_size = if (btree.is_root_a_leaf) Leaf.get_count(btree, btree.root) else Branch.get_subtree_size(btree, btree.root);

                            // Debug.print("subtree_size " # debug_show subtree_size);
                            assert subtree_size == MemoryBTree.size(btree);

                            // Debug.print("(idx, k, v) -> " # debug_show (idx, k, MemoryBTree.get(btree, btree_utils, k)));
                            if (?v != MemoryBTree.get(btree, btree_utils, k)) {
                                Debug.print("mismatch: " # debug_show (k, (?v, MemoryBTree.get(btree, btree_utils, k))) # " at index " # debug_show idx);
                                assert false;
                            };

                            //  assert Methods.validate_memory(btree, btree_utils);

                        };

                        Debug.print("About to validate after all inserts: size=" # debug_show MemoryBTree.size(btree) # ", leaf_count=" # debug_show MemoryBTree.leafCount(btree) # ", branch_count=" # debug_show MemoryBTree.branchCount(btree));
                        assert Methods.validate_memory(btree, btree_utils);

                        // Debug.print("entries: " # debug_show Iter.toArray(MemoryBTree.entries(btree, btree_utils)));

                        let entries = MemoryBTree.entries(btree, btree_utils);
                        let entry = Utils.unwrap(entries.next(), "expected key");
                        var prev = entry.0;

                        for ((i, (key, val)) in Itertools.enumerate(entries)) {
                            if (prev > key) {
                                Debug.print("mismatch: " # debug_show (prev, key) # " at index " # debug_show i);
                                assert false;
                            };

                            let expected = Map.get(map, Map.thash, key);
                            if (expected != ?val) {
                                Debug.print("mismatch: " # debug_show (key, (expected, val)) # " at index " # debug_show (i + 1));
                                assert false;
                            };

                            if (?val != MemoryBTree.get(btree, btree_utils, key)) {
                                Debug.print("mismatch: " # debug_show (key, (expected, MemoryBTree.get(btree, btree_utils, key))) # " at index " # debug_show (i + 1));
                                assert false;
                            };

                            prev := key;
                        };

                        assert Methods.validate_memory(btree, btree_utils);
                    },
                );


                test(
                    "remove()",
                    func() {

                        // Debug.print("node keys: " # debug_show MemoryBTree.toNodeKeys(btree, btree_utils));
                        // Debug.print("leaf nodes: " # debug_show MemoryBTree.toLeafNodes(btree, btree_utils));

                        for ((idx, (key, v)) in Itertools.enumerate(input.random.vals())) {
                            // Debug.print("removing " # debug_show key);
                            let val = MemoryBTree.remove(btree, btree_utils, key);
                            // Debug.print("(idx, val): " # debug_show (idx, val));
                            assert ?v == val;

                            assert MemoryBTree.size(btree) == input.random.size() - idx - 1;
                            // Debug.print("node keys: " # debug_show MemoryBTree.toNodeKeys(btree, btree_utils));
                            // Debug.print("leaf nodes: " # debug_show Iter.toArray(MemoryBTree.leafNodes(btree, btree_utils)));
                        };

                        assert Methods.validate_memory(btree, btree_utils);

                    },

                );

                test(
                    "clear() after the btree has been re-populated",
                    func() {
                        MemoryBTree.clear(btree);
                        assert MemoryBTree.size(btree) == 0;

                        assert Methods.validate_memory(btree, btree_utils);

                    },

                );

                test(
                    "random ops (insert, replace, remove) - single ops",
                    func() {
                        // Track inserted keys and their values
                        let inserted_keys = Buffer.Buffer<Text>(limit);
                        let map = Map.new<Text, Text>();

                        // Phase 1: Fill the btree up to the limit using the pre-generated random data
                        for ((key, val) in input.random.vals()) {
                            ignore Map.put(map, Map.thash, key, val);
                            ignore MemoryBTree.insert(btree, btree_utils, key, val);
                            inserted_keys.add(key);
                        };

                        let initial_size = MemoryBTree.size(btree);
                        assert initial_size == limit;
                        assert Methods.validate_memory(btree, btree_utils);

                        // Verify all inserted keys are retrievable
                        for ((key, val) in input.random.vals()) {
                            let got = MemoryBTree.get(btree, btree_utils, key);
                            if (?val != got) {
                                Debug.print("Phase 1 verification failed for key " # debug_show key # ": expected " # debug_show val # ", got " # debug_show got);
                                assert false;
                            };
                        };

                        // Phase 2: Random operations for another iteration of the limit size
                        for (i in Nat.rangeInclusive(0, limit - 1)) {
                            let op_type = fuzz.nat.randomRange(0, 2); // 0 = insert, 1 = replace, 2 = remove

                            if (inserted_keys.size() < 3 or op_type == 0) {
                                // Insert a new key
                                let new_key = fuzz.text.randomAlphanumeric(fuzz.nat.randomRange(10, 30)) # "_" # Nat.toText(i);
                                let new_val = "val_" # Nat.toText(i);

                                let prev = MemoryBTree.insert(btree, btree_utils, new_key, new_val);
                                ignore Map.put(map, Map.thash, new_key, new_val);

                                if (prev == null) {
                                    // New key was inserted
                                    inserted_keys.add(new_key);
                                };

                                // Verify the value was set correctly
                                let got = MemoryBTree.get(btree, btree_utils, new_key);
                                if (?new_val != got) {
                                    Debug.print("Insert verification failed for key " # debug_show new_key # ": expected " # debug_show new_val # ", got " # debug_show got);
                                    assert false;
                                };

                            } else if (op_type == 1) {
                                // Replace an existing key's value
                                let idx = fuzz.nat.randomRange(0, inserted_keys.size() - 1);
                                let key = inserted_keys.get(idx);
                                let old_val = Map.get(map, Map.thash, key);
                                let new_val = "rep_" # Nat.toText(i);

                                let prev = MemoryBTree.insert(btree, btree_utils, key, new_val);
                                ignore Map.put(map, Map.thash, key, new_val);

                                // Verify the previous value matches
                                if (prev != old_val) {
                                    Debug.print("Replace returned wrong previous value for key " # debug_show key # ": expected " # debug_show old_val # ", got " # debug_show prev);
                                    assert false;
                                };

                                // Verify the new value is set
                                let got = MemoryBTree.get(btree, btree_utils, key);
                                if (?new_val != got) {
                                    Debug.print("Replace verification failed for key " # debug_show key # ": expected " # debug_show new_val # ", got " # debug_show got);
                                    assert false;
                                };

                            } else {
                                // Remove an existing key
                                let idx = fuzz.nat.randomRange(0, inserted_keys.size() - 1);
                                let key = inserted_keys.get(idx);
                                let expected_val = Map.get(map, Map.thash, key);

                                let removed_val = MemoryBTree.remove(btree, btree_utils, key);
                                ignore Map.remove(map, Map.thash, key);

                                // Verify the removed value matches
                                if (removed_val != expected_val) {
                                    Debug.print("Remove returned wrong value for key " # debug_show key # ": expected " # debug_show expected_val # ", got " # debug_show removed_val);
                                    assert false;
                                };

                                // Verify the key is no longer in the btree
                                let got = MemoryBTree.get(btree, btree_utils, key);
                                if (got != null) {
                                    Debug.print("Key " # debug_show key # " still exists after removal with value " # debug_show got);
                                    assert false;
                                };

                                // Swap remove from inserted_keys buffer
                                let last = inserted_keys.removeLast();
                                if (idx < inserted_keys.size()) {
                                    switch (last) {
                                        case (?v) { inserted_keys.put(idx, v) };
                                        case (null) {};
                                    };
                                };
                            };
                        };

                        assert Methods.validate_memory(btree, btree_utils);

                        // Final verification: check all remaining keys match the map
                        assert MemoryBTree.size(btree) == Map.size(map);

                        for (key in inserted_keys.vals()) {
                            let expected = Map.get(map, Map.thash, key);
                            let got = MemoryBTree.get(btree, btree_utils, key);
                            if (expected != got) {
                                Debug.print("Final verification failed for key " # debug_show key # ": expected " # debug_show expected # ", got " # debug_show got);
                                assert false;
                            };
                        };

                        // Clean up for next test
                        MemoryBTree.clear(btree);
                        assert MemoryBTree.size(btree) == 0;
                    },
                );

                test(
                    "random ops (insert, replace, remove) - batch ops",
                    func() {
                        // Track inserted keys and their values
                        let inserted_keys = Buffer.Buffer<Text>(limit);
                        let map = Map.new<Text, Text>();

                        // Phase 1: Fill the btree up to the limit using the pre-generated random data
                        for ((key, val) in input.random.vals()) {
                            ignore Map.put(map, Map.thash, key, val);
                            ignore MemoryBTree.insert(btree, btree_utils, key, val);
                            inserted_keys.add(key);
                        };

                        let initial_size = MemoryBTree.size(btree);
                        assert initial_size == limit;
                        assert Methods.validate_memory(btree, btree_utils);

                        // Verify all inserted keys are retrievable
                        for ((key, val) in input.random.vals()) {
                            let got = MemoryBTree.get(btree, btree_utils, key);
                            if (?val != got) {
                                Debug.print("Phase 1 verification failed for key " # debug_show key # ": expected " # debug_show val # ", got " # debug_show got);
                                assert false;
                            };
                        };

                        // Phase 2: Random operations in batches (10% of limit per batch)
                        let batch_size = limit / 10; // 1K operations per batch
                        let num_batches = 10; // Total of 10K operations (limit)
                        var op_counter = 0;

                        for (batch_num in Nat.rangeInclusive(0, num_batches - 1)) {
                            let op_type = fuzz.nat.randomRange(0, 2); // 0 = insert, 1 = replace, 2 = remove

                            if (op_type == 0) {
                                // Batch insert
                                for (j in Nat.rangeInclusive(0, batch_size - 1)) {
                                    let new_key = fuzz.text.randomAlphanumeric(fuzz.nat.randomRange(10, 30)) # "_op" # Nat.toText(op_counter);
                                    let new_val = "val_" # Nat.toText(op_counter);

                                    let prev = MemoryBTree.insert(btree, btree_utils, new_key, new_val);
                                    ignore Map.put(map, Map.thash, new_key, new_val);

                                    if (prev == null) {
                                        inserted_keys.add(new_key);
                                    };

                                    let got = MemoryBTree.get(btree, btree_utils, new_key);
                                    if (?new_val != got) {
                                        Debug.print("Insert verification failed for key " # debug_show new_key # ": expected " # debug_show new_val # ", got " # debug_show got);
                                        assert false;
                                    };

                                    op_counter += 1;
                                };

                            } else if (op_type == 1) {
                                // Batch replace
                                for (j in Nat.rangeInclusive(0, batch_size - 1)) {
                                    if (inserted_keys.size() == 0) {
                                        // Nothing to replace, skip
                                        op_counter += 1;
                                    } else {
                                        let idx = fuzz.nat.randomRange(0, inserted_keys.size() - 1);
                                        let key = inserted_keys.get(idx);
                                        let old_val = Map.get(map, Map.thash, key);
                                        let new_val = "rep_" # Nat.toText(op_counter);

                                        let prev = MemoryBTree.insert(btree, btree_utils, key, new_val);
                                        ignore Map.put(map, Map.thash, key, new_val);

                                        if (prev != old_val) {
                                            Debug.print("Replace returned wrong previous value for key " # debug_show key # ": expected " # debug_show old_val # ", got " # debug_show prev);
                                            assert false;
                                        };

                                        let got = MemoryBTree.get(btree, btree_utils, key);
                                        if (?new_val != got) {
                                            Debug.print("Replace verification failed for key " # debug_show key # ": expected " # debug_show new_val # ", got " # debug_show got);
                                            assert false;
                                        };

                                        op_counter += 1;
                                    };
                                };

                            } else {
                                // Batch remove
                                for (j in Nat.rangeInclusive(0, batch_size - 1)) {
                                    if (inserted_keys.size() == 0) {
                                        // Nothing to remove, skip
                                        op_counter += 1;
                                    } else {
                                        let idx = fuzz.nat.randomRange(0, inserted_keys.size() - 1);
                                        let key = inserted_keys.get(idx);
                                        let expected_val = Map.get(map, Map.thash, key);

                                        let removed_val = MemoryBTree.remove(btree, btree_utils, key);
                                        ignore Map.remove(map, Map.thash, key);

                                        if (removed_val != expected_val) {
                                            Debug.print("Remove returned wrong value for key " # debug_show key # ": expected " # debug_show expected_val # ", got " # debug_show removed_val);
                                            assert false;
                                        };

                                        let got = MemoryBTree.get(btree, btree_utils, key);
                                        if (got != null) {
                                            Debug.print("Key " # debug_show key # " still exists after removal with value " # debug_show got);
                                            assert false;
                                        };

                                        // Swap remove from inserted_keys buffer
                                        let last = inserted_keys.removeLast();
                                        if (idx < inserted_keys.size()) {
                                            switch (last) {
                                                case (?v) { inserted_keys.put(idx, v) };
                                                case (null) {};
                                            };
                                        };

                                        op_counter += 1;
                                    };
                                };
                            };

                            // Validate memory after each batch
                            assert Methods.validate_memory(btree, btree_utils);
                        };

                        // Final verification: check all remaining keys match the map
                        assert MemoryBTree.size(btree) == Map.size(map);

                        for (key in inserted_keys.vals()) {
                            let expected = Map.get(map, Map.thash, key);
                            let got = MemoryBTree.get(btree, btree_utils, key);
                            if (expected != got) {
                                Debug.print("Final verification failed for key " # debug_show key # ": expected " # debug_show expected # ", got " # debug_show got);
                                assert false;
                            };
                        };

                        // Clean up for next test configuration
                        MemoryBTree.clear(btree);
                        assert MemoryBTree.size(btree) == 0;
                    },
                );

            },
        );
    };

    public func run_test(node_capacity: Nat){
        let limit = if (node_capacity == 4) 9_000 else 10_000;

        for ((input_label, input) in [
            ("random text keys", NodeCapacityTest.generate_random_input(limit)),
            ("prefixed text keys", NodeCapacityTest.generate_prefixed_input(limit)),
        ].vals()) {
            for (merge_threshold in [0.25].vals()) {
                for (is_prefix_compression_enabled in [true, false].vals()) {
                    let options = {
                        node_capacity = ?node_capacity;
                        merge_threshold = ?merge_threshold;
                        is_prefix_compression_enabled = ?is_prefix_compression_enabled;
                    };

                    suite(
                        "MemoryBTree (" # input_label # ") with node capacity " # debug_show (node_capacity) # ", merge threshold " # debug_show (merge_threshold) # ", prefix compression " # debug_show (is_prefix_compression_enabled),
                        func() {
                            NodeCapacityTest.btree_tests(limit, input, options);
                        },
                    );
                };
            };
        };

    };
};
