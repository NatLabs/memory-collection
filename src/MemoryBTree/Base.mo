import Debug "mo:base@0.16.0/Debug";
import Iter "mo:base@0.16.0/Iter";
import Int "mo:base@0.16.0/Int";
import Int64 "mo:base@0.16.0/Int64";
import Nat "mo:base@0.16.0/Nat";
import Option "mo:base@0.16.0/Option";
import Nat8 "mo:base@0.16.0/Nat8";
import Nat16 "mo:base@0.16.0/Nat16";
import Nat32 "mo:base@0.16.0/Nat32";
import Nat64 "mo:base@0.16.0/Nat64";
import Blob "mo:base@0.16.0/Blob";
import Float "mo:base@0.16.0/Float";

import MemoryRegion "mo:memory-region@1.3.2/MemoryRegion";
import RevIter "mo:itertools@0.2.2/RevIter";

import MemoryCmp "../TypeUtils/MemoryCmp";
import Blobify "../TypeUtils/Blobify";
import Methods "modules/Methods";
import MemoryBlock "modules/MemoryBlock";
import Branch "modules/Branch";
import Utils "../Utils";
import Migrations "Migrations";
import LeafModule "modules/Leaf";
import T "modules/Types";
import TypeUtils "../TypeUtils";
import Common "modules/Common";

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
    public type MemoryBTreeStats = T.MemoryBTreeStats;
    public type MergeStrategy = Migrations.MergeStrategy;

    let DEFAULT_ORDER = 256;
    public let Leaf = LeafModule;

    /// Options for creating a new MemoryBTree.
    public type BTreeOptions = {
        /// The maximum number of children per node. Must be between 16 and 4096.
        /// Default is 256.
        node_capacity : ?Nat;

        /// Enable tail compression for separator keys.
        /// When enabled, separator keys are truncated to the minimum length needed to
        /// distinguish between the last key of the left node and the first key of the right node.
        /// This can significantly reduce memory usage for keys with common prefixes.
        /// Note: Only works correctly with lexicographic comparison (e.g., Text, Blob keys).
        /// For numeric types like Nat that use size-based comparison, this should be disabled.
        /// Default is false.
        enable_tail_compression : ?Bool;

        /// Merge strategy to use for node merging after deletions.
        /// - #Conservative: Merge only when BOTH nodes are below threshold.
        ///   Very few merges, separator keys stay stable. Good for read-heavy workloads and tail compression.
        ///   May leave sparse nodes that never merge if neighbour is above threshold.
        /// - #Balanced: Merge when EITHER node is below threshold AND combined fits.
        ///   More merges but better memory efficiency. Cleans up sparse nodes proactively.
        /// Default is #Balanced.
        merge_strategy : ?MergeStrategy;

        /// Merge threshold: nodes are considered "sparse" when they have fewer than
        /// (node_capacity * merge_threshold) elements.
        /// - For #Conservative: merge only when BOTH nodes are below this threshold
        /// - For #Balanced: merge when EITHER node is below threshold AND combined fits
        /// This threshold also affects optimal split position selection when tail compression is enabled:
        /// splits occur at positions > merge_threshold_count and < (node_capacity - merge_threshold_count)
        /// to ensure both resulting nodes have enough elements to avoid immediate merging.
        /// Default is 0.25 (1/4 capacity).
        merge_threshold : ?Float;
    };

    public func _new_with_options(options : ?BTreeOptions, is_set : Bool) : MemoryBTree {
        let node_capacity = switch (options) {
            case (?opts) opts.node_capacity;
            case (null) null;
        };

        switch (node_capacity) {
            case (?n) {
                if (n < 16 or n > 4096) {
                    Debug.trap("MemoryBTree node_capacity must be between 16 and 4096");
                };
            };
            case (null) {};
        };

        let enable_tail_compression = switch (options) {
            case (?opts) Option.get(opts.enable_tail_compression, false);
            case (null) false;
        };

        let merge_strategy : MergeStrategy = switch (options) {
            case (?opts) Option.get(opts.merge_strategy, #Balanced);
            case (null) #Balanced;
        };

        let merge_threshold = switch (options) {
            case (?opts) Option.get(opts.merge_threshold, 0.25);
            case (null) 0.25;
        };

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

            enable_tail_compression;
            merge_strategy;
            merge_threshold;
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

    // public func new_set(options : ?BTreeOptions) : MemoryBTree {
    //     _new_with_options(options, true);
    // };

    /// Create a new MemoryBTree with the given options.
    /// If options is null, default values are used.
    public func newWithOptions(options : BTreeOptions) : MemoryBTree {
        _new_with_options(?options, false);
    };

    /// Create a new MemoryBTree with the given node capacity.
    /// For more configuration options, use `newWithOptions`.
    public func new(node_capacity : ?Nat) : MemoryBTree {
        let options : ?BTreeOptions = switch (node_capacity) {
            case (?cap) ?{ node_capacity = ?cap; enable_tail_compression = null; merge_strategy = null; merge_threshold = null };
            case (null) null;
        };
        _new_with_options(options, false);
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
            // New configuration fields (v1.0.0)
            ENABLE_TAIL_COMPRESSION_ADDRESS = 36; // 1 byte (0 = false, 1 = true)
            MERGE_STRATEGY_ADDRESS = 37; // 1 byte (0 = Conservative, 1 = Balanced)
            MERGE_THRESHOLD_ADDRESS = 38; // 8 bytes (Float stored as Nat64 bits)
            // Total: 46 bytes used, 18 bytes reserved for future use

            // values
            MAGIC : Blob = "BTR";
            LAYOUT_VERSION : Nat8 = 1; // Updated to version 1 for new fields
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
        // Store new configuration fields
        MemoryRegion.storeNat8(btree.data, MC.DATA.ENABLE_TAIL_COMPRESSION_ADDRESS, if (btree.enable_tail_compression) 1 else 0);
        MemoryRegion.storeNat8(btree.data, MC.DATA.MERGE_STRATEGY_ADDRESS, switch (btree.merge_strategy) { case (#Conservative) 0; case (#Balanced) 1 });
        MemoryRegion.storeNat64(btree.data, MC.DATA.MERGE_THRESHOLD_ADDRESS, Float.toInt64(btree.merge_threshold) |> Int64.toNat64(_));
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

    /// The total number of pages allocated to the BTree.
    public func allocatedPages(btree : MemoryBTree) : Nat {
        MemoryRegion.pages(btree.data) +
        MemoryRegion.pages(btree.values) +
        MemoryRegion.pages(btree.leaves) +
        MemoryRegion.pages(btree.branches);
    };

    /// The total number of bytes available from the allocated pages.
    public func allocatedBytes(btree : MemoryBTree) : Nat {
        MemoryRegion.capacity(btree.data) +
        MemoryRegion.capacity(btree.values) +
        MemoryRegion.capacity(btree.leaves) +
        MemoryRegion.capacity(btree.branches);
    };

    /// These are the bytes currently in use by the BTree.
    public func usedBytes(btree : MemoryBTree) : Nat {
        MemoryRegion.allocated(btree.data) +
        MemoryRegion.allocated(btree.values) +
        MemoryRegion.allocated(btree.leaves) +
        MemoryRegion.allocated(btree.branches);
    };

    /// The number of bytes that are not used by the BTree.
    public func freeBytes(btree : MemoryBTree) : Nat {
        allocatedBytes(btree) - usedBytes(btree);
    };

    /// The total bytes used for storing the btree's data (keys and values).
    public func dataBytes(btree : MemoryBTree) : Nat {
        MemoryRegion.allocated(btree.data) +
        MemoryRegion.allocated(btree.values);
    };

    /// The total bytes used for storing the btree's metadata (internal nodes: branches and leaves).
    public func metadataBytes(btree : MemoryBTree) : Nat {
        MemoryRegion.allocated(btree.leaves) +
        MemoryRegion.allocated(btree.branches);
    };

    public func leafBytes(btree : MemoryBTree) : Nat {
        MemoryRegion.allocated(btree.leaves);
    };

    public func branchBytes(btree : MemoryBTree) : Nat {
        MemoryRegion.allocated(btree.branches);
    };

    public func keyBytes(btree : MemoryBTree) : Nat {
        MemoryRegion.allocated(btree.data);
    };

    public func valueBytes(btree : MemoryBTree) : Nat {
        MemoryRegion.allocated(btree.values);
    };

    public func leafCount(btree : MemoryBTree) : Nat { btree.leaf_count };

    public func branchCount(btree : MemoryBTree) : Nat { btree.branch_count };

    public func totalNodeCount(btree : MemoryBTree) : Nat {
        btree.branch_count + btree.leaf_count;
    };

    public func stats(btree : MemoryBTree) : MemoryBTreeStats {
        {
            allocatedPages = allocatedPages(btree);
            bytesPerPage = MemoryRegion.PAGE_SIZE;
            allocatedBytes = allocatedBytes(btree);
            usedBytes = usedBytes(btree);
            freeBytes = freeBytes(btree);
            dataBytes = dataBytes(btree);
            metadataBytes = metadataBytes(btree);
            leafBytes = leafBytes(btree);
            branchBytes = branchBytes(btree);
            keyBytes = keyBytes(btree);
            valueBytes = valueBytes(btree);
            leafCount = leafCount(btree);
            branchCount = branchCount(btree);
            totalNodeCount = totalNodeCount(btree);
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
        var right_node_address = Leaf.split_with_options(btree, left_node_address, elem_index, kv_address, btree.enable_tail_compression, btree.merge_threshold);
        update_leaf_count(btree, btree.leaf_count + 1);
        // Debug.print("left leaf after split: " # debug_show Leaf.from_memory(btree, left_node_address));
        // Debug.print("right leaf after split: " # debug_show Leaf.from_memory(btree, right_node_address));

        var opt_parent = Leaf.get_parent(btree, right_node_address);
        var right_index = Leaf.get_index(btree, right_node_address);

        // Get the separator key using tail compression if enabled
        let ?right_node_first_key = Leaf.get_key_blob(btree, right_node_address, 0) else Debug.trap("insert: right_node_first_key accessed a null value");
        let separator_key = if (btree.enable_tail_compression) {
            let left_node_count = Leaf.get_count(btree, left_node_address);
            let ?left_node_last_key = Leaf.get_key_blob(btree, left_node_address, left_node_count - 1) else Debug.trap("insert: left_node_last_key accessed a null value");
            Common.get_tail_compressed_separator(left_node_last_key, right_node_first_key);
        } else {
            right_node_first_key;
        };
        var separator_key_address = MemoryBlock.Branch.store_key_blob(btree, separator_key);

        // assert Leaf.get_count(btree, left_node_address) == (btree.node_capacity / 2) + 1;
        // assert Leaf.get_count(btree, right_node_address) == (btree.node_capacity / 2);

        while (Option.isSome(opt_parent)) {

            let ?parent_address = opt_parent else Debug.trap("insert: Failed to get parent address");

            let parent_count = Branch.get_count(btree, parent_address);

            // insert right node in parent if there is enough space
            if (parent_count < btree.node_capacity) {
                // Debug.print("found branch with enough space");
                // Debug.print("parent before insert: " # debug_show Branch.from_memory(btree, parent_address));

                Branch.insert(btree, parent_address, right_index, separator_key_address, right_node_address);
                update_count(btree, btree.count + 1);

                // Debug.print("parent after insert: " # debug_show Branch.from_memory(btree, parent_address));

                return null;
            };

            // otherwise split parent
            left_node_address := parent_address;
            right_node_address := Branch.split(btree, left_node_address, right_index, separator_key_address, right_node_address);
            update_branch_count(btree, btree.branch_count + 1);

            // The separator key is temporarily stored in the right node at the last position.
            // We need to move it to the left node and update the separator key address.
            let ?first_key_address = Branch.get_key_address(btree, right_node_address, btree.node_capacity - 2) else Debug.trap("4. insert: accessed a null value in first key of branch");
            Branch.set_key_address_to_null(btree, right_node_address, btree.node_capacity - 2);
            separator_key_address := first_key_address;

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

        Branch.put_key_address(btree, new_root, 0, separator_key_address);

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
        // Leaf.validate() checks that the leaf_address the specified leaf_address is valid (i.e the start of the leaf node)
        let leaf_address = MC.REGION_HEADER_SIZE;
        assert Leaf.validate(btree, leaf_address);

        // remove all key-value pairs from the leaf
        // this will also deallocate the key and value blocks
        // but not the leaf node itself
        Leaf.clear(btree, leaf_address);
        assert Leaf.validate(btree, leaf_address);

        update_root(btree, leaf_address);
        update_is_root_a_leaf(btree, true);
        update_depth(btree, 1);
        update_count(btree, 0);
        update_branch_count(btree, 0);
        update_leaf_count(btree, 1);

        // Debug.print("leaves free memory: " # debug_show MemoryRegion.getFreeMemory(btree.leaves));
        // Debug.print("leaves stats: " # debug_show MemoryRegion.memoryInfo(btree.leaves));

        let leaf_memory_size = Leaf.get_memory_size(btree.node_capacity);
        let leaf_memory_end = leaf_address + leaf_memory_size;
        let leaves_region_size = MemoryRegion.size(btree.leaves);
        // Debug.print("leaf_memory_end: " # debug_show leaf_memory_end);
        // Debug.print("leaves_region_size: " # debug_show leaves_region_size);

        MemoryRegion.deallocateRange(btree.leaves, leaf_memory_end, leaves_region_size);

        assert MemoryRegion.size(btree.leaves) == MemoryRegion.allocated(btree.leaves) + MemoryRegion.deallocated(btree.leaves);
        // Debug.print("leaves free memory: " # debug_show MemoryRegion.getFreeMemory(btree.leaves));
        // Debug.print("leaves stats: " # debug_show MemoryRegion.memoryInfo(btree.leaves));

        assert MemoryRegion.allocated(btree.leaves) == MC.REGION_HEADER_SIZE + leaf_memory_size;
        assert MemoryRegion.isAllocated(btree.leaves, 0, MC.REGION_HEADER_SIZE);
        assert MemoryRegion.isAllocated(btree.leaves, MC.REGION_HEADER_SIZE, leaf_memory_size);

        let leaves_free_memory_list = MemoryRegion.getFreeMemory(btree.leaves);
        if (leaves_free_memory_list.size() > 0) {
            assert [(leaf_memory_end, MemoryRegion.size(btree.leaves) - leaf_memory_end)] == leaves_free_memory_list;
        };

        let branches_memory_size = MemoryRegion.size(btree.branches);
        MemoryRegion.deallocateRange(btree.branches, MC.REGION_HEADER_SIZE, branches_memory_size);
        assert MemoryRegion.allocated(btree.branches) == MC.REGION_HEADER_SIZE;
        assert MemoryRegion.size(btree.branches) == MemoryRegion.allocated(btree.branches) + MemoryRegion.deallocated(btree.branches);
        let branches_free_memory_list = MemoryRegion.getFreeMemory(btree.branches);
        if (branches_free_memory_list.size() > 0) {
            assert [(MC.REGION_HEADER_SIZE, MemoryRegion.size(btree.branches) - MC.REGION_HEADER_SIZE)] == branches_free_memory_list;
        };

        let data_memory_size = MemoryRegion.size(btree.data);
        MemoryRegion.deallocateRange(btree.data, MC.REGION_HEADER_SIZE, data_memory_size);
        assert MemoryRegion.allocated(btree.data) == MC.REGION_HEADER_SIZE;
        assert MemoryRegion.size(btree.data) == MemoryRegion.allocated(btree.data) + MemoryRegion.deallocated(btree.data);
        let data_free_memory_list = MemoryRegion.getFreeMemory(btree.data);
        if (data_free_memory_list.size() > 0) {
            assert [(MC.REGION_HEADER_SIZE, MemoryRegion.size(btree.data) - MC.REGION_HEADER_SIZE)] == data_free_memory_list;
        };

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

        // Update separator key if the first element was removed and the leaf is not empty
        if (elem_index == 0 and Leaf.get_count(btree, leaf_address) > 0) {
            let ?leaf_first_key = Leaf.get_key_blob(btree, leaf_address, 0) else Debug.trap("remove: leaf_first_key is null");

            // Use tail compression if enabled and there's a previous leaf
            let separator_key = if (btree.enable_tail_compression) {
                switch (Leaf.get_prev(btree, leaf_address)) {
                    case (null) leaf_first_key; // No prev leaf, use full key
                    case (?prev_leaf_address) {
                        let prev_count = Leaf.get_count(btree, prev_leaf_address);
                        let ?prev_last_key = Leaf.get_key_blob(btree, prev_leaf_address, prev_count - 1) else Debug.trap("remove: prev_last_key is null");
                        Common.get_tail_compressed_separator(prev_last_key, leaf_first_key);
                    };
                };
            } else {
                leaf_first_key;
            };
            Branch.update_separator_key(btree, parent, leaf_index, separator_key);
        };

        let leaf_count = Leaf.get_count(btree, leaf_address);

        // Check if we have a neighbour to potentially merge with
        let ?neighbour = Branch.get_larger_neighbour(btree, parent, leaf_index) else return ?prev_val;
        let neighbour_count = Leaf.get_count(btree, neighbour);
        let combined_count = leaf_count + neighbour_count;

        // Calculate merge threshold based on btree.merge_threshold
        let merge_threshold_count = Float.toInt(Float.fromInt(btree.node_capacity) * btree.merge_threshold) |> Int.abs(_);

        let current_is_empty = leaf_count == 0;
        let current_below_threshold = leaf_count < merge_threshold_count;
        let neighbour_below_threshold = neighbour_count < merge_threshold_count;
        let combined_fits = combined_count <= btree.node_capacity;

        // Determine if merge should occur based on selected strategy
        // IMPORTANT: Always check combined_fits to prevent node overflow
        let should_merge = switch (btree.merge_strategy) {
            case (#Conservative) {
                // Conservative merge: only merge when BOTH nodes are below threshold AND combined fits
                // This minimizes merges and keeps separator keys stable
                // Empty nodes are always cleaned up (neighbour is guaranteed to fit)
                current_is_empty or (current_below_threshold and neighbour_below_threshold and combined_fits);
            };
            case (#Balanced) {
                // Balanced merge: merge when EITHER node is below threshold AND combined fits
                // This provides better memory efficiency by proactively cleaning up sparse nodes
                current_is_empty or (current_below_threshold and combined_fits) or (neighbour_below_threshold and combined_fits);
            };
        };

        if (not should_merge) return ?prev_val;

        let neighbour_index = Leaf.get_index(btree, neighbour);

        let left = if (leaf_index < neighbour_index) { leaf_address } else {
            neighbour;
        };
        let right = if (leaf_index < neighbour_index) { neighbour } else {
            leaf_address;
        };
        //
        let left_index = if (leaf_index < neighbour_index) { leaf_index } else {
            neighbour_index;
        };
        let right_index = if (leaf_index < neighbour_index) { neighbour_index } else {
            leaf_index;
        };

        // Track if left was empty before merge - we'll need to update its separator key
        let left_was_empty = Leaf.get_count(btree, left) == 0;

        // remove merged leaf from parent
        // Debug.print("remove merged index: " # debug_show right_index # ", address: " # debug_show right);
        // Debug.print("parent: " # debug_show Branch.from_memory(btree, parent));

        // merge leaf with neighbour
        Leaf.merge(btree, left, right);
        let removed_key_address = Branch.remove(btree, parent, right_index);

        // Deallocate the key that was separating the merged leaves
        MemoryBlock.Branch.remove_key_blob(btree, removed_key_address);

        // If left was empty before merge, its separator key now points to deallocated memory.
        // Update the separator key to point to the new first key (which came from right).
        // Note: We must use update_separator_key (not update_separator_key_address) because
        // branch keys are stored independently with a different memory layout than leaf kv entries.
        if (left_was_empty) {
            let ?new_first_key_blob = Leaf.get_key_blob(btree, left, 0) else Debug.trap("remove: new_first_key_blob is null after merge");

            // Use tail compression if enabled and there's a previous leaf
            let separator_key = if (btree.enable_tail_compression) {
                switch (Leaf.get_prev(btree, left)) {
                    case (null) new_first_key_blob; // No prev leaf, use full key
                    case (?prev_leaf_address) {
                        let prev_count = Leaf.get_count(btree, prev_leaf_address);
                        let ?prev_last_key = Leaf.get_key_blob(btree, prev_leaf_address, prev_count - 1) else Debug.trap("remove: prev_last_key is null after merge");
                        Common.get_tail_compressed_separator(prev_last_key, new_first_key_blob);
                    };
                };
            } else {
                new_first_key_blob;
            };
            Branch.update_separator_key(btree, parent, left_index, separator_key);
        };

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

                Branch.deallocate(btree, parent);
                update_branch_count(btree, btree.branch_count - 1);

                return ?prev_val;

            } else {
                return ?prev_val;
            };
        };

        var branch = parent;
        let ?branch_parent = Branch.get_parent(btree, branch) else return set_only_child_to_root(parent);

        parent := branch_parent;

        label branch_merge_loop while (true) {
            let branch_count = Branch.get_count(btree, branch);
            let branch_index = Branch.get_index(btree, branch);
            let ?neighbour = Branch.get_larger_neighbour(btree, parent, branch_index) else return set_only_child_to_root(parent);

            let neighbour_count = Branch.get_count(btree, neighbour);
            let combined_count = branch_count + neighbour_count;

            // Calculate merge threshold based on btree.merge_threshold
            let merge_threshold_count = Float.toInt(Float.fromInt(btree.node_capacity) * btree.merge_threshold) |> Int.abs(_);

            let current_is_empty = branch_count == 0;
            let current_below_threshold = branch_count < merge_threshold_count;
            let neighbour_below_threshold = neighbour_count < merge_threshold_count;
            let combined_fits = combined_count <= btree.node_capacity;

            // Determine if merge should occur based on selected strategy (same logic as leaves)
            // IMPORTANT: Always check combined_fits to prevent node overflow
            let should_merge = switch (btree.merge_strategy) {
                case (#Conservative) {
                    // Conservative merge: only merge when BOTH nodes are below threshold AND combined fits
                    current_is_empty or (current_below_threshold and neighbour_below_threshold and combined_fits);
                };
                case (#Balanced) {
                    // Balanced merge: merge when EITHER node is below threshold AND combined fits
                    current_is_empty or (current_below_threshold and combined_fits) or (neighbour_below_threshold and combined_fits);
                };
            };

            if (not should_merge) return ?prev_val;

            // Track if left branch is empty before merge (need to update its separator key after)
            let neighbour_index = Branch.get_index(btree, neighbour);
            let left_index = if (neighbour_index < branch_index) neighbour_index else branch_index;
            let left_branch = if (neighbour_index < branch_index) neighbour else branch;
            let left_branch_count = Branch.get_count(btree, left_branch);
            let left_branch_was_empty = left_branch_count == 0;

            let merged_branch = Branch.merge(btree, branch, neighbour);
            let merged_branch_index = Branch.get_index(btree, merged_branch);
            let removed_key_address = Branch.remove(btree, parent, merged_branch_index);

            // The separator key is transferred to the merged branch during merge,
            // so it should not be deallocated here
            // MemoryBlock.Branch.remove_key_blob(btree, removed_key_address);

            // If left branch was empty before merge, its separator key points to invalid memory.
            // Update it to point to the first key of the merged subtree (from the first leaf).
            // Note: We must use update_separator_key (not update_separator_key_address) because
            // branch keys are stored independently with a different memory layout than leaf kv entries.
            if (left_branch_was_empty) {
                // Get first leaf in the merged branch to find the first key
                var first_child = left_branch;
                var has_leaves = Branch.has_leaves(btree, left_branch);
                while (not has_leaves) {
                    let ?child = Branch.get_child(btree, first_child, 0) else Debug.trap("branch merge: first child is null");
                    first_child := child;
                    has_leaves := Branch.has_leaves(btree, first_child);
                };
                // first_child is now a branch with leaves
                let ?first_leaf = Branch.get_child(btree, first_child, 0) else Debug.trap("branch merge: first leaf is null");
                let ?first_key_blob = Leaf.get_key_blob(btree, first_leaf, 0) else Debug.trap("branch merge: first key is null");
                Branch.update_separator_key(btree, parent, left_index, first_key_blob);
            };

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

    func process_range_request<ReturnValue>(
        btree : MemoryBTree,
        start : Nat,
        end : Nat,
        kv_address_to_result_mapper : (Address) -> ReturnValue,
    ) : RevIter<ReturnValue> {

        let (start_node, start_node_index) = Methods.get_leaf_node_by_index(btree, start);
        let (end_node, end_node_index) = Methods.get_leaf_node_by_index(btree, end);

        let start_index = start_node_index : Nat;
        let end_index = end_node_index : Nat;

        RevIter.map<Address, ReturnValue>(
            Methods.new_kv_block_address_iterator(btree, start_node, start_index, end_node, end_index),
            kv_address_to_result_mapper,
        );
    };

    public func range<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, start : Nat, end : Nat) : RevIter<(K, V)> {
        process_range_request<(K, V)>(
            btree,
            start,
            end,
            func(kv_address : Address) : (K, V) {
                let key_blob = MemoryBlock.get_key_blob(btree, kv_address);
                let val_blob = MemoryBlock.get_val_blob(btree, kv_address);
                Methods.deserialize_kv_blobs<K, V>(btree_utils, key_blob, val_blob);
            },
        );
    };

    public func rangeKeys<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, start : Nat, end : Nat) : RevIter<K> {

        process_range_request(
            btree,
            start,
            end,
            func(kv_address : Address) : K {
                let key_blob = MemoryBlock.get_key_blob(btree, kv_address);
                btree_utils.key.blobify.from_blob(key_blob);
            },
        );

    };

    public func rangeVals<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, start : Nat, end : Nat) : RevIter<V> {
        process_range_request(
            btree,
            start,
            end,
            func(kv_address : Address) : V {
                let val_blob = MemoryBlock.get_val_blob(btree, kv_address);
                btree_utils.value.blobify.from_blob(val_blob);
            },
        );
    };

    public func getInterval<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, start : ?K, end : ?K) : (Nat, Nat) {
        let start_rank = switch (start) {
            case (?key) switch (getExpectedIndex(btree, btree_utils, key)) {
                case (#Found(index)) index;
                case (#NotFound(index)) index;
            };
            case (null) 0;
        };

        let end_rank = switch (end) {
            case (?key) switch (getExpectedIndex(btree, btree_utils, key)) {
                case (#Found(index)) index + 1; // +1 because the end is exclusive
                case (#NotFound(index)) index + 1; // +1 because the end is exclusive
            };
            case (null) btree.count;
        };

        (start_rank, end_rank);
    };

    func process_scan_request<K, V, ReturnValue>(
        btree : MemoryBTree,
        btree_utils : BTreeUtils<K, V>,
        start : ?K,
        end : ?K,
        kv_address_to_result_mapper : (Address) -> ReturnValue,
    ) : RevIter<ReturnValue> {

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

        RevIter.map<Address, ReturnValue>(
            Methods.new_kv_block_address_iterator(btree, start_address, i, end_address, j),
            kv_address_to_result_mapper,
        );

    };

    public func scan<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, start : ?K, end : ?K) : RevIter<(K, V)> {
        process_scan_request<K, V, (K, V)>(
            btree,
            btree_utils,
            start,
            end,
            func(kv_block_address : Address) : (K, V) {
                let key_blob = MemoryBlock.get_key_blob(btree, kv_block_address);
                let val_blob = MemoryBlock.get_val_blob(btree, kv_block_address);

                Methods.deserialize_kv_blobs<K, V>(btree_utils, key_blob, val_blob);
            },
        );
    };

    public func scanKeys<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, start : ?K, end : ?K) : RevIter<K> {
        process_scan_request<K, V, K>(
            btree,
            btree_utils,
            start,
            end,
            func(kv_block_address : Address) : K {
                let key_blob = MemoryBlock.get_key_blob(btree, kv_block_address);
                btree_utils.key.blobify.from_blob(key_blob);
            },
        );
    };

    public func scanVals<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, start : ?K, end : ?K) : RevIter<V> {
        process_scan_request<K, V, V>(
            btree,
            btree_utils,
            start,
            end,
            func(kv_block_address : Address) : V {
                let val_blob = MemoryBlock.get_val_blob(btree, kv_block_address);
                btree_utils.value.blobify.from_blob(val_blob);
            },
        );
    };
};
