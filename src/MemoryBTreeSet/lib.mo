import RevIter "mo:itertools/RevIter";
import Option "mo:base/Option";

import Migrations "../MemoryBTree/Migrations";
import BaseMemoryBTree "../MemoryBTree/Base";
import StableMemoryBTree "../MemoryBTree/Stable";
import T "../MemoryBTree/modules/Types";

import TypeUtils "../TypeUtils";

module {

    public type StableStore = StableMemoryBTree.StableMemoryBTree;
    type TypeUtils<A> = TypeUtils.TypeUtils<A>;

    public type BTreeUtils<K, V> = T.BTreeUtils<K, V>;
    public type KeyUtils<K> = T.KeyUtils<K>;
    public type ValueUtils<V> = T.ValueUtils<V>;
    public type RevIter<A> = RevIter.RevIter<A>;

    /// Create a new stable store
    public func newStableStore(order : ?Nat) : StableStore = StableMemoryBTree.new(order);

    /// Upgrade an older version of the BTree to the latest one
    public func upgrade<K, V>(versions : StableStore) : StableStore {
        Migrations.upgrade(versions);
    };

    let blobify_empty_type : TypeUtils.Blobify<()> = {
        to_blob = func(e : ()) : Blob = "";
        from_blob = func(b : Blob) : () {
            return ();
        };
    };

    /// Create BTreeSet Utils for a given key
    public func createUtils<K>(key_utils : T.KeyUtils<K>) : BTreeUtils<K, ()> {
        return {
            key = key_utils;
            value = { blobify = blobify_empty_type };
        };
    };

    /// **Memory BTree Set** - An ordered set of keys stored in stable memory
    ///
    /// This is a class wrapper around the MemoryBTree that provides a set-like interface but does not offer any memory improvements over using the MemoryBTree directly.
    ///
    /// ```motoko
    /// import MemoryBTreeSet "mo:memory-collection/MemoryBTreeSet";
    /// import TypeUtils "mo:memory-collection/TypeUtils";
    ///
    /// var sstore = MemoryBTreeSet.newStableStore(null);
    /// let btree_utils = MemoryBTreeSet.createUtils(TypeUtils.Text);
    ///
    /// let set = MemoryBTreeSet.MemoryBTreeSet<Text>(sstore, btree_utils);
    ///
    /// ignore set.insert("a");
    /// ignore set.insert("b");
    ///
    /// assert set.contains("a");
    /// assert set.getMin() == ?"a";
    /// assert set.getMax() == ?"b";
    ///
    /// assert set.toArray() == ["a", "b"];
    /// ```
    public class MemoryBTreeSet<K>(sstore : StableStore, btree_utils : BTreeUtils<K, ()>) {
        let state = Migrations.getCurrentVersion(sstore);

        func extract_key((k, _) : (K, ())) : K = k;

        /// Checks if the btree set contains the key
        public func contains(key : K) : Bool = BaseMemoryBTree.contains<K, ()>(state, btree_utils, key);

        /// Retrieves the largest key in btree set
        public func getMax() : ?K = Option.map(
            BaseMemoryBTree.getMax(state, btree_utils),
            extract_key,
        );

        /// Retrieves the smallest key in btree set
        public func getMin() : ?K = Option.map(
            BaseMemoryBTree.getMin(state, btree_utils),
            extract_key,
        );

        /// Retrieves the key in the set that matches the given key or is the next largest key
        public func getCeiling(key : K) : ?K = Option.map(
            BaseMemoryBTree.getCeiling(state, btree_utils, key),
            extract_key,
        );

        /// Retrieves the key in the set that matches the given key or is the next smallest key
        public func getFloor(key : K) : ?K {
            let floor = BaseMemoryBTree.getFloor(state, btree_utils, key);

            switch (floor) {
                case (null) return null;
                case (?(k, ())) return ?k;
            };

        };

        /// Retrieves a key in the sorted position of the given index
        public func getFromIndex(index : Nat) : K {
            let (k, _) = BaseMemoryBTree.getFromIndex(state, btree_utils, index);
            return k;
        };

        public func getIndex(key : K) : Nat = BaseMemoryBTree.getIndex(state, btree_utils, key);

        /// Insert a new key into the btree set
        /// Returns true if the key was inserted, false if the key already exists
        public func insert(key : K) : Bool = switch (BaseMemoryBTree.insert<K, ()>(state, btree_utils, key, ())) {
            case (null) return false;
            case (?_) return true;
        };

        /// Remove the key from the btree set
        /// Returns true if the key was removed, false if the key does not exist
        public func remove(key : K) : Bool = switch (BaseMemoryBTree.remove<K, ()>(state, btree_utils, key)) {
            case (null) return false;
            case (?_) return true;
        };

        /// Remove the largest key from the btree set
        public func removeMax() : ?K {
            let max = BaseMemoryBTree.removeMax(state, btree_utils);

            switch (max) {
                case (null) return null;
                case (?(k, ())) return ?k;
            };

        };

        /// Remove the smallest key from the btree set
        public func removeMin() : ?K {
            let min = BaseMemoryBTree.removeMin(state, btree_utils);

            switch (min) {
                case (null) return null;
                case (?(k, ())) return ?k;
            };

        };

        /// Remove all keys in the btree set
        public func clear() = BaseMemoryBTree.clear(state);

        /// Returns a reversible iterator over the keys in the btree set
        public func keys() : RevIter<K> = BaseMemoryBTree.keys(state, btree_utils);

        /// Returns an array of all the keys in the btree set
        public func toArray() : [K] = BaseMemoryBTree.toKeys(state, btree_utils);
        public func toKeys() : [K] = BaseMemoryBTree.toKeys(state, btree_utils);

        /// Returns a reversible iterator over the keys in the given range
        public func range(i : Nat, j : Nat) : RevIter<(K)> {
            let iter = BaseMemoryBTree.range(state, btree_utils, i, j);
            RevIter.map(iter, extract_key);
        };

        public func scan(start : ?K, end : ?K) : RevIter<K> {
            let iter = BaseMemoryBTree.scan(state, btree_utils, start, end);
            RevIter.map(iter, extract_key);
        };

        public func size() : Nat = BaseMemoryBTree.size(state);

        public func bytes() : Nat = BaseMemoryBTree.bytes(state);

        public func metadataBytes() : Nat = BaseMemoryBTree.metadataBytes(state);

        /// Get the unique identifier for the given key
        public func getId(key : K) : ?Nat = BaseMemoryBTree.getId(state, btree_utils, key);

        /// Get the next unique identifier
        public func nextId() : Nat = BaseMemoryBTree.nextId(state);

        /// Lookup the key associated with the given id
        public func lookup(id : Nat) : ?K = BaseMemoryBTree.lookupKey(state, btree_utils, id);
        public func lookupKey(id : Nat) : ?K = BaseMemoryBTree.lookupKey(state, btree_utils, id);

        /// Reference a value by its id and increment the reference count
        /// Values will not be removed from the BTree until the reference count is back to zero
        public func reference(id : Nat) = BaseMemoryBTree.reference(state, btree_utils, id);

        /// Get the number of times the key has been referenced, if the key exists in the set
        public func getRefCount(id : Nat) : ?Nat = BaseMemoryBTree.getRefCount(state, btree_utils, id);

    };
};
