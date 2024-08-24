/// Branch Node Operations

import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat16 "mo:base/Nat16";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";
import Bool "mo:base/Bool";
import Float "mo:base/Float";

import MemoryRegion "mo:memory-region/MemoryRegion";
import RevIter "mo:itertools/RevIter";
// import Branch "mo:augmented-btrees/BpTree/Branch";

import MemoryFns "MemoryFns";
import T "Types";
import Leaf "Leaf";
import MemoryBlock "MemoryBlock";
import Migrations "../Migrations";

module Branch {

    type MemoryRegion = MemoryRegion.MemoryRegion;
    type RevIter<A> = RevIter.RevIter<A>;
    type BTreeUtils<K, V> = T.BTreeUtils<K, V>;
    type MemoryBTree = Migrations.MemoryBTree;
    type MemoryBlock = T.MemoryBlock;
    type Address = T.Address;
    type NodeType = T.NodeType;
    type UniqueId = T.UniqueId;

    public type Branch = Migrations.Branch;

    // access constants
    public let AC = {
        ADDRESS = 0;
        INDEX = 1;
        COUNT = 2;
        SUBTREE_SIZE = 3;

        PARENT = 0;
    };

    // memory constants
    public let MC = {
        HEADER_SIZE = 64;
        MAGIC_START = 0;
        MAGIC_SIZE = 3;

        DEPTH_START = 3;
        DEPTH_SIZE = 1;

        INDEX_START = 4;
        INDEX_SIZE = 2;

        COUNT_START = 6;
        COUNT_SIZE = 2;

        SUBTREE_COUNT_START = 8;
        SUBTREE_COUNT_SIZE = 8;

        PARENT_START = 16;
        ADDRESS_SIZE = 8;

        KEYS_START = 64;

        NULL_ADDRESS : Nat64 = 0x00;

        MAGIC : Blob = "BND";
        LAYOUT_VERSION : Nat8 = 0;
        NODE_TYPE : Nat8 = 0x00; // branch node
    };

    public func get_memory_size(node_capacity : Nat) : Nat {
        let bytes_per_node = MC.HEADER_SIZE + (Branch.MC.ADDRESS_SIZE * node_capacity - 1) // key pointers
        + (Branch.MC.ADDRESS_SIZE * node_capacity); // children nodes

        bytes_per_node;
    };

    public func CHILDREN_START(btree : MemoryBTree) : Nat {
        MC.KEYS_START + ((btree.node_capacity - 1) * MC.ADDRESS_SIZE);
    };

    public func get_node_key_offset(branch_address : Nat, i : Nat) : Nat {
        branch_address + MC.KEYS_START + (i * MC.ADDRESS_SIZE);
    };

    public func get_child_offset(btree : MemoryBTree, branch_address : Nat, i : Nat) : Nat {
        branch_address + CHILDREN_START(btree) + (i * MC.ADDRESS_SIZE);
    };

    public func new(btree : MemoryBTree) : Nat {
        let bytes_per_node = Branch.get_memory_size(btree.node_capacity);

        let branch_address = MemoryRegion.allocate(btree.branches, bytes_per_node);

        MemoryRegion.storeBlob(btree.branches, branch_address, MC.MAGIC);
        MemoryRegion.storeNat8(btree.branches, branch_address + MC.DEPTH_START, 0);
        // MemoryRegion.storeNat8(btree.branches, branch_address + MC.LAYOUT_VERSION_START, MC.LAYOUT_VERSION);

        MemoryRegion.storeNat16(btree.branches, branch_address + MC.INDEX_START, 0);
        MemoryRegion.storeNat16(btree.branches, branch_address + MC.COUNT_START, 0);
        MemoryRegion.storeNat64(btree.branches, branch_address + MC.SUBTREE_COUNT_START, 0);

        MemoryRegion.storeNat64(btree.branches, branch_address + MC.PARENT_START, MC.NULL_ADDRESS);

        var i = 0;

        while (i < (btree.node_capacity - 1 : Nat)) {
            let key_offset = get_node_key_offset(branch_address, i);
            MemoryRegion.storeNat64(btree.branches, key_offset, MC.NULL_ADDRESS);
            i += 1;
        };

        i := 0;

        while (i < btree.node_capacity) {
            let child_offset = get_child_offset(btree, branch_address, i);
            MemoryRegion.storeNat64(btree.branches, child_offset, MC.NULL_ADDRESS);
            i += 1;
        };

        branch_address;
    };

    public func from_memory(btree : MemoryBTree, branch_address : Address) : Branch {

        let branch : Branch = (
            [var 0, 0, 0, 0],
            [var null, null, null],
            Array.init(btree.node_capacity, null), // - 1
            Array.init(btree.node_capacity, null),
            Array.init(btree.node_capacity, null),
            Array.init<?Nat>(btree.node_capacity, null),
            Array.init(btree.node_capacity, null),
        );

        from_memory_into(btree, branch_address, branch, true);

        branch;
    };

