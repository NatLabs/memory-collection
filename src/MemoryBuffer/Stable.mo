import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Result "mo:base/Result";
import Order "mo:base/Order";

import MemoryRegion "mo:memory-region/MemoryRegion";
import RevIter "mo:itertools/RevIter";

import MemoryBuffer "Base";
import Migrations "Migrations";
import MemoryCmp "../TypeUtils/MemoryCmp";
import Blobify "../TypeUtils/Blobify";

module StableMemoryBuffer {
    type Iter<A> = Iter.Iter<A>;
    type RevIter<A> = RevIter.RevIter<A>;
    type Result<A, B> = Result.Result<A, B>;
    type MemoryRegion = MemoryRegion.MemoryRegion;

    type MemoryRegionV0 = MemoryRegion.MemoryRegionV0;
    type MemoryRegionV1 = MemoryRegion.MemoryRegionV1;

    type Order = Order.Order;

    public type Blobify<A> = Blobify.Blobify<A>;
    public type MemoryBuffer<A> = Migrations.MemoryBuffer<A>;
    public type StableMemoryBuffer<A> = Migrations.VersionedMemoryBuffer<A>;
    public type MemoryBufferUtils<A> = MemoryBuffer.MemoryBufferUtils<A>;

    public func new<A>() : StableMemoryBuffer<A> {
        return MemoryBuffer.toVersioned(MemoryBuffer.new());
    };

    public func upgrade<A>(self : StableMemoryBuffer<A>) : StableMemoryBuffer<A> {
        Migrations.upgrade(self);
    };

    public func verify<A>(self : StableMemoryBuffer<A>) : Result<(), Text> {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.verify(state);
    };

    public func init<A>(self : MemoryBufferUtils<A>, size : Nat, val : A) : StableMemoryBuffer<A> {
        return MemoryBuffer.toVersioned(MemoryBuffer.init(self, size, val));
    };

    public func tabulate<A>(blobify : MemoryBufferUtils<A>, size : Nat, fn : (i : Nat) -> A) : StableMemoryBuffer<A> {
        return MemoryBuffer.toVersioned(MemoryBuffer.tabulate(blobify, size, fn));
    };

    public func fromArray<A>(blobify : MemoryBufferUtils<A>, arr : [A]) : StableMemoryBuffer<A> {
        return MemoryBuffer.toVersioned(MemoryBuffer.fromArray(blobify, arr));
    };

    public func fromIter<A>(blobify : MemoryBufferUtils<A>, iter : Iter<A>) : StableMemoryBuffer<A> {
        return MemoryBuffer.toVersioned(MemoryBuffer.fromIter(blobify, iter));
    };

    public func size<A>(self : StableMemoryBuffer<A>) : Nat {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.size(state);
    };

    public func bytes<A>(self : StableMemoryBuffer<A>) : Nat {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.bytes(state);
    };

    public func metadataBytes<A>(self : StableMemoryBuffer<A>) : Nat {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.metadataBytes(state);
    };

    public func totalBytes<A>(self : StableMemoryBuffer<A>) : Nat {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.totalBytes(state);
    };

    public func capacity<A>(self : StableMemoryBuffer<A>) : Nat {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.capacity(state);
    };

    public func put<A>(self : StableMemoryBuffer<A>, blobify : MemoryBufferUtils<A>, index : Nat, value : A) {
        let state = Migrations.getCurrentVersion(self);
        MemoryBuffer.put(state, blobify, index, value);
    };

    public func getOpt<A>(self : StableMemoryBuffer<A>, blobify : MemoryBufferUtils<A>, index : Nat) : ?A {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.getOpt(state, blobify, index);
    };

    public func get<A>(self : StableMemoryBuffer<A>, blobify : MemoryBufferUtils<A>, index : Nat) : A {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.get(state, blobify, index);
    };

    public func _get_pointer<A>(self : StableMemoryBuffer<A>, index : Nat) : Nat {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer._get_pointer(state, index);
    };

    public func _get_memory_block<A>(self : StableMemoryBuffer<A>, index : Nat) : (Nat, Nat) {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer._get_memory_block(state, index);
    };

    public func _get_blob<A>(self : StableMemoryBuffer<A>, index : Nat) : Blob {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer._get_blob<A>(state, index);
    };

    public func add<A>(self : StableMemoryBuffer<A>, blobify : MemoryBufferUtils<A>, value : A) {
        let state = Migrations.getCurrentVersion(self);
        MemoryBuffer.add(state, blobify, value);
    };

