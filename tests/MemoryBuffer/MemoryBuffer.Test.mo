// @testmode wasi
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Prelude "mo:base/Prelude";
import Nat "mo:base/Nat";
import Array "mo:base/Array";

import { test; suite } "mo:test";
import Fuzz "mo:fuzz";
import { MaxBpTree; Cmp } "mo:augmented-btrees";
import MemoryRegion "mo:memory-region/MemoryRegion";
import Itertools "mo:itertools/Iter";
import MaxBpTreeMethods "mo:augmented-btrees/MaxBpTree/Methods";

import MemoryBuffer "../../src/MemoryBuffer/Base";

import Utils "../../src/Utils";
import TypeUtils "../../src/TypeUtils";

let { MemoryCmp; Blobify; Int8Cmp } = TypeUtils;

let limit = 10_000;
let order = Buffer.Buffer<Nat>(limit);
let values = Buffer.Buffer<Nat>(limit);

for (i in Iter.range(0, limit - 1)) {
    order.add(i);
};

let fuzz = Fuzz.fromSeed(0x7f7f);
fuzz.buffer.shuffle(order);
// Utils.shuffle_buffer(fuzz, order);

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

suite(
    "Memory Buffer",
    func() {
        let mbuffer = MemoryBuffer.new<Nat>();

        test(
            "add() to Buffer",
            func() {
                for (i in Iter.range(0, limit - 1)) {
                    MemoryBuffer.add(mbuffer, TypeUtils.BigEndian.Nat, i);
                    values.add(i);

                    assert MemoryBuffer.get(mbuffer, TypeUtils.BigEndian.Nat, i) == i;
                    assert MemoryBuffer.size(mbuffer) == i + 1;

                    // assert MemoryRegion.size(mbuffer.pointers) == 64 + (MemoryBuffer.size(mbuffer) * 12);
                };

                assert ?(MemoryRegion.size(mbuffer.blobs) - 64) == Itertools.sum(
                    Iter.map(
                        MemoryBuffer.blocks(mbuffer),
                        func((address, size) : (Nat, Nat)) : Nat = size,
                    ),
                    Nat.add,
                );
            },
        );

        test(
            "put() (new == prev) in Buffer",
            func() {
                for (i in order.vals()) {
                    assert MemoryBuffer.get(mbuffer, TypeUtils.BigEndian.Nat, i) == i;

                    MemoryBuffer.put(mbuffer, TypeUtils.BigEndian.Nat, i, i);
                    validate_region(mbuffer.blobs);
                    validate_region(mbuffer.pointers);
                    assert MemoryBuffer.get(mbuffer, TypeUtils.BigEndian.Nat, i) == i;
                };
            },
        );

        test(
            "put() new > old",
            func() {
                for (i in order.vals()) {
                    let val = i * 100;
                    let pointer = MemoryBuffer._get_pointer(mbuffer, i);
                    let memory_block = MemoryBuffer._get_memory_block(mbuffer, i);
                    let blob = MemoryBuffer._get_blob(mbuffer, i);
                    // Debug.print("old " # debug_show (i, pointer, memory_block, blob, TypeUtils.BigEndian.Nat.blobify.to_blob(i)));
                    assert blob == TypeUtils.BigEndian.Nat.blobify.to_blob(i);

                    // Debug.print("node keys: " # debug_show (MaxBpTree.toNodeKeys(mbuffer.blobs.free_memory)));
                    // Debug.print("leaf nodes: " # debug_show (MaxBpTree.toLeafNodes(mbuffer.blobs.free_memory)));
                    MemoryBuffer.put(mbuffer, TypeUtils.BigEndian.Nat, i, i * 100);

                    validate_region(mbuffer.blobs);
                    validate_region(mbuffer.pointers);

                    let serialized = TypeUtils.BigEndian.Nat.blobify.to_blob(val);

                    let new_pointer = MemoryBuffer._get_pointer(mbuffer, i);
                    let new_memory_block = MemoryBuffer._get_memory_block(mbuffer, i);
                    let new_blob = MemoryBuffer._get_blob(mbuffer, i);

                    // Debug.print("new " # debug_show (i, new_pointer, new_memory_block, new_blob));
                    // Debug.print("expected " # debug_show serialized);
                    assert new_blob == serialized;
                };
            },
        );

        test(
            "put() (new < prev) in Buffer",
            func() {

                for (i in order.vals()) {

                    assert MemoryBuffer.get(mbuffer, TypeUtils.BigEndian.Nat, i) == i * 100; // ensures the previous value did not get overwritten

                    let new_value = i;
                    MemoryBuffer.put(mbuffer, TypeUtils.BigEndian.Nat, i, new_value);
                    // Debug.print("node keys: " # debug_show (MaxBpTree.toNodeKeys(mbuffer.blobs.free_memory)));
                    // Debug.print("leaf nodes: " # debug_show (MaxBpTree.toLeafNodes(mbuffer.blobs.free_memory)));
                    validate_region(mbuffer.blobs);
                    validate_region(mbuffer.pointers);
                    let received = MemoryBuffer.get(mbuffer, TypeUtils.BigEndian.Nat, i);
                    if (received != new_value) {
                        Debug.print("mismatch at i = " # debug_show i);
                        Debug.print("(exprected, received) -> " # debug_show (new_value, received));

                        assert false;
                    };
                };
            },
        );

        test(
            "removeLast() from Buffer",
            func() {

                for (i in Iter.range(0, limit - 1)) {
                    let expected = limit - i - 1;

                    let removed = MemoryBuffer.removeLast(mbuffer, TypeUtils.BigEndian.Nat);

                    validate_region(mbuffer.blobs);
                    validate_region(mbuffer.pointers);
                    // Debug.print("(expected, removed) -> " # debug_show (expected, removed));
                    assert ?expected == removed;
                };
            },
        );

        test(
            "add() reallocation",
            func() {
                assert MemoryBuffer.size(mbuffer) == 0;

                for (i in Iter.range(0, limit - 1)) {
                    MemoryBuffer.add(mbuffer, TypeUtils.BigEndian.Nat, i);

                    let expected = i;
                    let received = MemoryBuffer.get(mbuffer, TypeUtils.BigEndian.Nat, i);

                    if (expected != received) {
                        Debug.print("mismatch at i = " # debug_show i);
                        Debug.print("(exprected, received) -> " # debug_show (expected, received));
                        assert false;
                    };

                    assert MemoryBuffer.size(mbuffer) == i + 1;
                };

            },
        );

        test(
            "reverse()",
            func() {
                let array = MemoryBuffer.toArray(mbuffer, TypeUtils.BigEndian.Nat);
                MemoryBuffer.reverse(mbuffer);
                let reversed = Array.reverse(array);
                assert reversed == MemoryBuffer.toArray(mbuffer, TypeUtils.BigEndian.Nat);
            },
        );

        test(
            "remove() from Buffer",
            func() {
                var size = order.size();

                for (i in order.vals()) {
                    assert MemoryBuffer.size(mbuffer) == size;

                    let expected = i;
                    let j = Nat.min(i, MemoryBuffer.size(mbuffer) - 1);
                    let removed = MemoryBuffer.remove(mbuffer, TypeUtils.BigEndian.Nat, j);
                    validate_region(mbuffer.blobs);
                    validate_region(mbuffer.pointers);

                    size -= 1;
                };

                assert MemoryBuffer.size(mbuffer) == size;

            },
        );

        test(
            "insert()",
            func() {

                for (i in order.vals()) {
                    let j = Nat.min(i, MemoryBuffer.size(mbuffer));
                    // Debug.print("inserting i = " # debug_show i # " at index " # debug_show j);

                    MemoryBuffer.insert(mbuffer, TypeUtils.BigEndian.Nat, j, i);
                    let received = MemoryBuffer.get(mbuffer, TypeUtils.BigEndian.Nat, j);
                    if (received != i) {
                        Debug.print("mismatch at i = " # debug_show i);
                        Debug.print("(exprected, received) -> " # debug_show (i, received));
                        assert false;
                    };
                    // assert MemoryBuffer.get(mbuffer, TypeUtils.BigEndian.Nat, j) == i;
                };
            },
        );

        test(
            "shuffle",
            func() {
                MemoryBuffer.shuffle(mbuffer);

                for (i in Iter.range(0, limit - 1)) {
                    let n = MemoryBuffer.get(mbuffer, TypeUtils.BigEndian.Nat, i);
                };
            },
        );

        test(
            "sortUnstable",
            func() {
                MemoryBuffer.sortUnstable<Nat>(mbuffer, TypeUtils.BigEndian.Nat, MemoryCmp.BigEndian.Nat);

                var prev = MemoryBuffer.get(mbuffer, TypeUtils.BigEndian.Nat, 0);
                for (i in Iter.range(1, limit - 1)) {
                    let n = MemoryBuffer.get(mbuffer, TypeUtils.BigEndian.Nat, i);
                    assert prev <= n;
                    prev := n;
                };
            },
        );

        test(
            "clear()",
            func() {
                MemoryBuffer.clear(mbuffer);
                assert MemoryBuffer.size(mbuffer) == 0;
            },
        );

        test(
            "addFromIter",
            func() {
                let iter = Iter.range(0, limit - 1);
                MemoryBuffer.addFromIter(mbuffer, TypeUtils.BigEndian.Nat, iter);
                for (i in Iter.range(0, limit - 1)) {
                    let n = MemoryBuffer.get(mbuffer, TypeUtils.BigEndian.Nat, i);
                    assert n == i;
                };
            },
        );

        test(
            "indexOf",
            func() {
                let arr : [Nat] = [3, 782, 910, 1289, 4782, 9999];
                for (i in arr.vals()) {
                    let index = MemoryBuffer.indexOf<Nat>(mbuffer, TypeUtils.BigEndian.Nat, Nat.equal, i);
                    assert index == ?i;
                };
            },
        );

        test(
            "items()",
            func() {
                let items = MemoryBuffer.items(mbuffer, TypeUtils.BigEndian.Nat);
                for (i in Iter.range(0, limit - 1)) {
                    let n = MemoryBuffer.get(mbuffer, TypeUtils.BigEndian.Nat, i);
                    assert ?(i, n) == items.next();
                };
            },
        );

        test(
            "tabulate",
            func() {
                let mbuffer = MemoryBuffer.tabulate(TypeUtils.BigEndian.Nat, limit, func(i : Nat) : Nat = i);
                assert MemoryBuffer.size(mbuffer) == limit;
                for (i in Iter.range(0, limit - 1)) {
                    let n = MemoryBuffer.get(mbuffer, TypeUtils.BigEndian.Nat, i);
                    assert n == i;
                };
            },
        );

    },
);