    func from_memory_into(btree : MemoryBTree, address : Address, branch : Branch, load_keys : Bool) {
        assert MemoryRegion.loadBlob(btree.branches, address, MC.MAGIC_SIZE) == MC.MAGIC;
        // assert MemoryRegion.loadNat8(btree.branches, address + MC.LAYOUT_VERSION_START) == MC.LAYOUT_VERSION;
        // assert MemoryRegion.loadNat8(btree.branches, address + MC.DEPTH_START) == MC.DEPTH;

        branch.0 [AC.ADDRESS] := address;
        branch.0 [AC.INDEX] := MemoryRegion.loadNat16(btree.branches, address + MC.INDEX_START) |> Nat16.toNat(_);
        branch.0 [AC.COUNT] := MemoryRegion.loadNat16(btree.branches, address + MC.COUNT_START) |> Nat16.toNat(_);
        branch.0 [AC.SUBTREE_SIZE] := MemoryRegion.loadNat64(btree.branches, address + MC.SUBTREE_COUNT_START) |> Nat64.toNat(_);

        branch.1 [AC.PARENT] := do {
            let p = MemoryRegion.loadNat64(btree.branches, address + MC.PARENT_START);
            if (p == MC.NULL_ADDRESS) null else ?Nat64.toNat(p);
        };

        var i = 0;

        label while_loop while (i + 1 < btree.node_capacity) {

            if (not load_keys) {
                branch.2 [i] := null;
                branch.6 [i] := null;
                i += 1;
                continue while_loop;
            };

            let key_address_offset = get_node_key_offset(address, i);
            let key_address = MemoryRegion.loadNat64(btree.branches, key_address_offset) |> Nat64.toNat(_);

            if (key_address == Nat64.toNat(MC.NULL_ADDRESS)) {
                branch.2 [i] := null;
                branch.6 [i] := null;
                i += 1;
                continue while_loop;
            };

            let key_block = MemoryBlock.get_key_block(btree, key_address);
            let key_blob = MemoryBlock.get_key_blob(btree, key_address);

            branch.2 [i] := ?key_block;
            branch.6 [i] := ?key_blob;
            i += 1;
        };

        // while (i + 1 < btree.node_capacity){
        //     branch.2 [i] := null;
        //     branch.6 [i] := null;
        //     i+=1;
        // };

        i := 0;

        label while_loop2 while (i < btree.node_capacity) {
            let child_offset = get_child_offset(btree, address, i);

            let child_address = MemoryRegion.loadNat64(btree.branches, child_offset);

            if (child_address == MC.NULL_ADDRESS) {
                branch.5 [i] := null;
                i += 1;
                continue while_loop2;
            };

            branch.5 [i] := ?Nat64.toNat(child_address);
            i += 1;
        };

        // while (i < btree.node_capacity){
        //     branch.5 [i] := null;
        //     i+=1;
        // };

        // i := 0;
        // while (i < btree.node_capacity){
        //     branch.3 [i] := null;
        //     branch.4 [i] := null;
        //     i+=1;
        // };

    };

    // func calc_heuristic(btree : MemoryBTree) : Float {
    //     let cache_capacity = Float.fromInt(LruCache.capacity(btree.nodes_cache));
    //     let cache_size = Float.fromInt(LruCache.size(btree.nodes_cache));
    //     let branch_count = Float.fromInt(btree.branch_count);

    //     let space_left = cache_capacity - cache_size;
    //     let branch_nodes_not_in_cache = branch_count - cache_size;

    //     var heuristic : Float = 0;

    //     if (space_left == 0) return 1;
    //     if (cache_capacity >= branch_count) return 10;
    //     if ((cache_capacity * 1.5) >= branch_count) return 2;

    //     heuristic := 10 - (((branch_nodes_not_in_cache - space_left / space_left) * 1.5)) % 8;

    //     return 10 - heuristic;
    // };

    // public func add_to_cache(btree : MemoryBTree, address : Nat) {
    //     if (LruCache.capacity(btree.nodes_cache) == 0) return;

    //     switch (LruCache.get(btree.nodes_cache, nhash, address)) {
    //         case (? #branch(_)) return;
    //         case (? #leaf(_)) Debug.trap("Branch.add_to_cache(): Expected a branch, got a leaf");
    //         case (_) {};
    //     };

    //     let heuristic = calc_heuristic(btree);
    //     if (Float.fromInt(address % 10) >= heuristic) return;

    //     let branch : Branch = if (LruCache.size(btree.nodes_cache) == LruCache.capacity(btree.nodes_cache)) {
    //         let ?prev_address = LruCache.lastKey(btree.nodes_cache) else Debug.trap("Leaf.add_to_cache: last is null");
    //         let ? #leaf(node) or ? #branch(node) = LruCache.peek(btree.nodes_cache, nhash, prev_address) else Debug.trap("Leaf.add_to_cache: leaf is null");
    //         from_memory_into(btree, address, node, true);
    //         node;
    //     } else {
    //         // loads from stable memory and adds to cache
    //         Branch.from_memory(btree, address);
    //     };

    //     // let branch = Branch.from_memory(btree, address);
    //     LruCache.put(btree.nodes_cache, nhash, address, #branch(branch));
    // };

    // public func rm_from_cache(btree : MemoryBTree, address : Address) {
    //     if (LruCache.capacity(btree.nodes_cache) == 0) return;
    //     ignore LruCache.remove(btree.nodes_cache, nhash, address);
    // };

