import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Nat8 "mo:base/Nat8";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";
import Order "mo:base/Order";
import Bool "mo:base/Bool";

import MemoryRegion "mo:memory-region/MemoryRegion";
import LruCache "mo:lru-cache";
import RevIter "mo:itertools/RevIter";
// import Branch "mo:augmented-btrees/BpTree/Branch";

import MemoryFns "MemoryFns";
import Blobify "../Blobify";
import MemoryCmp "../MemoryCmp";
import ArrayMut "ArrayMut";
import T "Types";
import Leaf "Leaf";
import MemoryBlock "MemoryBlock";

module Branch {

    type MemoryRegion = MemoryRegion.MemoryRegion;
    type LruCache<K, V> = LruCache.LruCache<K, V>;
    type Blobify<A> = Blobify.Blobify<A>;
    type RevIter<A> = RevIter.RevIter<A>;
    type MemoryUtils<K, V> = T.MemoryUtils<K, V>;
    type MemoryBTree = T.MemoryBTree;
    type MemoryBlock = T.MemoryBlock;
    type Node = T.Node;
    type Address = T.Address;
    type NodeType = T.NodeType;

    public type Branch = T.Branch;

    public type MemoryCmp<A> = MemoryCmp.MemoryCmp<A>;

    let { nhash } = LruCache;

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
        MAGIC_START = 0;
        MAGIC_SIZE = 3;

        LAYOUT_VERSION_START = 3;
        LAYOUT_VERSION_SIZE = 1;

        NODE_TYPE_START = 4;
        NODE_TYPE_SIZE = 1;

        INDEX_START = 5;
        INDEX_SIZE = 2;

        COUNT_START = 7;
        COUNT_SIZE = 2;

        SUBTREE_COUNT_START = 9;
        SUBTREE_COUNT_SIZE = 8;

        PARENT_START = 17;
        ADDRESS_SIZE = 8;

        KEYS_START = 25;
        MAX_KEY_SIZE = 2;

        NULL_ADDRESS : Nat64 = 0x00;

