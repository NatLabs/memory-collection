// @testmode wasi
import { test; suite } "mo:test";
import Debug "mo:base@0.14.13/Debug";
import Iter "mo:base@0.14.13/Iter";
import Buffer "mo:base@0.14.13/Buffer";
import Nat32 "mo:base@0.14.13/Nat32";
import Nat64 "mo:base@0.14.13/Nat64";
import Nat "mo:base@0.14.13/Nat";
import Order "mo:base@0.14.13/Order";
import Array "mo:base@0.14.13/Array";
import Blob "mo:base@0.14.13/Blob";
import Nat8 "mo:base@0.14.13/Nat8";

import Fuzz "mo:fuzz";
import Itertools "mo:itertools@0.2.2/Iter";
import Map "mo:map/Map";
import MemoryRegion "mo:memory-region@1.4.0/MemoryRegion";

import MemoryBTree "../../src/MemoryBTree/Base";
import TypeUtils "../../src/TypeUtils";
import Utils "../../src/Utils";
import Branch "../../src/MemoryBTree/modules/Branch";
import Leaf "../../src/MemoryBTree/modules/Leaf";
import Methods "../../src/MemoryBTree/modules/Methods";

type Buffer<A> = Buffer.Buffer<A>;
type Iter<A> = Iter.Iter<A>;
type Order = Order.Order;
type MemoryBlock = MemoryBTree.MemoryBlock;

let { nhash } = Map;
let fuzz = Fuzz.fromSeed(0xdeadbeef);

let limit = 10_000;

let nat_gen_iter : Iter<Nat> = {
    next = func() : ?Nat = ?fuzz.nat.randomRange(1, limit ** 2);
};

let unique_iter = Itertools.unique<Nat>(
    nat_gen_iter,
    func(n : Nat) : Nat32 = Nat64.toNat32(Nat64.fromNat(n) & 0xFFFF_FFFF),
    Nat.equal,
);
let random = Itertools.toBuffer<(Nat, Nat)>(
    Iter.map<(Nat, Nat), (Nat, Nat)>(
        Itertools.enumerate(Itertools.take(unique_iter, limit)),
        func((i, n) : (Nat, Nat)) : (Nat, Nat) = (n, i),
    )
);

let sorted = Buffer.clone(random);
sorted.sort(func(a : (Nat, Nat), b : (Nat, Nat)) : Order = Nat.compare(a.0, b.0));

let btree_utils = MemoryBTree.createUtils(TypeUtils.Nat, TypeUtils.Nat);

