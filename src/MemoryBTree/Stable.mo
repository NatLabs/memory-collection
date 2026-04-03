import Iter "mo:core@2.4/Iter";
import RevIter "mo:itertools@0.2/RevIter";

import Migrations "Migrations";
import MemoryBTree "Base";
import T "modules/Types";

module StableMemoryBTree {
    public type MemoryBTree = Migrations.MemoryBTree;
    public type StableMemoryBTree = Migrations.VersionedMemoryBTree;
    public type VersionedMemoryBTree = Migrations.VersionedMemoryBTree;
    public type MemoryBlock = T.MemoryBlock;
    public type BTreeUtils<K, V> = T.BTreeUtils<K, V>;
    public type MemoryBTreeStats = MemoryBTree.MemoryBTreeStats;
    public type MemoryCmp<A> = MemoryBTree.MemoryCmp<A>;
    public type TypeUtils<A> = MemoryBTree.TypeUtils<A>;
    public type MergeStrategy = MemoryBTree.MergeStrategy;
    public type BranchNodeKeys = MemoryBTree.BranchNodeKeys;
    public type BTreeOptions = MemoryBTree.BTreeOptions;

    type RevIter<A> = RevIter.RevIter<A>;

    public let Leaf = MemoryBTree.Leaf;
    public let Branch = MemoryBTree.Branch;
    public let defaultOptions : BTreeOptions = MemoryBTree.defaultOptions;
    public let POINTER_SIZE = MemoryBTree.POINTER_SIZE;
    public let LAYOUT_VERSION = MemoryBTree.LAYOUT_VERSION;
    public let MC = MemoryBTree.MC;
    public let Layout = MemoryBTree.Layout;

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

    public func stats(btree : StableMemoryBTree) : MemoryBTree.MemoryBTreeStats {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.stats(state);
    };

    public func dataBytes(btree : StableMemoryBTree) : Nat {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.dataBytes(state);
    };

    public func freeBytes(btree : StableMemoryBTree) : Nat {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.freeBytes(state);
    };

    public func metadataBytes(btree : StableMemoryBTree) : Nat {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.metadataBytes(state);
    };

    public func usedBytes(btree : StableMemoryBTree) : Nat {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.usedBytes(state);
    };

    public func allocatedBytes(btree : StableMemoryBTree) : Nat {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.allocatedBytes(state);
    };

    public func leafBytes(btree : StableMemoryBTree) : Nat {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.leafBytes(state);
    };

    public func branchBytes(btree : StableMemoryBTree) : Nat {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.branchBytes(state);
    };

    public func keyBytes(btree : StableMemoryBTree) : Nat {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.keyBytes(state);
    };

    public func valueBytes(btree : StableMemoryBTree) : Nat {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.valueBytes(state);
    };

    public func leafCount(btree : StableMemoryBTree) : Nat {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.leafCount(state);
    };

    public func branchCount(btree : StableMemoryBTree) : Nat {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.branchCount(state);
    };

    public func totalNodeCount(btree : StableMemoryBTree) : Nat {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.totalNodeCount(state);
    };

    public func allocatedPages(btree : StableMemoryBTree) : Nat {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.allocatedPages(state);
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

    public func newWithOptions(options : BTreeOptions) : StableMemoryBTree {
        let btree = MemoryBTree.newWithOptions(options);
        MemoryBTree.toVersioned(btree);
    };

    public func fromVersioned(btree : StableMemoryBTree) : MemoryBTree.MemoryBTree {
        Migrations.getCurrentVersion(btree);
    };

    public func toVersioned(btree : MemoryBTree.MemoryBTree) : StableMemoryBTree {
        MemoryBTree.toVersioned(btree);
    };

    public func mergeThresholdCount(btree : StableMemoryBTree) : Nat {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.mergeThresholdCount(state);
    };

    public func nodeCapacity(btree : StableMemoryBTree) : Nat {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.nodeCapacity(state);
    };

    public func config(btree : StableMemoryBTree) : {
        node_capacity : Nat;
        merge_threshold_count : Nat;
    } {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.config(state);
    };

    public func toEntries<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>) : [(K, V)] {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.toEntries(state, btree_utils);
    };

    public func toKeys<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>) : [K] {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.toKeys(state, btree_utils);
    };

    public func toVals<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>) : [V] {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.toVals(state, btree_utils);
    };

    public func leafNodes<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>) : RevIter<[?(K, V)]> {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.leafNodes(state, btree_utils);
    };

    public func toLeafNodes<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>) : [[?(K, V)]] {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.toLeafNodes(state, btree_utils);
    };

    public func toNodeKeys<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>) : [[BranchNodeKeys]] {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.toNodeKeys(state, btree_utils);
    };

    public func fromEntries<K, V>(
        btree_utils : BTreeUtils<K, V>,
        entries : Iter.Iter<(K, V)>,
        order : ?Nat,
    ) : StableMemoryBTree {
        let btree = MemoryBTree.fromEntries(btree_utils, entries, order);
        MemoryBTree.toVersioned(btree);
    };

    public func getInterval<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>, start : ?K, end : ?K) : (Nat, Nat) {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.getInterval(state, btree_utils, start, end);
    };

    public func printPathToKey<K, V>(btree : StableMemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) {
        let state = Migrations.getCurrentVersion(btree);
        MemoryBTree.printPathToKey(state, btree_utils, key);
    };

};
