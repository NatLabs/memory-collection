// @testmode wasi
import Buffer "mo:base@.v0.14.11/Buffer";
import Debug "mo:base@.v0.14.11/Debug";
import Iter "mo:base@.v0.14.11/Iter";
import Nat "mo:base@.v0.14.11/Nat";
import Result "mo:base@.v0.14.11/Result";

import { test; suite } "mo:test@.v2.1.1";
import Fuzz "mo:fuzz@.v1.0.0";
import { MaxBpTree; Cmp } "mo:augmented-btrees@.v0.7.1";
import MemoryRegion "mo:memory-region@.v1.3.2/MemoryRegion";
import Itertools "mo:itertools@.v0.2.2/Iter";
import MaxBpTreeMethods "mo:augmented-btrees@.v0.7.1/MaxBpTree/Methods";
import BpTree "mo:augmented-btrees@.v0.7.1/BpTree";

import MemoryBuffer "../../src/MemoryBuffer/Base";

import TypeUtils "../../src/TypeUtils";

let limit = 10_000;
let fuzz = Fuzz.fromSeed(0xdeadbeef);

// Create input arrays for different test scenarios
let order = Buffer.Buffer<Nat>(limit);
let initial_values = Buffer.Buffer<Text>(limit);
let equal_size_values = Buffer.Buffer<Text>(limit);
let greater_size_values = Buffer.Buffer<Text>(limit);
let less_size_values = Buffer.Buffer<Text>(limit);

for (i in Iter.range(0, limit - 1)) {
    order.add(i);

    let size_a = fuzz.nat.randomRange(0, 25);
    let text_a = fuzz.text.randomAlphanumeric(size_a);

    // Less size values: shorter text strings
    less_size_values.add(text_a);

    let size_b = fuzz.nat.randomRange(size_a, 50);
    let text_b = fuzz.text.randomAlphanumeric(size_b);

    // Initial values: short text strings
    initial_values.add(text_b);

    let text_c = fuzz.text.randomAlphanumeric(size_b);

    // Equal size values: same length as initial
    equal_size_values.add(text_c);

    let size_d = fuzz.nat.randomRange(size_b, 100);
    let text_d = fuzz.text.randomAlphanumeric(size_d);

    // Greater size values: longer text strings
    greater_size_values.add(text_d);

};

fuzz.buffer.shuffle(order);

type MemoryRegion = MemoryRegion.MemoryRegion;