    public func display(btree : MemoryBTree, btree_utils : BTreeUtils<Nat, Nat>, branch_address : Nat) {
        // let branch = Branch.from_memory(btree, branch_address);

        // Debug.print(
        //     "Branch -> " # debug_show (
        //         branch.0,
        //         branch.1,
        //         Array.map(
        //             Array.freeze(branch.2),
        //             func(key_block : ?MemoryBlock) : ?Nat {
        //                 switch (key_block) {
        //                     case (?key_block) {
        //                         let blob = MemoryBlock.get_key(btree, key_block);
        //                         let key = btree_utils.key.blobify.from_blob(MemoryBlock.get_key(btree, key_block));
        //                         key;

        //                     };
        //                     case (_) null;
        //                 };
        //             },
        //         ),
        //         branch.5,
        //         // branch.6
        //     )
        // );
    };

    public func update_index(btree : MemoryBTree, branch_address : Nat, new_index : Nat) {

        MemoryRegion.storeNat16(btree.branches, branch_address + MC.INDEX_START, Nat16.fromNat(new_index));
    };

    public func update_depth(btree : MemoryBTree, branch_address : Nat, new_depth : Nat) {
        MemoryRegion.storeNat8(btree.branches, branch_address + MC.DEPTH_START, Nat8.fromNat(new_depth));
    };

    public func put_key_address(btree : MemoryBTree, branch_address : Nat, i : Nat, key_address : UniqueId) {
        assert i < (btree.node_capacity - 1 : Nat);

        let offset = get_node_key_offset(branch_address, i);
        MemoryRegion.storeNat64(btree.branches, offset, Nat64.fromNat(key_address));
    };

    public func put_child(btree : MemoryBTree, branch_address : Nat, i : Nat, child_address : Nat) {
        assert i < btree.node_capacity;

        let offset = get_child_offset(btree, branch_address, i);
        MemoryRegion.storeNat64(btree.branches, offset, Nat64.fromNat(child_address));

        let branch_stores_leaves = Branch.has_leaves(btree, branch_address);

        switch (branch_stores_leaves) {
            case (false) {
                Branch.update_parent(btree, child_address, ?branch_address);
                Branch.update_index(btree, child_address, i);
            };
            case (true) {
                Leaf.update_parent(btree, child_address, ?branch_address);
                Leaf.update_index(btree, child_address, i);
            };
        };
    };

    // public func get_node_subtree_size(btree : MemoryBTree, node_address : Address) : Nat {
    //     switch (Branch.get_node_type(btree, node_address)) {
    //         case (#branch) {
    //             Branch.get_subtree_size(btree, node_address);
    //         };
    //         case (#leaf) {
    //             Leaf.get_count(btree, node_address);
    //         };
    //     };
    // };

    public func add_child(btree : MemoryBTree, branch_address : Nat, child_address : Nat) {

        let count = Branch.get_count(btree, branch_address);

        assert count < btree.node_capacity;

        let branch_stores_leaves = Branch.has_leaves(btree, branch_address);

        let child_subtree_size = switch (branch_stores_leaves) {
            case (false) {
                Branch.update_parent(btree, child_address, ?branch_address);
                Branch.update_index(btree, child_address, count);
                Branch.get_subtree_size(btree, child_address);
            };
            case (true) {
                Leaf.update_parent(btree, child_address, ?branch_address);
                Leaf.update_index(btree, child_address, count);
                Leaf.get_count(btree, child_address);
            };
        };

        let offset = get_child_offset(btree, branch_address, count);
        MemoryRegion.storeNat64(btree.branches, offset, Nat64.fromNat(child_address));

        let prev_subtree_size = Branch.get_subtree_size(btree, branch_address);
        Branch.update_subtree_size(btree, branch_address, prev_subtree_size + child_subtree_size);
        Branch.update_count(btree, branch_address, count + 1);
    };

    public func get_magic(btree : MemoryBTree, node_address : Nat) : Blob {
        MemoryRegion.loadBlob(btree.branches, node_address, MC.MAGIC_SIZE);
    };

    public func get_depth(btree : MemoryBTree, node_address : Nat) : Nat {
        let depth = MemoryRegion.loadNat8(btree.branches, node_address + MC.DEPTH_START) |> Nat8.toNat(_);

        depth;
    };

    public func has_leaves(btree : MemoryBTree, branch_address : Nat) : Bool {
        let depth = Branch.get_depth(btree, branch_address);
        depth == 2;
    };

