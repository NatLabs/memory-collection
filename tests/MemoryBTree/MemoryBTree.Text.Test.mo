// @testmode wasi
/// Test file for MemoryBTree with Text keys
/// Tests both random text keys and prefixed text keys
/// 
/// Run: mops test --testmode wasi Text.Test

import { test; suite } "mo:test";
import Debug "mo:base@0.14.13/Debug";
import Iter "mo:base@0.14.13/Iter";
import Buffer "mo:base@0.14.13/Buffer";
import Int "mo:base@0.14.13/Int";
import Nat "mo:base@0.14.13/Nat";
import Order "mo:base@0.14.13/Order";
import Text "mo:base@0.14.13/Text";

import Fuzz "mo:fuzz";
import Itertools "mo:itertools@0.2.2/Iter";
import Map "mo:map/Map";
import MemoryRegion "mo:memory-region@1.3.2/MemoryRegion";

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

let { thash } = Map;
let fuzz = Fuzz.fromSeed(0xdeadbeef);

let limit = 10_000;

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
        let remainingLen : Int = MAX_KEY_LEN - prefix.size() - indexStr.size() - 1; // -1 for separator
        let suffixLen : Nat = if (remainingLen > 10) 10 else if (remainingLen > 0) Int.abs(remainingLen) else 0;
        let suffix = if (suffixLen > 0) fuzz.text.randomAlphanumeric(suffixLen) else "";
        
        let key = prefix # suffix # "_" # indexStr;
        buffer.add((key, key));
    };
    buffer;
};

// Generate test data once for reuse
// Random keys - generated first
let random_keys = generate_random_text_keys(limit);

// Prefixed keys - generated second (uses fuzz state after random keys)
let prefixed_keys = generate_prefixed_text_keys(limit);

// Create sorted versions
func sort_text_buffer(buf : Buffer.Buffer<(Text, Text)>) : Buffer.Buffer<(Text, Text)> {
    let sorted = Buffer.clone(buf);
    sorted.sort(func(a : (Text, Text), b : (Text, Text)) : Order = Text.compare(a.0, b.0));
    sorted;
};

let random_sorted = sort_text_buffer(random_keys);
let prefixed_sorted = sort_text_buffer(prefixed_keys);

let btree_utils = MemoryBTree.createUtils(TypeUtils.Text, TypeUtils.Text);

