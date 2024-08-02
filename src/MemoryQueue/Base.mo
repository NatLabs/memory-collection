import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";

import MemoryRegion "mo:memory-region/MemoryRegion";

import Blobify "../TypeUtils/Blobify";
import TypeUtils "../TypeUtils";

module MemoryQueue {

    type Blobify<A> = Blobify.Blobify<A>;
    type Iter<A> = Iter.Iter<A>;
    type MemoryRegion = MemoryRegion.MemoryRegion;

    //
    public type MemoryQueue = {
        region : MemoryRegion;

        var head : Nat;
        var tail : Nat;
        var count : Nat;
    };

    public type MemoryQueueUtils<A> = {
        blobify : TypeUtils.Blobify<A>;
    };

    public func createUtils<A>(queue_utils : MemoryQueueUtils<A>) : MemoryQueueUtils<A> {
        queue_utils;
    };

    /// Create a new memory queue
    public func new<A>() : MemoryQueue {
        let mem_queue : MemoryQueue = {
            region = MemoryRegion.new();

            var head = 0;
            var tail = 0;
            var count = 0;
        };

        init_region_header(mem_queue);

        mem_queue;
    };

    let C = {
        MAGIC_NUMBER_ADDRESS = 0x00;
        LAYOUT_VERSION_ADDRESS = 3;
        COUNT_ADDRESS = 4;
        HEAD_START = 12;
        TAIL_START = 20;

        POINTERS_START = 64;
        BLOB_START = 64;

        REGION_HEADER_SIZE = 64;
        LAYOUT_VERSION = 0;
        NULL_ADDRESS = 0x00;

        NODE_NEXT_OFFSET = 0;
        NODE_SIZE_OFFSET = 8;
        NODE_VALUE_OFFSET = 12;

        NODE_METADATA_SIZE = 12;
    };

    /// Node layout
    /// | Next (8 bytes) | Size (4 bytes) | Value (|Size| bytes) |

    func init_region_header<A>(mem_queue : MemoryQueue) {

        ignore MemoryRegion.allocate(mem_queue.region, C.REGION_HEADER_SIZE); // Reserved Space for the Region Header
        MemoryRegion.storeBlob(mem_queue.region, C.MAGIC_NUMBER_ADDRESS, "MQU");
        MemoryRegion.storeNat8(mem_queue.region, C.LAYOUT_VERSION_ADDRESS, Nat8.fromNat(C.LAYOUT_VERSION));
        MemoryRegion.storeNat64(mem_queue.region, C.COUNT_ADDRESS, 0);
        MemoryRegion.storeNat64(mem_queue.region, C.HEAD_START, Nat64.fromNat(C.NULL_ADDRESS));
        MemoryRegion.storeNat64(mem_queue.region, C.TAIL_START, Nat64.fromNat(C.NULL_ADDRESS));
        assert MemoryRegion.size(mem_queue.region) == C.REGION_HEADER_SIZE;
    };

    func update_count(mem_queue : MemoryQueue, count : Nat) {
        mem_queue.count := count;
        MemoryRegion.storeNat64(mem_queue.region, C.COUNT_ADDRESS, Nat64.fromNat(count));
    };

    func update_head(mem_queue : MemoryQueue, head : Nat) {
        mem_queue.head := head;
        MemoryRegion.storeNat64(mem_queue.region, C.HEAD_START, Nat64.fromNat(head));
    };

    func update_tail(mem_queue : MemoryQueue, tail : Nat) {
        mem_queue.tail := tail;
        MemoryRegion.storeNat64(mem_queue.region, C.TAIL_START, Nat64.fromNat(tail));
    };

    /// Checks if the memory queue is empty
    public func isEmpty(mem_queue : MemoryQueue) : Bool {
        mem_queue.count == 0;
    };

    public type MemoryQueueStats = MemoryRegion.MemoryInfo;

    public func stats(mem_queue : MemoryQueue) : MemoryQueueStats {
        MemoryRegion.memoryInfo(mem_queue.region);
    };

    /// Returns the number of elements in the memory queue
    public func size(mem_queue : MemoryQueue) : Nat {
        mem_queue.count;
    };

