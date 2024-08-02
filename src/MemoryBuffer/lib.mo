/// ## Memory Buffer
/// A memory buffer is a data structure that stores a sequence of values in memory.
///
/// Import the `MemoryBuffer` module to use the memory buffer data structure.
/// ```motoko
/// import MemoryBuffer "mo:memory-collection/MemoryBuffer";
/// import TypeUtils "mo:memory-collection/TypeUtils";
/// ```
///
/// #### Usage Examples
/// ```motoko
///   stable var sstore = MemoryBuffer.newStableStore<Nat>();
///
///   let buffer = MemoryBuffer.MemoryBuffer<Nat>(sstore, TypeUtils.Nat);
///   buffer.add(1);
///   buffer.add(3);
///   buffer.insert(1, 2);
///   assert buffer.toArray() == [1, 2, 3];
///
///   for ((i, n) in buffer.items()) {
///     assert buffer.get(i) == n;
///     buffer.put(i, n ** 2);
///   };
///
///   assert buffer.toArray() == [1, 4, 9];
///   assert buffer.remove(1) == ?4;
///   assert buffer.removeLast() == ?9;
/// ```

import Iter "mo:base/Iter";
import Order "mo:base/Order";
import Nat "mo:base/Nat";

import RevIter "mo:itertools/RevIter";

import BaseMemoryBuffer "Base";
import StableMemoryBuffer "Stable";
import Migrations "Migrations";
import MemoryCmp "../TypeUtils/MemoryCmp";