    public func get_node_type(btree : MemoryBTree, node_address : Nat) : NodeType {

        let leaf_magic = MemoryRegion.loadBlob(btree.leaves, node_address, MC.MAGIC_SIZE);
        let branch_magic = MemoryRegion.loadBlob(btree.branches, node_address, MC.MAGIC_SIZE);

        Debug.print("leaf_magic = " # debug_show leaf_magic);
        Debug.print("branch_magic = " # debug_show branch_magic);

        let is_leaf = leaf_magic == MC.MAGIC;
        let is_branch = branch_magic == MC.MAGIC;

        assert leaf_magic == MC.MAGIC or branch_magic == MC.MAGIC;

        if (is_leaf != is_branch) {
            if (is_leaf) return #leaf;
            if (is_branch) return #branch;
        };

        // if there is a leaf and branch at the same address

        let leaf_depth = Leaf.get_depth(btree, node_address);
        let branch_depth = Branch.get_depth(btree, node_address);
        Debug.print("leaf_depth = " # debug_show leaf_depth);
        Debug.print("branch_depth = " # debug_show branch_depth);

        let mem_depth = MemoryRegion.loadNat8(btree.branches, node_address + MC.DEPTH_START) |> Nat8.toNat(_);
        Debug.print("mem_depth = " # debug_show mem_depth);

        if (mem_depth == 1) {
            #leaf;
        } else {
            #branch;
        };

    };

    public func get_count(btree : MemoryBTree, branch_address : Nat) : Nat {

        MemoryRegion.loadNat16(btree.branches, branch_address + MC.COUNT_START) |> Nat16.toNat(_);
    };

    public func get_index(btree : MemoryBTree, branch_address : Nat) : Nat {

        MemoryRegion.loadNat16(btree.branches, branch_address + MC.INDEX_START) |> Nat16.toNat(_);
    };

    public func get_parent(btree : MemoryBTree, branch_address : Nat) : ?Nat {

        let parent = MemoryRegion.loadNat64(btree.branches, branch_address + MC.PARENT_START);
        if (parent == MC.NULL_ADDRESS) null else ?Nat64.toNat(parent);
    };

    public func get_key_address(btree : MemoryBTree, branch_address : Nat, i : Nat) : ?UniqueId {
        let key_offset = get_node_key_offset(branch_address, i);
        let key_address = MemoryRegion.loadNat64(btree.branches, key_offset);

        if (key_address == MC.NULL_ADDRESS) return null;

        ?Nat64.toNat(key_address);
    };

    public func get_key_blob(btree : MemoryBTree, branch_address : Nat, i : Nat) : ?(Blob) {

        let ?kv_address = Branch.get_key_address(btree, branch_address, i) else return null;
        ?MemoryBlock.get_key_blob(btree, kv_address);
    };

    public func set_key_address_to_null(btree : MemoryBTree, branch_address : Nat, i : Nat) {

        let key_offset = get_node_key_offset(branch_address, i);
        MemoryRegion.storeNat64(btree.branches, key_offset, MC.NULL_ADDRESS);
    };

    public func get_child(btree : MemoryBTree, branch_address : Nat, i : Nat) : ?Nat {

        MemoryRegion.loadNat64(btree.branches, get_child_offset(btree, branch_address, i))
        |> ?Nat64.toNat(_);
    };

    public func set_child_to_null(btree : MemoryBTree, branch_address : Nat, i : Nat) {

        MemoryRegion.storeNat64(btree.branches, get_child_offset(btree, branch_address, i), MC.NULL_ADDRESS);
    };

    public func get_subtree_size(btree : MemoryBTree, branch_address : Nat) : Nat {

        MemoryRegion.loadNat64(btree.branches, branch_address + MC.SUBTREE_COUNT_START) |> Nat64.toNat(_);
    };

    public func binary_search<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, address : Nat, cmp : (K, K) -> Int8, search_key : K, arr_len : Nat) : Int {
        if (arr_len == 0) return -1; // should insert at index Int.abs(i + 1)
        var l = 0;

        // arr_len will always be between 4 and 512
        var r = arr_len - 1 : Nat;

        while (l < r) {
            let mid = (l + r) / 2;

            let ?key_blob = Branch.get_key_blob(btree, address, mid) else Debug.trap("1. binary_search_blob_seq: accessed a null value");
            let key = btree_utils.key.blobify.from_blob(key_blob);

            let result = cmp(search_key, key);

            if (result == -1) {
                r := mid;

            } else if (result == 1) {
                l := mid + 1;
            } else {
                return mid;
            };
        };

        let insertion = l;

        // Check if the insertion point is valid
        // return the insertion point but negative and subtracting 1 indicating that the key was not found
        // such that the insertion index for the key is Int.abs(insertion) - 1
        // [0,  1,  2]
        //  |   |   |
        // -1, -2, -3
        switch (Branch.get_key_blob(btree, address, insertion)) {
            case (?(key_blob)) {
                let key = btree_utils.key.blobify.from_blob(key_blob);
                let result = cmp(search_key, key);

                if (result == 0) insertion else if (result == -1) -(insertion + 1) else -(insertion + 2);
            };
            case (_) {
                Debug.print("insertion = " # debug_show insertion);
                Debug.print("arr_len = " # debug_show arr_len);
                // Debug.print(
                //     "arr = " # debug_show Array.freeze(get_keys(btree, address))
                // );
                Debug.trap("2. binary_search: accessed a null value");
            };
        };
    };

    public func binary_search_blob_seq(btree : MemoryBTree, address : Nat, cmp : (Blob, Blob) -> Int8, search_key : Blob, arr_len : Nat) : Int {
        if (arr_len == 0) return -1; // should insert at index Int.abs(i + 1)
        var l = 0;

        // arr_len will always be between 4 and 512
        var r = arr_len - 1 : Nat;

        while (l < r) {
            let mid = (l + r) / 2;

            let ?key_blob = Branch.get_key_blob(btree, address, mid) else Debug.trap("1. binary_search_blob_seq: accessed a null value");
            let result = cmp(search_key, key_blob);

            if (result == -1) {
                r := mid;

            } else if (result == 1) {
                l := mid + 1;
            } else {
                return mid;
            };
        };

        let insertion = l;

        // Check if the insertion point is valid
        // return the insertion point but negative and subtracting 1 indicating that the key was not found
        // such that the insertion index for the key is Int.abs(insertion) - 1
        // [0,  1,  2]
        //  |   |   |
        // -1, -2, -3
        switch (Branch.get_key_blob(btree, address, insertion)) {
            case (?(key_blob)) {
                let result = cmp(search_key, key_blob);

                if (result == 0) insertion else if (result == -1) -(insertion + 1) else -(insertion + 2);
            };
            case (_) {
                Debug.print("insertion = " # debug_show insertion);
                Debug.print("arr_len = " # debug_show arr_len);
                // Debug.print(
                //     "arr = " # debug_show Array.freeze(get_keys(btree, address))
                // );
                Debug.trap("2. binary_search_blob_seq: accessed a null value");
            };
        };
    };

    public func update_count(btree : MemoryBTree, branch_address : Nat, count : Nat) {

        MemoryRegion.storeNat16(btree.branches, branch_address + MC.COUNT_START, Nat16.fromNat(count));
    };

    public func update_subtree_size(btree : MemoryBTree, branch_address : Nat, new_size : Nat) {

        MemoryRegion.storeNat64(btree.branches, branch_address + MC.SUBTREE_COUNT_START, Nat64.fromNat(new_size));
    };

    public func update_parent(btree : MemoryBTree, branch_address : Nat, opt_parent : ?Nat) {

        let parent = switch (opt_parent) {
            case (null) MC.NULL_ADDRESS;
            case (?_parent) Nat64.fromNat(_parent);
        };

        MemoryRegion.storeNat64(btree.branches, branch_address + MC.PARENT_START, parent);
    };

    public func update_median_key_address(btree : MemoryBTree, parent_address : Nat, child_index : Nat, new_key_address : UniqueId) {
        var curr_address = parent_address;
        var i = child_index;

        while (i == 0) {
            i := Branch.get_index(btree, curr_address);
            let ?parent_address = Branch.get_parent(btree, curr_address) else return; // occurs when key is the first key in the tree
            curr_address := parent_address;
        };

        Branch.put_key_address(btree, curr_address, i - 1, new_key_address);
    };

    // inserts node but does not update the subtree size with the node's subtree size
    // because it's likely that the inserted node is a node split from a node
    // in this branch's subtree

    public func insert(btree : MemoryBTree, branch_address : Nat, i : Nat, key_address : UniqueId, child_address : Nat) {
        let count = Branch.get_count(btree, branch_address);

        assert count < btree.node_capacity;
        assert i <= count;

        // shift keys and children
        do {
            if (i == 0) {
                // elements inserted are always nodes created as a result of split
                // so their index is always greater than one as new nodes created from
                // a split operation are always inserted at the right
                // update_median_key_address(btree, branch, i, key);
                // Debug.trap("Branch.insert(): inserting at index 0 is not allowed");
            } else {
                let key_offset = get_node_key_offset(branch_address, i - 1);
                let key_end_boundary = get_node_key_offset(branch_address, count - 1);

                MemoryFns.shift(btree.branches.region, key_offset, key_end_boundary, MC.ADDRESS_SIZE);
                MemoryRegion.storeNat64(btree.branches, key_offset, Nat64.fromNat(key_address));
            };

            let child_offset = get_child_offset(btree, branch_address, i);
            let child_end_boundary = get_child_offset(btree, branch_address, count);

            MemoryFns.shift(btree.branches.region, child_offset, child_end_boundary, MC.ADDRESS_SIZE);
            MemoryRegion.storeNat64(btree.branches, child_offset, Nat64.fromNat(child_address));
        };

        // Debug.print("updating children index values");
        // update children index values
        var j = count;
        let branch_stores_leaves = Branch.has_leaves(btree, branch_address);

        label while_loop while (j >= i) {

            let ?child_address = Branch.get_child(btree, branch_address, j) else Debug.trap("Branch.insert(): child address is null");

            switch (branch_stores_leaves) {
                case ((false)) {
                    Branch.update_index(btree, child_address, j);
                    Branch.update_parent(btree, child_address, ?branch_address);
                };
                case (true) {
                    Leaf.update_index(btree, child_address, j);
                    Leaf.update_parent(btree, child_address, ?branch_address);
                };
            };

            if (j == 0) break while_loop else j -= 1;
        };

        Branch.update_count(btree, branch_address, count + 1);

    };

    public func split(btree : MemoryBTree, branch_address : Nat, child_index : Nat, child_key_address : UniqueId, child : Nat) : Nat {

        let arr_len = btree.node_capacity;
        let median = (arr_len / 2) + 1;

        let is_elem_added_to_right = child_index >= median;

        var median_key_address = ?child_key_address;

        var offset = if (is_elem_added_to_right) 0 else 1;
        var already_inserted = false;

        let right_cnt = arr_len + 1 - median : Nat;
        let right_address = Branch.new(btree);

        let depth = Branch.get_depth(btree, branch_address);
        Branch.update_depth(btree, right_address, depth);

        var i = 0;
        var elems_removed_from_left = 0;

        if (not is_elem_added_to_right) {
            let j = i + median - offset : Nat;

            median_key_address := Branch.get_key_address(btree, branch_address, j - 1);

            let start_key = get_node_key_offset(branch_address, j);
            let end_key = get_node_key_offset(branch_address, arr_len - 1);

            let new_start_key = get_node_key_offset(right_address, 0);
            let blob_slice = MemoryRegion.loadBlob(btree.branches, start_key, end_key - start_key);
            MemoryRegion.storeBlob(btree.branches, new_start_key, blob_slice);

            let start_child = get_child_offset(btree, branch_address, j);
            let end_child = get_child_offset(btree, branch_address, arr_len);

            let new_start_child = get_child_offset(btree, right_address, 0);
            let child_slice = MemoryRegion.loadBlob(btree.branches, start_child, end_child - start_child);
            MemoryRegion.storeBlob(btree.branches, new_start_child, child_slice);

            elems_removed_from_left += right_cnt;

            var children_subtrees_size = 0;
            let branch_stores_leaves = Branch.has_leaves(btree, branch_address);

            while (i < right_cnt) {
                let ?child_address = Branch.get_child(btree, right_address, i) else Debug.trap("Branch.split: accessed a null value");

                children_subtrees_size += switch (branch_stores_leaves) {
                    case (false) {
                        Branch.update_parent(btree, child_address, ?right_address);
                        Branch.update_index(btree, child_address, i);
                        Branch.get_subtree_size(btree, child_address);
                    };
                    case (true) {
                        Leaf.update_parent(btree, child_address, ?right_address);
                        Leaf.update_index(btree, child_address, i);
                        Leaf.get_count(btree, child_address);
                    };
                };

                i += 1;
            };

            Branch.update_subtree_size(btree, right_address, children_subtrees_size);
        } else while (i < right_cnt) {
            let j = i + median - offset : Nat;

            let child_node = if (j >= median and j == child_index and not already_inserted) {
                offset += 1;
                already_inserted := true;
                if (i > 0) {
                    Branch.put_key_address(btree, right_address, i - 1, child_key_address);
                };
                child;
            } else {
                if (i == 0) {
                    median_key_address := Branch.get_key_address(btree, branch_address, j - 1);
                } else {
                    let ?shifted_key_address = Branch.get_key_address(btree, branch_address, j - 1) else Debug.trap("Branch.split: accessed a null value");

                    Branch.put_key_address(btree, right_address, i - 1, shifted_key_address);
                };

                Branch.set_key_address_to_null(btree, branch_address, j - 1);

                // branch.0 [AC.COUNT] -= 1;
                elems_removed_from_left += 1;

                let ?child_address = Branch.get_child(btree, branch_address, j) else Debug.trap("Branch.split: accessed a null value");
                Branch.set_child_to_null(btree, branch_address, j);

                child_address;
            };

            Branch.add_child(btree, right_address, child_node);
            i += 1;
        };

        // remove the elements moved to the right branch from the subtree size of the left branch
        let prev_left_subtree_size = Branch.get_subtree_size(btree, branch_address);
        let right_subtree_size = Branch.get_subtree_size(btree, right_address);
        Branch.update_subtree_size(btree, branch_address, prev_left_subtree_size - right_subtree_size);

        // update the count of the left branch
        // to reflect the removed elements
        let prev_left_count = Branch.get_count(btree, branch_address);
        Branch.update_count(btree, branch_address, prev_left_count - elems_removed_from_left);

        if (not is_elem_added_to_right) {
            Branch.insert(btree, branch_address, child_index, child_key_address, child);
        };

        Branch.update_count(btree, branch_address, median);

        let branch_index = Branch.get_index(btree, branch_address);
        Branch.update_index(btree, right_address, branch_index + 1);

        Branch.update_count(btree, right_address, right_cnt);

        let branch_parent = Branch.get_parent(btree, branch_address);
        Branch.update_parent(btree, right_address, branch_parent);

        // store the first key of the right node at the end of the keys in left node
        // no need to delete as the value will get overwritten because it exceeds the count position
        let ?_median_key_address = median_key_address else Debug.trap("Branch.split: median key_block is null");
        Branch.put_key_address(btree, right_address, btree.node_capacity - 2, _median_key_address);

        right_address;
    };

    public func get_larger_neighbour(btree : MemoryBTree, parent_address : Address, index : Nat) : ?Address {

        let ?child = Branch.get_child(btree, parent_address, index) else Debug.trap("1. get_larger_neighbor: accessed a null value");
        var neighbour = child;

        let parent_count = Branch.get_count(btree, parent_address);
        let parent_has_leaves = Branch.has_leaves(btree, parent_address);

        if (parent_count > 1) {
            if (index != 0) {
                let ?left_neighbour = Branch.get_child(btree, parent_address, index - 1 : Nat) else Debug.trap("1. redistribute_leaf_keys: accessed a null value");
                neighbour := left_neighbour;
            };

            if (index != (parent_count - 1 : Nat)) {
                let ?right_neighbour = Branch.get_child(btree, parent_address, index + 1) else Debug.trap("2. redistribute_leaf_keys: accessed a null value");

                if (neighbour == child) return ?right_neighbour;

                switch (parent_has_leaves) {
                    case (false) if (Branch.get_count(btree, right_neighbour) > Branch.get_count(btree, neighbour)) {
                        return ?right_neighbour;
                    };
                    case (true) if (Leaf.get_count(btree, right_neighbour) > Leaf.get_count(btree, neighbour)) {
                        return ?right_neighbour;
                    };
                };
            };
        };

        if (neighbour == child) return null;

        return ?neighbour;
    };

    // shift keys and children in any direction indicated by the offset
    // positive offset shifts to the right, negative offset shifts to the left
    // since the keys indicates the boundaries of the children,
    // the first key is the starting boundary of the second child
    // for this reason shifting past the first key is not allowed
    // can only shift from [1.. n] where n is the number of keys
    // and the addition of the offset to the index must be >= 1
    public func shift(btree : MemoryBTree, branch : Address, start : Nat, end : Nat, offset : Int) {
        assert start + offset >= 1;

        if (offset == 0) return;

        var i = start;
        let branch_has_leaves = Branch.has_leaves(btree, branch);

        // update child indexes to future position after shift
        while (i < end) {
            let ?child = Branch.get_child(btree, branch, i) else Debug.trap("Branch.shift(): accessed a null value");

            switch (branch_has_leaves) {
                case (false) {
                    Branch.update_index(btree, child, Int.abs(i + offset));
                };
                case (true) {
                    Leaf.update_index(btree, child, Int.abs(i + offset));
                };
            };
            i += 1;
        };

        if (start != 0) {
            let key_offset = get_node_key_offset(branch, start - 1);
            let key_end_boundary = get_node_key_offset(branch, end - 1);

            let _offset = Int.max(offset, 0 - (start - 1));

            MemoryFns.shift(btree.branches.region, key_offset, key_end_boundary, offset * MC.ADDRESS_SIZE);
        } else {
            let key_offset = get_node_key_offset(branch, start);
            let key_end_boundary = get_node_key_offset(branch, end - 1);

            MemoryFns.shift(btree.branches.region, key_offset, key_end_boundary, offset * MC.ADDRESS_SIZE);
        };

        let child_offset = get_child_offset(btree, branch, start);
        let child_end_boundary = get_child_offset(btree, branch, end);

        MemoryFns.shift(btree.branches.region, child_offset, child_end_boundary, offset * MC.ADDRESS_SIZE);

    };

    // most branch removes are a result of a merge operation
    // the right node is always merged into the left node so it unlikely
    // that we would need to remove the 0th index, which will cause issues
    // because the keys hold one less value than the children array
    public func remove(btree : MemoryBTree, branch : Address, index : Nat) {
        let count = Branch.get_count(btree, branch);

        Branch.shift(btree, branch, index + 1, count, - 1);
        Branch.update_count(btree, branch, count - 1);
    };

    public func redistribute(btree : MemoryBTree, branch : Address) : Bool {
        let ?parent = Branch.get_parent(btree, branch) else Debug.trap("Branch.redistribute: parent should not be null");
        let branch_index = Branch.get_index(btree, branch);
        // Debug.print("redistribute: " # debug_show branch_index);
        let ?neighbour = Branch.get_larger_neighbour(btree, parent, branch_index) else return false;
        let branch_has_leaves = Branch.has_leaves(btree, branch);

        // Debug.print("branch_has_leaves: " # debug_show (branch, branch_has_leaves));
        // Debug.print("branch depth: " # debug_show Branch.get_depth(btree, branch));

        let neighbour_index = Branch.get_index(btree, neighbour);

        let branch_count = Branch.get_count(btree, branch);
        let neighbour_count = Branch.get_count(btree, neighbour);

        let sum_count = branch_count + neighbour_count;
        let min_count_for_both_nodes = btree.node_capacity;

        // Debug.print("branch: " # debug_show from_memory(btree, branch));
        // Debug.print("neighbour: " # debug_show from_memory(btree, neighbour));

        if (sum_count < min_count_for_both_nodes) return false;

        let data_to_move = (sum_count / 2) - branch_count : Nat;

        var moved_subtree_size = 0;

        if (neighbour_index < branch_index) {
            // Debug.print("redistribute: left neighbour");
            // move data from the left neighbour to the right branch
            let ?_median_key_address = Branch.get_key_address(btree, parent, neighbour_index) else return Debug.trap("Branch.redistribute: median_key_address should not be null");
            var median_key_address = _median_key_address;

            Branch.shift(btree, branch, 0, branch_count, data_to_move);

            var i = 0;
            while (i < data_to_move) {
                let j = neighbour_count - 1 - i : Nat;
                // Debug.print("neighbour: " # debug_show from_memory(btree, neighbour));
                let ?key_address = Branch.get_key_address(btree, neighbour, j - 1) else return Debug.trap("Branch.redistribute: key_address should not be null");
                let ?child = Branch.get_child(btree, neighbour, j) else return Debug.trap("Branch.redistribute: child should not be null");
                Branch.remove(btree, neighbour, j);

                // Debug.print("median_key_address: " # debug_show median_key_address);

                let new_index = data_to_move - i - 1 : Nat;
                Branch.put_key_address(btree, branch, new_index, median_key_address);
                Branch.put_child(btree, branch, new_index, child);

                let child_subtree_size = if (branch_has_leaves) Leaf.get_count(btree, child) else Branch.get_subtree_size(btree, child);
                moved_subtree_size += child_subtree_size;

                median_key_address := key_address;

                i += 1;
            };

            // Debug.print("parent median_key_address: " # debug_show median_key_address);
            // Debug.print("parent median_key_blob: " # debug_show median_key_blob);

            Branch.put_key_address(btree, parent, neighbour_index, median_key_address);

        } else {
            // Debug.print("redistribute: right neighbour");
            // move data from the right neighbour to the left branch

            let ?_median_key_address = Branch.get_key_address(btree, parent, branch_index) else return Debug.trap("Branch.redistribute: median_key_address should not be null");
            var median_key_address = _median_key_address;

            var i = 0;
            while (i < data_to_move) {

                // Debug.print("median_key_address: " # debug_show median_key_address);

                let ?child = Branch.get_child(btree, neighbour, i) else return Debug.trap("Branch.redistribute: child should not be null");
                Branch.insert(btree, branch, branch_count + i, median_key_address, child);

                let child_subtree_size = if (branch_has_leaves) Leaf.get_count(btree, child) else Branch.get_subtree_size(btree, child);
                moved_subtree_size += child_subtree_size;

                let ?key_block = Branch.get_key_address(btree, neighbour, i) else return Debug.trap("Branch.redistribute: key_block should not be null");
                let ?key_blob = Branch.get_key_blob(btree, neighbour, i) else return Debug.trap("Branch.redistribute: key_blob should not be null");

                median_key_address := key_block;

                i += 1;
            };

            // Debug.print("parent median_key_address: " # debug_show median_key_address);

            // shift keys and children in the right neighbour
            // since we can't shift to the first child index,
            // we will shift to the second index and insert the
            // value at the first child index manually
            let ?first_child = Branch.get_child(btree, neighbour, data_to_move) else return Debug.trap("Branch.redistribute: first_child should not be null");
            Branch.shift(btree, neighbour, data_to_move + 1, neighbour_count, -data_to_move);
            Branch.put_child(btree, neighbour, 0, first_child);

            // update median key in parent
            Branch.put_key_address(btree, parent, branch_index, median_key_address);
        };

        Branch.update_count(btree, branch, branch_count + data_to_move);
        Branch.update_count(btree, neighbour, neighbour_count - data_to_move);

        let branch_subtree_size = Branch.get_subtree_size(btree, branch);
        Branch.update_subtree_size(btree, branch, branch_subtree_size + moved_subtree_size);

        let neighbour_subtree_size = Branch.get_subtree_size(btree, neighbour);
        Branch.update_subtree_size(btree, neighbour, neighbour_subtree_size - moved_subtree_size);

        true;
    };

    public func deallocate(btree : MemoryBTree, branch : Address) {
        let memory_size = Branch.get_memory_size(btree.node_capacity);
        MemoryRegion.deallocate(btree.branches, branch, memory_size);
    };

    public func merge(btree : MemoryBTree, branch : Address, neighbour : Address) : (deallocated_branch : Address) {
        let ?parent = Branch.get_parent(btree, branch) else Debug.trap("Branch.merge: parent should not be null");
        let branch_index = Branch.get_index(btree, branch);

        let neighbour_index = Branch.get_index(btree, neighbour);

        let left = if (neighbour_index < branch_index) neighbour else branch;
        let right = if (neighbour_index < branch_index) branch else neighbour;

        // let left_index = if (neighbour_index < branch_index) neighbour_index else branch_index;
        let right_index = if (neighbour_index < branch_index) branch_index else neighbour_index;

        let left_count = Branch.get_count(btree, left);
        let right_count = Branch.get_count(btree, right);

        let left_subtree_size = Branch.get_subtree_size(btree, left);
        let right_subtree_size = Branch.get_subtree_size(btree, right);

        let ?_median_key_address = Branch.get_key_address(btree, parent, right_index - 1) else Debug.trap("Branch.merge: median_key_address should not be null");
        var median_key_address = _median_key_address;

        // Debug.print("left branch before merge: " # debug_show Branch.from_memory(btree, left));
        // Debug.print("right branch before merge: " # debug_show Branch.from_memory(btree, right));

        var i = 0;
        label while_loop while (i < right_count) {
            // Debug.print("median_key_address: " # debug_show median_key_address);
            let ?child = Branch.get_child(btree, right, i) else return Debug.trap("Branch.merge: child should not be null");
            Branch.insert(btree, left, left_count + i, median_key_address, child);

            if (i < (right_count - 1 : Nat)) {
                let ?key_block = Branch.get_key_address(btree, right, i) else return Debug.trap("Branch.merge: key_block should not be null");
                median_key_address := key_block;
            };

            i += 1;
        };

        Branch.update_count(btree, left, left_count + right_count);
        Branch.update_subtree_size(btree, left, left_subtree_size + right_subtree_size);

        // Debug.print("left branch after merge: " # debug_show Branch.from_memory(btree, left));
        // Debug.print("right branch after merge: " # debug_show Branch.from_memory(btree, right));

        // Branch.remove(btree, parent, right_index);

        right;
    };
};
