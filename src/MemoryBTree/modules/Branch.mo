/// Branch Node Operations

import Debug "mo:core@2.4/Debug";
import Runtime "mo:core@2.4/Runtime";
import Array "mo:core@2.4/Array";
import VarArray "mo:core@2.4/VarArray";
import Int "mo:core@2.4/Int";
import Nat "mo:core@2.4/Nat";
import Nat8 "mo:core@2.4/Nat8";
import Nat16 "mo:core@2.4/Nat16";
import Nat64 "mo:core@2.4/Nat64";
import Blob "mo:core@2.4/Blob";
import Bool "mo:core@2.4/Bool";
import Float "mo:core@2.4/Float";
import Option "mo:core@2.4/Option";

import MemoryRegion "mo:memory-region@1.5/MemoryRegion";
import RevIter "mo:itertools@0.2/RevIter";
// import Branch "mo:augmented-btrees/BpTree/Branch";

import MemoryFns "MemoryFns";
import T "Types";
import Leaf "Leaf";
import MemoryBlock "MemoryBlock";
import Migrations "../Migrations";
import Common "Common";

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

        PREFIX_KEY_ADDRESS_START = 24;
        PREFIX_KEY_ADDRESS_SIZE = 8;

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

        MemoryRegion.storeNat16(btree.branches, branch_address + MC.INDEX_START, 0);
        MemoryRegion.storeNat16(btree.branches, branch_address + MC.COUNT_START, 0);
        MemoryRegion.storeNat64(btree.branches, branch_address + MC.SUBTREE_COUNT_START, 0);

        MemoryRegion.storeNat64(btree.branches, branch_address + MC.PARENT_START, MC.NULL_ADDRESS);
        MemoryRegion.storeNat64(btree.branches, branch_address + MC.PREFIX_KEY_ADDRESS_START, MC.NULL_ADDRESS);

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
        // assert Branch.validate(btree, branch_address);

        let branch : Branch = (
            [var 0, 0, 0, 0],
            [var null, null, null],
            VarArray.repeat(null, btree.node_capacity), // - 1
            VarArray.repeat(null, btree.node_capacity),
            VarArray.repeat(null, btree.node_capacity),
            VarArray.repeat<?Nat>(null, btree.node_capacity),
            VarArray.repeat(null, btree.node_capacity),
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

            let key_block = MemoryBlock.Branch.get_key_block(btree, key_address);
            let key_blob = MemoryBlock.Branch.get_key_blob(btree, key_address);

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

     public func display(btree : MemoryBTree, btree_utils : BTreeUtils<Nat, Nat>, branch_address : Nat) {
        // assert Branch.validate(btree, branch_address);
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
        //                         let blob = MemoryBlock.Branch.get_key(btree, key_block);
        //                         let key = btree_utils.key.blobify.from_blob(MemoryBlock.Branch.get_key(btree, key_block));
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
        // assert Branch.validate(btree, branch_address);

        MemoryRegion.storeNat16(btree.branches, branch_address + MC.INDEX_START, Nat16.fromNat(new_index));
    };

    public func update_depth(btree : MemoryBTree, branch_address : Nat, new_depth : Nat) {
        // assert Branch.validate(btree, branch_address);
        MemoryRegion.storeNat8(btree.branches, branch_address + MC.DEPTH_START, Nat8.fromNat(new_depth));
    };

    public func put_key_address(btree : MemoryBTree, branch_address : Nat, i : Nat, key_address : UniqueId) {
        // assert Branch.validate(btree, branch_address);
        assert i < (btree.node_capacity - 1 : Nat);

        let offset = get_node_key_offset(branch_address, i);
        MemoryRegion.storeNat64(btree.branches, offset, Nat64.fromNat(key_address));
    };

    public func put_key(btree : MemoryBTree, branch_address : Nat, i : Nat, key : Blob) {
        // assert Branch.validate(btree, branch_address);
        assert i < (btree.node_capacity - 1 : Nat);

        let key_address = MemoryBlock.Branch.store_key_blob(btree, key);
        Branch.put_key_address(btree, branch_address, i, key_address);
    };

    public func replace_key(btree : MemoryBTree, branch_address : Nat, i : Nat, key : Blob) {
        // assert Branch.validate(btree, branch_address);
        assert i < (btree.node_capacity - 1 : Nat);

        let ?prev_key_address = Branch.get_key_address(btree, branch_address, i) else Runtime.trap("Branch.replace_key: accessed a null value");

        switch (MemoryBlock.Branch.replace_key_blob(btree, prev_key_address, key)) {
            case (?new_key_address) {
                Branch.put_key_address(btree, branch_address, i, new_key_address);
            };
            case (null) {
                // Key was replaced in-place, no address change needed
            };
        };

    };

    public func put_child(btree : MemoryBTree, branch_address : Nat, i : Nat, child_address : Nat) {
        // assert Branch.validate(btree, branch_address);
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
        // assert Branch.validate(btree, branch_address);

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
        // assert Branch.validate(btree, node_address);
        let depth = MemoryRegion.loadNat8(btree.branches, node_address + MC.DEPTH_START) |> Nat8.toNat(_);

        depth;
    };

    public func has_leaves(btree : MemoryBTree, branch_address : Nat) : Bool {
        // assert Branch.validate(btree, branch_address);
        let depth = Branch.get_depth(btree, branch_address);
        depth == 2;
    };

    public func get_node_type(btree : MemoryBTree, node_address : Nat) : NodeType {

        let leaf_magic = MemoryRegion.loadBlob(btree.leaves, node_address, MC.MAGIC_SIZE);
        let branch_magic = MemoryRegion.loadBlob(btree.branches, node_address, MC.MAGIC_SIZE);

        // Debug.print("leaf_magic = " # debug_show leaf_magic);
        // Debug.print("branch_magic = " # debug_show branch_magic);

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
        // Debug.print("leaf_depth = " # debug_show leaf_depth);
        // Debug.print("branch_depth = " # debug_show branch_depth);

        let mem_depth = MemoryRegion.loadNat8(btree.branches, node_address + MC.DEPTH_START) |> Nat8.toNat(_);
        // Debug.print("mem_depth = " # debug_show mem_depth);

        if (mem_depth == 1) {
            #leaf;
        } else {
            #branch;
        };

    };

    public func get_count(btree : MemoryBTree, branch_address : Nat) : Nat {
        // assert Branch.validate(btree, branch_address);

        MemoryRegion.loadNat16(btree.branches, branch_address + MC.COUNT_START) |> Nat16.toNat(_);
    };

    public func get_index(btree : MemoryBTree, branch_address : Nat) : Nat {
        // assert Branch.validate(btree, branch_address);

        MemoryRegion.loadNat16(btree.branches, branch_address + MC.INDEX_START) |> Nat16.toNat(_);
    };

    public func get_parent(btree : MemoryBTree, branch_address : Nat) : ?Nat {
        // assert Branch.validate(btree, branch_address);

        let parent = MemoryRegion.loadNat64(btree.branches, branch_address + MC.PARENT_START);
        if (parent == MC.NULL_ADDRESS) null else ?Nat64.toNat(parent);
    };

    public func get_key_address(btree : MemoryBTree, branch_address : Nat, i : Nat) : ?UniqueId {
        // assert Branch.validate(btree, branch_address);
        let key_offset = get_node_key_offset(branch_address, i);
        let key_address = MemoryRegion.loadNat64(btree.branches, key_offset);

        if (key_address == MC.NULL_ADDRESS) return null;

        ?Nat64.toNat(key_address);
    };

    public func get_key_blob(btree : MemoryBTree, branch_address : Nat, i : Nat) : ?(Blob) {
        // assert Branch.validate(btree, branch_address);

        let ?kv_address = Branch.get_key_address(btree, branch_address, i) else return null;
        ?MemoryBlock.Branch.get_key_blob(btree, kv_address);
    };

    public func set_key_address_to_null(btree : MemoryBTree, branch_address : Nat, i : Nat) {
        // assert Branch.validate(btree, branch_address);

        let key_offset = get_node_key_offset(branch_address, i);
        MemoryRegion.storeNat64(btree.branches, key_offset, MC.NULL_ADDRESS);
    };

    public func get_child(btree : MemoryBTree, branch_address : Nat, i : Nat) : ?Nat {
        // assert Branch.validate(btree, branch_address);

        let raw_value = MemoryRegion.loadNat64(btree.branches, get_child_offset(btree, branch_address, i));
        if (raw_value == MC.NULL_ADDRESS) {
            return null;
        };
        let child_addr = Nat64.toNat(raw_value);
        ?child_addr;
    };

    public func set_child_to_null(btree : MemoryBTree, branch_address : Nat, i : Nat) {
        // assert Branch.validate(btree, branch_address);

        MemoryRegion.storeNat64(btree.branches, get_child_offset(btree, branch_address, i), MC.NULL_ADDRESS);
    };

    public func get_subtree_size(btree : MemoryBTree, branch_address : Nat) : Nat {
        // assert Branch.validate(btree, branch_address);

        MemoryRegion.loadNat64(btree.branches, branch_address + MC.SUBTREE_COUNT_START) |> Nat64.toNat(_);
    };

    public func get_boundary_keys(btree : MemoryBTree, branch_address : Nat) : (?Blob, ?Blob) {
        // assert Branch.validate(btree, branch_address);
        var opt_left : ?Blob = null;
        var opt_right : ?Blob = null;
        var current = branch_address;

        label search loop {
            let ?parent = Branch.get_parent(btree, current) else break search;
            let branch_index = Branch.get_index(btree, current);
            let parent_count = Branch.get_count(btree, parent);

            // Guard branch_index < parent_count: after a branch split, the new right
            // branch is assigned a tentative stored_index of left_branch_index + 1 before
            // being inserted into the parent. If left_branch_index == parent_count - 1,
            // the tentative index equals parent_count, placing keys[branch_index - 1] one
            // slot beyond the last valid key. Skip rather than trap — we continue up the
            // tree and may find a bound from a higher ancestor.
            if (Option.isNull(opt_left) and branch_index > 0 and branch_index < parent_count) {
                let ?key = Branch.get_key_blob(btree, parent, branch_index - 1) else Runtime.trap("Branch.get_boundary_keys: accessed a null left key");
                opt_left := ?key;
            };

            if (Option.isNull(opt_right) and branch_index < parent_count - 1) {
                let ?key = Branch.get_key_blob(btree, parent, branch_index) else Runtime.trap("Branch.get_boundary_keys: accessed a null right key");
                opt_right := ?key;
            };

            if (Option.isSome(opt_left) and Option.isSome(opt_right)) break search;
            current := parent;
        };

        (opt_left, opt_right);
    };

    public func get_child_boundary_keys(btree : MemoryBTree, branch_address : Nat, child_index : Nat) : (?Blob, ?Blob) {
        // assert Branch.validate(btree, branch_address);
        let branch_count = Branch.get_count(btree, branch_address);
        assert child_index <= branch_count;

        let opt_left_boundary_key = if (child_index == 0) null else Branch.get_key_blob(btree, branch_address, child_index - 1);
        let opt_right_boundary_key = if (child_index == branch_count - 1) null else Branch.get_key_blob(btree, branch_address, child_index);

        switch(opt_left_boundary_key, opt_right_boundary_key){
            case (?left, ?right) return (?left, ?right);
            case _ {};
        };

        let branch_boundary_keys = Branch.get_boundary_keys(btree, branch_address);

        (
            switch (opt_left_boundary_key) { case null branch_boundary_keys.0; case _ opt_left_boundary_key },
            switch (opt_right_boundary_key) { case null branch_boundary_keys.1; case _ opt_right_boundary_key },
        );
    };

    public func binary_search<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, address : Nat, cmp : (K, K) -> Int8, search_key : K, arr_len : Nat) : Int {
        // assert Branch.validate(btree, address);
        if (arr_len == 0) return -1; // should insert at index Int.abs(i + 1)
        var l = 0;

        // arr_len will always be between 4 and 512
        var r = arr_len - 1 : Nat;

        while (l < r) {
            let mid = (l + r) / 2;

            let ?key_blob = Branch.get_key_blob(btree, address, mid) else Runtime.trap("1. binary_search_blob_seq: accessed a null value");
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
                Runtime.trap("2. binary_search: accessed a null value");
            };
        };
    };

    public func binary_search_blob_seq(btree : MemoryBTree, address : Nat, cmp : (Blob, Blob) -> Int8, search_key : Blob, arr_len : Nat) : Int {
        // assert Branch.validate(btree, address);
        if (arr_len == 0) return -1; // should insert at index Int.abs(i + 1)
        var l = 0;

        // arr_len will always be between 4 and 512
        var r = arr_len - 1 : Nat;

        while (l < r) {
            let mid = (l + r) / 2;

            let ?key_blob = Branch.get_key_blob(btree, address, mid) else Runtime.trap("1. binary_search_blob_seq: accessed a null value");
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
                Runtime.trap("2. binary_search_blob_seq: accessed a null value");
            };
        };
    };

    public func update_count(btree : MemoryBTree, branch_address : Nat, count : Nat) {
        // assert Branch.validate(btree, branch_address);

        MemoryRegion.storeNat16(btree.branches, branch_address + MC.COUNT_START, Nat16.fromNat(count));
    };

    public func update_subtree_size(btree : MemoryBTree, branch_address : Nat, new_size : Nat) {
        // assert Branch.validate(btree, branch_address);

        MemoryRegion.storeNat64(btree.branches, branch_address + MC.SUBTREE_COUNT_START, Nat64.fromNat(new_size));
    };

    public func update_parent(btree : MemoryBTree, branch_address : Nat, opt_parent : ?Nat) {
        // assert Branch.validate(btree, branch_address);

        let parent = switch (opt_parent) {
            case (null) MC.NULL_ADDRESS;
            case (?_parent) Nat64.fromNat(_parent);
        };

        MemoryRegion.storeNat64(btree.branches, branch_address + MC.PARENT_START, parent);
    };

    public func replace_separator_key_address(btree : MemoryBTree, parent_address : Nat, child_index : Nat, new_key_address : UniqueId) : ?Address {
        var curr_address = parent_address;
        var i = child_index;

        while (i == 0) {
            i := Branch.get_index(btree, curr_address);
            let ?parent_address = Branch.get_parent(btree, curr_address) else return null; // occurs for the leftmost leaf
            curr_address := parent_address;
        };

        let opt_prev_key_address = Branch.get_key_address(btree, curr_address, i - 1);

        Branch.put_key_address(btree, curr_address, i - 1, new_key_address);

        opt_prev_key_address;
    };

    public func update_separator_key_address(btree : MemoryBTree, parent_address : Nat, child_index : Nat, new_key_address : UniqueId) {
        var curr_address = parent_address;
        var i = child_index;

        while (i == 0) {
            i := Branch.get_index(btree, curr_address);
            let ?parent_address = Branch.get_parent(btree, curr_address) else return; // occurs when key is the first key in the tree
            curr_address := parent_address;
        };

        Branch.put_key_address(btree, curr_address, i - 1, new_key_address);
    };

    public func update_separator_key(btree : MemoryBTree, parent_address : Nat, child_index : Nat, new_key : Blob) {
        var curr_address = parent_address;
        var i = child_index;

        while (i == 0) {
            i := Branch.get_index(btree, curr_address);
            let ?parent_address = Branch.get_parent(btree, curr_address) else return; // occurs when key is the first key in the tree
            curr_address := parent_address;
        };

        Branch.replace_key(btree, curr_address, i - 1, new_key);
    };

    // inserts node but does not update the subtree size with the node's subtree size
    // because it's likely that the inserted node is a node split from a node
    // in this branch's subtree

    public func insert(btree : MemoryBTree, branch_address : Nat, i : Nat, key_address : UniqueId, child_address : Nat) {
        let count = Branch.get_count(btree, branch_address);
        insert_with_count(btree, branch_address, i, key_address, child_address, count);
    };

    public func insert_with_count(btree : MemoryBTree, branch_address : Nat, i : Nat, key_address : UniqueId, child_address : Nat, count : Nat) {
        // assert Branch.validate(btree, branch_address);
        assert count < btree.node_capacity;
        assert i <= count;

        // shift keys and children
        do {
            if (i == 0) {
                // elements inserted are always nodes created as a result of split
                // so their index is always greater than one as new nodes created from
                // a split operation are always inserted at the right
                // update_separator_key_address(btree, branch, i, key);
                // Runtime.trap("Branch.insert(): inserting at index 0 is not allowed");
            } else {
                let key_offset = get_node_key_offset(branch_address, i - 1);
                let key_end_boundary = get_node_key_offset(branch_address, count - 1);

                MemoryFns.shift_by(btree.branches.region, key_offset, key_end_boundary, MC.ADDRESS_SIZE);
                MemoryRegion.storeNat64(btree.branches, key_offset, Nat64.fromNat(key_address));
            };

            let child_offset = get_child_offset(btree, branch_address, i);
            let child_end_boundary = get_child_offset(btree, branch_address, count);

            MemoryFns.shift_by(btree.branches.region, child_offset, child_end_boundary, MC.ADDRESS_SIZE);
            MemoryRegion.storeNat64(btree.branches, child_offset, Nat64.fromNat(child_address));
        };

        // Debug.print("updating children index values");
        // update children index values
        var j = count;
        let branch_stores_leaves = Branch.has_leaves(btree, branch_address);

        label while_loop while (j >= i) {

            let ?child_address = Branch.get_child(btree, branch_address, j) else Runtime.trap("Branch.insert(): child address is null");

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

    public func insert_with_key_blob(btree : MemoryBTree, branch_address : Nat, i : Nat, key_blob : Blob, child_address : Nat) {
        let key_address = MemoryBlock.Branch.store_key_blob(btree, key_blob);
        Branch.insert(btree, branch_address, i, key_address, child_address);
    };

    /// Split a branch node, inserting new child at child_index
    /// Returns (right_address, separator_key_address)
    public func split(btree : MemoryBTree, branch_address : Nat, child_index : Nat, child_key_address : UniqueId, child : Nat) : (Nat, UniqueId) {
        // assert Branch.validate(btree, branch_address);

        let arr_len = btree.node_capacity;
        
        let median = (arr_len / 2) + 1;

        let is_elem_added_to_right = child_index >= median;

        var separator_key_address = ?child_key_address;

        var offset = if (is_elem_added_to_right) 0 else 1;
        var already_inserted = false;

        let right_cnt = arr_len + 1 - median : Nat;
        let right_address = Branch.new(btree);
        // assert Branch.validate(btree, right_address);

        let depth = Branch.get_depth(btree, branch_address);
        Branch.update_depth(btree, right_address, depth);
        // assert Branch.validate(btree, right_address);

        var i = 0;
        var elems_removed_from_left = 0;

        if (not is_elem_added_to_right) {
            let j = i + median - offset : Nat;

            separator_key_address := Branch.get_key_address(btree, branch_address, j - 1);
            // Clear the separator slot from the left branch so it no longer shares
            // ownership of the key address with the parent. After the split, the
            // parent owns this key exclusively and may free it during later merges.
            Branch.set_key_address_to_null(btree, branch_address, j - 1);

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
                let ?child_address = Branch.get_child(btree, right_address, i) else Runtime.trap("Branch.split: accessed a null value");

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
                    separator_key_address := Branch.get_key_address(btree, branch_address, j - 1);
                } else {
                    let ?shifted_key_address = Branch.get_key_address(btree, branch_address, j - 1) else Runtime.trap("Branch.split: accessed a null value");

                    Branch.put_key_address(btree, right_address, i - 1, shifted_key_address);
                };

                Branch.set_key_address_to_null(btree, branch_address, j - 1);

                // branch.0 [AC.COUNT] -= 1;
                elems_removed_from_left += 1;

                let ?child_address = Branch.get_child(btree, branch_address, j) else Runtime.trap("Branch.split: accessed a null value");
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
        let ?_separator_key_address = separator_key_address else Runtime.trap("Branch.split: median key_block is null");

        (right_address, _separator_key_address);
    };

    public func split_with_key_blob(btree : MemoryBTree, branch_address : Nat, child_index : Nat, child_key_blob : Blob, child : Nat) : (Nat, UniqueId) {
        let key_address = MemoryBlock.Branch.store_key_blob(btree, child_key_blob);
        Branch.split(btree, branch_address, child_index, key_address, child);
    };

    public func get_larger_neighbour(btree : MemoryBTree, parent_address : Address, index : Nat) : ?Address {

        let ?child = Branch.get_child(btree, parent_address, index) else Runtime.trap("1. get_larger_neighbor: accessed a null value");
        var neighbour = child;

        let parent_count = Branch.get_count(btree, parent_address);
        let parent_has_leaves = Branch.has_leaves(btree, parent_address);

        if (parent_count > 1) {
            if (index != 0) {
                let ?left_neighbour = Branch.get_child(btree, parent_address, index - 1 : Nat) else Runtime.trap("1. redistribute_leaf_keys: accessed a null value");
                neighbour := left_neighbour;
            };

            if (index != (parent_count - 1 : Nat)) {
                let ?right_neighbour = Branch.get_child(btree, parent_address, index + 1) else Runtime.trap("2. redistribute_leaf_keys: accessed a null value");

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

    public func get_smaller_neighbour(btree : MemoryBTree, parent_address : Address, index : Nat) : ?Address {

        let ?child = Branch.get_child(btree, parent_address, index) else Runtime.trap("1. get_smaller_neighbor: accessed a null value");
        var neighbour = child;

        let parent_count = Branch.get_count(btree, parent_address);
        let parent_has_leaves = Branch.has_leaves(btree, parent_address);

        if (parent_count > 1) {
            if (index != (parent_count - 1 : Nat)) {
                let ?right_neighbour = Branch.get_child(btree, parent_address, index + 1) else Runtime.trap("1. redistribute_leaf_keys: accessed a null value");
                neighbour := right_neighbour;
            };

            if (index != 0) {
                let ?left_neighbour = Branch.get_child(btree, parent_address, index - 1 : Nat) else Runtime.trap("2. redistribute_leaf_keys: accessed a null value");

                if (neighbour == child) return ?left_neighbour;

                switch (parent_has_leaves) {
                    case (false) if (Branch.get_count(btree, left_neighbour) > Branch.get_count(btree, neighbour)) {
                        return ?left_neighbour;
                    };
                    case (true) if (Leaf.get_count(btree, left_neighbour) > Leaf.get_count(btree, neighbour)) {
                        return ?left_neighbour;
                    };
                };
            };
        };

        if (neighbour == child) return null;

        return ?neighbour;
    };

    // Returns the neighbour leaf that will yield the longest common prefix after merging
    // with the leaf at `leaf_index`.  When both neighbours produce equal prefix lengths,
    // the one with more entries is preferred (to balance the surviving leaf).
    // Returns null when the parent has no other children (only-child leaf).
    public func get_merge_neighbour_with_best_compression(btree : MemoryBTree, parent : Address, leaf_index : Nat) : ?Address {
        let parent_count = Branch.get_count(btree, parent);

        let opt_left  = if (leaf_index > 0)                 Branch.get_child(btree, parent, leaf_index - 1) else null;
        let opt_right = if (leaf_index + 1 < parent_count) Branch.get_child(btree, parent, leaf_index + 1) else null;

        switch (opt_left, opt_right) {
            case (null, null) null;
            case (?nb, null)  ?nb;
            case (null, ?nb)  ?nb;
            case (?left_nb, ?right_nb) {
                let ?leaf_address = Branch.get_child(btree, parent, leaf_index) else Runtime.trap("get_merge_neighbour_with_best_compression: leaf is null");
                let leaf_prefix  = Leaf.get_prefix_key(btree, leaf_address);
                let left_prefix  = Leaf.get_prefix_key(btree, left_nb);
                let right_prefix = Leaf.get_prefix_key(btree, right_nb);

                let prefix_len_left  = Common.get_prefix_length(leaf_prefix, left_prefix);
                let prefix_len_right = Common.get_prefix_length(leaf_prefix, right_prefix);

                if      (prefix_len_left  > prefix_len_right)                                ?left_nb
                else if (prefix_len_right > prefix_len_left)                                 ?right_nb
                else if (Leaf.get_count(btree, left_nb) > Leaf.get_count(btree, right_nb)) ?left_nb
                else                                                                          ?right_nb;
            };
        };
    };

    // shift keys and children in any direction indicated by the offset
    // positive offset shifts to the right, negative offset shifts to the left
    // since the keys indicates the boundaries of the children,
    // the first key is the starting boundary of the second child
    // for this reason shifting past the first key is not allowed
    // can only shift from [1.. n] where n is the number of keys
    // and the addition of the offset to the index must be >= 1
    /// Shifts keys in the branch. Keys are 0-indexed (key at index i separates children i and i+1).
    /// Shifts keys from index `start` to `end-1` by `offset` positions.
    public func shift_keys(btree : MemoryBTree, branch_address : Address, start : Nat, end : Nat, offset : Int) {
        // assert Branch.validate(btree, branch_address);
        if (offset == 0 or start >= end) return;

        let key_offset = get_node_key_offset(branch_address, start);
        let key_end_boundary = get_node_key_offset(branch_address, end);

        MemoryFns.shift_by(btree.branches.region, key_offset, key_end_boundary, offset * MC.ADDRESS_SIZE);
    };

    /// Shifts children in the branch from index `start` to `end-1` by `offset` positions.
    /// Also updates the stored index of each shifted child.
    public func shift_children(btree : MemoryBTree, branch_address : Address, start : Nat, end : Nat, offset : Int) {
        // assert Branch.validate(btree, branch_address);
        if (offset == 0 or start >= end) return;

        let branch_has_leaves = Branch.has_leaves(btree, branch_address);

        // update child indexes to future position after shift
        var i = start;
        while (i < end) {
            let ?child = Branch.get_child(btree, branch_address, i) else Runtime.trap("Branch.shift_children(): accessed a null value");

            switch (branch_has_leaves) {
                case (false) Branch.update_index(btree, child, Int.abs(i + offset));
                case (true) Leaf.update_index(btree, child, Int.abs(i + offset));
            };
            i += 1;
        };

        let child_offset = get_child_offset(btree, branch_address, start);
        let child_end_boundary = get_child_offset(btree, branch_address, end);

        MemoryFns.shift_by(btree.branches.region, child_offset, child_end_boundary, offset * MC.ADDRESS_SIZE);
    };

    /// Shifts both keys and children. This is the legacy function that combines both operations.
    /// Note: The key indexing here uses the convention where key[i-1] is associated with child[i].
    public func shift(btree : MemoryBTree, branch_address : Address, start : Nat, end : Nat, offset : Int) {
        // assert Branch.validate(btree, branch_address);
        assert start + offset >= 1;

        if (offset == 0) return;

        // Update child indexes first (before memory shifts)
        var i = start;
        let branch_has_leaves = Branch.has_leaves(btree, branch_address);
        while (i < end) {
            let ?child = Branch.get_child(btree, branch_address, i) else Runtime.trap("Branch.shift(): accessed a null value");

            switch (branch_has_leaves) {
                case (false) Branch.update_index(btree, child, Int.abs(i + offset));
                case (true) Leaf.update_index(btree, child, Int.abs(i + offset));
            };
            i += 1;
        };

        // Shift keys: key indices are offset by 1 from child indices
        // key[i-1] separates child[i-1] and child[i]
        if (start != 0) {
            shift_keys(btree, branch_address, start - 1, end - 1, offset);
        } else {
            // When start is 0, we shift keys from index 0 to end-1
            shift_keys(btree, branch_address, 0, end - 1, offset);
        };

        // Shift children
        let child_offset = get_child_offset(btree, branch_address, start);
        let child_end_boundary = get_child_offset(btree, branch_address, end);
        MemoryFns.shift_by(btree.branches.region, child_offset, child_end_boundary, offset * MC.ADDRESS_SIZE);
    };

    // most branch removes are a result of a merge operation
    // the right node is always merged into the left node so it unlikely
    // that we would need to remove the 0th index, which will cause issues
    // because the keys hold one less value than the children array
    // Returns the key address that was removed so the caller can decide whether to deallocate it
    public func remove(btree : MemoryBTree, branch_address : Address, index : Nat) : ?UniqueId {
        let count = Branch.get_count(btree, branch_address);
        remove_with_count(btree, branch_address, index, count);
    };

    public func remove_with_count(btree : MemoryBTree, branch_address : Address, index : Nat, count : Nat) : ?UniqueId {
        // assert Branch.validate(btree, branch_address);
        
        if (index == 0) {

            if (count == 1){
                // just set the only child to null and update count
                Branch.set_child_to_null(btree, branch_address, 0);
                Branch.update_count(btree, branch_address, 0);
                return null;
            };

            let ?next_key_address = Branch.get_key_address(btree, branch_address, 0) else Runtime.trap("Branch.remove: accessed a null value");

            // replace the separator key with the key to the right
            // this function will traverse up the tree and find the location of the separator key if the index is 0
            let opt_prev_separator_key_address = Branch.replace_separator_key_address(btree, branch_address, index, next_key_address);

            // Shift children [1..count-1] → [0..count-2] and keys [1..count-2] → [0..count-3].
            // We must NOT use Branch.shift here because Branch.shift(start=1, offset=-1) would
            // incorrectly try to shift key[0] to key[-1] (before the key array).
            Branch.shift_children(btree, branch_address, 1, count, -1);
            Branch.shift_keys(btree, branch_address, 1, count - 1, -1);
            Branch.set_key_address_to_null(btree, branch_address, count - 2);
            Branch.set_child_to_null(btree, branch_address, count - 1);
            Branch.update_count(btree, branch_address, count - 1);

            // When replace_separator_key_address returns null, the branch is the leftmost in
            // the tree; next_key_address was not placed into any ancestor and is now orphaned
            // (the branch's key[0] slot was overwritten by the shift). Return it for the caller
            // to free. Otherwise return the old separator that was displaced in the ancestor.
            return ?(Option.get(opt_prev_separator_key_address, next_key_address));
        };

        let ?key_address_at_index = Branch.get_key_address(btree, branch_address, index - 1) else Runtime.trap("Branch.remove: accessed a null value");

        // shift keys and children left to fill the gap left by the removed child and key
        // then clear the last child position to prevent stale references
        Branch.shift(btree, branch_address, index + 1, count, -1); 
        Branch.set_key_address_to_null(btree, branch_address, count - 2); // keys are (|children| - 1), so last key is at count - 2
        Branch.set_child_to_null(btree, branch_address, count - 1); 

        Branch.update_count(btree, branch_address, count - 1);

        ?key_address_at_index;
    };

    // public func redistribute(btree : MemoryBTree, branch : Address) : Bool {
    //     let ?parent = Branch.get_parent(btree, branch) else Runtime.trap("Branch.redistribute: parent should not be null");
    //     let branch_index = Branch.get_index(btree, branch);
    //     // Debug.print("redistribute: " # debug_show branch_index);
    //     let ?neighbour = Branch.get_larger_neighbour(btree, parent, branch_index) else return false;
    //     let branch_has_leaves = Branch.has_leaves(btree, branch);

    //     // Debug.print("branch_has_leaves: " # debug_show (branch, branch_has_leaves));
    //     // Debug.print("branch depth: " # debug_show Branch.get_depth(btree, branch));

    //     let neighbour_index = Branch.get_index(btree, neighbour);

    //     let branch_count = Branch.get_count(btree, branch);
    //     let neighbour_count = Branch.get_count(btree, neighbour);

    //     let sum_count = branch_count + neighbour_count;
    //     let min_count_for_both_nodes = btree.node_capacity;

    //     // Debug.print("branch: " # debug_show from_memory(btree, branch));
    //     // Debug.print("neighbour: " # debug_show from_memory(btree, neighbour));

    //     if (sum_count < min_count_for_both_nodes) return false;

    //     let data_to_move = (sum_count / 2) - branch_count : Nat;

    //     var moved_subtree_size = 0;

    //     if (neighbour_index < branch_index) {
    //         // Debug.print("redistribute: left neighbour");
    //         // move data from the left neighbour to the right branch
    //         let ?_separator_key_address = Branch.get_key_address(btree, parent, neighbour_index) else return Runtime.trap("Branch.redistribute: separator_key_address should not be null");
    //         var separator_key_address = _separator_key_address;

    //         Branch.shift(btree, branch, 0, branch_count, data_to_move);

    //         var i = 0;
    //         while (i < data_to_move) {
    //             let j = neighbour_count - 1 - i : Nat;
    //             // Debug.print("neighbour: " # debug_show from_memory(btree, neighbour));
    //             let ?child = Branch.get_child(btree, neighbour, j) else return Runtime.trap("Branch.redistribute: child should not be null");
    //             let removed_key_address = Branch.remove(btree, neighbour, j);

    //             // Debug.print("separator_key_address: " # debug_show separator_key_address);

    //             let new_index = data_to_move - i - 1 : Nat;
    //             Branch.put_key_address(btree, branch, new_index, separator_key_address);
    //             Branch.put_child(btree, branch, new_index, child);

    //             let child_subtree_size = if (branch_has_leaves) Leaf.get_count(btree, child) else Branch.get_subtree_size(btree, child);
    //             moved_subtree_size += child_subtree_size;

    //             separator_key_address := removed_key_address;

    //             i += 1;
    //         };

    //         // Debug.print("parent separator_key_address: " # debug_show separator_key_address);
    //         // Debug.print("parent separator_key_blob: " # debug_show separator_key_blob);

    //         Branch.put_key_address(btree, parent, neighbour_index, separator_key_address);

    //     } else {
    //         // Debug.print("redistribute: right neighbour");
    //         // move data from the right neighbour to the left branch

    //         let ?_separator_key_address = Branch.get_key_address(btree, parent, branch_index) else return Runtime.trap("Branch.redistribute: separator_key_address should not be null");
    //         var separator_key_address = _separator_key_address;

    //         var i = 0;
    //         while (i < data_to_move) {

    //             // Debug.print("separator_key_address: " # debug_show separator_key_address);

    //             let ?child = Branch.get_child(btree, neighbour, i) else return Runtime.trap("Branch.redistribute: child should not be null");
    //             Branch.insert(btree, branch, branch_count + i, separator_key_address, child);

    //             let child_subtree_size = if (branch_has_leaves) Leaf.get_count(btree, child) else Branch.get_subtree_size(btree, child);
    //             moved_subtree_size += child_subtree_size;

    //             let ?key_block = Branch.get_key_address(btree, neighbour, i) else return Runtime.trap("Branch.redistribute: key_block should not be null");
    //             let ?key_blob = Branch.get_key_blob(btree, neighbour, i) else return Runtime.trap("Branch.redistribute: key_blob should not be null");

    //             separator_key_address := key_block;

    //             i += 1;
    //         };

    //         // Debug.print("parent separator_key_address: " # debug_show separator_key_address);

    //         // shift keys and children in the right neighbour
    //         // since we can't shift to the first child index,
    //         // we will shift to the second index and insert the
    //         // value at the first child index manually
    //         let ?first_child = Branch.get_child(btree, neighbour, data_to_move) else return Runtime.trap("Branch.redistribute: first_child should not be null");
    //         Branch.shift(btree, neighbour, data_to_move + 1, neighbour_count, -data_to_move);
    //         Branch.put_child(btree, neighbour, 0, first_child);

    //         // update median key in parent
    //         Branch.put_key_address(btree, parent, branch_index, separator_key_address);
    //     };

    //     Branch.update_count(btree, branch, branch_count + data_to_move);
    //     Branch.update_count(btree, neighbour, neighbour_count - data_to_move);

    //     let branch_subtree_size = Branch.get_subtree_size(btree, branch);
    //     Branch.update_subtree_size(btree, branch, branch_subtree_size + moved_subtree_size);

    //     let neighbour_subtree_size = Branch.get_subtree_size(btree, neighbour);
    //     Branch.update_subtree_size(btree, neighbour, neighbour_subtree_size - moved_subtree_size);

    //     true;
    // };

    // Redistributes children from `neighbour` into `branch` to balance them.
    // `branch` is assumed to be sparse (below merge threshold).
    // Moves `floor((branch_count + neighbour_count) / 2) - branch_count` entries
    // from whatever side `neighbour` is on.
    //
    // Does NOT recompress prefix keys — only moves separator-key addresses and
    // children.  Subtree sizes are updated to reflect the moved weight.
    //
    // Returns true if entries were actually moved.
    public func redistribute(btree : MemoryBTree, branch_address : Address, neighbour : Address, parent : Address) : Bool {
        let branch_index    = Branch.get_index(btree, branch_address);
        let neighbour_index = Branch.get_index(btree, neighbour);

        let branch_count    = Branch.get_count(btree, branch_address);
        let neighbour_count = Branch.get_count(btree, neighbour);

        let data_to_move = (branch_count + neighbour_count) / 2 - branch_count;
        if (data_to_move == 0) return false;

        // Separator key that sits between the two siblings in the parent.
        // key[i] separates child[i] from child[i+1], so the separator index
        // equals the left sibling's child-index in the parent.
        let sep_index = Nat.min(branch_index, neighbour_index);
        let ?sep_key_address = Branch.get_key_address(btree, parent, sep_index)
            else Runtime.trap("Branch.redistribute: sep_key_address is null");

        var moved_subtree_size = 0;
        let branch_has_leaves = Branch.has_leaves(btree, branch_address);

        if (neighbour_index < branch_index) {
            // ── Left neighbour ───────────────────────────────────────────────────
            // Move the last `data_to_move` entries of neighbour into the HEAD of branch.

            // Shift the existing branch contents right to make room.
            shift_children(btree, branch_address, 0, branch_count,     data_to_move);
            shift_keys    (btree, branch_address, 0, branch_count - 1, data_to_move);

            var i = 0;
            while (i < data_to_move) {
                let src = neighbour_count - data_to_move + i;
                let ?child = Branch.get_child(btree, neighbour, src)
                    else Runtime.trap("Branch.redistribute (L->R): child is null");

                // put_child writes the address and updates parent + stored index.
                Branch.put_child(btree, branch_address, i, child);

                // Key at branch.key[i] separates branch.child[i] from branch.child[i+1].
                //   inner slots (i < dm-1): neighbour.key[src]  (was the separator between
                //                          consecutive moved children inside neighbour)
                //   last slot  (i == dm-1): old parent separator (bridges last moved child
                //                          to the first original child now at position dm)
                let key_addr = if (i < data_to_move - 1) {
                    let ?ka = Branch.get_key_address(btree, neighbour, src)
                        else Runtime.trap("Branch.redistribute (L->R): inner key is null");
                    ka
                } else {
                    sep_key_address
                };
                Branch.put_key_address(btree, branch_address, i, key_addr);

                let sz = if (branch_has_leaves) Leaf.get_count(btree, child)
                         else Branch.get_subtree_size(btree, child);
                moved_subtree_size += sz;
                i += 1;
            };

            // New parent separator: the key that now marks the right boundary of neighbour.
            let ?new_sep = Branch.get_key_address(btree, neighbour, neighbour_count - data_to_move - 1)
                else Runtime.trap("Branch.redistribute (L->R): new_sep is null");
            Branch.put_key_address(btree, parent, sep_index, new_sep);

        } else {
            // ── Right neighbour ──────────────────────────────────────────────────
            // Move the first `data_to_move` entries of neighbour into the TAIL of branch.

            var i = 0;
            while (i < data_to_move) {
                let ?child = Branch.get_child(btree, neighbour, i)
                    else Runtime.trap("Branch.redistribute (R->L): child is null");

                Branch.put_child(btree, branch_address, branch_count + i, child);

                // Key at branch.key[branch_count + i - 1]:
                //   first slot (i == 0): old parent separator (bridges last original child
                //                       to the first moved child)
                //   later slots (i > 0): neighbour.key[i-1] (was the separator between
                //                        consecutive moved children inside neighbour)
                let key_addr = if (i == 0) {
                    sep_key_address
                } else {
                    let ?ka = Branch.get_key_address(btree, neighbour, i - 1)
                        else Runtime.trap("Branch.redistribute (R->L): inner key is null");
                    ka
                };
                Branch.put_key_address(btree, branch_address, branch_count + i - 1, key_addr);

                let sz = if (branch_has_leaves) Leaf.get_count(btree, child)
                         else Branch.get_subtree_size(btree, child);
                moved_subtree_size += sz;
                i += 1;
            };

            // New parent separator: the boundary between branch and neighbour after the move.
            let ?new_sep = Branch.get_key_address(btree, neighbour, data_to_move - 1)
                else Runtime.trap("Branch.redistribute (R->L): new_sep is null");
            Branch.put_key_address(btree, parent, sep_index, new_sep);

            // Compact neighbour: slide the remaining entries left.
            shift_children(btree, neighbour, data_to_move, neighbour_count,     -data_to_move);
            shift_keys    (btree, neighbour, data_to_move, neighbour_count - 1, -data_to_move);
        };

        Branch.update_count(btree, branch_address, branch_count + data_to_move);
        Branch.update_count(btree, neighbour,      neighbour_count - data_to_move);

        let bs = Branch.get_subtree_size(btree, branch_address);
        Branch.update_subtree_size(btree, branch_address, bs + moved_subtree_size);
        let ns = Branch.get_subtree_size(btree, neighbour);
        Branch.update_subtree_size(btree, neighbour, ns - moved_subtree_size);

        true;
    };

    public func validate(btree: MemoryBTree, branch: Address) : Bool {
        get_magic(btree, branch) == MC.MAGIC;
    };

    /// Deallocates all separator keys in a branch.
    /// This should be called before deallocating a branch to prevent memory leaks.
    public func deallocate_keys(btree : MemoryBTree, branch : Address) {
        // assert Branch.validate(btree, branch);
        
        let count = Branch.get_count(btree, branch);
        var i = 0;
        while (i < count - 1) {
            switch (Branch.get_key_address(btree, branch, i)) {
                case (?key_address) {
                    MemoryBlock.Branch.remove_key_blob(btree, key_address);
                };
                case (null) {};
            };
            i += 1;
        };
    };

    public func deallocate(btree : MemoryBTree, branch : Address) {
        // assert Branch.validate(btree, branch);

        // Only deallocate the branch node itself, not the keys
        // Keys should be explicitly managed by the caller to avoid double-free errors
        let memory_size = Branch.get_memory_size(btree.node_capacity);
        

        // deallocate memory region
        MemoryRegion.deallocate(btree.branches, branch, memory_size);
    };

    public func merge(btree : MemoryBTree, branch_address : Address, neighbour : Address) : (Nat, Address) {
        // assert Branch.validate(btree, branch_address);
        // assert Branch.validate(btree, neighbour);
        let ?parent = Branch.get_parent(btree, branch_address) else Runtime.trap("Branch.merge: parent should not be null");
        let branch_index = Branch.get_index(btree, branch_address);

        let neighbour_index = Branch.get_index(btree, neighbour);

        let left = if (neighbour_index < branch_index) neighbour else branch_address;
        let right = if (neighbour_index < branch_index) branch_address else neighbour;

        // let left_index = if (neighbour_index < branch_index) neighbour_index else branch_index;
        let right_index = if (neighbour_index < branch_index) branch_index else neighbour_index;

        let left_count = Branch.get_count(btree, left);
        let right_count = Branch.get_count(btree, right);

        let left_subtree_size = Branch.get_subtree_size(btree, left);
        let right_subtree_size = Branch.get_subtree_size(btree, right);

        let ?separator_key_address = Branch.get_key_address(btree, parent, right_index - 1) else Runtime.trap("Branch.merge: separator_key_address should not be null");

        // Debug.print("left branch before merge: " # debug_show Branch.from_memory(btree, left));
        // Debug.print("right branch before merge: " # debug_show Branch.from_memory(btree, right));

        // Store the separator key from parent at the end of left's keys (at position left_count - 1)
        Branch.put_key_address(btree, left, left_count - 1, separator_key_address);

        // Bulk copy keys from right to left (right has right_count - 1 keys, positions 0 to right_count - 2)
        if (right_count > 1) {
            let start_key = get_node_key_offset(right, 0);
            let end_key = get_node_key_offset(right, right_count - 1);
            let dest_key = get_node_key_offset(left, left_count);
            
            let keys_blob = MemoryRegion.loadBlob(btree.branches, start_key, end_key - start_key);
            MemoryRegion.storeBlob(btree.branches, dest_key, keys_blob);
        };

        // Bulk copy children from right to left (right has right_count children, positions 0 to right_count - 1)
        let start_child = get_child_offset(btree, right, 0);
        let end_child = get_child_offset(btree, right, right_count);
        let dest_child = get_child_offset(btree, left, left_count);
        
        let children_blob = MemoryRegion.loadBlob(btree.branches, start_child, end_child - start_child);
        MemoryRegion.storeBlob(btree.branches, dest_child, children_blob);

        // Update parent and index for all copied children
        let branch_has_leaves = Branch.has_leaves(btree, left);
        var i = 0;
        while (i < right_count) {
            let ?child = Branch.get_child(btree, left, left_count + i) else Runtime.trap("Branch.merge: child should not be null");
            
            switch (branch_has_leaves) {
                case (false) {
                    Branch.update_parent(btree, child, ?left);
                    Branch.update_index(btree, child, left_count + i);
                };
                case (true) {
                    Leaf.update_parent(btree, child, ?left);
                    Leaf.update_index(btree, child, left_count + i);
                };
            };
            
            i += 1;
        };

        Branch.update_count(btree, left, left_count + right_count);
        Branch.update_subtree_size(btree, left, left_subtree_size + right_subtree_size);

        // update the right count as well, so any function it's passed to after the merge
        // knows that the right node is now empty
        Branch.update_count(btree, right, 0);

        (right, right_index);
    };
};