func validate_region(memory_region : MemoryRegion) {
    if (not MaxBpTreeMethods.validate_max_path(memory_region.free_memory, Cmp.Nat)) {
        Debug.print("invalid max path discovered at index ");
        Debug.print("node keys: " # debug_show (MaxBpTree.toNodeKeys(memory_region.free_memory)));
        Debug.print("node leaves: " # debug_show (MaxBpTree.toLeafNodes(memory_region.free_memory)));
        assert false;
    };

    if (not MaxBpTreeMethods.validate_subtree_size(memory_region.free_memory)) {
        Debug.print("invalid subtree size at index ");
        Debug.print("node keys: " # debug_show (MaxBpTree.toNodeKeys(memory_region.free_memory)));
        Debug.print("node leaves: " # debug_show (MaxBpTree.toLeafNodes(memory_region.free_memory)));
        assert false;
    };
};

class MemoryBlocksMap<A>(mbuffer : MemoryBuffer.MemoryBuffer<A>) {
    let memory_blocks = BpTree.new<(Nat, Nat), Nat>(null);

    func compare(a : (Nat, Nat), b : (Nat, Nat)) : Int8 {
        if (a.0 < b.0 and a.1 <= b.0) {
            -1;
        } else if (a.0 >= b.1 and a.1 > b.0) {
            1;
        } else {
            0;
        };
    };

    public func add(_block : (Nat, Nat), index : Nat) : Bool {
        let block = (_block.0, _block.0 + _block.1);

        switch (BpTree.getEntry(memory_blocks, compare, block)) {
            case (?(existing_block, prev_index)) {
                Debug.print("Memory block already exists at index " # debug_show prev_index # ", current index: " # debug_show index);
                Debug.print("Existing block: " # debug_show existing_block # ", New block: " # debug_show block);
                Debug.print("Actual memory block at prev index: " # debug_show MemoryBuffer._get_memory_block(mbuffer, prev_index));
                false;
            };
            case (null) {
                ignore BpTree.insert(memory_blocks, compare, block, index);
                true;
            };
        };
    };

};

suite(
    "Memory Buffer",
    func() {
        let mbuffer = MemoryBuffer.new<Text>();

        test(
            "add() to Buffer",
            func() {
                for (i in Iter.range(0, limit - 1)) {
                    let value = initial_values.get(i);
                    MemoryBuffer.add(mbuffer, TypeUtils.Text, value);

                    assert MemoryBuffer.get(mbuffer, TypeUtils.Text, i) == value;
                    assert MemoryBuffer.size(mbuffer) == i + 1;

                    assert MemoryRegion.size(mbuffer.pointers) == 64 + (MemoryBuffer.size(mbuffer) * 12);
                };

                let total_blob_size = Itertools.sum(
                    Iter.map(
                        MemoryBuffer.blocks(mbuffer),
                        func((_address, size) : (Nat, Nat)) : Nat = size,
                    ),
                    Nat.add,
                );

                switch (total_blob_size) {
                    case (?sum) {
                        let blob_size = MemoryRegion.size(mbuffer.blobs);
                        assert blob_size == sum + 64;
                    };
                    case null {
                        let blob_size = MemoryRegion.size(mbuffer.blobs);
                        assert blob_size == 64;
                    };
                };
            },
        );

        test(
            "get() from Buffer",
            func() {
                for (i in Iter.range(0, limit - 1)) {
                    let expected_value = initial_values.get(i);
                    assert MemoryBuffer.get(mbuffer, TypeUtils.Text, i) == expected_value;
                };
            },
        );

        test(
            "put() (new == prev) in Buffer",
            func() {
                for (i in order.vals()) {
                    let initial_value = initial_values.get(i);
                    let equal_value = equal_size_values.get(i);

                    assert MemoryBuffer.get(mbuffer, TypeUtils.Text, i) == initial_value;

                    MemoryBuffer.put(mbuffer, TypeUtils.Text, i, equal_value);
                    validate_region(mbuffer.blobs);
                    validate_region(mbuffer.pointers);
                    assert MemoryBuffer.get(mbuffer, TypeUtils.Text, i) == equal_value;
                };

                // After putting equal values, the memory region should not change
                assert MemoryRegion.getFreeMemory(mbuffer.blobs) == [];
                assert MemoryRegion.getFreeMemory(mbuffer.pointers) == [];
            },
        );

        test(
            "get() from Buffer",
            func() {
                for (i in Iter.range(0, limit - 1)) {
                    let expected_value = equal_size_values.get(i);
                    assert MemoryBuffer.get(mbuffer, TypeUtils.Text, i) == expected_value;
                };
            },
        );

        test(
            "put() new > old",
            func() {

                let memory_blocks_map = MemoryBlocksMap(mbuffer);

                for (i in order.vals()) {
                    let equal_value = equal_size_values.get(i);
                    let greater_value = greater_size_values.get(i);

                    assert MemoryBuffer.get(mbuffer, TypeUtils.Text, i) == equal_value; // ensures the previous value did not get overwritten

                    let _pointer = MemoryBuffer._get_pointer(mbuffer, i);
                    let _memory_block = MemoryBuffer._get_memory_block(mbuffer, i);
                    let blob = MemoryBuffer._get_blob(mbuffer, i);
                    // Debug.print("old " # debug_show (i, pointer, memory_block, blob, TypeUtils.Text.blobify.to_blob(equal_value)));
                    assert blob == TypeUtils.Text.blobify.to_blob(equal_value);

                    let prev_block_free_memory = MemoryRegion.getFreeMemory(mbuffer.blobs);
                    if (_memory_block.1 > 0) {
                        // Debug.print("previous memory region free memory: " # debug_show (prev_block_free_memory));
                        // assert MemoryRegion.isAllocated(mbuffer.blobs, _memory_block.0);
                        if (not MemoryRegion.isAllocated(mbuffer.blobs, _memory_block.0, _memory_block.1)) {
                            Debug.print("Memory block was not allocated at index " # debug_show i);
                            Debug.print("Memory block: " # debug_show _memory_block);
                            Debug.print("Pointer: " # debug_show _pointer);
                            Debug.print("Blob: " # debug_show blob);
                            Debug.print("prev memory region free memory: " # debug_show (prev_block_free_memory));
                            assert false;
                        };

                        if (MemoryRegion.isFreed(mbuffer.blobs, _memory_block.0, _memory_block.1) != #ok(false)) {
                            Debug.print("isFreed response: " # debug_show (MemoryRegion.isFreed(mbuffer.blobs, _memory_block.0, _memory_block.1)));
                            Debug.print("Memory block was freed unexpectedly at index " # debug_show i);
                            Debug.print("Memory block: " # debug_show _memory_block);
                            Debug.print("Pointer: " # debug_show _pointer);
                            Debug.print("Blob: " # debug_show blob);
                            Debug.print("memory region free memory: " # debug_show (MemoryRegion.getFreeMemory(mbuffer.blobs)));
                            assert false;
                        };
                        assert MemoryRegion.isFreed(mbuffer.blobs, _memory_block.0, _memory_block.1) == #ok(false);

                    };

                    // Debug.print("node keys: " # debug_show (MaxBpTree.toNodeKeys(mbuffer.blobs.free_memory)));
                    // Debug.print("leaf nodes: " # debug_show (MaxBpTree.toLeafNodes(mbuffer.blobs.free_memory)));
                    MemoryBuffer.put(mbuffer, TypeUtils.Text, i, greater_value);

                    validate_region(mbuffer.blobs);
                    validate_region(mbuffer.pointers);

                    let serialized = TypeUtils.Text.blobify.to_blob(greater_value);

                    let new_pointer = MemoryBuffer._get_pointer(mbuffer, i);
                    let new_memory_block = MemoryBuffer._get_memory_block(mbuffer, i);
                    let new_blob = MemoryBuffer._get_blob(mbuffer, i);

                    if (new_memory_block.1 > 0) {
                        if (not MemoryRegion.isAllocated(mbuffer.blobs, new_memory_block.0, new_memory_block.1)) {
                            Debug.print("Memory block was not allocated at index " # debug_show i);
                            Debug.print("Memory block: " # debug_show new_memory_block);
                            Debug.print("Pointer: " # debug_show new_pointer);
                            Debug.print("Blob: " # debug_show new_blob);
                            Debug.print("previous memory region free memory: " # debug_show (prev_block_free_memory));
                            Debug.print("current memory region free memory: " # debug_show (MemoryRegion.getFreeMemory(mbuffer.blobs)));
                            assert false;
                        };

                        if (not memory_blocks_map.add(new_memory_block, i)) {
                            Debug.print("i = " # debug_show i # ", greater_value = " # debug_show greater_value # ", received = " # debug_show MemoryBuffer.get(mbuffer, TypeUtils.Text, i));
                            Debug.print("old blob: " # debug_show blob);
                            Debug.print("new blob: " # debug_show new_blob);

                            Debug.print("old pointer: " # debug_show _pointer);
                            Debug.print("new pointer: " # debug_show MemoryBuffer._get_pointer(mbuffer, i));

                            Debug.print("old memory block: " # debug_show _memory_block);
                            Debug.print("new memory block: " # debug_show MemoryBuffer._get_memory_block(mbuffer, i));

                            Debug.print("blobs free memory: " # debug_show (prev_block_free_memory));
                            Debug.print("pointers free memory: " # debug_show (MemoryRegion.getFreeMemory(mbuffer.pointers)));

                            assert false;

                        };

                    };

                    // Debug.print("new " # debug_show (i, new_pointer, new_memory_block, new_blob));
                    // Debug.print("expected " # debug_show serialized);
                    assert new_blob == serialized;
                    assert MemoryBuffer.get(mbuffer, TypeUtils.Text, i) == greater_value;

                };
            },
        );

        test(
            "get() from Buffer",
            func() {
                for (i in Iter.range(0, limit - 1)) {
                    let expected_value = greater_size_values.get(i);

                    assert MemoryBuffer.get(mbuffer, TypeUtils.Text, i) == expected_value;
                };
            },
        );

        test(
            "put() (new < prev) in Buffer",
            func() {

                for (i in order.vals()) {
                    let greater_value = greater_size_values.get(i);
                    let less_value = less_size_values.get(i);

                    assert MemoryBuffer.get(mbuffer, TypeUtils.Text, i) == greater_value; // ensures the previous value did not get overwritten

                    MemoryBuffer.put(mbuffer, TypeUtils.Text, i, less_value);
                    // Debug.print("node keys: " # debug_show (MaxBpTree.toNodeKeys(mbuffer.blobs.free_memory)));
                    // Debug.print("leaf nodes: " # debug_show (MaxBpTree.toLeafNodes(mbuffer.blobs.free_memory)));
                    validate_region(mbuffer.blobs);
                    validate_region(mbuffer.pointers);
                    let received = MemoryBuffer.get(mbuffer, TypeUtils.Text, i);
                    if (received != less_value) {
                        Debug.print("mismatch at i = " # debug_show i);
                        Debug.print("(expected, received) -> " # debug_show (less_value, received));

                        assert false;
                    };
                };
            },
        );

        test(
            "get() from Buffer",
            func() {

                for (i in Iter.range(0, limit - 1)) {
                    let expected_value = less_size_values.get(i);
                    assert MemoryBuffer.get(mbuffer, TypeUtils.Text, i) == expected_value;
                };
            },
        );

    },
);