    /// Adds a value to the end of the memory queue
    public func add<A>(mem_queue : MemoryQueue, queue_utils : MemoryQueueUtils<A>, value : A) {
        let blob = queue_utils.blobify.to_blob(value);

        let node_address = MemoryRegion.allocate(mem_queue.region, C.NODE_METADATA_SIZE + blob.size());
        MemoryRegion.storeNat64(mem_queue.region, node_address + C.NODE_NEXT_OFFSET, Nat64.fromNat(C.NULL_ADDRESS));
        MemoryRegion.storeNat32(mem_queue.region, node_address + C.NODE_SIZE_OFFSET, Nat32.fromNat(blob.size()));
        MemoryRegion.storeBlob(mem_queue.region, node_address + C.NODE_VALUE_OFFSET, blob);

        if (mem_queue.count == 0) {
            update_head(mem_queue, node_address);
        } else {
            MemoryRegion.storeNat64(mem_queue.region, mem_queue.tail + C.NODE_NEXT_OFFSET, Nat64.fromNat(node_address));
        };

        update_tail(mem_queue, node_address);
        update_count(mem_queue, mem_queue.count + 1);
    };

    /// Removes and returns the first element in the memory queue.
    /// If the queue is empty, it returns `null`.
    public func pop<A>(mem_queue : MemoryQueue, queue_utils : MemoryQueueUtils<A>) : ?A {

        let node_address = if (mem_queue.count > 0) mem_queue.head else return null;

        let next = MemoryRegion.loadNat64(mem_queue.region, node_address + C.NODE_NEXT_OFFSET)
        |> Nat64.toNat(_);
        let size = MemoryRegion.loadNat32(mem_queue.region, node_address + C.NODE_SIZE_OFFSET)
        |> Nat32.toNat(_);

        let blob = MemoryRegion.loadBlob(mem_queue.region, node_address + C.NODE_VALUE_OFFSET, size);

        update_head(mem_queue, next);

        if (mem_queue.count == 1) {
            update_tail(mem_queue, C.NULL_ADDRESS);
        };

        update_count(mem_queue, mem_queue.count - 1);

        MemoryRegion.deallocate(mem_queue.region, node_address, C.NODE_METADATA_SIZE + size);

        let value = queue_utils.blobify.from_blob(blob);
        ?(value);
    };

    /// Returns the first element at the front of the memory queue.
    public func peek<A>(mem_queue : MemoryQueue, queue_utils : MemoryQueueUtils<A>) : ?A {
        let node_address = if (mem_queue.count > 0) mem_queue.head else return null;

        let size = MemoryRegion.loadNat32(mem_queue.region, node_address + C.NODE_SIZE_OFFSET)
        |> Nat32.toNat(_);

        let blob = MemoryRegion.loadBlob(mem_queue.region, node_address + C.NODE_VALUE_OFFSET, size);

        let value = queue_utils.blobify.from_blob(blob);
        ?(value);
    };

    /// Returns an iterator over the values in the memory queue, starting from the front.
    public func vals<A>(mem_queue : MemoryQueue, queue_utils : MemoryQueueUtils<A>) : Iter<A> {
        var node = mem_queue.head;

        func next() : ?A {
            if (node == C.NULL_ADDRESS) {
                return null;
            };

            let size = MemoryRegion.loadNat32(mem_queue.region, node + C.NODE_SIZE_OFFSET)
            |> Nat32.toNat(_);

            let blob = MemoryRegion.loadBlob(mem_queue.region, node + C.NODE_VALUE_OFFSET, size);

            let value = queue_utils.blobify.from_blob(blob);

            node := MemoryRegion.loadNat64(mem_queue.region, node + C.NODE_NEXT_OFFSET)
            |> Nat64.toNat(_);

            ?(value);
        };

        { next };
    };

    /// Returns an array of the values in the queue, in the order they were added.
    public func toArray<A>(mem_queue : MemoryQueue, queue_utils : MemoryQueueUtils<A>) : [A] {
        let vals_iter = vals(mem_queue, queue_utils);

        Array.tabulate(
            mem_queue.count,
            func(i : Nat) : A {
                let ?value = vals_iter.next() else Debug.trap("MemoryQueue.toArray: index out of bounds");
                value;
            },
        );
    };

    /// Removes all the elements from the memory queue.
    public func clear<A>(mem_queue : MemoryQueue) {
        MemoryRegion.clear(mem_queue.region);
        init_region_header(mem_queue);
    };

};