module {

    type Iter<A> = Iter.Iter<A>;
    type RevIter<A> = RevIter.RevIter<A>;
    type Order = Order.Order;
    public type MemoryBufferUtils<A> = BaseMemoryBuffer.MemoryBufferUtils<A>;
    public type MemoryBufferStats = BaseMemoryBuffer.MemoryBufferStats;

    public type BaseMemoryBuffer<A> = Migrations.MemoryBuffer<A>;
    public type StableMemoryBuffer<A> = Migrations.VersionedMemoryBuffer<A>;

    /// Creates a new stable store for the memory buffer.

    public type StableStore<A> = StableMemoryBuffer<A>;

    public func createUtils<A>(buffer_utils : MemoryBufferUtils<A>) : MemoryBufferUtils<A> {
        buffer_utils;
    };

    /// Creates a new stable store for the memory buffer.
    public func newStableStore<A>() : StableMemoryBuffer<A> = StableMemoryBuffer.new();

    public func upgrade<A>(sstore : StableMemoryBuffer<A>) : StableMemoryBuffer<A> {
        Migrations.upgrade<A>(sstore);
    };

    public class MemoryBuffer<A>(sstore : StableMemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>) {
        let internal = Migrations.getCurrentVersion(sstore);

        /// Adds an element to the end of the buffer.
        public func add(elem : A) = BaseMemoryBuffer.add<A>(internal, buffer_utils, elem);

        /// Returns the element at the given index.
        public func get(i : Nat) : A = BaseMemoryBuffer.get<A>(internal, buffer_utils, i);

        /// Returns the number of elements in the buffer.
        public func size() : Nat = BaseMemoryBuffer.size<A>(internal);

        /// Returns the number of bytes used to store the serialized elements in the buffer.
        public func bytes() : Nat = BaseMemoryBuffer.bytes<A>(internal);

        /// Returns the number of bytes used to store the metadata and memory block pointers.
        public func metadataBytes() : Nat = BaseMemoryBuffer.metadataBytes<A>(internal);

        /// Returns the number of elements the buffer can hold before resizing.
        public func capacity() : Nat = BaseMemoryBuffer.capacity<A>(internal);

        /// Overwrites the element at the given index with the new element.
        public func put(i : Nat, elem : A) = BaseMemoryBuffer.put<A>(internal, buffer_utils, i, elem);

        /// Returns the element at the given index or `null` if the index is out of bounds.
        public func getOpt(i : Nat) : ?A = BaseMemoryBuffer.getOpt<A>(internal, buffer_utils, i);

        /// Adds all elements from the given iterator to the end of the buffer.
        public func addFromIter(iter : Iter<A>) = BaseMemoryBuffer.addFromIter<A>(internal, buffer_utils, iter);

        /// Adds all elements from the given array to the end of the buffer.
        public func addFromArray(arr : [A]) = BaseMemoryBuffer.addFromArray<A>(internal, buffer_utils, arr);

        /// Returns a reversable iterator over the elements in the buffer.
        ///
        /// ```motoko
        ///     stable var sstore = MemoryBuffer.newStableStore<Text>();
        ///     sstore := MemoryBuffer.upgrade(sstore);
        ///
        ///     let buffer = MemoryBuffer.MemoryBuffer<Text>(sstore, TypeUtils.Text);
        ///
        ///     buffer.addFromArray(["a", "b", "c"]);
        ///
        ///     let vals = Iter.toArray(buffer.vals());
        ///     assert vals == ["a", "b", "c"];
        ///
        ///     let reversed = Iter.toArray(buffer.vals().rev());
        ///     assert reversed == ["c", "b", "a"];
        /// ```
        public func vals() : RevIter<A> = BaseMemoryBuffer.vals<A>(internal, buffer_utils);

        /// Returns a reversable iterator over a tuple of the index and element in the buffer.
        public func items() : RevIter<(Nat, A)> = BaseMemoryBuffer.items<A>(internal, buffer_utils);

        /// Returns a reversable iterator over the serialized elements in the buffer.
        public func blobs() : RevIter<Blob> = BaseMemoryBuffer.blobs<A>(internal);

        /// Swaps the elements at the given indices.
        public func swap(i : Nat, j : Nat) = BaseMemoryBuffer.swap<A>(internal, i, j);

        /// Swaps the element at the given index with the last element in the buffer and removes it.
        /// Returns the removed element or null if the array is empty.
        ///
        /// Runtime: `O(1)`
        ///
        /// ```motoko
        ///    stable var sstore = MemoryBuffer.newStableStore<Text>();
        ///    sstore := MemoryBuffer.upgrade(sstore);
        ///
        ///   let buffer = MemoryBuffer.MemoryBuffer<Nat>(sstore, TypeUtils.Nat); // little-endian
        ///
        ///   buffer.addFromArray([1, 2, 3]);
        ///
        ///   assert buffer.swapRemove(0) == ?1;
        ///   assert buffer.toArray() == [3, 2];
        /// ```

        public func swapRemove(i : Nat) : A = BaseMemoryBuffer.swapRemove<A>(internal, buffer_utils, i);

        /// Removes the element at the given index.
        public func remove(i : Nat) : A = BaseMemoryBuffer.remove<A>(internal, buffer_utils, i);

        /// Removes the last element from the buffer.
        ///
        /// ```motoko
        ///     stable var sstore = MemoryBuffer.newStableStore<Text>();
        ///     sstore := MemoryBuffer.upgrade(sstore);
        ///
        ///     let buffer = MemoryBuffer.MemoryBuffer<Nat>(sstore, TypeUtils.Nat); // little-endian
        ///
        ///     buffer.addFromArray([1, 2, 3]);
        ///
        ///     assert buffer.removeLast() == ?3;
        /// ```
        public func removeLast() : ?A = BaseMemoryBuffer.removeLast<A>(internal, buffer_utils);

        /// Inserts an element at the given index.
        public func insert(i : Nat, elem : A) = BaseMemoryBuffer.insert<A>(internal, buffer_utils, i, elem);

        /// Sorts the elements in the buffer using the given comparison function.
        /// This function implements quicksort, an unstable sorting algorithm with an average time complexity of `O(n log n)`.
        /// It also supports a comparision function that can either compare the elements the default type or in their serialized form as blobs.
        /// For more information on the comparison function, refer to the [MemoryCmp module](../MemoryCmp).
        public func sortUnstable(cmp : MemoryCmp.MemoryCmp<A>) = BaseMemoryBuffer.sortUnstable<A>(internal, buffer_utils, cmp);

        /// Removes all elements from the buffer.
        public func clear() = BaseMemoryBuffer.clear<A>(internal);

        /// Copies all the elements in the buffer to a new array.
        public func toArray() : [A] = BaseMemoryBuffer.toArray<A>(internal, buffer_utils);

        /// Randomly shuffles the elements in the buffer.
        public func shuffle() = BaseMemoryBuffer.shuffle<A>(internal);

        /// Reverse the order of the elements in the buffer.
        public func reverse() = BaseMemoryBuffer.reverse<A>(internal);

        /// Returns the index of the first element that is equal to the given element.
        public func indexOf(equal : (A, A) -> Bool, elem : A) : ?Nat = BaseMemoryBuffer.indexOf<A>(internal, buffer_utils, equal, elem);

        /// Returns the index of the last element that is equal to the given element.
        public func lastIndexOf(equal : (A, A) -> Bool, elem : A) : ?Nat = BaseMemoryBuffer.lastIndexOf<A>(internal, buffer_utils, equal, elem);

        /// Returns `true` if the buffer contains the given element.
        public func contains(equal : (A, A) -> Bool, elem : A) : Bool = BaseMemoryBuffer.contains<A>(internal, buffer_utils, equal, elem);

        /// Returns `true` if the buffer is empty.
        public func isEmpty() : Bool = BaseMemoryBuffer.isEmpty<A>(internal);

        /// Returns the stats for each of the regions used by the memory buffer.
        public func stats() : MemoryBufferStats = BaseMemoryBuffer.stats<A>(internal);

        public func _getInternalRegion() : BaseMemoryBuffer<A> = internal;
        public func _getBlobifyFn() : MemoryBufferUtils<A> = buffer_utils;
    };

    public func init<A>(internal : StableMemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>, size : Nat, val : A) : MemoryBuffer<A> {
        let mbuffer = MemoryBuffer(internal, buffer_utils);

        for (_ in Iter.range(0, size - 1)) {
            mbuffer.add(val);
        };

        return mbuffer;
    };

    // public func tabulate<A>(internal: StableMemoryBuffer<A>, buffer_utils: MemoryBufferUtils<A>, size: Nat, f: (Nat) -> A) : MemoryBuffer<A> {
    //     BaseMemoryBuffer.tabulate(internal, buffer_utils, size, f);
    //     return MemoryBuffer(internal, buffer_utils);
    // };

    // public func fromArray<A>(internal: StableMemoryBuffer<A>, buffer_utils: MemoryBufferUtils<A>, arr: [A]) : MemoryBuffer<A> {
    //     BaseMemoryBuffer.fromArray(internal, buffer_utils, arr);
    //     return MemoryBuffer(internal, buffer_utils);
    // };

    public func toArray<A>(mbuffer : MemoryBuffer<A>) : [A] {
        return BaseMemoryBuffer.toArray(mbuffer._getInternalRegion(), mbuffer._getBlobifyFn());
    };

    // public func fromIter<A>(internal: StableMemoryBuffer<A>, buffer_utils: MemoryBufferUtils<A>, iter: Iter<A>) : MemoryBuffer<A> {
    //     BaseMemoryBuffer.fromIter(internal, buffer_utils, iter);
    //     return MemoryBuffer(internal, buffer_utils);
    // };

    public func append<A>(mbuffer : MemoryBuffer<A>, b : MemoryBuffer<A>) {
        BaseMemoryBuffer.append(mbuffer._getInternalRegion(), mbuffer._getBlobifyFn(), b._getInternalRegion());
    };

    public func appendArray<A>(mbuffer : MemoryBuffer<A>, arr : [A]) {
        BaseMemoryBuffer.appendArray<A>(mbuffer._getInternalRegion(), mbuffer._getBlobifyFn(), arr);
    };

    public func appendBuffer<A>(mbuffer : MemoryBuffer<A>, other : { vals : () -> Iter<A> }) {
        BaseMemoryBuffer.appendBuffer<A>(mbuffer._getInternalRegion(), mbuffer._getBlobifyFn(), other);
    };

    public func blocks<A>(mbuffer : MemoryBuffer<A>) : RevIter<(Nat, Nat)> = BaseMemoryBuffer.blocks<A>(mbuffer._getInternalRegion());

    public func reverse<A>(mbuffer : MemoryBuffer<A>) = BaseMemoryBuffer.reverse<A>(mbuffer._getInternalRegion());

};
