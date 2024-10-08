import RevIter "mo:itertools/RevIter";

import Migrations "Migrations";
import MemoryBTree "Base";
import T "modules/Types";

module StableMemoryBTree {
    public type MemoryBTree = Migrations.MemoryBTree;
    public type StableMemoryBTree = Migrations.VersionedMemoryBTree;
    public type MemoryBlock = T.MemoryBlock;
    public type BTreeUtils<K, V> = T.BTreeUtils<K, V>;
    type RevIter<A> = RevIter.RevIter<A>;

    public func createUtils<K, V>(key_utils : T.KeyUtils<K>, value_utils : T.ValueUtils<V>) : BTreeUtils<K, V> {
        return {
            key = key_utils;
            value = value_utils;
        };
    };

    public func new(order : ?Nat) : StableMemoryBTree {
        let btree = MemoryBTree.new(order);
        MemoryBTree.toVersioned(btree);
    };

    public func fromArray<K, V>(
        btree_utils : BTreeUtils<K, V>,
        arr : [(K, V)],
        order : ?Nat,
    ) : StableMemoryBTree {
        let btree = MemoryBTree.fromArray(btree_utils, arr, order);
        MemoryBTree.toVersioned(btree);
    };

    public func toArray<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>) : [(K, V)] {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.toArray(state, btree_utils);
    };

    public func insert<K, V>(
        btree : StableMemoryBTree,
        btree_utils : BTreeUtils<K, V>,
        key : K,
        val : V,
    ) : ?V {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.insert<K, V>(state, btree_utils, key, val);
    };

    public func remove<K, V>(
        btree : StableMemoryBTree,
        btree_utils : BTreeUtils<K, V>,
        key : K,
    ) : ?V {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.remove(state, btree_utils, key);
    };

    public func removeMax<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>) : ?(K, V) {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.removeMax(state, btree_utils);
    };

    public func removeMin<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>) : ?(K, V) {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.removeMin(state, btree_utils);
    };

    public func get<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : ?V {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.get(state, btree_utils, key);
    };

    public func contains<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : Bool {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.contains(state, btree_utils, key);
    };

    public func getMax<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>) : ?(K, V) {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.getMax(state, btree_utils);
    };

    public func getMin<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>) : ?(K, V) {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.getMin(state, btree_utils);
    };

    public func getCeiling<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : ?(K, V) {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.getCeiling(state, btree_utils, key);
    };

    public func getFloor<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : ?(K, V) {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.getFloor(state, btree_utils, key);
    };

    public func getFromIndex<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>, index : Nat) : (K, V) {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.getFromIndex<K, V>(state, btree_utils, index);
    };

    public func getIndex<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : Nat {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.getIndex(state, btree_utils, key);
    };

    public type ExpectedIndex = MemoryBTree.ExpectedIndex;

    public func getExpectedIndex<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : ExpectedIndex {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.getExpectedIndex(state, btree_utils, key);
    };

    public func clear(btree : StableMemoryBTree) {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.clear(state);
    };

    public func entries<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>) : RevIter<(K, V)> {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.entries(state, btree_utils);
    };

    public func keys<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>) : RevIter<K> {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.keys(state, btree_utils);
    };

    public func vals<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>) : RevIter<V> {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.vals(state, btree_utils);
    };

    public func scan<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>, start : ?K, end : ?K) : RevIter<(K, V)> {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.scan(state, btree_utils, start, end);
    };

    public func scanKeys<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>, start : ?K, end : ?K) : RevIter<K> {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.scanKeys(state, btree_utils, start, end);
    };

    public func scanVals<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>, start : ?K, end : ?K) : RevIter<V> {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.scanVals(state, btree_utils, start, end);
    };

    public func range<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>, start : Nat, end : Nat) : RevIter<(K, V)> {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.range(state, btree_utils, start, end);
    };

    public func rangeKeys<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>, start : Nat, end : Nat) : RevIter<K> {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.rangeKeys(state, btree_utils, start, end);
    };

    public func rangeVals<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>, start : Nat, end : Nat) : RevIter<V> {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.rangeVals(state, btree_utils, start, end);
    };

    public func size(btree : StableMemoryBTree) : Nat {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.size(state);
    };

    public func bytes(btree : StableMemoryBTree) : Nat {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.bytes(state);
    };

    public func metadataBytes(btree : StableMemoryBTree) : Nat {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.metadataBytes(state);
    };

    public func getId<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : ?Nat {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.getId(state, btree_utils, key);
    };

    public func nextId<K, V>(btree : StableMemoryBTree) : Nat {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.nextId(state);
    };

    public func lookup<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>, id : Nat) : ?(K, V) {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.lookup(state, btree_utils, id);
    };

    public func lookupKey<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>, id : Nat) : ?K {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.lookupKey(state, btree_utils, id);
    };

    public func lookupVal<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>, id : Nat) : ?V {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.lookupVal(state, btree_utils, id);
    };

    public func reference<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>, id : Nat) {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.reference(state, btree_utils, id);
    };

    public func getRefCount<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>, id : Nat) : ?Nat {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.getRefCount(state, btree_utils, id);
    };

};
