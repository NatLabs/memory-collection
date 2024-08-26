import RevIter "mo:itertools/RevIter";

import Migrations "Migrations";
import BaseMemoryBTree "Base";
import StableMemoryBTree "Stable";
import T "modules/Types";

import TypeUtils "../TypeUtils";

module {

    public type MemoryBlock = T.MemoryBlock;
    type RevIter<A> = RevIter.RevIter<A>;

    type TypeUtils<A> = TypeUtils.TypeUtils<A>;

    public type StableStore = StableMemoryBTree.StableMemoryBTree;

    public type BTreeUtils<K, V> = T.BTreeUtils<K, V>;
    public type KeyUtils<K> = T.KeyUtils<K>;
    public type ValueUtils<V> = T.ValueUtils<V>;
    public type MemoryBTreeStats = BaseMemoryBTree.MemoryBTreeStats;

    public type ExpectedIndex = BaseMemoryBTree.ExpectedIndex;

    /// Create a new stable store
    public func newStableStore(order : ?Nat) : StableStore = StableMemoryBTree.new(order);

    /// Upgrade an older version of the BTree to the latest version
    public func upgrade<K, V>(sstore : StableStore) : StableStore {
        Migrations.upgrade(sstore);
    };

    /// Create BTreeUtils for a given key and value type
    ///
    /// ```motoko
    ///     import MemoryBTree "mo:memory-collection/MemoryBTree";
    ///     import TypeUtils "mo:memory-collection/TypeUtils";
    ///
    ///     let btree_utils = MemoryBTree.createUtils(
    ///         TypeUtils.BigEndian.Nat,
    ///         TypeUtils.Text
    ///     );
    ///
    ///     let sstore = MemoryBTree.newStableStore(null);
    ///     let mbtree = MemoryBTree.MemoryBTree(sstore, btree_utils);
    ///
    ///     ignore mbtree.insert(0, "hello");
    ///     ignore mbtree.insert(1, "world");
    ///     ignore mbtree.insert(2, "!");
    ///     assert mbtree.size() == 3;
    ///
    ///     assert mbtree.getMin() == (0, "hello");
    ///     assert mbtree.get(1) == "world";
    ///     assert mbtree.getMax() == (2, "!");
    ///
    ///     assert mbtree.toArray() == [(0, "hello"), (1, "world"), (2, "!")];
    ///

    ///
    /// ```
    public func createUtils<K, V>(key_utils : T.KeyUtils<K>, value_utils : T.ValueUtils<V>) : BTreeUtils<K, V> {
        return {
            key = key_utils;
            value = value_utils;
        };
    };

    /// MemoryBTree class
    public class MemoryBTree<K, V>(sstore : StableStore, btree_utils : BTreeUtils<K, V>) {
        let state = Migrations.getCurrentVersion(sstore);

        /// Get the value associated with a key
        public func get(key : K) : ?V = BaseMemoryBTree.get<K, V>(state, btree_utils, key);

        /// Checks if the BTree contains the given key
        public func contains(key : K) : Bool = BaseMemoryBTree.contains<K, V>(state, btree_utils, key);

        /// Get the entry with the maximum key
        public func getMax() : ?(K, V) = BaseMemoryBTree.getMax<K, V>(state, btree_utils);

        /// Get the entry with the minimum key
        public func getMin() : ?(K, V) = BaseMemoryBTree.getMin<K, V>(state, btree_utils);

        /// Get the entry that either matches the key or is the next largest key
        public func getCeiling(key : K) : ?(K, V) = BaseMemoryBTree.getCeiling<K, V>(state, btree_utils, key);

        /// Get the entry that either matches the key or is the next smallest key
        public func getFloor(key : K) : ?(K, V) = BaseMemoryBTree.getFloor<K, V>(state, btree_utils, key);

        /// Get the entry at the given index in the sorted order
        public func getFromIndex(i : Nat) : (K, V) = BaseMemoryBTree.getFromIndex<K, V>(state, btree_utils, i);

        /// Get the index (sorted position) of the given key in the btree
        /// > Throws an error if the key is not found.
        /// > Use `getExpectedIndex()` if you want to get the index without throwing an error.
        public func getIndex(key : K) : Nat = BaseMemoryBTree.getIndex<K, V>(state, btree_utils, key);

        /// Get the index (sorted position) of the given key in the btree
        /// Returns a `ExpectedIndex` variant that returns `#Found(index)` if the key exists or `#NotFound(index)` if it does not.
        public func getExpectedIndex(key : K) : BaseMemoryBTree.ExpectedIndex = BaseMemoryBTree.getExpectedIndex<K, V>(state, btree_utils, key);

        /// Insert a new key-value pair into the BTree
        public func insert(key : K, val : V) : ?V = BaseMemoryBTree.insert<K, V>(state, btree_utils, key, val);

        /// Remove the key-value pair associated with the given key
        public func remove(key : K) : ?V = BaseMemoryBTree.remove<K, V>(state, btree_utils, key);

        /// Remove the entry with the maximum key
        public func removeMax() : ?(K, V) = BaseMemoryBTree.removeMax<K, V>(state, btree_utils);

        /// Remove the entry with the minimum key
        public func removeMin() : ?(K, V) = BaseMemoryBTree.removeMin<K, V>(state, btree_utils);

        /// Clear the BTree - Remove all entries from the BTree
        public func clear() = BaseMemoryBTree.clear(state);

        /// Returns a reversible iterator over the entries in the BTree
        public func entries() : RevIter<(K, V)> = BaseMemoryBTree.entries(state, btree_utils);

        /// Returns a reversible iterator over the keys in the BTree
        public func keys() : RevIter<(K)> = BaseMemoryBTree.keys(state, btree_utils);

        /// Returns a reversible iterator over the values in the BTree
        public func vals() : RevIter<(V)> = BaseMemoryBTree.vals(state, btree_utils);

        /// Returns an array of all the entries in the BTree
        public func toArray() : [(K, V)] = BaseMemoryBTree.toArray(state, btree_utils);

        /// Returns an array of all the keys in the BTree
        public func toKeys() : [K] = BaseMemoryBTree.toKeys(state, btree_utils);

        /// Returns an array of all the values in the BTree
        public func toVals() : [V] = BaseMemoryBTree.toVals(state, btree_utils);

        /// Returns the start and end index of the range between the given keys
        public func getInterval(start : ?K, end : ?K) : (Nat, Nat) = BaseMemoryBTree.getInterval(state, btree_utils, start, end);

        /// Returns a reversible iterator over the entries in the given range
        public func range(i : Nat, j : Nat) : RevIter<(K, V)> = BaseMemoryBTree.range(state, btree_utils, i, j);

        /// Returns a reversible iterator over the entries in the given range
        public func scan(start : ?K, end : ?K) : RevIter<(K, V)> = BaseMemoryBTree.scan(state, btree_utils, start, end);

        /// Returns the number of entries in the BTree
        public func size() : Nat = BaseMemoryBTree.size(state);

        /// Returns the number of bytes used to store the keys and values data
        public func bytes() : Nat = BaseMemoryBTree.bytes(state);

        /// Returns the number of bytes used to store information about the nodes and structure of the BTree
        public func metadataBytes() : Nat = BaseMemoryBTree.metadataBytes(state);

        /// Returns the total number of bytes used to store the BTree
        public func totalBytes() : Nat = BaseMemoryBTree.totalBytes(state);

        /// Returns the stats for each memory region used by the BTree
        public func stats() : MemoryBTreeStats = BaseMemoryBTree.stats(state);

        /// Functions for Unique Id References to values in the BTree

        /// Get the id associated with a key
        public func getId(key : K) : ?Nat = BaseMemoryBTree.getId(state, btree_utils, key);

        /// Get the next available id that will be assigned to a new value
        public func nextId() : Nat = BaseMemoryBTree.nextId(state);

        /// Get the entry associated with the given id
        public func lookup(id : Nat) : ?(K, V) = BaseMemoryBTree.lookup(state, btree_utils, id);

        /// Get the key associated with the given id
        public func lookupKey(id : Nat) : ?K = BaseMemoryBTree.lookupKey(state, btree_utils, id);

        /// Get the value associated with the given id
        public func lookupVal(id : Nat) : ?V = BaseMemoryBTree.lookupVal(state, btree_utils, id);

        /// Reference a value by its id and increment the reference count
        /// Values will not be removed from the BTree until the reference count is back to zero
        public func reference(id : Nat) = BaseMemoryBTree.reference(state, btree_utils, id);

        /// Get the reference count associated with the given id
        public func getRefCount(id : Nat) : ?Nat = BaseMemoryBTree.getRefCount(state, btree_utils, id);

    };

    /// Create a MemoryBTree from an array of key-value pairs
    public func fromArray<K, V>(sstore : StableStore, btree_utils : BTreeUtils<K, V>, arr : [(K, V)]) : MemoryBTree<K, V> {
        let state = Migrations.getCurrentVersion(sstore);

        for ((k, v) in arr.vals()) {
            ignore BaseMemoryBTree.insert<K, V>(state, btree_utils, k, v);
        };

        MemoryBTree(sstore, btree_utils);
    };
};