        MAGIC : Blob = "BTN";
        LAYOUT_VERSION : Nat8 = 0;
        NODE_TYPE : Nat8 = 0x00; // branch node
    };

    public func get_memory_size(btree : MemoryBTree) : Nat {
        let bytes_per_node = Branch.MC.MAGIC_SIZE // magic
        + Branch.MC.LAYOUT_VERSION_SIZE // layout version
        + Branch.MC.NODE_TYPE_SIZE // node type
        + Branch.MC.ADDRESS_SIZE // parent address
        + Branch.MC.INDEX_SIZE // Node's position in parent node
        + Branch.MC.SUBTREE_COUNT_SIZE // number of elements in the node
        + Branch.MC.COUNT_SIZE // number of elements in the node
        // key pointers
        + (
            (
                Branch.MC.ADDRESS_SIZE // address of memory block
                + Branch.MC.MAX_KEY_SIZE // key size
            ) * (btree.order - 1 : Nat)
        )
        // children nodes
        + (Branch.MC.ADDRESS_SIZE * btree.order);

        bytes_per_node;
    };

    public func CHILDREN_START(btree : MemoryBTree) : Nat {
        MC.KEYS_START + ((btree.order - 1) * (MC.MAX_KEY_SIZE + MC.ADDRESS_SIZE));
    };

    public func get_key_offset(branch_address : Nat, i : Nat) : Nat {
        branch_address + MC.KEYS_START + (i * (MC.MAX_KEY_SIZE + MC.ADDRESS_SIZE));
    };

    public func get_child_offset(btree : MemoryBTree, branch_address : Nat, i : Nat) : Nat {
        branch_address + CHILDREN_START(btree) + (i * MC.ADDRESS_SIZE);
    };

    public func new(btree : MemoryBTree) : Nat {
        let bytes_per_node = Branch.get_memory_size(btree);

        let branch_address = MemoryRegion.allocate(btree.metadata, bytes_per_node);

        MemoryRegion.storeBlob(btree.metadata, branch_address, MC.MAGIC);
        MemoryRegion.storeNat8(btree.metadata, branch_address + MC.LAYOUT_VERSION_START, MC.LAYOUT_VERSION);
        MemoryRegion.storeNat8(btree.metadata, branch_address + MC.NODE_TYPE_START, MC.NODE_TYPE);

        MemoryRegion.storeNat16(btree.metadata, branch_address + MC.INDEX_START, 0);
        MemoryRegion.storeNat16(btree.metadata, branch_address + MC.COUNT_START, 0);
        MemoryRegion.storeNat64(btree.metadata, branch_address + MC.SUBTREE_COUNT_START, 0);

        MemoryRegion.storeNat64(btree.metadata, branch_address + MC.PARENT_START, MC.NULL_ADDRESS);

        var i = 0;

        while (i < (btree.order - 1 : Nat)) {
            let key_offset = get_key_offset(branch_address, i);
            MemoryRegion.storeNat64(btree.metadata, key_offset, MC.NULL_ADDRESS);
            MemoryRegion.storeNat16(btree.metadata, key_offset + MC.ADDRESS_SIZE, Nat16.fromNat(0));
            i += 1;
        };

        i := 0;

        while (i < btree.order) {
            let child_offset = get_child_offset(btree, branch_address, i);
            MemoryRegion.storeNat64(btree.metadata, child_offset, MC.NULL_ADDRESS);
            i += 1;
        };

        branch_address;
    };

    func read_keys_into(btree : MemoryBTree, branch_address : Nat, keys : [var ?(MemoryBlock, Blob)]) {
        var i = 0;

        label while_loop while (i < (btree.order - 1)) {
            let key_offset = get_key_offset(branch_address, i);

            let key_address = MemoryRegion.loadNat64(btree.metadata, key_offset);

            if (key_address == MC.NULL_ADDRESS) break while_loop;

            let key_size = MemoryRegion.loadNat16(btree.metadata, key_offset + MC.ADDRESS_SIZE) |> Nat16.toNat(_);
            let key_block = (Nat64.toNat(key_address), key_size);
            let key_blob = MemoryBlock.get_key(btree, key_block);
            let key = (key_block, key_blob);

            keys[i] := ?key;
            i += 1;
        };
    };

    public func from_memory(btree : MemoryBTree, branch_address : Address) : Branch {
        assert MemoryRegion.loadBlob(btree.metadata, branch_address, MC.MAGIC_SIZE) == MC.MAGIC;
        assert MemoryRegion.loadNat8(btree.metadata, branch_address + MC.LAYOUT_VERSION_START) == MC.LAYOUT_VERSION;
        assert MemoryRegion.loadNat8(btree.metadata, branch_address + MC.NODE_TYPE_START) == MC.NODE_TYPE;

        let index = MemoryRegion.loadNat16(btree.metadata, branch_address + MC.INDEX_START) |> Nat16.toNat(_);
        let count = MemoryRegion.loadNat16(btree.metadata, branch_address + MC.COUNT_START) |> Nat16.toNat(_);
        let subtree_size = MemoryRegion.loadNat64(btree.metadata, branch_address + MC.SUBTREE_COUNT_START) |> Nat64.toNat(_);

        let parent = do {
            let p = MemoryRegion.loadNat64(btree.metadata, branch_address + MC.PARENT_START);
            if (p == MC.NULL_ADDRESS) null else ?Nat64.toNat(p);
        };

        let branch : Branch = (
            [var branch_address, index, count, subtree_size],
            [var parent],
            Array.init(btree.order - 1, null),
            Array.init<?Nat>(btree.order, null),
            Array.init(btree.order - 1, null),
        );

        var i = 0;

        label while_loop while (i < (btree.order - 1)) {
            let key_offset = get_key_offset(branch_address, i);

            let key_address = MemoryRegion.loadNat64(btree.metadata, key_offset);

            if (key_address == MC.NULL_ADDRESS) break while_loop;

            let key_size = MemoryRegion.loadNat16(btree.metadata, key_offset + MC.ADDRESS_SIZE) |> Nat16.toNat(_);
            let key_block = (Nat64.toNat(key_address), key_size);
            let key_blob = MemoryBlock.get_key(btree, key_block);

            branch.2 [i] := ?key_block;
            branch.4 [i] := ?key_blob;
            i += 1;
        };

        i := 0;

        label while_loop2 while (i < btree.order) {
            let child_offset = get_child_offset(btree, branch_address, i);

            let child_address = MemoryRegion.loadNat64(btree.metadata, child_offset);

            if (child_address == MC.NULL_ADDRESS) break while_loop2;

            branch.3 [i] := ?Nat64.toNat(child_address);
            i += 1;
        };

        branch;
    };

    public func from_address(btree : MemoryBTree, address : Address, update_cache : Bool) : Branch {
        let opt_node = if (update_cache) {
            LruCache.get(btree.nodes_cache, nhash, address);
        } else {
            LruCache.peek(btree.nodes_cache, nhash, address);
        };

        switch (opt_node) {
            case (? #branch(branch)) return branch;
            case (null) {};
            case (? #leaf(_)) Debug.trap("Branch.from_address(): Expected a branch, got a leaf");
        };

        let branch = Branch.from_memory(btree, address);
        if (update_cache) LruCache.put(btree.nodes_cache, nhash, address, #branch(branch));
        branch;
    };

    public func add_to_cache(btree : MemoryBTree, address : Nat) {
        switch (LruCache.get(btree.nodes_cache, nhash, address)) {
            case (? #branch(_)) return;
            case (? #leaf(_)) Debug.trap("Branch.add_to_cache(): Expected a branch, got a leaf");
            case (_) {};
        };

        let branch = Branch.from_memory(btree, address);
        LruCache.put(btree.nodes_cache, nhash, address, #branch(branch));
    };

    public func update_index(btree : MemoryBTree, branch_address : Nat, new_index : Nat) {
        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) branch.0 [AC.INDEX] := new_index;
            case (? #leaf(_)) Debug.trap("Branch.update_index(): Expected a branch, got a leaf");
            case (_) {};
        };

        MemoryRegion.storeNat16(btree.metadata, branch_address + MC.INDEX_START, Nat16.fromNat(new_index));
    };

    public func put_key(btree : MemoryBTree, branch_address : Nat, i : Nat, key_block : MemoryBlock, key_blob : Blob) {
        assert i < (btree.order - 1 : Nat);

        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) {
                branch.2 [i] := ?key_block;
                branch.4 [i] := ?key_blob;
            };
            case (? #leaf(_)) Debug.trap("Branch.put_key(): Expected a branch, got a leaf");
            case (_) {};
        };

        let offset = branch_address + MC.KEYS_START + (i * (MC.MAX_KEY_SIZE + MC.ADDRESS_SIZE));
        MemoryRegion.storeNat64(btree.metadata, offset, Nat64.fromNat(key_block.0));
        MemoryRegion.storeNat16(btree.metadata, offset + MC.ADDRESS_SIZE, Nat16.fromNat(key_block.1));
    };

    public func put_child(btree : MemoryBTree, branch_address : Nat, i : Nat, child_address : Nat) {
        assert i < btree.order;

        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) branch.3 [i] := ?child_address;
            case (? #leaf(_)) Debug.trap("Branch.put_child(): Expected a branch, got a leaf");
            case (_) {};
        };

        let offset = get_child_offset(btree, branch_address, i);
        MemoryRegion.storeNat64(btree.metadata, offset, Nat64.fromNat(child_address));
    };

    public func get_node_subtree_size(btree : MemoryBTree, node_address : Address) : Nat {
        switch (Branch.get_node_type(btree, node_address)) {
            case (#branch) {
                Branch.get_subtree_size(btree, node_address);
            };
            case (#leaf) {
                Leaf.get_count(btree, node_address);
            };
        };
    };

    public func add_child(btree : MemoryBTree, branch_address : Nat, child_address : Nat) {

        let count = Branch.get_count(btree, branch_address);

        assert count < btree.order;

        switch (Branch.get_node_type(btree, child_address)) {
            case (#branch) {
                Branch.update_parent(btree, child_address, ?branch_address);
                Branch.update_index(btree, child_address, count);
            };
            case (#leaf) {
                Leaf.update_parent(btree, child_address, ?branch_address);
                Leaf.update_index(btree, child_address, count);
            };
        };

        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) {
                branch.3 [count] := ?child_address;
            };
            case (? #leaf(_)) Debug.trap("Branch.put_child(): Expected a branch, got a leaf");
            case (_) {};
        };

        let offset = get_child_offset(btree, branch_address, count);
        MemoryRegion.storeNat64(btree.metadata, offset, Nat64.fromNat(child_address));

        let child_subtree_size = Branch.get_node_subtree_size(btree, child_address);
        let prev_subtree_size = Branch.get_subtree_size(btree, branch_address);
        Branch.update_subtree_size(btree, branch_address, prev_subtree_size + child_subtree_size);
        Branch.update_count(btree, branch_address, count + 1);
    };

    public func get_node(btree : MemoryBTree, node_address : Nat) : Node {
        switch (LruCache.get(btree.nodes_cache, nhash, node_address)) {
            case (?node) return node;
            case (_) {};
        };

        assert MemoryRegion.loadBlob(btree.metadata, node_address, MC.MAGIC_SIZE) == MC.MAGIC;

        let node_type = MemoryRegion.loadNat8(btree.metadata, node_address + MC.NODE_TYPE_START);

        let node = if (node_type == Branch.MC.NODE_TYPE) {
            #branch(Branch.from_address(btree, node_address, true));
        } else {
            #leaf(Leaf.from_address(btree, node_address, true));
        };

        node;
    };

    public func get_node_type(btree : MemoryBTree, node_address : Nat) : NodeType {
        switch (LruCache.peek(btree.nodes_cache, nhash, node_address)) {
            case (? #branch(_)) return #branch;
            case (? #leaf(_)) return #leaf;
            case (_) {};
        };
        assert MemoryRegion.loadBlob(btree.metadata, node_address, MC.MAGIC_SIZE) == MC.MAGIC;

        let node_type = MemoryRegion.loadNat8(btree.metadata, node_address + MC.NODE_TYPE_START);

        if (node_type == Branch.MC.NODE_TYPE) {
            #branch;
        } else {
            #leaf;
        };
    };

    public func get_count(btree : MemoryBTree, branch_address : Nat) : Nat {
        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) return branch.0 [AC.COUNT];
            case (? #leaf(leaf)) Debug.trap("Branch.get_child(): Expected a branch, got a leaf");
            case (_) {};
        };

        MemoryRegion.loadNat16(btree.metadata, branch_address + MC.COUNT_START) |> Nat16.toNat(_);
    };

    public func get_index(btree : MemoryBTree, branch_address : Nat) : Nat {
        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) return branch.0 [AC.INDEX];
            case (? #leaf(leaf)) Debug.trap("Branch.get_child(): Expected a branch, got a leaf");
            case (_) {};
        };

        MemoryRegion.loadNat16(btree.metadata, branch_address + MC.INDEX_START) |> Nat16.toNat(_);
    };

    public func get_parent(btree : MemoryBTree, branch_address : Nat) : ?Nat {
        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) return branch.1 [AC.PARENT];
            case (? #leaf(leaf)) Debug.trap("Branch.get_child(): Expected a branch, got a leaf");
            case (_) {};
        };

        let parent = MemoryRegion.loadNat64(btree.metadata, branch_address + MC.PARENT_START);
        if (parent == MC.NULL_ADDRESS) null else ?Nat64.toNat(parent);
    };

    public func get_keys(btree : MemoryBTree, branch_address : Nat) : [var ?(MemoryBlock, Blob)] {
        // switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
        //     case (? #branch(branch)) return branch.2;
        //     case (? #leaf(leaf)) return leaf.2;
        //     case (_) {};
        // };

        let keys = Array.init<?(MemoryBlock, Blob)>(btree.order - 1, null);
        read_keys_into(btree, branch_address, keys);
        keys;
    };

    public func get_key_block(btree : MemoryBTree, branch_address : Nat, i : Nat) : ?MemoryBlock {
        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) return branch.2 [i];
            case (? #leaf(leaf)) Debug.trap("Branch.get_child(): Expected a branch, got a leaf");
            case (_) {};
        };

        let key_offset = get_key_offset(branch_address, i);
        let key_address = MemoryRegion.loadNat64(btree.metadata, key_offset);
        let key_size = MemoryRegion.loadNat16(btree.metadata, key_offset + MC.ADDRESS_SIZE) |> Nat16.toNat(_);

        if (key_address == MC.NULL_ADDRESS) return null;

        let key_block = (Nat64.toNat(key_address), key_size);
        ?key_block;
    };

    public func get_key_blob(btree : MemoryBTree, branch_address : Nat, i : Nat) : ?(Blob) {
        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) return branch.4 [i];
            case (? #leaf(leaf)) Debug.trap("Branch.get_child(): Expected a branch, got a leaf");
            case (_) {};
        };

        let ?key_block = Branch.get_key_block(btree, branch_address, i) else return null;
        let key_blob = MemoryBlock.get_key(btree, key_block);
        ?(key_blob);
    };

    public func get_child(btree : MemoryBTree, branch_address : Nat, i : Nat) : ?Nat {
        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) return branch.3 [i];
            case (? #leaf(leaf)) Debug.trap("Branch.get_child(): Expected a branch, got a leaf");
            case (_) {};
        };

        MemoryRegion.loadNat64(btree.metadata, get_child_offset(btree, branch_address, i))
        |> ?Nat64.toNat(_);
    };

    public func get_subtree_size(btree : MemoryBTree, branch_address : Nat) : Nat {
        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) return branch.0 [AC.SUBTREE_SIZE];
            case (? #leaf(leaf)) Debug.trap("Branch.get_child(): Expected a branch, got a leaf");
            case (_) {};
        };

        MemoryRegion.loadNat32(btree.metadata, branch_address + MC.SUBTREE_COUNT_START) |> Nat32.toNat(_);
    };

    public func binary_search<K, V>(btree : MemoryBTree, mem_utils : MemoryUtils<K, V>, address : Nat, cmp : (K, K) -> Int8, search_key : K, arr_len : Nat) : Int {
        if (arr_len == 0) return -1; // should insert at index Int.abs(i + 1)
        var l = 0;

        // arr_len will always be between 4 and 512
        var r = arr_len - 1 : Nat;

        while (l < r) {
            let mid = (l + r) / 2;

            let ?key_blob = Branch.get_key_blob(btree, address, mid) else Debug.trap("1. binary_search_blob_seq: accessed a null value");
            let key = mem_utils.0.from_blob(key_blob);

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
                let key = mem_utils.0.from_blob(key_blob);
                let result = cmp(search_key, key);

                if (result == 0) insertion else if (result == -1) -(insertion + 1) else -(insertion + 2);
            };
            case (_) {
                Debug.print("insertion = " # debug_show insertion);
                Debug.print("arr_len = " # debug_show arr_len);
                Debug.print(
                    "arr = " # debug_show Array.freeze(get_keys(btree, address))
                );
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
                Debug.print(
                    "arr = " # debug_show Array.freeze(get_keys(btree, address))
                );
                Debug.trap("2. binary_search_blob_seq: accessed a null value");
            };
        };
    };

    public func update_count(btree : MemoryBTree, branch_address : Nat, count : Nat) {
        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) branch.0 [AC.COUNT] := count;
            case (? #leaf(_)) Debug.trap("Branch.update_count(): Expected a branch, got a leaf");
            case (_) {};
        };

        MemoryRegion.storeNat16(btree.metadata, branch_address + MC.COUNT_START, Nat16.fromNat(count));
    };

    public func update_subtree_size(btree : MemoryBTree, branch_address : Nat, new_size : Nat) {
        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) branch.0 [AC.SUBTREE_SIZE] := new_size;
            case (? #leaf(_)) Debug.trap("Branch.update_subtree_size(): Expected a branch, got a leaf");
            case (_) {};
        };

        MemoryRegion.storeNat32(btree.metadata, branch_address + MC.SUBTREE_COUNT_START, Nat32.fromNat(new_size));
    };

    public func update_parent(btree : MemoryBTree, branch_address : Nat, opt_parent : ?Nat) {
        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) branch.1 [AC.PARENT] := opt_parent;
            case (? #leaf(_)) Debug.trap("Branch.update_parent(): Expected a branch, got a leaf");
            case (_) {};
        };

        let parent = switch (opt_parent) {
            case (null) MC.NULL_ADDRESS;
            case (?_parent) Nat64.fromNat(_parent);
        };

        MemoryRegion.storeNat64(btree.metadata, branch_address + MC.PARENT_START, parent);
    };

    public func update_median_key(btree : MemoryBTree, parent_address : Nat, child_index : Nat, new_key_block : MemoryBlock, new_key_blob : Blob) {
        var curr_address = parent_address;
        var i = child_index;

        while (i == 0) {
            i := Branch.get_index(btree, curr_address);
            let ?parent_address = Branch.get_parent(btree, curr_address) else return; // occurs when key is the first key in the tree
            curr_address := parent_address;
        };

        Branch.put_key(btree, curr_address, i - 1, new_key_block, new_key_blob);
    };

    // inserts node but does not update the subtree size with the node's subtree size
    // because it's likely that the inserted node is a node split from a node
    // in this branch's subtree
    public func insert(btree : MemoryBTree, branch_address : Nat, i : Nat, key_block : MemoryBlock, key_blob : Blob, child_address : Nat) {
        let count = Branch.get_count(btree, branch_address);

        assert count < btree.order;
        assert i <= count;

        switch (LruCache.peek(btree.nodes_cache, nhash, branch_address)) {
            case (? #branch(branch)) {
                var j = count;

                while (j > i) {
                    branch.2 [j - 1] := branch.2 [j - 2];
                    branch.3 [j] := branch.3 [j - 1];
                    branch.4 [j - 1] := branch.4 [j - 2];

                    j -= 1;
                };

                branch.2 [i - 1] := ?key_block;
                branch.3 [i] := ?child_address;
                branch.4 [i - 1] := ?key_blob;

            };
            case (? #leaf(_)) Debug.trap("Branch.insert(): Expected a branch, got a leaf");
            case (_) {};
        };

        // shift keys and children
        do {
            if (i == 0) {
                // elements inserted are always nodes created as a result of split
                // so their index is always greater than one as new nodes created from
                // a split operation are always inserted at the right
                // update_median_key(btree, branch, i, key);
            } else {
                let key_offset = get_key_offset(branch_address, i - 1);
                let key_end_boundary = get_key_offset(branch_address, count - 1);

                MemoryFns.shift(btree.metadata, key_offset, key_end_boundary, MC.MAX_KEY_SIZE + MC.ADDRESS_SIZE);
                MemoryRegion.storeNat64(btree.metadata, key_offset, Nat64.fromNat(key_block.0));
                MemoryRegion.storeNat16(btree.metadata, key_offset + MC.ADDRESS_SIZE, Nat16.fromNat(key_block.1));
            };

            let child_offset = get_child_offset(btree, branch_address, i);
            let child_end_boundary = get_child_offset(btree, branch_address, count);

            MemoryFns.shift(btree.metadata, child_offset, child_end_boundary, MC.ADDRESS_SIZE);
            MemoryRegion.storeNat64(btree.metadata, child_offset, Nat64.fromNat(child_address));
        };

        // update children index values
        var j = count;

        while (j >= i) {
            // if (j == i) {
            //     branch.2 [j - 1] := ?key;
            //     let #leaf(node) or #branch(node) = child;
            //     branch.3 [j] := ?node.0 [AC.ADDRESS];
            // } else {
            //     branch.2 [j - 1] := branch.2 [j - 2];
            //     branch.3 [j] := branch.3 [j - 1];
            // };

            let ?child_address = Branch.get_child(btree, branch_address, j) else Debug.trap("Branch.insert(): child address is null");

            switch (Branch.get_node_type(btree, child_address)) {
                case ((#branch)) {
                    Branch.update_index(btree, child_address, j);
                };
                case (#leaf) {
                    Leaf.update_index(btree, child_address, j);
                };
            };

            j -= 1;
        };

        Branch.update_count(btree, branch_address, count + 1);

    };

    public func split(btree : MemoryBTree, branch_address : Nat, child_index : Nat, child_key_block : MemoryBlock, child_key_blob : Blob, child : Nat) : Nat {

        let arr_len = btree.order;
        let median = (arr_len / 2) + 1;

        let is_elem_added_to_right = child_index >= median;

        var median_key_block = ?child_key_block;
        var median_key_blob = ?child_key_blob;

        var offset = if (is_elem_added_to_right) 0 else 1;
        var already_inserted = false;

        let right_cnt = arr_len + 1 - median : Nat;
        let right_address = Branch.new(btree);

        var i = 0;
        var elems_removed_from_left = 0;

        while (i < right_cnt) {
            let j = i + median - offset : Nat;

            let child_node = if (j >= median and j == child_index and not already_inserted) {
                offset += 1;
                already_inserted := true;
                if (i > 0) {
                    Branch.put_key(btree, right_address, i - 1, child_key_block, child_key_blob);
                };
                child;
            } else {
                if (i == 0) {
                    median_key_block := Branch.get_key_block(btree, branch_address, j - 1);
                    median_key_blob := Branch.get_key_blob(btree, branch_address, j - 1);
                } else {
                    let ?shifted_key_block = Branch.get_key_block(btree, branch_address, j - 1) else Debug.trap("Branch.split: accessed a null value");
                    let ?shifted_key_blob = Branch.get_key_blob(btree, branch_address, j - 1) else Debug.trap("Branch.split: accessed a null value");
                    Branch.put_key(btree, right_address, i - 1, shifted_key_block, shifted_key_blob);
                };

                // branch.2 [j - 1] := null;
                // branch.0 [AC.COUNT] -= 1;

                elems_removed_from_left += 1;

                let ?child_address = Branch.get_child(btree, branch_address, j) else Debug.trap("Branch.split: accessed a null value");
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
            Branch.insert(btree, branch_address, child_index, child_key_block, child_key_blob, child);
        };

        Branch.update_count(btree, branch_address, median);

        let branch_index = Branch.get_index(btree, branch_address);
        Branch.update_index(btree, right_address, branch_index + 1);

        Branch.update_count(btree, right_address, right_cnt);

        let branch_parent = Branch.get_parent(btree, branch_address);
        Branch.update_parent(btree, right_address, branch_parent);

        // store the first key of the right node at the end of the keys in left node
        // no need to delete as the value will get overwritten because it exceeds the count position
        let ?_median_key_block = median_key_block else Debug.trap("Branch.split: median key_block is null");
        let ?_median_key_blob = median_key_blob else Debug.trap("Branch.split: median key_blob is null");
        Branch.put_key(btree, right_address, btree.order - 2, _median_key_block, _median_key_blob);

        right_address;
    };

    public func get_larger_neighbour(btree : MemoryBTree, parent_address : Address, index : Nat) : ?Address {

        let ?_neighbour = Branch.get_child(btree, parent_address, index) else Debug.trap("1. get_larger_neighbor: accessed a null value");
        var neighbour = _neighbour;

        let parent_count = Branch.get_count(btree, parent_address);

        if (parent_count > 1) {
            if (index != 0) {
                let ?left_neighbour = Branch.get_child(btree, parent_address, index - 1 : Nat) else Debug.trap("1. redistribute_leaf_keys: accessed a null value");
                neighbour := left_neighbour;
            };

            if (index != (parent_count - 1 : Nat)) {
                let ?right_neighbour = Branch.get_child(btree, parent_address, index + 1) else Debug.trap("2. redistribute_leaf_keys: accessed a null value");

                switch (Branch.get_node_type(btree, right_neighbour)) {
                    case (#branch) if (Branch.get_count(btree, right_neighbour) > Branch.get_count(btree, neighbour)) {
                        return ?right_neighbour;
                    };
                    case (#leaf) if (Leaf.get_count(btree, right_neighbour) > Leaf.get_count(btree, neighbour)) {
                        return ?right_neighbour;
                    };
                };
            };
        };

        if (Branch.get_child(btree, parent_address, index) == ?neighbour) return null;

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
        let count = Branch.get_count(btree, branch);

        assert start + offset >= 1;

        if (offset == 0) return;

        switch (LruCache.peek(btree.nodes_cache, nhash, branch)) {
            case (? #leaf(leaf)) if (offset >= 0) {
                var i = end;
                while (i > start) {
                    let prev = i - 1;
                    let curr = Int.abs(offset + i - 1);

                    leaf.2 [curr - 1] := leaf.2 [prev - 1];
                    leaf.3 [curr] := leaf.3 [prev];
                    leaf.4 [curr - 1] := leaf.4 [prev - 1];
                };
            } else {
                var i = start;
                while (i < end) {
                    let curr = Int.abs(offset + i);

                    leaf.2 [curr - 1] := leaf.2 [i - 1];
                    leaf.3 [curr] := leaf.3 [i];
                    leaf.4 [curr - 1] := leaf.4 [i - 1];

                    leaf.2 [i - 1] := null;
                    leaf.3 [i] := null;
                    leaf.4 [i - 1] := null;

                    i += 1;
                };
            };
            case (? #branch(_)) Debug.trap("Branch.shift(): Expected a leaf, got a branch");
            case (_) {};
        };

        if ( start + offset >= 1) {
            let key_offset = get_key_offset(branch, start - 1);
            let key_end_boundary = get_key_offset(branch, end - 1);

            MemoryFns.shift(btree.metadata, key_offset, key_end_boundary, MC.MAX_KEY_SIZE + MC.ADDRESS_SIZE);
        };
        
        let child_offset = get_child_offset(btree, branch, start);
        let child_end_boundary = get_child_offset(btree, branch, end);

        MemoryFns.shift(btree.metadata, child_offset, child_end_boundary, MC.ADDRESS_SIZE);

    };

    // most branch removes are a result of a merge operation
    // the right node is always merged into the left node so it unlikely 
    // that we would need to remove the 0th index, which will cause issues
    // because the keys hold one less value than the children array
    public func remove(btree: MemoryBTree, branch: Address, index: Nat){
        let count = Branch.get_count(btree, branch);

        Leaf.shift(btree, branch, index + 1, count, - 1);
        Leaf.update_count(btree, branch, count - 1);
    };

    public func redistribute(btree: MemoryBTree, branch: Address) : Bool {
        let ?neighbour = Branch.get_larger_neighbour(btree, branch, 0) else return false;

        let branch_count = Branch.get_count(btree, branch);
        let neighbour_count = Branch.get_count(btree, neighbour);

        let sum_count = branch_count + neighbour_count;
        let min_count_for_both_nodes = btree.order;

        if (sum_count < min_count_for_both_nodes) return false;

        let data_to_move = (sum_count / 2) - branch_count;

        let ?parent = Branch.get_parent(btree, branch) else return Debug.trap("Branch.redistribute: parent should not be null");

        var moved_subtree_size = 0;

        let branch_index = Branch.get_index(btree, branch);
        let neighbour_index = Branch.get_index(btree, neighbour);

        if (neighbour_index < branch_index ){
            // move data from the left neighbour to the right branch    
            let ?_median_key_block = Branch.get_key_block(btree, parent, neighbour_index) else return Debug.trap("Branch.redistribute: median_key_block should not be null");
            let ?_median_key_blob = Branch.get_key_blob(btree, parent, neighbour_index) else return Debug.trap("Branch.redistribute: median_key_blob should not be null");

            var median_key_block = _median_key_block;
            var median_key_blob = _median_key_blob;

            Branch.shift(btree, branch, 0, branch_count, data_to_move);

            var i = 0;
            while (i < data_to_move) {
                let j = neighbour_count - 1 - i;

                let ?key_block = Branch.get_key_block(btree, neighbour, j) else return Debug.trap("Branch.redistribute: key_block should not be null");
                let ?key_blob = Branch.get_key_blob(btree, neighbour, j) else return Debug.trap("Branch.redistribute: key_blob should not be null");
                let ?child = Branch.get_child(btree, neighbour, j) else return Debug.trap("Branch.redistribute: child should not be null");
                Branch.remove(btree, neighbour, j);

                let new_index = data_to_move - i - 1;
                Branch.put_key(btree, branch, new_index, median_key_block, median_key_blob);
                Branch.put_child(btree, branch, new_index, child);

                let child_subtree_size = Branch.get_node_subtree_size(btree, child);
                moved_subtree_size += child_subtree_size;

                median_key_block := key_block;
                median_key_blob := key_blob;

                i += 1;
            };

            Branch.put_key(btree, parent, neighbour_index, median_key_block, median_key_blob);

        } else {
            // move data from the right neighbour to the left branch

            let ?_median_key_block = Branch.get_key_block(btree, parent, branch_index) else return Debug.trap("Branch.redistribute: median_key_block should not be null");
            let ?_median_key_blob = Branch.get_key_blob(btree, parent, branch_index) else return Debug.trap("Branch.redistribute: median_key_blob should not be null");
            
            var median_key_block = _median_key_block;
            var median_key_blob = _median_key_blob;

            var i = 0;
            while (i < data_to_move) {
                
                let ?child = Branch.get_child(btree, neighbour, i) else return Debug.trap("Branch.redistribute: child should not be null");
                Branch.insert(btree, branch, branch_count + i, median_key_block, median_key_blob, child);

                let child_subtree_size = Branch.get_node_subtree_size(btree, child);
                moved_subtree_size += child_subtree_size;

                let ?key_block = Branch.get_key_block(btree, neighbour, i) else return Debug.trap("Branch.redistribute: key_block should not be null");
                let ?key_blob = Branch.get_key_blob(btree, neighbour, i) else return Debug.trap("Branch.redistribute: key_blob should not be null");

                median_key_block := key_block;
                median_key_blob := key_blob;

                i += 1;
            };

            // shift keys and children in the right neighbour
            // since we can't shift to the first child index,
            // we will shift to the second index and insert the 
            // value at the first child index manually
            let ?first_child = Branch.get_child(btree, neighbour, data_to_move) else return Debug.trap("Branch.redistribute: first_child should not be null");
            Branch.shift(btree, neighbour, data_to_move + 1, neighbour_count, -data_to_move);
            Branch.put_child(btree, neighbour, 0, first_child);

            // update median key in parent
            Branch.put_key(btree, parent, branch_index, median_key_block, median_key_blob);
        };

        Branch.update_count(btree, branch, branch_count + data_to_move);
        Branch.update_count(btree, neighbour, neighbour_count - data_to_move);

        let branch_subtree_size = Branch.get_subtree_size(btree, branch);
        Branch.update_subtree_size(btree, branch, branch_subtree_size + moved_subtree_size);

        let neighbour_subtree_size = Branch.get_subtree_size(btree, neighbour);
        Branch.update_subtree_size(btree, neighbour, neighbour_subtree_size - moved_subtree_size);

        true;
    };

    public func merge(btree: MemoryBTree, branch: Address) {

    };
};
