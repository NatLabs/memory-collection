// @testmode wasi
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";

import MemoryRegion "mo:memory-region/MemoryRegion";
import { test; suite } "mo:test";

import MemoryQueue "../../src/MemoryQueue/Base";
import Blobify "../../src/Blobify";

let limit = 10_000;
let buffer = Buffer.Buffer<Nat>(limit);
for (i in Iter.range(0, limit - 1)) {
    buffer.add(i);
};

let mem_queue = MemoryQueue.new();

suite(
    "MemoryQueueTests",
    func() {
        test(
            "add()",
            func() {

                for (i in buffer.vals()) {
                    MemoryQueue.add(mem_queue, Blobify.Nat, i);
                    assert MemoryQueue.size(mem_queue) == i + 1;
                };

            },
        );

        test(
            "pop() and peek()",
            func() {

                for (i in buffer.vals()) {
                    assert ?i == MemoryQueue.peek(mem_queue, Blobify.Nat);
                    assert ?i == MemoryQueue.pop(mem_queue, Blobify.Nat);
                    assert MemoryQueue.size(mem_queue) == limit - i - 1;
                };

                assert null == MemoryQueue.peek(mem_queue, Blobify.Nat);
                assert null == MemoryQueue.pop(mem_queue, Blobify.Nat);
            },
        );

        test(
            "clear()",
            func() {
                MemoryQueue.clear(mem_queue);
                assert MemoryRegion.size(mem_queue.region) == 64;
            },
        );

        test(
            "add()",
            func() {

                for (i in buffer.vals()) {
                    MemoryQueue.add(mem_queue, Blobify.Nat, i);
                    assert MemoryQueue.size(mem_queue) == i + 1;
                };

            },
        );

        test(
            "pop() and peek()",
            func() {

                for (i in buffer.vals()) {
                    assert ?i == MemoryQueue.peek(mem_queue, Blobify.Nat);
                    assert ?i == MemoryQueue.pop(mem_queue, Blobify.Nat);
                    assert MemoryQueue.size(mem_queue) == limit - i - 1;
                };
                
                assert null == MemoryQueue.peek(mem_queue, Blobify.Nat);
                assert null == MemoryQueue.pop(mem_queue, Blobify.Nat);
                
                assert MemoryRegion.size(mem_queue.region) == 64;
            },
        );

    },
);