func btree_tests(memory_btree_options : MemoryBTree.BTreeOptions) {
    let btree = MemoryBTree.newWithOptions(memory_btree_options);
    Debug.print("BTree config: " # debug_show MemoryBTree.config(btree));

    suite(
        "MemoryBTree",
        func() {
            test(
                "insert random",
                func() {
                    let map = Map.new<Nat, Nat>();
                    // assert btree.order == 4;

                    // Debug.print("random size " # debug_show random.size());
                    label for_loop for ((k, i) in random.vals()) {
                        // Debug.print("inserting " # debug_show k # " at index " # debug_show i);

                        ignore Map.put(map, nhash, k, i);
                        ignore MemoryBTree.insert(btree, btree_utils, k, i);
                        assert MemoryBTree.size(btree) == i + 1;

                        // Debug.print("keys " # debug_show MemoryBTree.toNodeKeys(btree, btree_utils));
                        // Debug.print("leafs " # debug_show MemoryBTree.toLeafNodes(btree, btree_utils));

                        let subtree_size = if (btree.is_root_a_leaf) Leaf.get_count(btree, btree.root) else Branch.get_subtree_size(btree, btree.root);

                        // Debug.print("subtree_size " # debug_show subtree_size);
                        assert subtree_size == MemoryBTree.size(btree);

                        // Debug.print("(i, k, v) -> " # debug_show (i, k, MemoryBTree.get(btree, btree_utils, k)));
                        if (?i != MemoryBTree.get(btree, btree_utils, k)) {
                            Debug.print("mismatch: " # debug_show (k, (?i, MemoryBTree.get(btree, btree_utils, k))) # " at index " # debug_show i);
                            assert false;
                        };

                    };

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

                        let expected = Map.get(map, nhash, key);
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
                "get()",
                func() {
                    var i = 0;
                    for ((key, val) in random.vals()) {
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

                    for (i in Itertools.range(0, sorted.size())) {
                        let (key, _) = sorted.get(i);

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

                    for (i in Itertools.range(0, sorted.size())) {
                        let (key, _) = sorted.get(i);

                        let expected = #Found(i);
                        let rank = MemoryBTree.getExpectedIndex(btree, btree_utils, key);

                        if (not (rank == expected)) {
                            Debug.print("getIndex -> " # debug_show (MemoryBTree.getIndex(btree, btree_utils, key)));
                            Debug.print("mismatch for key:" # debug_show key);
                            Debug.print("expected != rank: " # debug_show (expected, rank));
                            assert false;
                        };
                    };

                    let non_consecutive_range = Itertools.add(
                        Iter.map(
                            Iter.filter(
                                Itertools.slidingTuples(Itertools.range(0, sorted.size())),
                                func((i, j) : (Nat, Nat)) : Bool = (sorted.get(i).0 + 1) != sorted.get(j).0,
                            ),
                            func((i, j) : (Nat, Nat)) : Nat = i,
                        ),
                        sorted.size() - 1 : Nat,
                    );

                    for (i in non_consecutive_range) {
                        let key = sorted.get(i).0 + 1;

                        let expected = #NotFound(i + 1);
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
                    for (i in Itertools.range(0, sorted.size())) {
                        let expected = sorted.get(i);
                        let received = MemoryBTree.getFromIndex(btree, btree_utils, i);

                        if (not ((expected, expected) == received)) {
                            Debug.print("mismatch at rank:" # debug_show i);
                            Debug.print("expected != received: " # debug_show ((expected, expected), received));
                            assert false;
                        };
                    };
                },
            );

            test(
                "getFloor()",
                func() {

                    for (i in Itertools.range(0, sorted.size())) {
                        let (key, _) = sorted.get(i);

                        let expected = sorted.get(i);
                        let received = MemoryBTree.getFloor(btree, btree_utils, key);

                        if (not (?expected == received)) {
                            Debug.print("equality check failed");
                            Debug.print("mismatch at key:" # debug_show key);
                            Debug.print("expected != received: " # debug_show (expected, received));
                            assert false;
                        };

                        let prev = key - 1;

                        if (i > 0) {
                            let expected = sorted.get(i - 1);
                            let received = MemoryBTree.getFloor(btree, btree_utils, prev);

                            if (not (?(expected) == received)) {
                                Debug.print("prev key failed");
                                Debug.print("mismatch at key:" # debug_show prev);
                                Debug.print("expected != received: " # debug_show (expected, received));
                                assert false;
                            };
                        } else {
                            assert MemoryBTree.getFloor(btree, btree_utils, prev) == null;
                        };

                        let next = key + 1;

                        do {
                            let expected = if (i + 1 < sorted.size() and sorted.get(i + 1).0 == next) sorted.get(i + 1) else sorted.get(i);
                            let received = MemoryBTree.getFloor(btree, btree_utils, next);

                            if (not (?expected == received)) {
                                Debug.print("next key failed");
                                Debug.print("mismatch at key:" # debug_show next);
                                Debug.print("expected != received: " # debug_show (expected, received));
                                assert false;
                            };
                        };

                    };
                },
            );

            test(
                "getCeiling()",
                func() {
                    for (i in Itertools.range(0, sorted.size())) {
                        var key = sorted.get(i).0;

                        let expected = sorted.get(i);
                        let received = MemoryBTree.getCeiling<Nat, Nat>(btree, btree_utils, key);

                        if (not (?expected == received)) {
                            Debug.print("equality check failed");
                            Debug.print("mismatch at key:" # debug_show key);
                            Debug.print("expected != received: " # debug_show (expected, received));
                            assert false;
                        };

                        let prev = key - 1;

                        do {
                            let expected = if (i > 0 and sorted.get(i - 1).0 == prev) sorted.get(i - 1) else sorted.get(i);
                            let received = MemoryBTree.getCeiling<Nat, Nat>(btree, btree_utils, prev);

                            if (not (?expected == received)) {
                                Debug.print("prev key failed");
                                Debug.print("mismatch at key:" # debug_show prev);
                                Debug.print("expected != received: " # debug_show (expected, received));
                                assert false;
                            };
                        };

                        let next = key + 1;

                        if (i + 1 < sorted.size()) {
                            let expected = sorted.get(i + 1);
                            let received = MemoryBTree.getCeiling<Nat, Nat>(btree, btree_utils, next);

                            if (not (?expected == received)) {
                                Debug.print("next key failed");
                                Debug.print("mismatch at key:" # debug_show next);
                                Debug.print("expected != received: " # debug_show (expected, received));
                                assert false;
                            };
                        } else {
                            assert MemoryBTree.getCeiling<Nat, Nat>(btree, btree_utils, next) == null;
                        };

                    };
                },
            );
            test(
                "entries()",
                func() {
                    var i = 0;
                    for ((a, b) in Itertools.zip(MemoryBTree.entries(btree, btree_utils), sorted.vals())) {
                        if (a != b) {
                            Debug.print("mismatch: " # debug_show (a, b) # " at index " # debug_show i);
                            assert false;
                        };
                        i += 1;
                    };

                    assert i == sorted.size();

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
                        let start_key = sorted.get(i).0;
                        let end_key = sorted.get(j).0;

                        var index = i;

                        for ((k, v) in MemoryBTree.scan<Nat, Nat>(btree, btree_utils, ?start_key, ?end_key)) {
                            let expected = sorted.get(index).0;

                            if (not (expected == k)) {
                                Debug.print("mismatch: " # debug_show (expected, k));
                                Debug.print("scan " # debug_show Iter.toArray(MemoryBTree.scan(btree, btree_utils, ?start_key, ?end_key)));

                                let expected_vals = Iter.range(i, j)
                                |> Iter.map<Nat, Nat>(_, func(n : Nat) : Nat = sorted.get(n).1);
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

                    let sorted_array = Buffer.toArray(sorted);

                    for ((i, j) in sliding_tuples) {

                        if (
                            not Itertools.equal<(Nat, Nat)>(
                                MemoryBTree.range(btree, btree_utils, i, j),
                                Itertools.fromArraySlice<(Nat, Nat)>(sorted_array, i, j),
                                func(a : (Nat, Nat), b : (Nat, Nat)) : Bool = a == b,
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
                    let mem_blocks = Buffer.Buffer<(MemoryBlock, MemoryBlock)>(8);
                    let blobs = Buffer.Buffer<(Blob, Blob)>(8);
                    assert Methods.validate_memory(btree, btree_utils);

                    for ((key, i) in random.vals()) {

                        let prev_val = i;
                        let new_val = 1 + prev_val * 10;

                        // Debug.print("replacing " # debug_show key # " at index " # debug_show i # " with " # debug_show new_val);
                        // Debug.print("tree before insert: " # debug_show MemoryBTree.toNodeKeys(btree, btree_utils));
                        // Debug.print("leaf nodes: " # debug_show MemoryBTree.toLeafNodes(btree, btree_utils));

                        let ?prev_id = MemoryBTree.getId(btree, btree_utils, key);
                        assert ?(key, prev_val) == MemoryBTree.lookup(btree, btree_utils, prev_id);
                        let ?mem_block = MemoryBTree._lookup_mem_block(btree, prev_id);
                        let prev_key_blob = MemoryRegion.loadBlob(btree.data, mem_block.0.0, mem_block.0.1);
                        let prev_val_blob = MemoryRegion.loadBlob(btree.data, mem_block.1.0, mem_block.1.1);
                        // MemoryBTree._lookup_val_blob(btree,  prev_id);

                        assert ?prev_val == MemoryBTree.insert(btree, btree_utils, key, new_val);

                        let ?id = MemoryBTree.getId(btree, btree_utils, key);

                        assert ?new_val == MemoryBTree.get(btree, btree_utils, key);

                        let ?new_mem_block = MemoryBTree._lookup_mem_block(btree, id);
                        // Debug.print("id at test: " # debug_show id);

                        // Debug.print("new entry: " # debug_show (key, new_val));
                        assert ?(key, new_val) == MemoryBTree.lookup(btree, btree_utils, id);
                        assert prev_key_blob == MemoryRegion.loadBlob(btree.data, new_mem_block.0.0, new_mem_block.0.1);
                        let new_val_blob = btree_utils.value.blobify.to_blob(new_val);

                        let recieved_val_blob = MemoryRegion.loadBlob(btree.values, new_mem_block.1.0, new_mem_block.1.1);
                        // Debug.print("new_val_mem_block: " # debug_show new_mem_block.1);
                        // Debug.print("new_val_blob (recieved, expected) " # debug_show (recieved_val_blob, new_val_blob));
                        assert new_val_blob == recieved_val_blob;

                        mem_blocks.add(new_mem_block);
                        blobs.add((prev_key_blob, new_val_blob));

                        if (i > 0) {
                            let ?left_id = MemoryBTree.getId(btree, btree_utils, random.get(i - 1).0);
                            let ?left_key_blob = MemoryBTree._lookup_key_blob(btree, left_id);
                            let ?left_val_blob = MemoryBTree._lookup_val_blob(btree, left_id);

                            let ?left_mem_block = MemoryBTree._lookup_mem_block(btree, left_id);

                            let left_blob_entry = (left_key_blob, left_val_blob);
                            let expected_blob_entry = blobs.get(i - 1);

                            if (left_blob_entry != expected_blob_entry) {
                                Debug.print("blob entry mismatch: " # debug_show (left_blob_entry, expected_blob_entry) # " at index " # debug_show (i - 1));
                                Debug.print("left_mem_block " # debug_show left_mem_block);
                                Debug.print(debug_show Buffer.toArray(mem_blocks));
                                assert false;
                            };
                        };

                        // Debug.print("tree after insert: " # debug_show MemoryBTree.toNodeKeys(btree, btree_utils));
                        // Debug.print("leaf nodes: " # debug_show MemoryBTree.toLeafNodes(btree, btree_utils));

                        assert MemoryBTree.size(btree) == size;
                    };

                    assert Methods.validate_memory(btree, btree_utils);

                    var i = 0;
                    for ((key, _val) in random.vals()) {
                        let val = 1 + _val * 10;
                        let received = MemoryBTree.get(btree, btree_utils, key);
                        let ?id = MemoryBTree.getId(btree, btree_utils, key);
                        let ?mem_block = MemoryBTree._lookup_mem_block(btree, id);
                        let expected_mem_block = mem_blocks.get(i);

                        let ?(received_key_blob) = MemoryBTree._lookup_key_blob(btree, id);
                        let ?(received_val_blob) = MemoryBTree._lookup_val_blob(btree, id);
                        let recieved_blob_entry = (received_key_blob, received_val_blob);

                        let expected_blob_entry = blobs.get(i);

                        if (recieved_blob_entry != expected_blob_entry) {
                            Debug.print("blob entry mismatch: " # debug_show (recieved_blob_entry, expected_blob_entry) # " at index " # debug_show i);
                            Debug.print(debug_show Buffer.toArray(mem_blocks));
                            assert false;
                        };

                        assert mem_block == expected_mem_block;
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

                    for ((key, i) in random.vals()) {

                        // Debug.print("node keys: " # debug_show MemoryBTree.toNodeKeys(btree, btree_utils));
                        // Debug.print("btree.leaf_count before toLeafNodes: " # debug_show MemoryBTree.leafCount(btree));

                        // Debug.print("removing " # debug_show key);
                        let expected_val = 1 + i * 10;

                        let result = MemoryBTree.get(btree, btree_utils, key);
                        assert ?expected_val == result;

                        let val = MemoryBTree.remove(btree, btree_utils, key);
                        // Debug.print("(i, val): " # debug_show (i, val));

                        assert ?expected_val == val;

                        assert MemoryBTree.size(btree) == random.size() - i - 1;
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
                    let map = Map.new<Nat, Nat>();
                    // assert btree.order == 4;

                    // Debug.print("random size " # debug_show random.size());
                    label for_loop for ((k, i) in random.vals()) {


                        // Debug.print("keys " # debug_show (MemoryBTree.toNodeKeys(btree, btree_utils)));
                        // Debug.print("leafs " # debug_show (MemoryBTree.toLeafNodes(btree, btree_utils)));
                        // Debug.print("inserting " # debug_show k  # " at index " # debug_show i);
                        // Debug.print("key blob: " # debug_show (btree_utils.key.blobify.to_blob(k)));

                        ignore Map.put(map, nhash, k, i);
                        ignore MemoryBTree.insert(btree, btree_utils, k, i);
                        assert MemoryBTree.size(btree) == i + 1;

                        let subtree_size = if (btree.is_root_a_leaf) Leaf.get_count(btree, btree.root) else Branch.get_subtree_size(btree, btree.root);

                        assert subtree_size == MemoryBTree.size(btree);

                        if (?i != MemoryBTree.get(btree, btree_utils, k)) {
                            Debug.print("mismatch: " # debug_show (k, (i, MemoryBTree.get(btree, btree_utils, k))) # " at index " # debug_show i);
                            assert false;
                        };
                    };

                    // Debug.print("entries: " # debug_show Iter.toArray(MemoryBTree.entries(btree, btree_utils)));

                    let entries = MemoryBTree.entries(btree, btree_utils);
                    let entry = Utils.unwrap(entries.next(), "expected key");
                    var prev = entry.0;

                    for ((i, (key, val)) in Itertools.enumerate(entries)) {
                        if (prev > key) {
                            Debug.print("mismatch: " # debug_show (prev, key) # " at index " # debug_show i);
                            assert false;
                        };

                        let expected = Map.get(map, nhash, key);
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

                    for ((key, i) in random.vals()) {
                        // Debug.print("removing " # debug_show key);
                        let val = MemoryBTree.remove(btree, btree_utils, key);
                        // Debug.print("(i, val): " # debug_show (i, val));
                        assert ?i == val;

                        assert MemoryBTree.size(btree) == random.size() - i - 1;
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

                    MemoryBTree.clear(btree);
                    assert MemoryBTree.size(btree) == 0;

                    assert Methods.validate_memory(btree, btree_utils);
                },

            );

            test(
                "random ops (insert, replace, remove) - single ops",
                func() {
                    // Track inserted keys and their values
                    let inserted_keys = Buffer.Buffer<Nat>(limit);
                    let map = Map.new<Nat, Nat>();

                    // Phase 1: Fill the btree up to the limit using the pre-generated random data
                    for ((key, val) in random.vals()) {
                        ignore Map.put(map, nhash, key, val);
                        ignore MemoryBTree.insert(btree, btree_utils, key, val);
                        inserted_keys.add(key);
                    };

                    let initial_size = MemoryBTree.size(btree);
                    assert initial_size == limit;
                    assert Methods.validate_memory(btree, btree_utils);

                    // Verify all inserted keys are retrievable
                    for ((key, val) in random.vals()) {
                        let got = MemoryBTree.get(btree, btree_utils, key);
                        if (?val != got) {
                            Debug.print("Phase 1 verification failed for key " # debug_show key # ": expected " # debug_show val # ", got " # debug_show got);
                            assert false;
                        };
                    };

                    // Phase 2: Random operations for another iteration of the limit size
                    for (i in Iter.range(0, limit - 1)) {
                        let op_type = fuzz.nat.randomRange(0, 2); // 0 = insert, 1 = replace, 2 = remove

                        if (inserted_keys.size() < 3 or op_type == 0) {
                            // Insert a new key
                            let new_key = fuzz.nat.randomRange(1, limit ** 2);
                            let new_val = limit + i;

                            let prev = MemoryBTree.insert(btree, btree_utils, new_key, new_val);
                            ignore Map.put(map, nhash, new_key, new_val);

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
                            let old_val = Map.get(map, nhash, key);
                            let new_val = limit * 2 + i;

                            let prev = MemoryBTree.insert(btree, btree_utils, key, new_val);
                            ignore Map.put(map, nhash, key, new_val);

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
                            let expected_val = Map.get(map, nhash, key);

                            let removed_val = MemoryBTree.remove(btree, btree_utils, key);
                            ignore Map.remove(map, nhash, key);

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
                        let expected = Map.get(map, nhash, key);
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
                    let inserted_keys = Buffer.Buffer<Nat>(limit);
                    let map = Map.new<Nat, Nat>();

                    // Phase 1: Fill the btree up to the limit using the pre-generated random data
                    for ((key, val) in random.vals()) {
                        ignore Map.put(map, nhash, key, val);
                        ignore MemoryBTree.insert(btree, btree_utils, key, val);
                        inserted_keys.add(key);
                    };

                    let initial_size = MemoryBTree.size(btree);
                    assert initial_size == limit;
                    assert Methods.validate_memory(btree, btree_utils);

                    // Verify all inserted keys are retrievable
                    for ((key, val) in random.vals()) {
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

                    for (batch_num in Iter.range(0, num_batches - 1)) {
                        let op_type = fuzz.nat.randomRange(0, 2); // 0 = insert, 1 = replace, 2 = remove

                        if (op_type == 0) {
                            // Batch insert
                            for (j in Iter.range(0, batch_size - 1)) {
                                let new_key = fuzz.nat.randomRange(1, limit ** 2);
                                let new_val = limit + op_counter;

                                let prev = MemoryBTree.insert(btree, btree_utils, new_key, new_val);
                                ignore Map.put(map, nhash, new_key, new_val);

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
                            for (j in Iter.range(0, batch_size - 1)) {
                                if (inserted_keys.size() == 0) {
                                    // Nothing to replace, skip
                                    op_counter += 1;
                                } else {
                                    let idx = fuzz.nat.randomRange(0, inserted_keys.size() - 1);
                                    let key = inserted_keys.get(idx);
                                    let old_val = Map.get(map, nhash, key);
                                    let new_val = limit * 2 + op_counter;

                                    let prev = MemoryBTree.insert(btree, btree_utils, key, new_val);
                                    ignore Map.put(map, nhash, key, new_val);

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
                            for (j in Iter.range(0, batch_size - 1)) {
                                if (inserted_keys.size() == 0) {
                                    // Nothing to remove, skip
                                    op_counter += 1;
                                } else {
                                    let idx = fuzz.nat.randomRange(0, inserted_keys.size() - 1);
                                    let key = inserted_keys.get(idx);
                                    let expected_val = Map.get(map, nhash, key);

                                    let removed_val = MemoryBTree.remove(btree, btree_utils, key);
                                    ignore Map.remove(map, nhash, key);

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
                        let expected = Map.get(map, nhash, key);
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

            // ── insertBatch tests ────────────────────────────────────────────────

            test(
                "insertBatch: empty batch returns empty array",
                func() {
                    MemoryBTree.clear(btree);
                    let result = MemoryBTree.insertBatch(btree, btree_utils, []);
                    assert result.size() == 0;
                    assert MemoryBTree.size(btree) == 0;
                },
            );

            test(
                "insertBatch: all new keys - correctness and structural validity",
                func() {
                    MemoryBTree.clear(btree);
                    let map = Map.new<Nat, Nat>();

                    // Build a batch of 100 distinct keys not in the tree
                    let batch_size = 100;
                    let batch = Array.tabulate<(Nat, Nat)>(batch_size, func(i : Nat) : (Nat, Nat) { (i * 3 + 1, i * 7 + 2) });

                    for ((k, v) in batch.vals()) {
                        ignore Map.put(map, nhash, k, v);
                    };

                    let results = MemoryBTree.insertBatch(btree, btree_utils, batch);

                    // All previous values should be null (new keys)
                    for (r in results.vals()) {
                        assert r == null;
                    };

                    assert MemoryBTree.size(btree) == batch_size;

                    // Every key must be retrievable with the correct value
                    for ((k, v) in batch.vals()) {
                        if (MemoryBTree.get(btree, btree_utils, k) != ?v) {
                            Debug.print("insertBatch all-new: mismatch for key " # debug_show k);
                            assert false;
                        };
                    };

                    // Subtree-size invariant
                    let subtree_size = if (btree.is_root_a_leaf) Leaf.get_count(btree, btree.root) else Branch.get_subtree_size(btree, btree.root);
                    assert subtree_size == MemoryBTree.size(btree);

                    assert Methods.validate_memory(btree, btree_utils);

                    MemoryBTree.clear(btree);
                },
            );

            test(
                "insertBatch: replacements return previous values",
                func() {
                    MemoryBTree.clear(btree);

                    // Pre-populate with keys 0..49
                    let initial = Array.tabulate<(Nat, Nat)>(50, func(i : Nat) : (Nat, Nat) { (i, i * 10) });
                    ignore MemoryBTree.insertBatch(btree, btree_utils, initial);
                    assert MemoryBTree.size(btree) == 50;

                    // Replace the same 50 keys with new values
                    let replacements = Array.tabulate<(Nat, Nat)>(50, func(i : Nat) : (Nat, Nat) { (i, i * 20) });
                    let results = MemoryBTree.insertBatch(btree, btree_utils, replacements);

                    // Size must not change
                    assert MemoryBTree.size(btree) == 50;

                    // Each result must be the old value
                    for (i in Iter.range(0, 49)) {
                        if (results[i] != ?(i * 10)) {
                            Debug.print("insertBatch replacement: wrong prev value at i=" # debug_show i # " got=" # debug_show results[i]);
                            assert false;
                        };
                    };

                    // New values must be stored
                    for (i in Iter.range(0, 49)) {
                        if (MemoryBTree.get(btree, btree_utils, i) != ?(i * 20)) {
                            Debug.print("insertBatch replacement: wrong stored value at i=" # debug_show i);
                            assert false;
                        };
                    };

                    let subtree_size = if (btree.is_root_a_leaf) Leaf.get_count(btree, btree.root) else Branch.get_subtree_size(btree, btree.root);
                    assert subtree_size == MemoryBTree.size(btree);

                    assert Methods.validate_memory(btree, btree_utils);

                    MemoryBTree.clear(btree);
                },
            );

            test(
                "insertBatch: mixed new and replacement keys",
                func() {
                    MemoryBTree.clear(btree);
                    let map = Map.new<Nat, Nat>();

                    // Insert keys 0..49 first
                    for (i in Iter.range(0, 49)) {
                        ignore MemoryBTree.insert(btree, btree_utils, i, i * 10);
                        ignore Map.put(map, nhash, i, i * 10);
                    };

                    // Batch: keys 25..124 (25 replacements + 75 new)
                    let batch = Array.tabulate<(Nat, Nat)>(100, func(i : Nat) : (Nat, Nat) { (i + 25, (i + 25) * 99) });
                    for ((k, v) in batch.vals()) {
                        ignore Map.put(map, nhash, k, v);
                    };

                    let results = MemoryBTree.insertBatch(btree, btree_utils, batch);

                    // Expected total size: 125 unique keys
                    assert MemoryBTree.size(btree) == 125;

                    // Verify replacement results (keys 25..49 were pre-existing)
                    for (i in Iter.range(0, 24)) {
                        let expected_prev = ?((i + 25) * 10);
                        if (results[i] != expected_prev) {
                            Debug.print("mixed: wrong prev for key " # debug_show (i + 25) # " expected=" # debug_show expected_prev # " got=" # debug_show results[i]);
                            assert false;
                        };
                    };
                    // New keys 50..124 should return null
                    for (i in Iter.range(25, 99)) {
                        if (results[i] != null) {
                            Debug.print("mixed: expected null for new key " # debug_show (i + 25) # " got=" # debug_show results[i]);
                            assert false;
                        };
                    };

                    // All values must match the map
                    for ((k, v) in Map.entries(map)) {
                        if (MemoryBTree.get(btree, btree_utils, k) != ?v) {
                            Debug.print("mixed: value mismatch for key " # debug_show k);
                            assert false;
                        };
                    };

                    let subtree_size = if (btree.is_root_a_leaf) Leaf.get_count(btree, btree.root) else Branch.get_subtree_size(btree, btree.root);
                    assert subtree_size == MemoryBTree.size(btree);

                    assert Methods.validate_memory(btree, btree_utils);

                    MemoryBTree.clear(btree);
                },
            );

            test(
                "insertBatch: batch causes leaf overflow / multiple leaf creation",
                func() {
                    MemoryBTree.clear(btree);

                    // Fill a leaf nearly to capacity then insert a batch that causes multi-leaf creation
                    let initial_count = btree.node_capacity - 1;
                    let initial = Array.tabulate<(Nat, Nat)>(initial_count, func(i : Nat) : (Nat, Nat) { (i * 2, i) });
                    ignore MemoryBTree.insertBatch(btree, btree_utils, initial);
                    assert MemoryBTree.size(btree) == initial_count;

                    // Insert enough new keys (odd numbers) to push well past capacity
                    let overflow_count = btree.node_capacity + 10;
                    let overflow = Array.tabulate<(Nat, Nat)>(overflow_count, func(i : Nat) : (Nat, Nat) { (i * 2 + 1, i + 1000) });
                    let results = MemoryBTree.insertBatch(btree, btree_utils, overflow);

                    // All should be new
                    for (r in results.vals()) { assert r == null };

                    let expected_total = initial_count + overflow_count;
                    assert MemoryBTree.size(btree) == expected_total;

                    // Verify all inserted values are accessible
                    for ((k, v) in initial.vals()) {
                        if (MemoryBTree.get(btree, btree_utils, k) != ?v) {
                            Debug.print("overflow: initial key mismatch k=" # debug_show k);
                            assert false;
                        };
                    };
                    for ((k, v) in overflow.vals()) {
                        if (MemoryBTree.get(btree, btree_utils, k) != ?v) {
                            Debug.print("overflow: overflow key mismatch k=" # debug_show k);
                            assert false;
                        };
                    };

                    let subtree_size = if (btree.is_root_a_leaf) Leaf.get_count(btree, btree.root) else Branch.get_subtree_size(btree, btree.root);
                    assert subtree_size == MemoryBTree.size(btree);

                    assert Methods.validate_memory(btree, btree_utils);

                    MemoryBTree.clear(btree);
                },
            );

            test(
                "insertBatch: duplicate keys within batch – last value wins",
                func() {
                    MemoryBTree.clear(btree);

                    // Batch has key 42 at positions 0 and 2.  Position 2 (value 999) should win.
                    let batch : [(Nat, Nat)] = [(42, 100), (10, 200), (42, 999), (20, 300)];
                    let results = MemoryBTree.insertBatch(btree, btree_utils, batch);

                    // Three distinct keys inserted
                    assert MemoryBTree.size(btree) == 3;

                    // Key 42 should have the last value
                    assert MemoryBTree.get(btree, btree_utils, 42) == ?999;
                    assert MemoryBTree.get(btree, btree_utils, 10) == ?200;
                    assert MemoryBTree.get(btree, btree_utils, 20) == ?300;

                    // The winner for key 42 (results[2]) gets the previous tree value (null)
                    assert results[2] == null;

                    let subtree_size = if (btree.is_root_a_leaf) Leaf.get_count(btree, btree.root) else Branch.get_subtree_size(btree, btree.root);
                    assert subtree_size == MemoryBTree.size(btree);

                    assert Methods.validate_memory(btree, btree_utils);

                    MemoryBTree.clear(btree);
                },
            );

            test(
                "insertBatch: results match sequential insert behaviour on random data",
                func() {
                    MemoryBTree.clear(btree);

                    let batch_count = 100;

                    // Use deterministic distinct keys for the pre-existing portion so there are
                    // no accidental duplicates that would make result comparison non-trivial.
                    let existing_count = 20;
                    let existing = Array.tabulate<(Nat, Nat)>(existing_count, func(i : Nat) : (Nat, Nat) { (i + 1, i * 5) });

                    for ((k, v) in existing.vals()) {
                        ignore MemoryBTree.insert(btree, btree_utils, k, v);
                    };

                    // Build the full batch: existing keys (replacements) + new distinct keys.
                    let new_keys = Array.tabulate<(Nat, Nat)>(batch_count - existing_count, func(i : Nat) : (Nat, Nat) { (50_001 + i, i * 3) });
                    let batch = Array.append(existing, new_keys);

                    // Reference: a separate tree with the same initial state and sequential inserts.
                    let ref_btree = MemoryBTree.newWithOptions({ node_capacity = ?(btree.node_capacity); merge_threshold = null; is_tail_compression_enabled = null });
                    for ((k, v) in existing.vals()) {
                        ignore MemoryBTree.insert(ref_btree, btree_utils, k, v);
                    };
                    let ref_results = Array.map<(Nat, Nat), ?Nat>(
                        batch,
                        func((k, v)) = MemoryBTree.insert(ref_btree, btree_utils, k, v),
                    );

                    // insertBatch on the original tree.
                    let batch_results = MemoryBTree.insertBatch(btree, btree_utils, batch);

                    // Sizes must match.
                    assert MemoryBTree.size(btree) == MemoryBTree.size(ref_btree);

                    // Each returned previous value must match what sequential insert returns.
                    for (i in Iter.range(0, batch_count - 1)) {
                        if (batch_results[i] != ref_results[i]) {
                            Debug.print("results mismatch at i=" # debug_show i # " batch=" # debug_show batch_results[i] # " ref=" # debug_show ref_results[i]);
                            assert false;
                        };
                    };

                    // All stored values must match the reference tree.
                    for ((k, _) in batch.vals()) {
                        if (MemoryBTree.get(btree, btree_utils, k) != MemoryBTree.get(ref_btree, btree_utils, k)) {
                            Debug.print("value mismatch after insertBatch for key " # debug_show k);
                            assert false;
                        };
                    };

                    let subtree_size = if (btree.is_root_a_leaf) Leaf.get_count(btree, btree.root) else Branch.get_subtree_size(btree, btree.root);
                    assert subtree_size == MemoryBTree.size(btree);

                    assert Methods.validate_memory(btree, btree_utils);

                    MemoryBTree.clear(btree);
                },
            );

            test(
                "insertBatch: large batch spanning many leaves",
                func() {
                    MemoryBTree.clear(btree);
                    let map = Map.new<Nat, Nat>();

                    let large_batch_size = 500;
                    let large_batch = Array.tabulate<(Nat, Nat)>(large_batch_size, func(i : Nat) : (Nat, Nat) { (i, i * 13 + 7) });
                    for ((k, v) in large_batch.vals()) { ignore Map.put(map, nhash, k, v) };

                    let results = MemoryBTree.insertBatch(btree, btree_utils, large_batch);

                    assert MemoryBTree.size(btree) == large_batch_size;

                    for (r in results.vals()) { assert r == null };

                    for ((k, v) in large_batch.vals()) {
                        if (MemoryBTree.get(btree, btree_utils, k) != ?v) {
                            Debug.print("large batch: mismatch for key " # debug_show k);
                            assert false;
                        };
                    };

                    let subtree_size = if (btree.is_root_a_leaf) Leaf.get_count(btree, btree.root) else Branch.get_subtree_size(btree, btree.root);
                    assert subtree_size == MemoryBTree.size(btree);

                    assert Methods.validate_memory(btree, btree_utils);

                    MemoryBTree.clear(btree);
                },
            );

        },
    );
};

for (node_capacity in [4, 32].vals()) {
    for (merge_threshold in [0.125, 0.25, 0.5].vals()) {
        for (is_tail_compression_enabled in [true, false].vals()) {
            let options = {
                node_capacity = ?node_capacity;
                merge_threshold = ?merge_threshold;
                is_tail_compression_enabled = ?is_tail_compression_enabled;
            };

            suite(
                "MemoryBTree with node capacity " # debug_show (node_capacity) # ", merge threshold " # debug_show (merge_threshold) # ", tail compression " # debug_show (is_tail_compression_enabled),
                func() {
                    btree_tests(options);
                },
            );
        };
    };
};