// Generic function to verify all keys exist in the btree
// Returns (found_count, not_found_count, not_found_keys)
func verify_all_keys_exist(
    btree : MemoryBTree.MemoryBTree, 
    data : Buffer.Buffer<(Text, Text)>,
    get_expected_val : (Text, Text) -> Text  // Function to compute expected value from (key, original_val)
) : (Nat, Nat, Buffer.Buffer<(Nat, Text)>) {
    var found : Nat = 0;
    var notFound : Nat = 0;
    let notFoundKeys = Buffer.Buffer<(Nat, Text)>(16);
    
    for ((i, (key, orig_val)) in Itertools.enumerate(data.vals())) {
        let expected_val = get_expected_val(key, orig_val);
        let got = MemoryBTree.get(btree, btree_utils, key);
        if (got == null) {
            notFound += 1;
            notFoundKeys.add((i, key));
        } else if (?expected_val != got) {
            Debug.print("Value mismatch for key[" # Nat.toText(i) # "]=\"" # key # "\": expected \"" # expected_val # "\", got " # debug_show got);
            notFound += 1;
            notFoundKeys.add((i, key));
        } else {
            found += 1;
        };
    };
    
    (found, notFound, notFoundKeys);
};

func btree_tests(node_capacity : Nat, tail_compression : Bool, data : Buffer.Buffer<(Text, Text)>, sorted : Buffer.Buffer<(Text, Text)>, test_name : Text) {
    let btree = MemoryBTree.newWithOptions({ 
        MemoryBTree.defaultOptions with 
        node_capacity = ?node_capacity;
        is_tail_compression_enabled = ?tail_compression;
    });

    suite(
        "MemoryBTree Text Keys - " # test_name,
        func() {
            test(
                "insert",
                func() {
                    let map = Map.new<Text, Text>();

                    label for_loop for ((i, (k, v)) in Itertools.enumerate(data.vals())) {
                        ignore Map.put(map, thash, k, v);
                        ignore MemoryBTree.insert(btree, btree_utils, k, v);
                        
                        if (MemoryBTree.size(btree) != i + 1) {
                            Debug.print("size mismatch after insert: expected " # Nat.toText(i + 1) # ", got " # Nat.toText(MemoryBTree.size(btree)));
                            Debug.print("key: " # k);
                            assert false;
                        };

                        let subtree_size = if (btree.is_root_a_leaf) Leaf.get_count(btree, btree.root) else Branch.get_subtree_size(btree, btree.root);
                        assert subtree_size == MemoryBTree.size(btree);

                        if (?v != MemoryBTree.get(btree, btree_utils, k)) {
                            Debug.print("mismatch: " # debug_show (k, (?v, MemoryBTree.get(btree, btree_utils, k))) # " at index " # debug_show i);
                            assert false;
                        };
                    };

                    assert Methods.validate_memory(btree, btree_utils);

                    let entries = MemoryBTree.entries(btree, btree_utils);
                    let entry = Utils.unwrap(entries.next(), "expected key");
                    var prev = entry.0;

                    for ((i, (key, val)) in Itertools.enumerate(entries)) {
                        if (Text.compare(prev, key) == #greater) {
                            Debug.print("ordering mismatch: " # debug_show (prev, key) # " at index " # debug_show i);
                            assert false;
                        };

                        let expected = Map.get(map, thash, key);
                        if (expected != ?val) {
                            Debug.print("value mismatch: " # debug_show (key, (expected, val)) # " at index " # debug_show (i + 1));
                            assert false;
                        };

                        if (?val != MemoryBTree.get(btree, btree_utils, key)) {
                            Debug.print("get mismatch: " # debug_show (key, (expected, MemoryBTree.get(btree, btree_utils, key))) # " at index " # debug_show (i + 1));
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
                    for ((key, val) in data.vals()) {
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

                        for ((k, v) in MemoryBTree.scan<Text, Text>(btree, btree_utils, ?start_key, ?end_key)) {
                            let expected = sorted.get(index).0;

                            if (not (expected == k)) {
                                Debug.print("mismatch: " # debug_show (expected, k));
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
                            not Itertools.equal<(Text, Text)>(
                                MemoryBTree.range(btree, btree_utils, i, j),
                                Itertools.fromArraySlice<(Text, Text)>(sorted_array, i, j),
                                func(a : (Text, Text), b : (Text, Text)) : Bool = a == b,
                            )
                        ) {
                            Debug.print("mismatch: " # debug_show (i, j));
                            assert false;
                        };
                    };
                },
            );

            test(
                "replace",
                func() {
                    let size = MemoryBTree.size(btree);
                    assert Methods.validate_memory(btree, btree_utils);

                    for ((i, (key, prev_val)) in Itertools.enumerate(data.vals())) {
                        let new_val = prev_val # "_replaced";

                        let prev_result = MemoryBTree.insert(btree, btree_utils, key, new_val);
                        if (?prev_val != prev_result) {
                            Debug.print("Replace failed at i=" # Nat.toText(i) # " key=\"" # key # "\"");
                            Debug.print("Expected prev_val: " # prev_val);
                            Debug.print("Got: " # debug_show prev_result);
                            assert false;
                        };
                        
                        let get_result = MemoryBTree.get(btree, btree_utils, key);
                        if (?new_val != get_result) {
                            Debug.print("Get after replace failed at i=" # Nat.toText(i) # " key=\"" # key # "\"");
                            Debug.print("Expected: " # new_val);
                            Debug.print("Got: " # debug_show get_result);
                            assert false;
                        };
                        
                        assert MemoryBTree.size(btree) == size;

                       
                    };

                    assert Methods.validate_memory(btree, btree_utils);

                    // Final verification: all keys should have replaced values
                    let (found, notFound, notFoundKeys) = verify_all_keys_exist(
                        btree, data,
                        func(_ : Text, orig_val : Text) : Text = orig_val # "_replaced"
                    );
                    
                    if (notFound > 0) {
                        Debug.print("After all replacements: " # Nat.toText(notFound) # " keys not found!");
                        Debug.print("Missing keys:");
                        for ((idx, k) in notFoundKeys.vals()) {
                            Debug.print("  i=" # Nat.toText(idx) # " key=\"" # k # "\"");
                        };
                        assert false;
                    };
                    
                    Debug.print("Replace test passed: all " # Nat.toText(found) # " keys verified");
                },
            );

            test(
                "remove()",
                func() {
                    assert Methods.validate_memory(btree, btree_utils);

                    var removed = 0;
                    var notFound = 0;
                    var existsBeforeRemove = 0;
                    var notExistsBeforeRemove = 0;

                    for ((i, (key, prev_val)) in Itertools.enumerate(data.vals())) {
                        let expected_val = prev_val # "_replaced";

                        // Check if key exists before removal
                        let exists = MemoryBTree.get(btree, btree_utils, key);
                        if (exists == null) {
                            notExistsBeforeRemove += 1;
                            Debug.trap("Key not found BEFORE remove: i=" # Nat.toText(i) # " key=\"" # key # "\"");
                        } else {
                            Debug.print("Key exists BEFORE remove: i=" # Nat.toText(i) # " key=\"" # key # "\"");
                            existsBeforeRemove += 1;
                        };

                        Debug.print("printing path to key before removal: i=" # Nat.toText(i) # " key=\"" # key # "\"");
                        MemoryBTree.printPathToKey(btree, btree_utils, key);

                        let val = MemoryBTree.remove(btree, btree_utils, key);

                        Debug.print("printing path to key after removal: i=" # Nat.toText(i) # " key=\"" # key # "\"");
                        MemoryBTree.printPathToKey(btree, btree_utils, key);

                        if (val == null) {
                            notFound += 1;
                            Debug.print("Key not found DURING remove: i=" # Nat.toText(i) # " key=\"" # key # "\"");
                        } else {
                            removed += 1;
                            if (?expected_val != val) {
                                Debug.print("remove value mismatch: expected " # expected_val # ", got " # debug_show val);
                                assert false;
                            };
                        };

                        let expected_size = data.size() - i - 1;
                        if (MemoryBTree.size(btree) != expected_size) {
                            Debug.print("size mismatch after remove: expected " # Nat.toText(expected_size) # ", got " # Nat.toText(MemoryBTree.size(btree)));
                        };
                    };

                    Debug.print("Remove stats: removed=" # Nat.toText(removed) # " notFound=" # Nat.toText(notFound));
                    Debug.print("Exists check: existsBeforeRemove=" # Nat.toText(existsBeforeRemove) # " notExistsBeforeRemove=" # Nat.toText(notExistsBeforeRemove));

                    assert notFound == 0;
                    assert MemoryBTree.size(btree) == 0;
                    assert Methods.validate_memory(btree, btree_utils);
                },
            );

            test(
                "check for memory leaks",
                func() {
                    Debug.print("checking for memory leaks");
                    Debug.print("data info: " # debug_show MemoryRegion.memoryInfo(btree.data));
                    Debug.print("values info: " # debug_show MemoryRegion.memoryInfo(btree.values));
                    Debug.print("leaves info: " # debug_show MemoryRegion.memoryInfo(btree.leaves));
                    Debug.print("branches info: " # debug_show MemoryRegion.memoryInfo(btree.branches));

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

                    assert MemoryRegion.allocated(btree.data) == MemoryBTree.MC.REGION_HEADER_SIZE;
                    assert MemoryRegion.allocated(btree.values) == MemoryBTree.MC.REGION_HEADER_SIZE;
                    assert MemoryRegion.allocated(btree.leaves) == MemoryBTree.MC.REGION_HEADER_SIZE + MemoryBTree.Leaf.get_memory_size(btree.node_capacity);
                    assert MemoryRegion.allocated(btree.branches) == MemoryBTree.MC.REGION_HEADER_SIZE;
                },
            );
        },
    );
};

// Run tests with different configurations
// Test with random keys
suite(
    "Random Text Keys Tests",
    func() {
        for (node_capacity in [32, 256].vals()) {
            for (tail_compression in [false, true].vals()) {
                let tc_str = if (tail_compression) "TC=ON" else "TC=OFF";
                btree_tests(node_capacity, tail_compression, random_keys, random_sorted, "Random cap=" # Nat.toText(node_capacity) # " " # tc_str);
            };
        };
    },
);

// Test with prefixed keys
suite(
    "Prefixed Text Keys Tests",
    func() {
        for (node_capacity in [16, 32, 256].vals()) {
            for (tail_compression in [false, true].vals()) {
                let tc_str = if (tail_compression) "TC=ON" else "TC=OFF";
                btree_tests(node_capacity, tail_compression, prefixed_keys, prefixed_sorted, "Prefixed cap=" # Nat.toText(node_capacity) # " " # tc_str);
            };
        };
    },
);
