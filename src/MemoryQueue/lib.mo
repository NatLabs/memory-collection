/// ## MemoryQueue
///
/// A persistent First In First Out queue using stable memory.
///
/// The queue is implemented as a singly linked list of nodes,
/// where each node contains the value, its size, and a pointer to the next node.
///
/// Each node requires a overhead of 12 bytes (8 bytes for the pointer, 4 bytes for the size)
/// in addition to the value itself. It's important to consider this overhead when storing values.
///
///
/// To use the module, you need to import the required modules:
/// ```motoko name=imported-modules
/// import MemoryQueue "mo:memory-collections/MemoryQueue";
/// import TypeUtils "mo:memory-collections/TypeUtils";
/// ```

import Iter "mo:base/Iter";
import Nat "mo:base/Nat";

import MemoryRegion "mo:memory-region/MemoryRegion";

import BaseMemoryQueue "Base";
import StableMemoryQueue "Stable";

import Migrations "migrations";

module {

    public type Iter<A> = Iter.Iter<A>;
    public type MemoryRegion = MemoryRegion.MemoryRegion;
    public type BaseMemoryQueue = BaseMemoryQueue.MemoryQueue;
    public type StableMemoryQueue = StableMemoryQueue.StableMemoryQueue;
    public type MemoryQueueUtils<A> = BaseMemoryQueue.MemoryQueueUtils<A>;
    public type MemoryQueueStats = BaseMemoryQueue.MemoryQueueStats;

    public type StableStore = StableMemoryQueue;

    public func newStableStore() : StableMemoryQueue {
        StableMemoryQueue.new();
    };

    public func upgrade(sstore : StableMemoryQueue) : StableMemoryQueue {
        Migrations.upgrade(sstore);
    };

    public func createUtils<A>(queue_utils : MemoryQueueUtils<A>) : MemoryQueueUtils<A> {
        queue_utils;
    };

    /// Example:
    ///
    /// ```motoko
    /// stable var sstore = MemoryQueue.newStableStore();
    /// sstore := MemoryQueue.upgrade(sstore);
    ///
    /// let queue = MemoryQueue.new<Text>(sstore, TypeUtils.Text);
    ///
    /// queue.add("first");
    /// queue.add("second");
    /// queue.add("third");
    ///
    /// assert queue.size() == 3;
    /// assert queue.pop() == ?"first";
    ///
    /// assert queue.size() == 2;
    /// assert queue.peek() == ?"second";
    /// ```
    public class MemoryQueue<A>(sstore : StableStore, queue_utils : MemoryQueueUtils<A>) {
        let state = Migrations.getCurrentVersion(sstore);

        /// Adds a value to the end of the memory queue
        public func add(val : A) = BaseMemoryQueue.add(state, queue_utils, val);

        /// Returns the first element at the front of the memory queue.
        public func peek() : ?A = BaseMemoryQueue.peek(state, queue_utils);

        /// Removes and returns the first element in the memory queue.
        /// If the queue is empty, it returns `null`.
        public func pop() : ?A = BaseMemoryQueue.pop(state, queue_utils);

        /// Returns the number of elements in the memory queue
        public func size() : Nat = BaseMemoryQueue.size(state);

        /// Checks if the memory queue is empty
        public func isEmpty() : Bool = BaseMemoryQueue.isEmpty(state);

        /// Removes all the elements from the memory queue.
        public func clear() = BaseMemoryQueue.clear(state);

        /// Returns an iterator over the values in the memory queue, starting from the front.
        public func vals() : Iter<A> = BaseMemoryQueue.vals(state, queue_utils);

        /// Returns an array of the values in the queue, in the order they were added.
        public func toArray() : [A] = BaseMemoryQueue.toArray(state, queue_utils);

        /// Returns the memory stats for the memory region used by the memory queue.
        public func stats() : BaseMemoryQueue.MemoryQueueStats = BaseMemoryQueue.stats(state);

    };
};