    public func addFromIter<A>(self : StableMemoryBuffer<A>, blobify : MemoryBufferUtils<A>, iter : Iter<A>) {
        let state = Migrations.getCurrentVersion(self);
        MemoryBuffer.addFromIter(state, blobify, iter);
    };

    public func addFromArray<A>(self : StableMemoryBuffer<A>, blobify : MemoryBufferUtils<A>, arr : [A]) {
        let state = Migrations.getCurrentVersion(self);
        MemoryBuffer.addFromArray(state, blobify, arr);
    };

    public func append<A>(self : StableMemoryBuffer<A>, blobify : MemoryBufferUtils<A>, other : StableMemoryBuffer<A>) {
        let curr_state = Migrations.getCurrentVersion(self);
        let other_state = Migrations.getCurrentVersion(other);
        MemoryBuffer.append(curr_state, blobify, other_state);
    };

    public func vals<A>(self : StableMemoryBuffer<A>, blobify : MemoryBufferUtils<A>) : RevIter<A> {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.vals(state, blobify);
    };

    public func items<A>(self : StableMemoryBuffer<A>, blobify : MemoryBufferUtils<A>) : RevIter<(index : Nat, value : A)> {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.items(state, blobify);
    };

    public func blobs<A>(self : StableMemoryBuffer<A>) : RevIter<Blob> {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.blobs(state);
    };

    public func pointers<A>(self : StableMemoryBuffer<A>) : RevIter<Nat> {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.pointers(state);
    };

    public func blocks<A>(self : StableMemoryBuffer<A>) : RevIter<(Nat, Nat)> {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.blocks(state);
    };

    public func remove<A>(self : StableMemoryBuffer<A>, blobify : MemoryBufferUtils<A>, index : Nat) : A {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.remove(state, blobify, index);
    };

    public func removeLast<A>(self : StableMemoryBuffer<A>, blobify : MemoryBufferUtils<A>) : ?A {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.removeLast(state, blobify);
    };

    public func swap<A>(self : StableMemoryBuffer<A>, index_a : Nat, index_b : Nat) {
        let state = Migrations.getCurrentVersion(self);
        MemoryBuffer.swap(state, index_a, index_b);
    };

    public func swapRemove<A>(self : StableMemoryBuffer<A>, blobify : MemoryBufferUtils<A>, index : Nat) : A {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.swapRemove(state, blobify, index);
    };

    public func reverse<A>(self : StableMemoryBuffer<A>) {
        let state = Migrations.getCurrentVersion(self);
        MemoryBuffer.reverse(state);
    };

    public func clear<A>(self : StableMemoryBuffer<A>) {
        let state = Migrations.getCurrentVersion(self);
        MemoryBuffer.clear(state);
    };

    public func clone<A>(self : StableMemoryBuffer<A>) : StableMemoryBuffer<A> {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.toVersioned(MemoryBuffer.clone(state));
    };

    public func insert<A>(self : StableMemoryBuffer<A>, blobify : MemoryBufferUtils<A>, index : Nat, value : A) {
        let state = Migrations.getCurrentVersion(self);
        MemoryBuffer.insert(state, blobify, index, value);
    };

    public func sortUnstable<A>(self : StableMemoryBuffer<A>, blobify : MemoryBufferUtils<A>, cmp : MemoryCmp.MemoryCmp<A>) {
        let state = Migrations.getCurrentVersion(self);
        MemoryBuffer.sortUnstable(state, blobify, cmp);
    };

    public func shuffle<A>(self : StableMemoryBuffer<A>) {
        let state = Migrations.getCurrentVersion(self);
        MemoryBuffer.shuffle(state);
    };

    public func indexOf<A>(self : StableMemoryBuffer<A>, blobify : MemoryBufferUtils<A>, equal : (A, A) -> Bool, value : A) : ?Nat {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.indexOf(state, blobify, equal, value);
    };

    public func lastIndexOf<A>(self : StableMemoryBuffer<A>, blobify : MemoryBufferUtils<A>, equal : (A, A) -> Bool, value : A) : ?Nat {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.lastIndexOf(state, blobify, equal, value);
    };

    public func contains<A>(self : StableMemoryBuffer<A>, blobify : MemoryBufferUtils<A>, equal : (A, A) -> Bool, value : A) : Bool {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.contains(state, blobify, equal, value);
    };

    public func isEmpty<A>(self : StableMemoryBuffer<A>) : Bool {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.isEmpty(state);
    };

    public func toArray<A>(self : StableMemoryBuffer<A>, blobify : MemoryBufferUtils<A>) : [A] {
        let state = Migrations.getCurrentVersion(self);
        return MemoryBuffer.toArray(state, blobify);
    };

};
