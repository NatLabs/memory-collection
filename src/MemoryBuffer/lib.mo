import Iter "mo:base/Iter";
import Order "mo:base/Order";
import Nat "mo:base/Nat";

import RevIter "mo:itertools/RevIter";

import Blobify "../Blobify";
import BaseMemoryBuffer "Base";
import VersionedMemoryBuffer "Versioned";
import Migrations "Migrations";
import MemoryCmp "../MemoryCmp";

module {

    /// ```motoko
    ///     let mbuffer = MemoryBufferClass.new();
    /// ```

    type Iter<A> = Iter.Iter<A>;
    type RevIter<A> = RevIter.RevIter<A>;
    type Order = Order.Order;
    type Blobify<A> = Blobify.Blobify<A>;

    public type BaseMemoryBuffer<A> = Migrations.MemoryBuffer<A>;
    public type VersionedMemoryBuffer<A> = Migrations.VersionedMemoryBuffer<A>;

    /// Creates a new stable store for the memory buffer.
    public func new<A>() : VersionedMemoryBuffer<A> = VersionedMemoryBuffer.new();

    /// Creates a new stable store for the memory buffer.
    public func newStableStore<A>() : VersionedMemoryBuffer<A> = VersionedMemoryBuffer.new();

    public func upgrade<A>(versions : VersionedMemoryBuffer<A>) : VersionedMemoryBuffer<A> {
        Migrations.upgrade<A>(versions);
    };

    public class MemoryBufferClass<A>(versions : VersionedMemoryBuffer<A>, blobify : Blobify<A>) {
        let internal = Migrations.getCurrentVersion(versions);

        /// Adds an element to the end of the buffer.
        public func add(elem: A) = BaseMemoryBuffer.add<A>(internal, blobify, elem);

        /// Returns the element at the given index.
        public func get(i: Nat) : A = BaseMemoryBuffer.get<A>(internal, blobify, i);

        /// Returns the number of elements in the buffer.
        public func size() : Nat = BaseMemoryBuffer.size<A>(internal);

        /// Returns the number of bytes used to store the serialized elements in the buffer.
        public func bytes() : Nat = BaseMemoryBuffer.bytes<A>(internal);

        /// Returns the number of bytes used to store the metadata and memory block pointers.
        public func metadataBytes() : Nat = BaseMemoryBuffer.metadataBytes<A>(internal);

        /// Returns the number of elements the buffer can hold before resizing.
        public func capacity() : Nat = BaseMemoryBuffer.capacity<A>(internal);
        
        /// Overwrites the element at the given index with the new element.
        public func put(i: Nat, elem: A) = BaseMemoryBuffer.put<A>(internal, blobify, i, elem);
        
        /// Returns the element at the given index or `null` if the index is out of bounds.
        public func getOpt(i: Nat) : ?A = BaseMemoryBuffer.getOpt<A>(internal, blobify, i);

        /// Adds all elements from the given iterator to the end of the buffer.
        public func addFromIter(iter: Iter<A>) = BaseMemoryBuffer.addFromIter<A>(internal, blobify, iter);

        /// Adds all elements from the given array to the end of the buffer.
        public func addFromArray(arr: [A]) = BaseMemoryBuffer.addFromArray<A>(internal, blobify, arr);

        /// Returns a reversable iterator over the elements in the buffer.
        /// 
        /// ```motoko
        ///     stable var sstore = BaseMemoryBuffer.newStableStore<Text>();
        ///     sstore := BaseMemoryBuffer.upgrade(sstore);
        ///     
        ///     let buffer = BaseMemoryBuffer.BaseMemoryBuffer<Text>(sstore, Blobify.Text);
        ///
        ///     buffer.addFromArray(["a", "b", "c"]);
        ///
        ///     let vals = Iter.toArray(buffer.vals());
        ///     assert vals == ["a", "b", "c"];
        ///
        ///     let reversed = Iter.toArray(buffer.vals().rev());
        ///     assert reversed == ["c", "b", "a"];
        /// ```
        public func vals() : RevIter<A> = BaseMemoryBuffer.vals<A>(internal, blobify);

        /// Returns a reversable iterator over a tuple of the index and element in the buffer.
        public func items() : RevIter<(Nat, A)> = BaseMemoryBuffer.items<A>(internal, blobify);

        /// Returns a reversable iterator over the serialized elements in the buffer.
        public func blobs() : RevIter<Blob> = BaseMemoryBuffer.blobs<A>(internal);

        /// Swaps the elements at the given indices.
        public func swap(i: Nat, j: Nat) = BaseMemoryBuffer.swap<A>(internal, i, j);

        /// Swaps the element at the given index with the last element in the buffer and removes it.
        public func swapRemove(i: Nat) : A = BaseMemoryBuffer.swapRemove<A>(internal, blobify, i);

        /// Removes the element at the given index.
        public func remove(i: Nat) : A = BaseMemoryBuffer.remove<A>(internal, blobify, i);

        /// Removes the last element from the buffer.
        ///
        /// ```motoko
        ///     stable var sstore = BaseMemoryBuffer.newStableStore<Text>();
        ///     sstore := BaseMemoryBuffer.upgrade(sstore);
        ///     
        ///     let buffer = BaseMemoryBuffer.BaseMemoryBuffer<Nat>(sstore, Blobify.Nat); // little-endian
        ///
        ///     buffer.addFromArray([1, 2, 3]);
        ///
        ///     assert buffer.removeLast() == ?3;
        /// ```
        public func removeLast() : ?A = BaseMemoryBuffer.removeLast<A>(internal, blobify);
        
        /// Inserts an element at the given index.
        public func insert(i: Nat, elem: A) = BaseMemoryBuffer.insert<A>(internal, blobify, i, elem);

        /// Sorts the elements in the buffer using the given comparison function.
        /// This function implements quicksort, an unstable sorting algorithm with an average time complexity of `O(n log n)`.
        /// It also supports a comparision function that can either compare the elements the default type or in their serialized form as blobs.
        /// For more information on the comparison function, refer to the [MemoryCmp module](../MemoryCmp).
        public func sortUnstable(cmp: MemoryCmp.MemoryCmp<A> ) = BaseMemoryBuffer.sortUnstable<A>(internal, blobify, cmp);


        /// Removes all elements from the buffer.
        public func clear() = BaseMemoryBuffer.clear<A>(internal);

        /// Copies all the elements in the buffer to a new array.
        public func toArray() : [A] = BaseMemoryBuffer.toArray<A>(internal, blobify);


        /// Randomly shuffles the elements in the buffer.
        public func shuffle() = BaseMemoryBuffer.shuffle<A>(internal);

        /// Reverse the order of the elements in the buffer.
        public func reverse() = BaseMemoryBuffer.reverse<A>(internal);

        /// Returns the index of the first element that is equal to the given element.
        public func indexOf(equal: (A, A) -> Bool, elem: A) : ?Nat = BaseMemoryBuffer.indexOf<A>(internal, blobify, equal, elem);

        /// Returns the index of the last element that is equal to the given element.
        public func lastIndexOf(equal: (A, A) -> Bool, elem: A) : ?Nat = BaseMemoryBuffer.lastIndexOf<A>(internal, blobify, equal, elem);

        /// Returns `true` if the buffer contains the given element.
        public func contains(equal: (A, A) -> Bool, elem: A) : Bool = BaseMemoryBuffer.contains<A>(internal, blobify, equal, elem);

        /// Returns `true` if the buffer is empty.
        public func isEmpty() : Bool = BaseMemoryBuffer.isEmpty<A>(internal);

        public func _getInternalRegion() : BaseMemoryBuffer<A> = internal;
        public func _getBlobifyFn() : Blobify<A> = blobify;
    };

    public func init<A>(internal: VersionedMemoryBuffer<A>, blobify: Blobify<A>, size: Nat, val: A) : MemoryBufferClass<A> {
        let mbuffer = MemoryBufferClass(internal, blobify);

        for (_ in Iter.range(0, size - 1)){
            mbuffer.add(val);
        };

        return mbuffer;
    };

    // public func tabulate<A>(internal: VersionedMemoryBuffer<A>, blobify: Blobify<A>, size: Nat, f: (Nat) -> A) : MemoryBufferClass<A> {
    //     BaseMemoryBuffer.tabulate(internal, blobify, size, f);
    //     return MemoryBufferClass(internal, blobify);
    // };

    // public func fromArray<A>(internal: VersionedMemoryBuffer<A>, blobify: Blobify<A>, arr: [A]) : MemoryBufferClass<A> {
    //     BaseMemoryBuffer.fromArray(internal, blobify, arr);
    //     return MemoryBufferClass(internal, blobify);
    // };

    public func toArray<A>(mbuffer: MemoryBufferClass<A>) : [A] {
        return BaseMemoryBuffer.toArray(mbuffer._getInternalRegion(), mbuffer._getBlobifyFn());
    };

    // public func fromIter<A>(internal: VersionedMemoryBuffer<A>, blobify: Blobify<A>, iter: Iter<A>) : MemoryBufferClass<A> {
    //     BaseMemoryBuffer.fromIter(internal, blobify, iter);
    //     return MemoryBufferClass(internal, blobify);
    // };

    public func append<A>(mbuffer: MemoryBufferClass<A>, b: MemoryBufferClass<A>) {
        BaseMemoryBuffer.append(mbuffer._getInternalRegion(), mbuffer._getBlobifyFn(), b._getInternalRegion());
    };

    public func appendArray<A>(mbuffer: MemoryBufferClass<A>, arr: [A]) {
        BaseMemoryBuffer.appendArray<A>(mbuffer._getInternalRegion(), mbuffer._getBlobifyFn(), arr);
    };

    public func appendBuffer<A>(mbuffer: MemoryBufferClass<A>, other : { vals : () -> Iter<A> }) {
        BaseMemoryBuffer.appendBuffer<A>(mbuffer._getInternalRegion(), mbuffer._getBlobifyFn(), other);
    };

    public func blocks<A>(mbuffer: MemoryBufferClass<A>) : RevIter<(Nat, Nat)> = BaseMemoryBuffer.blocks<A>(mbuffer._getInternalRegion());
    
    public func reverse<A>(mbuffer: MemoryBufferClass<A>) = BaseMemoryBuffer.reverse<A>(mbuffer._getInternalRegion());

}