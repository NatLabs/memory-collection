import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Nat8 "mo:base/Nat8";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";

import MemoryRegion "mo:memory-region/MemoryRegion";
import RevIter "mo:itertools/RevIter";
import Find "mo:map/Map/modules/find";

import MemoryCmp "../TypeUtils/MemoryCmp";
import Blobify "../TypeUtils/Blobify";
import Methods "modules/Methods";
import MemoryBlock "modules/MemoryBlock";
import Branch "modules/Branch";
import Utils "../Utils";
import Migrations "Migrations";
import Leaf "modules/Leaf";
import T "modules/Types";
import TypeUtils "../TypeUtils";

module {
    type Address = Nat;
    type MemoryRegion = MemoryRegion.MemoryRegion;
    type Blobify<A> = Blobify.Blobify<A>;
    type RevIter<A> = RevIter.RevIter<A>;
    type Iter<A> = Iter.Iter<A>;
    type UniqueId = T.UniqueId;

    public type MemoryCmp<A> = MemoryCmp.MemoryCmp<A>;

    public type MemoryBTree = Migrations.MemoryBTree;
    public type VersionedMemoryBTree = Migrations.VersionedMemoryBTree;

    public type MemoryBlock = T.MemoryBlock;
    public type TypeUtils<A> = TypeUtils.TypeUtils<A>;

    public type BTreeUtils<K, V> = T.BTreeUtils<K, V>;

    let CACHE_LIMIT = 50_000;
    let DEFAULT_ORDER = 256;

    public func _new_with_options(node_capacity : ?Nat, opt_cache_size : ?Nat, is_set : Bool) : MemoryBTree {
        let cache_size = Option.get(opt_cache_size, CACHE_LIMIT);
        let btree : MemoryBTree = {
            is_set;
            node_capacity = Option.get(node_capacity, DEFAULT_ORDER);

            var count = 0;
            var root = 0;
            var branch_count = 0;
            var leaf_count = 0;
            var depth = 0;
            var is_root_a_leaf = true;

            leaves = MemoryRegion.new();
            branches = MemoryRegion.new();
            data = MemoryRegion.new();
            values = MemoryRegion.new();

        };

        init_region_header(btree);

        let leaf_address = Leaf.new(btree);
        Leaf.update_depth(btree, leaf_address, 1);
        assert Leaf.get_depth(btree, leaf_address) == 1;

        update_leaf_count(btree, 1);
        update_root(btree, leaf_address);
        update_is_root_a_leaf(btree, true);
        update_depth(btree, 1);

        return btree;
    };

    // public func new_set(node_capacity : ?Nat, cache_size : ?Nat) : MemoryBTree {
    //     _new_with_options(node_capacity, cache_size, true);
    // };

    public func new(node_capacity : ?Nat) : MemoryBTree {
        _new_with_options(node_capacity, ?0, false);
    };

    public let POINTER_SIZE = 12;
    public let LAYOUT_VERSION = 0;

    public let MC = {

        REGION_HEADER_SIZE = 64;

        DATA = {
            // addresses
            MAGIC_ADDRESS = 0; // 3 bytes
            LAYOUT_VERSION_ADDRESS = 3; // 1 byte
            BRANCHES_REGION_ID_ADDRESS = 4; // 4 bytes
            LEAVES_REGION_ID_ADDRESS = 8; // 4 bytes
            NODE_CAPACITY_ADDRESS = 12; // 2 bytes
            ROOT_ADDRESS = 14; // 8 bytes
            COUNT_ADDRESS = 22; // 8 bytes
            DEPTH_ADDRESS = 30; // 1 byte
            IS_ROOT_A_LEAF_ADDRESS = 31; // 1 byte
            VALUES_REGION_ID_ADDRESS = 32; // 4 bytes

            // values
            MAGIC : Blob = "BTR";
            LAYOUT_VERSION : Nat8 = 0;
        };

        VALUES = {
            // addresses
            MAGIC_ADDRESS = 0;
            LAYOUT_VERSION_ADDRESS = 3;
            DATA_REGION_ID_ADDRESS = 4; // 4 bytes

            // values
            MAGIC : Blob = "VLS";
            LAYOUT_VERSION : Nat8 = 0;
        };

        BRANCHES = {
            // addresses
            MAGIC_ADDRESS = 0;
            LAYOUT_VERSION_ADDRESS = 3;
            DATA_REGION_ID_ADDRESS = 4; // 4 bytes
            BRANCH_COUNT_ADDRESS = 8; // 8 bytes

            // values
            MAGIC : Blob = "BRS";
            LAYOUT_VERSION : Nat8 = 0;
        };

        LEAVES = {
            // addresses
            MAGIC_ADDRESS = 0;
            LAYOUT_VERSION_ADDRESS = 3;
            DATA_REGION_ID_ADDRESS = 4; // 4 bytes
            LEAF_COUNT_ADDRESS = 8; // 8 bytes

            // values
            MAGIC : Blob = "LVS";
            LAYOUT_VERSION : Nat8 = 0;
        };

    };

    public let Layout = [MC];

    func init_region_header(btree : MemoryBTree) {
        ignore MemoryRegion.allocate(btree.data, MC.REGION_HEADER_SIZE);
        MemoryRegion.storeBlob(btree.data, MC.DATA.MAGIC_ADDRESS, MC.DATA.MAGIC);
        MemoryRegion.storeNat8(btree.data, MC.DATA.LAYOUT_VERSION_ADDRESS, MC.DATA.LAYOUT_VERSION);
        MemoryRegion.storeNat32(btree.data, MC.DATA.BRANCHES_REGION_ID_ADDRESS, Nat32.fromNat(MemoryRegion.id(btree.branches)));
        MemoryRegion.storeNat32(btree.data, MC.DATA.LEAVES_REGION_ID_ADDRESS, Nat32.fromNat(MemoryRegion.id(btree.leaves)));
        MemoryRegion.storeNat16(btree.data, MC.DATA.NODE_CAPACITY_ADDRESS, 0);
        MemoryRegion.storeNat64(btree.data, MC.DATA.ROOT_ADDRESS, 0); // set to default value, will be updated once a node is created
        MemoryRegion.storeNat64(btree.data, MC.DATA.COUNT_ADDRESS, 0);
        MemoryRegion.storeNat8(btree.data, MC.DATA.DEPTH_ADDRESS, 0);
        MemoryRegion.storeNat8(btree.data, MC.DATA.IS_ROOT_A_LEAF_ADDRESS, 0);
        MemoryRegion.storeNat32(btree.data, MC.DATA.VALUES_REGION_ID_ADDRESS, Nat32.fromNat(MemoryRegion.id(btree.values)));
        assert MemoryRegion.allocated(btree.data) == MC.REGION_HEADER_SIZE;

        ignore MemoryRegion.allocate(btree.values, MC.REGION_HEADER_SIZE);
        MemoryRegion.storeBlob(btree.values, MC.VALUES.MAGIC_ADDRESS, MC.VALUES.MAGIC);
        MemoryRegion.storeNat8(btree.values, MC.VALUES.LAYOUT_VERSION_ADDRESS, MC.VALUES.LAYOUT_VERSION);
        MemoryRegion.storeNat32(btree.values, MC.VALUES.DATA_REGION_ID_ADDRESS, Nat32.fromNat(MemoryRegion.id(btree.data)));
        assert MemoryRegion.allocated(btree.values) == MC.REGION_HEADER_SIZE;

        ignore MemoryRegion.allocate(btree.branches, MC.REGION_HEADER_SIZE);
        MemoryRegion.storeBlob(btree.branches, MC.BRANCHES.MAGIC_ADDRESS, MC.BRANCHES.MAGIC);
        MemoryRegion.storeNat8(btree.branches, MC.BRANCHES.LAYOUT_VERSION_ADDRESS, MC.BRANCHES.LAYOUT_VERSION);
        MemoryRegion.storeNat32(btree.branches, MC.BRANCHES.DATA_REGION_ID_ADDRESS, Nat32.fromNat(MemoryRegion.id(btree.data)));
        MemoryRegion.storeNat64(btree.branches, MC.BRANCHES.BRANCH_COUNT_ADDRESS, 0);
        assert MemoryRegion.allocated(btree.branches) == MC.REGION_HEADER_SIZE;

        ignore MemoryRegion.allocate(btree.leaves, MC.REGION_HEADER_SIZE);
        MemoryRegion.storeBlob(btree.leaves, MC.LEAVES.MAGIC_ADDRESS, MC.LEAVES.MAGIC);
        MemoryRegion.storeNat8(btree.leaves, MC.LEAVES.LAYOUT_VERSION_ADDRESS, MC.LEAVES.LAYOUT_VERSION);
        MemoryRegion.storeNat32(btree.leaves, MC.LEAVES.DATA_REGION_ID_ADDRESS, Nat32.fromNat(MemoryRegion.id(btree.data)));
        MemoryRegion.storeNat64(btree.leaves, MC.LEAVES.LEAF_COUNT_ADDRESS, 0);
        assert MemoryRegion.allocated(btree.leaves) == MC.REGION_HEADER_SIZE;
    };

    public func createUtils<K, V>(key_utils : T.KeyUtils<K>, value_utils : T.ValueUtils<V>) : BTreeUtils<K, V> {
        return {
            key = key_utils;
            value = value_utils;
        };
    };

    public func size(btree : MemoryBTree) : Nat {
        btree.count;
    };

    public func fromVersioned(btree : VersionedMemoryBTree) : MemoryBTree {
        Migrations.getCurrentVersion(btree);
    };

    public func toVersioned(btree : MemoryBTree) : VersionedMemoryBTree {
        Migrations.addVersion(btree);
    };

    public func bytes(btree : MemoryBTree) : Nat {
        MemoryRegion.allocated(btree.data);
    };

    public func metadataBytes(btree : MemoryBTree) : Nat {
        MemoryRegion.allocated(btree.leaves) +
        MemoryRegion.allocated(btree.branches);
    };

    public func totalBytes(btree : MemoryBTree) : Nat {
        MemoryRegion.allocated(btree.data) +
        MemoryRegion.allocated(btree.leaves) +
        MemoryRegion.allocated(btree.branches);
    };

    public type MemoryBTreeStats = {
        branches : MemoryRegion.MemoryInfo;
        leaves : MemoryRegion.MemoryInfo;
        data : MemoryRegion.MemoryInfo;
    };

    public func stats(btree : MemoryBTree) : MemoryBTreeStats {
        let branches = MemoryRegion.memoryInfo(btree.branches);
        let leaves = MemoryRegion.memoryInfo(btree.leaves);
        let data = MemoryRegion.memoryInfo(btree.data);

        {
            branches;
            leaves;
            data;
        };

    };

    func update_root(btree : MemoryBTree, new_root : Address) {
        btree.root := new_root;
        MemoryRegion.storeNat64(btree.data, MC.DATA.ROOT_ADDRESS, Nat64.fromNat(new_root));
    };

    func update_count(btree : MemoryBTree, new_count : Nat) {
        btree.count := new_count;
        MemoryRegion.storeNat64(btree.data, MC.DATA.COUNT_ADDRESS, Nat64.fromNat(new_count));
    };

    func update_branch_count(btree : MemoryBTree, new_count : Nat) {
        btree.branch_count := new_count;
        MemoryRegion.storeNat64(btree.branches, MC.BRANCHES.BRANCH_COUNT_ADDRESS, Nat64.fromNat(new_count));
    };

    func update_leaf_count(btree : MemoryBTree, new_count : Nat) {
        btree.leaf_count := new_count;
        MemoryRegion.storeNat64(btree.leaves, MC.LEAVES.LEAF_COUNT_ADDRESS, Nat64.fromNat(new_count));
    };

    func update_depth(btree : MemoryBTree, new_depth : Nat) {
        btree.depth := new_depth;
        MemoryRegion.storeNat64(btree.data, MC.DATA.DEPTH_ADDRESS, Nat64.fromNat(new_depth));
    };

    func update_is_root_a_leaf(btree : MemoryBTree, is_leaf : Bool) {
        btree.is_root_a_leaf := is_leaf;
        MemoryRegion.storeNat8(btree.data, MC.DATA.IS_ROOT_A_LEAF_ADDRESS, if (is_leaf) 1 else 0);
    };

    func inc_subtree_size(btree : MemoryBTree, branch_address : Nat, _child_index : Nat) {
        let subtree_size = Branch.get_subtree_size(btree, branch_address);
        Branch.update_subtree_size(btree, branch_address, subtree_size + 1);
    };

    public func insert<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, key : K, value : V) : ?V {
        let key_blob = btree_utils.key.blobify.to_blob(key);

        let leaf_address = Methods.get_leaf_address_and_update_path(btree, btree_utils, key, ?key_blob, inc_subtree_size);
        let count = Leaf.get_count(btree, leaf_address);

        let int_index = switch (btree_utils.key.cmp) {
            case (#GenCmp(cmp)) Leaf.binary_search<K, V>(btree, btree_utils, leaf_address, cmp, key, count);
            case (#BlobCmp(cmp)) {
                Leaf.binary_search_blob_seq(btree, leaf_address, cmp, key_blob, count);
            };
        };

        let elem_index = if (int_index >= 0) Int.abs(int_index) else Int.abs(int_index + 1);

        let val_blob = btree_utils.value.blobify.to_blob(value);

        if (int_index >= 0) {
            // existing key
            let ?kv_address = Leaf.get_kv_address(btree, leaf_address, elem_index) else Debug.trap("insert: accessed a null value");
            let prev_val_blob = MemoryBlock.replace_val(btree, kv_address, val_blob);

            Methods.update_leaf_to_root(btree, leaf_address, decrement_subtree_size);

            return ?btree_utils.value.blobify.from_blob(prev_val_blob);
        };

        let kv_address = MemoryBlock.store(btree, key_blob, val_blob);
        // Debug.print("kv_address: " # debug_show kv_address);
        // Debug.print("kv_blobs: " # debug_show (MemoryBlock.get_key_blob(btree, kv_address), MemoryBlock.get_val_blob(btree, kv_address)));
        // Debug.print("actual kv_blobs: " # debug_show (key_blob, val_blob));

        if (count < btree.node_capacity) {
            // Debug.print("found leaf with enough space");
            Leaf.insert_with_count(btree, leaf_address, elem_index, kv_address, count);
            update_count(btree, btree.count + 1);

            return null;
        };

        // split leaf
        var left_node_address = leaf_address;
        var right_node_address = Leaf.split(btree, left_node_address, elem_index, kv_address);
        update_leaf_count(btree, btree.leaf_count + 1);
        // Debug.print("left leaf after split: " # debug_show Leaf.from_memory(btree, left_node_address));
        // Debug.print("right leaf after split: " # debug_show Leaf.from_memory(btree, right_node_address));

        var opt_parent = Leaf.get_parent(btree, right_node_address);
        var right_index = Leaf.get_index(btree, right_node_address);

        let ?first_key_address = Leaf.get_kv_address(btree, right_node_address, 0) else Debug.trap("insert: first_key_address accessed a null value");
        var median_key_address = first_key_address;

        // assert Leaf.get_count(btree, left_node_address) == (btree.node_capacity / 2) + 1;
        // assert Leaf.get_count(btree, right_node_address) == (btree.node_capacity / 2);

        while (Option.isSome(opt_parent)) {

            let ?parent_address = opt_parent else Debug.trap("insert: Failed to get parent address");

            let parent_count = Branch.get_count(btree, parent_address);

            // insert right node in parent if there is enough space
            if (parent_count < btree.node_capacity) {
                // Debug.print("found branch with enough space");
                // Debug.print("parent before insert: " # debug_show Branch.from_memory(btree, parent_address));

                Branch.insert(btree, parent_address, right_index, median_key_address, right_node_address);
                update_count(btree, btree.count + 1);

                // Debug.print("parent after insert: " # debug_show Branch.from_memory(btree, parent_address));

                return null;
            };

            // otherwise split parent
            left_node_address := parent_address;
            right_node_address := Branch.split(btree, left_node_address, right_index, median_key_address, right_node_address);
            update_branch_count(btree, btree.branch_count + 1);

            let ?first_key_address = Branch.get_key_address(btree, right_node_address, btree.node_capacity - 2) else Debug.trap("4. insert: accessed a null value in first key of branch");
            Branch.set_key_address_to_null(btree, right_node_address, btree.node_capacity - 2);
            median_key_address := first_key_address;

            right_index := Branch.get_index(btree, right_node_address);
            opt_parent := Branch.get_parent(btree, right_node_address);

        };

        // Debug.print("new root");
        // new root
        let new_root = Branch.new(btree);
        update_branch_count(btree, btree.branch_count + 1);

        let new_depth = btree.depth + 1;
        Branch.update_depth(btree, new_root, new_depth);
        assert Branch.get_depth(btree, new_root) == new_depth;

        Branch.put_key_address(btree, new_root, 0, median_key_address);

        Branch.add_child(btree, new_root, left_node_address);
        Branch.add_child(btree, new_root, right_node_address);

        assert Branch.get_count(btree, new_root) == 2;

        update_root(btree, new_root);
        update_is_root_a_leaf(btree, false);
        update_depth(btree, new_depth);
        update_count(btree, btree.count + 1);

        null;
    };

    /// Increase the reference count of the entry with the given id if it exists.
    /// The reference count is used to track the number of entities depending on the entry.
    /// If the reference count is 0, the entry is deleted.
    /// To decrease the reference count, use the `remove()` function.
    /// This is an opt-in feature that helps you maintain the integrity of the data.
    /// Prevents you from prematurely deleting an entry that is still being used.
    /// If you don't need this feature, you can use the library without calling this function.
    public func reference<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, id : UniqueId) {
        if (not MemoryBlock.id_exists(btree, id)) return;
        MemoryBlock.increment_ref_count(btree, id);
    };

    /// Get the reference count of the entry with the given id.
    public func getRefCount<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, id : UniqueId) : ?Nat {
        if (not MemoryBlock.id_exists(btree, id)) return null;
        ?MemoryBlock.get_ref_count(btree, id);
    };

    public func lookup<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, id : UniqueId) : ?(K, V) {
        if (not MemoryBlock.id_exists(btree, id)) return null;

        let key_blob = MemoryBlock.get_key_blob(btree, id);
        let val_blob = MemoryBlock.get_val_blob(btree, id);
        let kv = Methods.deserialize_kv_blobs<K, V>(btree_utils, key_blob, val_blob);
        ?kv;
    };

    public func lookupKey<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, id : UniqueId) : ?K {
        if (not MemoryBlock.id_exists(btree, id)) return null;

        let key_blob = MemoryBlock.get_key_blob(btree, id);
        let key = btree_utils.key.blobify.from_blob(key_blob);
        ?key;
    };

    public func lookupVal<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, id : UniqueId) : ?V {
        if (not MemoryBlock.id_exists(btree, id)) return null;

        let val_blob = MemoryBlock.get_val_blob(btree, id);
        let val = btree_utils.value.blobify.from_blob(val_blob);
        ?val;
    };

    public func _lookup_mem_block<K, V>(btree : MemoryBTree, id : UniqueId) : ?(MemoryBlock, MemoryBlock) {
        if (not MemoryBlock.id_exists(btree, id)) return null;

        let key_block = MemoryBlock.get_key_block(btree, id);
        let val_block = MemoryBlock.get_val_block(btree, id);

        ?(key_block, val_block);
    };

    public func _lookup_key_blob<K, V>(btree : MemoryBTree, id : UniqueId) : ?Blob {
        if (not MemoryBlock.id_exists(btree, id)) return null;

        let key_blob = MemoryBlock.get_key_blob(btree, id);
        ?key_blob;
    };

    public func _lookup_val_blob<K, V>(btree : MemoryBTree, id : UniqueId) : ?Blob {
        if (not MemoryBlock.id_exists(btree, id)) return null;

        let val_blob = MemoryBlock.get_val_blob(btree, id);
        ?val_blob;
    };

    public func getId<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : ?UniqueId {
        let key_blob = btree_utils.key.blobify.to_blob(key);

        let leaf_address = Methods.get_leaf_address(btree, btree_utils, key, ?key_blob);
        let count = Leaf.get_count(btree, leaf_address);

        let int_index = switch (btree_utils.key.cmp) {
            case (#GenCmp(cmp)) Leaf.binary_search<K, V>(btree, btree_utils, leaf_address, cmp, key, count);
            case (#BlobCmp(cmp)) {
                Leaf.binary_search_blob_seq(btree, leaf_address, cmp, key_blob, count);
            };
        };

        if (int_index < 0) return null;

        let elem_index = Int.abs(int_index);

        let opt_key_address = Leaf.get_kv_address(btree, leaf_address, elem_index);
        opt_key_address;
    };

    public func nextId<K, V>(btree : MemoryBTree) : UniqueId {
        MemoryBlock.next_id(btree);
    };

    public func entries<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : RevIter<(K, V)> {
        Methods.entries(btree, btree_utils);
    };

    public func toEntries<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : [(K, V)] {
        Utils.sized_iter_to_array<(K, V)>(entries(btree, btree_utils), btree.count);
    };

    public func toArray<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : [(K, V)] {
        Utils.sized_iter_to_array<(K, V)>(entries(btree, btree_utils), btree.count);
    };

    public func keys<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : RevIter<K> {
        Methods.keys(btree, btree_utils);
    };

    public func toKeys<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : [K] {
        Utils.sized_iter_to_array<K>(keys(btree, btree_utils), btree.count);
    };

    public func vals<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : RevIter<V> {
        Methods.vals(btree, btree_utils);
    };

    public func toVals<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : [V] {
        Utils.sized_iter_to_array<V>(vals(btree, btree_utils), btree.count);
    };

    public func leafNodes<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : RevIter<[?(K, V)]> {
        Methods.leaf_nodes(btree, btree_utils);
    };

    public func toLeafNodes<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : [[?(K, V)]] {
        Utils.sized_iter_to_array<[?(K, V)]>(leafNodes<K, V>(btree, btree_utils), btree.leaf_count);
    };

    public func toNodeKeys<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : [[(Nat, Nat, Nat, [?K])]] {
        Methods.node_keys(btree, btree_utils);
    };

    public func get<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : ?V {
        let key_blob = btree_utils.key.blobify.to_blob(key);

        let leaf_address = Methods.get_leaf_address(btree, btree_utils, key, ?key_blob);
        let count = Leaf.get_count(btree, leaf_address);

        let int_index = switch (btree_utils.key.cmp) {
            case (#GenCmp(cmp)) Leaf.binary_search<K, V>(btree, btree_utils, leaf_address, cmp, key, count);
            case (#BlobCmp(cmp)) {
                Leaf.binary_search_blob_seq(btree, leaf_address, cmp, key_blob, count);
            };
        };

        if (int_index < 0) return null;

        let elem_index = Int.abs(int_index);

        let ?val_blob = Leaf.get_val_blob(btree, leaf_address, elem_index) else Debug.trap("get: accessed a null value");
        let value = btree_utils.value.blobify.from_blob(val_blob);
        ?value;
    };

    public func contains<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : Bool {
        let key_blob = btree_utils.key.blobify.to_blob(key);

        let leaf_address = Methods.get_leaf_address(btree, btree_utils, key, ?key_blob);
        let count = Leaf.get_count(btree, leaf_address);

        let int_index = switch (btree_utils.key.cmp) {
            case (#GenCmp(cmp)) Leaf.binary_search<K, V>(btree, btree_utils, leaf_address, cmp, key, count);
            case (#BlobCmp(cmp)) {
                Leaf.binary_search_blob_seq(btree, leaf_address, cmp, key_blob, count);
            };
        };

        if (int_index < 0) return false;

        return true;

    };

    public func getMin<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : ?(K, V) {
        let leaf_address = Methods.get_min_leaf_address(btree);

        let ?key_blob = Leaf.get_key_blob(btree, leaf_address, 0) else Debug.trap("getMin: accessed a null value");
        let ?val_blob = Leaf.get_val_blob(btree, leaf_address, 0) else Debug.trap("getMin: accessed a null value");

        let key = btree_utils.key.blobify.from_blob(key_blob);
        let value = btree_utils.value.blobify.from_blob(val_blob);
        ?(key, value);
    };

    public func getMax<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : ?(K, V) {
        let leaf_address = Methods.get_max_leaf_address(btree);
        let count = Leaf.get_count(btree, leaf_address);

        let ?key_blob = Leaf.get_key_blob(btree, leaf_address, count - 1 : Nat) else Debug.trap("getMax: accessed a null value");
        let ?val_blob = Leaf.get_val_blob(btree, leaf_address, count - 1 : Nat) else Debug.trap("getMax: accessed a null value");

        let key = btree_utils.key.blobify.from_blob(key_blob);
        let value = btree_utils.value.blobify.from_blob(val_blob);
        ?(key, value);
    };

    public func clear(btree : MemoryBTree) {

        // the first leaf node should be at the address where the header ends
        let leaf_address = MC.REGION_HEADER_SIZE;
        assert Leaf.validate(btree, leaf_address);

        Leaf.clear(btree, leaf_address);
        assert Leaf.validate(btree, leaf_address);

        update_root(btree, leaf_address);
        update_is_root_a_leaf(btree, true);
        update_depth(btree, 1);
        update_count(btree, 0);
        update_branch_count(btree, 0);
        update_leaf_count(btree, 1);

        let leaf_memory_size = Leaf.get_memory_size(btree.node_capacity);
        let everything_after_leaf = leaf_address + leaf_memory_size;
        let leaves_region_size = MemoryRegion.size(btree.leaves);
        MemoryRegion.deallocateRange(btree.leaves, everything_after_leaf, leaves_region_size);

        assert MemoryRegion.allocated(btree.leaves) == everything_after_leaf;
        assert MemoryRegion.size(btree.leaves) == everything_after_leaf;
        assert MemoryRegion.deallocated(btree.leaves) == 0;
        assert [] == Iter.toArray(MemoryRegion.deallocatedBlocksInRange(btree.leaves, 0, leaves_region_size));

        let branches_memory_size = MemoryRegion.size(btree.branches);
        MemoryRegion.deallocateRange(btree.branches, MC.REGION_HEADER_SIZE, branches_memory_size);
        assert MemoryRegion.allocated(btree.branches) == MC.REGION_HEADER_SIZE;
        assert MemoryRegion.size(btree.branches) == MC.REGION_HEADER_SIZE;
        assert MemoryRegion.deallocated(btree.branches) == 0;
        assert [] == Iter.toArray(MemoryRegion.deallocatedBlocksInRange(btree.branches, 0, branches_memory_size));

        let data_memory_size = MemoryRegion.size(btree.data);
        MemoryRegion.deallocateRange(btree.data, MC.REGION_HEADER_SIZE, data_memory_size);
        assert MemoryRegion.allocated(btree.data) == MC.REGION_HEADER_SIZE;
        assert MemoryRegion.size(btree.data) == MC.REGION_HEADER_SIZE;
        assert MemoryRegion.deallocated(btree.data) == 0;
        assert [] == Iter.toArray(MemoryRegion.deallocatedBlocksInRange(btree.data, 0, data_memory_size));

    };

    func decrement_subtree_size(btree : MemoryBTree, branch_address : Nat, _child_index : Nat) {
        let subtree_size = Branch.get_subtree_size(btree, branch_address);
        Branch.update_subtree_size(btree, branch_address, subtree_size - 1);
    };

    public func remove<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : ?V {
        let key_blob = btree_utils.key.blobify.to_blob(key);

        let leaf_address = Methods.get_leaf_address_and_update_path(btree, btree_utils, key, ?key_blob, decrement_subtree_size);
        let count = Leaf.get_count(btree, leaf_address);

        let int_index = switch (btree_utils.key.cmp) {
            case (#GenCmp(cmp)) Leaf.binary_search(btree, btree_utils, leaf_address, cmp, key, count);
            case (#BlobCmp(cmp)) {
                Leaf.binary_search_blob_seq(btree, leaf_address, cmp, key_blob, count);
            };
        };

        if (int_index < 0) {
            // key not found, so revert the path to its original state by incrementing the subtree size
            Methods.update_leaf_to_root(btree, leaf_address, inc_subtree_size);
            return null;
        };

        let elem_index = Int.abs(int_index);

        let ?prev_kv_address = Leaf.get_kv_address(btree, leaf_address, elem_index) else Debug.trap("remove: prev_kv_address is null");

        let prev_val_blob = MemoryBlock.get_val_blob(btree, prev_kv_address);
        let prev_val = btree_utils.value.blobify.from_blob(prev_val_blob);

        // If the entry is being referenced by other entities,
        // we decrement the reference count and only delete the entry if the reference count is 0.
        if (MemoryBlock.decrement_ref_count(btree, prev_kv_address) >= 1) return ?prev_val;

        MemoryBlock.remove(btree, prev_kv_address); // deallocate key and value blocks
        Leaf.remove(btree, leaf_address, elem_index); // remove the deleted key-value pair from the leaf
        update_count(btree, btree.count - 1);

        let ?parent_address = Leaf.get_parent(btree, leaf_address) else return ?prev_val; // if parent is null then leaf_node is the root
        var parent = parent_address;
        // Debug.print("Leaf's parent: " # debug_show Branch.from_memory(btree, parent));

        let leaf_index = Leaf.get_index(btree, leaf_address);

        if (elem_index == 0) {
            // if the first element is removed then update the parent key
            let ?next_key_address = Leaf.get_kv_address(btree, leaf_address, 0) else Debug.trap("remove: next_key_block is null");
            Branch.update_median_key_address(btree, parent, leaf_index, next_key_address);
        };

        let min_count = btree.node_capacity / 2;
        let leaf_count = Leaf.get_count(btree, leaf_address);

        if (leaf_count >= min_count) return ?prev_val;

        // redistribute entries from larger neighbour to the current leaf below min_count
        let ?neighbour = Branch.get_larger_neighbour(btree, parent, leaf_index) else Debug.trap("remove: neighbour is null");

        let neighbour_index = Leaf.get_index(btree, neighbour);

        let left = if (leaf_index < neighbour_index) { leaf_address } else {
            neighbour;
        };
        let right = if (leaf_index < neighbour_index) { neighbour } else {
            leaf_address;
        };

        // let left_index = if (leaf_index < neighbour_index) { leaf_index } else { neighbour_index };
        let right_index = if (leaf_index < neighbour_index) { neighbour_index } else {
            leaf_index;
        };

        // Debug.print("leaf.redistribute");

        if (Leaf.redistribute(btree, leaf_address, neighbour)) {

            let ?key_address = Leaf.get_kv_address(btree, right, 0) else Debug.trap("remove: key_block is null");
            Branch.put_key_address(btree, parent, right_index - 1, key_address);

            return ?prev_val;
        };

        // Debug.print("merging leaf");

        // remove merged leaf from parent
        // Debug.print("remove merged index: " # debug_show right_index);
        // Debug.print("parent: " # debug_show Branch.from_memory(btree, parent));

        // merge leaf with neighbour
        Leaf.merge(btree, left, right);
        Branch.remove(btree, parent, right_index);

        // deallocate right leaf that was merged into left
        Leaf.deallocate(btree, right);
        update_leaf_count(btree, btree.leaf_count - 1);

        // Debug.print("parent: " # debug_show Branch.from_memory(btree, parent));
        // Debug.print("leaf_nodes: " # debug_show Iter.toArray(Methods.leaf_addresses(btree)));

        func set_only_child_to_root(parent : Address) : ?V {
            if (Branch.get_count(btree, parent) == 1) {
                let ?child = Branch.get_child(btree, parent, 0) else Debug.trap("set_only_child_to_root: child is null");

                let child_is_leaf = Branch.has_leaves(btree, parent);

                if (child_is_leaf) {
                    Leaf.update_parent(btree, child, null);
                } else {
                    Branch.update_parent(btree, child, null);
                };

                update_root(btree, child);
                update_is_root_a_leaf(btree, child_is_leaf);
                update_depth(btree, btree.depth - 1);
                return ?prev_val;

            } else {
                return ?prev_val;
            };
        };

        var branch = parent;
        let ?branch_parent = Branch.get_parent(btree, branch) else return set_only_child_to_root(parent);

        parent := branch_parent;

        while (Branch.get_count(btree, branch) < min_count) {
            // Debug.print("redistribute branch");
            // Debug.print("parent before redistribute: " # debug_show Branch.from_memory(btree, parent));
            // Debug.print("branch before redistribute: " # debug_show Branch.from_memory(btree, branch));

            if (Branch.redistribute(btree, branch)) {
                // Debug.print("parent after redistribute: " # debug_show Branch.from_memory(btree, parent));
                // Debug.print("branch after redistribute: " # debug_show Branch.from_memory(btree, branch));
                return ?prev_val;
            };

            // Debug.print("branch after redistribute: " # debug_show Branch.from_memory(btree, branch));

            // Debug.print("merging branch");
            // Debug.print("parent before merge: " # debug_show Branch.from_memory(btree, parent));
            let branch_index = Branch.get_index(btree, branch);
            let ?neighbour = Branch.get_larger_neighbour(btree, parent, branch_index) else Debug.trap("Branch.merge: neighbour should not be null");

            let merged_branch = Branch.merge(btree, branch, neighbour);
            let merged_branch_index = Branch.get_index(btree, merged_branch);
            Branch.remove(btree, parent, merged_branch_index);
            Branch.deallocate(btree, merged_branch);
            update_branch_count(btree, btree.branch_count - 1);

            // Debug.print("parent after merge: " # debug_show Branch.from_memory(btree, parent));
            // Debug.print("leaf_nodes: " # debug_show Iter.toArray(Methods.leaf_addresses(btree)));

            branch := parent;
            let ?branch_parent = Branch.get_parent(btree, branch) else return set_only_child_to_root(parent);

            parent := branch_parent;

            if (Branch.get_count(btree, parent) == 1) {
                return set_only_child_to_root(parent);
            };
        };

        return ?prev_val;
    };

    public func removeMin<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : ?(K, V) {
        let ?min = getMin<K, V>(btree, btree_utils) else return null;
        ignore remove<K, V>(btree, btree_utils, min.0);
        ?min;
    };

    public func removeMax<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : ?(K, V) {
        let ?max = getMax<K, V>(btree, btree_utils) else return null;
        ignore remove<K, V>(btree, btree_utils, max.0);
        ?max;
    };

    public func fromArray<K, V>(btree_utils : BTreeUtils<K, V>, arr : [(K, V)], order : ?Nat) : MemoryBTree {
        fromEntries(btree_utils, arr.vals(), order);
    };

    public func fromEntries<K, V>(btree_utils : BTreeUtils<K, V>, entries : Iter<(K, V)>, order : ?Nat) : MemoryBTree {
        let btree = new(order);

        for ((k, v) in entries) {
            ignore insert(btree, btree_utils, k, v);
        };

        btree;
    };

    public func getCeiling<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : ?(K, V) {
        let key_blob = btree_utils.key.blobify.to_blob(key);
        let leaf_address = Methods.get_leaf_address<K, V>(btree, btree_utils, key, ?key_blob);

        let i = switch (btree_utils.key.cmp) {
            case (#GenCmp(cmp)) Leaf.binary_search<K, V>(btree, btree_utils, leaf_address, cmp, key, Leaf.get_count(btree, leaf_address));
            case (#BlobCmp(cmp)) {
                Leaf.binary_search_blob_seq(btree, leaf_address, cmp, key_blob, Leaf.get_count(btree, leaf_address));
            };
        };

        if (i >= 0) {
            let ?(k, v) = Leaf.get_kv_blobs(btree, leaf_address, Int.abs(i)) else return null;
            return ?Methods.deserialize_kv_blobs<K, V>(btree_utils, k, v);
        };

        let expected_index = Int.abs(i) - 1 : Nat;

        if (expected_index == Leaf.get_count(btree, leaf_address)) {
            let ?next_address = Leaf.get_next(btree, leaf_address) else return null;
            let ?(k, v) = Leaf.get_kv_blobs(btree, next_address, 0) else return null;
            return ?Methods.deserialize_kv_blobs<K, V>(btree_utils, k, v);
        };

        let ?(k, v) = Leaf.get_kv_blobs(btree, leaf_address, expected_index) else return null;
        return ?Methods.deserialize_kv_blobs<K, V>(btree_utils, k, v);
    };

    public func getFloor<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : ?(K, V) {
        let key_blob = btree_utils.key.blobify.to_blob(key);
        let leaf_address = Methods.get_leaf_address<K, V>(btree, btree_utils, key, ?key_blob);

        let i = switch (btree_utils.key.cmp) {
            case (#GenCmp(cmp)) Leaf.binary_search<K, V>(btree, btree_utils, leaf_address, cmp, key, Leaf.get_count(btree, leaf_address));
            case (#BlobCmp(cmp)) {
                Leaf.binary_search_blob_seq(btree, leaf_address, cmp, key_blob, Leaf.get_count(btree, leaf_address));
            };
        };

        if (i >= 0) {
            let ?kv_blobs = Leaf.get_kv_blobs(btree, leaf_address, Int.abs(i)) else return null;
            return ?Methods.deserialize_kv_blobs<K, V>(btree_utils, kv_blobs.0, kv_blobs.1);
        };

        let expected_index = Int.abs(i) - 1 : Nat;

        if (expected_index == 0) {
            let ?prev_address = Leaf.get_prev(btree, leaf_address) else return null;
            let prev_count = Leaf.get_count(btree, prev_address);
            let ?(k, v) = Leaf.get_kv_blobs(btree, prev_address, prev_count - 1) else return null;
            return ?Methods.deserialize_kv_blobs<K, V>(btree_utils, k, v);
        };

        let ?kv_blobs = Leaf.get_kv_blobs(btree, leaf_address, expected_index - 1) else return null;
        return ?Methods.deserialize_kv_blobs<K, V>(btree_utils, kv_blobs.0, kv_blobs.1);
    };

    // Returns the key-value pair at the given index.
    // Throws an error if the index is greater than the size of the tree.
    public func getFromIndex<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, index : Nat) : (K, V) {
        if (index >= btree.count) return Debug.trap("getFromIndex: index is out of bounds");

        let (leaf_address, i) = Methods.get_leaf_node_by_index(btree, index);

        let ?entry = Leaf.get_kv_blobs(btree, leaf_address, i) else Debug.trap("getFromIndex: accessed a null value");

        Methods.deserialize_kv_blobs(btree_utils, entry.0, entry.1);
    };

    // Returns the index of the given key in the tree.
    // Throws an error if the key does not exist in the tree.
    public func getIndex<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : Nat {
        let key_blob = btree_utils.key.blobify.to_blob(key);
        let (leaf_address, index_pos) = Methods.get_leaf_node_and_index(btree, btree_utils, key_blob);

        let count = Leaf.get_count(btree, leaf_address);
        let int_index = switch (btree_utils.key.cmp) {
            case (#GenCmp(cmp)) Leaf.binary_search<K, V>(btree, btree_utils, leaf_address, cmp, key, count);
            case (#BlobCmp(cmp)) {
                Leaf.binary_search_blob_seq(btree, leaf_address, cmp, key_blob, count);
            };
        };

        if (int_index < 0) {
            Debug.trap("getIndex(): Key not found. Use getExpectedIndex() instead to get keys that might not be in the tree");
        };

        index_pos + Int.abs(int_index);
    };

    /// Returns the index of the given key in the tree.
    /// Used to indicate whether the key is in the tree or not.
    public type ExpectedIndex = {
        #Found : Nat;
        #NotFound : Nat;
    };

    public func getExpectedIndex<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, key : K) : ExpectedIndex {
        let key_blob = btree_utils.key.blobify.to_blob(key);
        let (leaf_address, index_pos) = Methods.get_leaf_node_and_index(btree, btree_utils, key_blob);

        let count = Leaf.get_count(btree, leaf_address);
        let int_index = switch (btree_utils.key.cmp) {
            case (#GenCmp(cmp)) Leaf.binary_search<K, V>(btree, btree_utils, leaf_address, cmp, key, count);
            case (#BlobCmp(cmp)) {
                Leaf.binary_search_blob_seq(btree, leaf_address, cmp, key_blob, count);
            };
        };

        if (int_index < 0) {
            #NotFound(index_pos + Int.abs(int_index + 1));
        } else {
            #Found(index_pos + Int.abs(int_index));
        };

    };

    public func range<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, start : Nat, end : Nat) : RevIter<(K, V)> {
        let (start_node, start_node_index) = Methods.get_leaf_node_by_index(btree, start);
        let (end_node, end_node_index) = Methods.get_leaf_node_by_index(btree, end);

        let start_index = start_node_index : Nat;
        let end_index = end_node_index : Nat;

        RevIter.map<(Blob, Blob), (K, V)>(
            Methods.new_blobs_iterator(btree, start_node, start_index, end_node, end_index),
            func((key_blob, val_blob) : (Blob, Blob)) : (K, V) {
                Methods.deserialize_kv_blobs<K, V>(btree_utils, key_blob, val_blob);
            },
        );
    };

    public func getInterval<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, start : ?K, end : ?K) : (Nat, Nat) {
        let start_rank = switch (start) {
            case (?key) getIndex(btree, btree_utils, key);
            case (null) 0;
        };

        let end_rank = switch (end) {
            case (?key) getIndex(btree, btree_utils, key) + 1; // +1 because the end is exclusive
            case (null) btree.count;
        };

        (start_rank, end_rank);
    };

    public func scan<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, start : ?K, end : ?K) : RevIter<(K, V)> {
        let start_address = switch (start) {
            case (?key) {
                let key_blob = btree_utils.key.blobify.to_blob(key);
                Methods.get_leaf_address(btree, btree_utils, key, ?key_blob);
            };
            case (null) Methods.get_min_leaf_address(btree);
        };

        let start_index = switch (start) {
            case (?key) switch (btree_utils.key.cmp) {
                case (#GenCmp(cmp)) Leaf.binary_search<K, V>(btree, btree_utils, start_address, cmp, key, Leaf.get_count(btree, start_address));
                case (#BlobCmp(cmp)) {
                    let key_blob = btree_utils.key.blobify.to_blob(key);
                    Leaf.binary_search_blob_seq(btree, start_address, cmp, key_blob, Leaf.get_count(btree, start_address));
                };
            };
            case (null) 0;
        };

        // if start_index is negative then the element was not found
        // moreover if start_index is negative then abs(i) - 1 is the index of the first element greater than start
        var i = if (start_index >= 0) Int.abs(start_index) else Int.abs(start_index) - 1 : Nat;

        let end_address = switch (end) {
            case (?key) {
                let key_blob = btree_utils.key.blobify.to_blob(key);
                Methods.get_leaf_address(btree, btree_utils, key, ?key_blob);
            };
            case (null) Methods.get_max_leaf_address(btree);
        };

        let end_index = switch (end) {
            case (?key) switch (btree_utils.key.cmp) {
                case (#GenCmp(cmp)) Leaf.binary_search<K, V>(btree, btree_utils, end_address, cmp, key, Leaf.get_count(btree, end_address));
                case (#BlobCmp(cmp)) {
                    let key_blob = btree_utils.key.blobify.to_blob(key);
                    Leaf.binary_search_blob_seq(btree, end_address, cmp, key_blob, Leaf.get_count(btree, end_address));
                };
            };
            case (null) Leaf.get_count(btree, end_address);
        };

        var j = if (end_index >= 0) Int.abs(end_index) + 1 else Int.abs(end_index) - 1 : Nat;

        RevIter.map<(Blob, Blob), (K, V)>(
            Methods.new_blobs_iterator(btree, start_address, i, end_address, j),
            func((key_blob, val_blob) : (Blob, Blob)) : (K, V) {
                Methods.deserialize_kv_blobs<K, V>(btree_utils, key_blob, val_blob);
            },
        );
    };
};
