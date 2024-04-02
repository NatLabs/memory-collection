import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";

import MemoryRegion "mo:memory-region/MemoryRegion";
import LruCache "mo:lru-cache";
import BTree "mo:stableheapbtreemap/BTree";
import RevIter "mo:itertools/RevIter";
// import Branch "mo:augmented-btrees/BpTree/Branch";

import MemoryFns "./MemoryFns";
import Blobify "../Blobify";
import MemoryCmp "../MemoryCmp";
import ArrayMut "ArrayMut";
import MemoryBlock "MemoryBlock";
import T "Types";

module Leaf {
    public type Leaf = T.Leaf;
    type Address = T.Address;
    type MemoryBTree = T.MemoryBTree;
    type MemoryBlock = T.MemoryBlock;
    type MemoryUtils<K, V> = T.MemoryUtils<K, V>;
    type NodeType = T.Node;

    let { nhash } = LruCache;

    public let MAGIC_START = 0;
    public let MAGIC_SIZE = 3;

    public let LAYOUT_VERSION_START = 3;
    public let LAYOUT_VERSION_SIZE = 1;

    public let NODE_TYPE_START = 4;
    public let NODE_TYPE_SIZE = 1;

    public let INDEX_START = 5;
    public let INDEX_SIZE = 2;

    public let COUNT_START = 7;
    public let COUNT_SIZE = 2;

    public let PARENT_START = 9;
    public let ADDRESS_SIZE = 8;

    public let PREV_START = 17;

    public let NEXT_START = 25;

    public let KEYS_START = 33;
    public let MAX_KEY_SIZE = 2;

    public let MAX_VALUE_SIZE = 4;

    public let KEY_MEMORY_BLOCK_SIZE = 10;
    public let VALUE_MEMORY_BLOCK_SIZE = 12;

    // access constants
    public let AC = {
        ADDRESS = 0;
        INDEX = 1;
        COUNT = 2;

        PARENT = 0;
        PREV = 1;
        NEXT = 2;
    };

    public let Flags = {
        IS_LEAF_MASK : Nat8 = 0x80;
        IS_ROOT_MASK : Nat8 = 0x40; // DOUBLES AS HAS_PARENT_MASK
        HAS_PREV_MASK : Nat8 = 0x20;
        HAS_NEXT_MASK : Nat8 = 0x10;
    };

    public let KV_MEMORY_BLOCK_SIZE = 14; // ADDRESS_SIZE + MAX_KEY_SIZE + MAX_VALUE_SIZE
    // public let KV_MEMORY_BLOCK_SIZE_FOR_SET = 10; // ADDRESS_SIZE + MAX_KEY_SIZE

    public let NULL_ADDRESS : Nat64 = 0x00;

    public let MAGIC : Blob = "BTN";

    public let LAYOUT_VERSION : Nat8 = 0;

    public let NODE_TYPE : Nat8 = 1; // leaf

    public func get_memory_size(btree : MemoryBTree) : Nat {
        let bytes_per_node = MAGIC_SIZE // magic
        + LAYOUT_VERSION_SIZE // layout version
        + NODE_TYPE_SIZE // node type
        + ADDRESS_SIZE // parent address
        + INDEX_SIZE // Node's position in parent node
        + ADDRESS_SIZE // prev leaf address
        + ADDRESS_SIZE // next leaf address
        + COUNT_SIZE // number of elements in the node
        // keys
        + (
            (
                ADDRESS_SIZE // address of memory block
                + MAX_KEY_SIZE // key size
            ) * btree.order
        )
        // values
        + (
            (
                ADDRESS_SIZE // address of memory block
                + MAX_VALUE_SIZE // value size
            ) * btree.order
        )
        ;

        bytes_per_node;
    };

    public func get_keys_offset(leaf_address : Nat, i : Nat) : Nat {
        leaf_address + KEYS_START + (i * (Leaf.MAX_KEY_SIZE + Leaf.ADDRESS_SIZE));
    };

    public func get_vals_offset(btree: MemoryBTree, leaf_address : Nat, i: Nat) : Nat {
        get_keys_offset(leaf_address, btree.order) + (i * VALUE_MEMORY_BLOCK_SIZE);
    };

    public func new(btree : MemoryBTree) : Leaf {
        let bytes_per_node = Leaf.get_memory_size(btree);

        let leaf_address = MemoryRegion.allocate(btree.metadata, bytes_per_node);

        MemoryRegion.storeBlob(btree.metadata, leaf_address, Leaf.MAGIC);
        MemoryRegion.storeNat8(btree.metadata, leaf_address + Leaf.LAYOUT_VERSION_START, Leaf.LAYOUT_VERSION); // layout version
        MemoryRegion.storeNat8(btree.metadata, leaf_address + Leaf.NODE_TYPE_START, Leaf.NODE_TYPE); // node type

        MemoryRegion.storeNat16(btree.metadata, leaf_address + Leaf.INDEX_START, 0); // node's position in parent node
        MemoryRegion.storeNat16(btree.metadata, leaf_address + Leaf.COUNT_START, 0); // number of elements in the node

        // adjacent nodes
        MemoryRegion.storeNat64(btree.metadata, leaf_address + Leaf.PARENT_START, NULL_ADDRESS);
        MemoryRegion.storeNat64(btree.metadata, leaf_address + Leaf.PREV_START, NULL_ADDRESS);
        MemoryRegion.storeNat64(btree.metadata, leaf_address + Leaf.NEXT_START, NULL_ADDRESS);

        var i = 0;

        // keys
        while (i < btree.order) {
            let key_offset = get_keys_offset(leaf_address, i);
            MemoryRegion.storeNat64(btree.metadata, key_offset, NULL_ADDRESS);
            MemoryRegion.storeNat16(btree.metadata, key_offset + Leaf.ADDRESS_SIZE, 0);

            i += 1;
        };

        // vals 
        i := 0;
        while (i < btree.order) {
            let val_offset = get_vals_offset(btree, leaf_address, i);
            MemoryRegion.storeNat64(btree.metadata, val_offset, NULL_ADDRESS);
            MemoryRegion.storeNat32(btree.metadata, val_offset + Leaf.ADDRESS_SIZE, 0);

            i += 1;
        };

        let leaf : Leaf = (
            [var leaf_address, 0, 0],
            [var null, null, null],
            Array.init(btree.order, null),
            Array.init(btree.order, null),
        );

        LruCache.put(btree.nodes_cache, nhash, leaf.0 [AC.ADDRESS], #leaf(leaf));

        leaf;
    };

    public func partial_new(btree : MemoryBTree) : Nat {
        let bytes_per_node = Leaf.get_memory_size(btree);

        let leaf_address = MemoryRegion.allocate(btree.metadata, bytes_per_node);

        MemoryRegion.storeBlob(btree.metadata, leaf_address, Leaf.MAGIC);
        MemoryRegion.storeNat8(btree.metadata, leaf_address + Leaf.LAYOUT_VERSION_START, Leaf.LAYOUT_VERSION); // layout version
        MemoryRegion.storeNat8(btree.metadata, leaf_address + Leaf.NODE_TYPE_START, Leaf.NODE_TYPE); // node type

        MemoryRegion.storeNat16(btree.metadata, leaf_address + Leaf.INDEX_START, 0); // node's position in parent node
        MemoryRegion.storeNat16(btree.metadata, leaf_address + Leaf.COUNT_START, 0); // number of elements in the node

        // adjacent nodes
        MemoryRegion.storeNat64(btree.metadata, leaf_address + Leaf.PARENT_START, NULL_ADDRESS);
        MemoryRegion.storeNat64(btree.metadata, leaf_address + Leaf.PREV_START, NULL_ADDRESS);
        MemoryRegion.storeNat64(btree.metadata, leaf_address + Leaf.NEXT_START, NULL_ADDRESS);

        var i = 0;

        // keys
        while (i < btree.order) {
            let key_offset = get_keys_offset(leaf_address, i);
            MemoryRegion.storeNat64(btree.metadata, key_offset, NULL_ADDRESS);
            MemoryRegion.storeNat16(btree.metadata, key_offset + Leaf.ADDRESS_SIZE, 0);

            i += 1;
        };

        // vals 
        i := 0;
        while (i < btree.order) {
            let val_offset = get_vals_offset(btree, leaf_address, i);
            MemoryRegion.storeNat64(btree.metadata, val_offset, NULL_ADDRESS);
            MemoryRegion.storeNat32(btree.metadata, val_offset + Leaf.ADDRESS_SIZE, 0);

            i += 1;
        };

        leaf_address;
    };

    func read_keys_into(btree: MemoryBTree, leaf_address: Nat, keys: [var ?(MemoryBlock, Blob)]){
        var i = 0;

        label while_loop while (i < btree.order) {
            let key_offset = get_keys_offset(leaf_address, i);
            let mb_address = MemoryRegion.loadNat64(btree.metadata, key_offset);

            if (mb_address == NULL_ADDRESS) break while_loop;

            let key_size = MemoryRegion.loadNat16(btree.metadata, key_offset + ADDRESS_SIZE) |> Nat16.toNat(_);
            let key_block = (Nat64.toNat(mb_address), key_size);
            let key_blob = MemoryBlock.get_key(btree, key_block);

            keys [i] := ?(key_block, key_blob);

            i += 1;
        };
    };
    
    public func from_memory(btree : MemoryBTree, leaf_address : Nat) : Leaf {
        assert MemoryRegion.loadBlob(btree.metadata, leaf_address, MAGIC_SIZE) == MAGIC;
        assert MemoryRegion.loadNat8(btree.metadata, leaf_address + LAYOUT_VERSION_START) == LAYOUT_VERSION;
        assert MemoryRegion.loadNat8(btree.metadata, leaf_address + NODE_TYPE_START) == NODE_TYPE;

        let index = MemoryRegion.loadNat16(btree.metadata, leaf_address + INDEX_START) |> Nat16.toNat(_);
        let count = MemoryRegion.loadNat16(btree.metadata, leaf_address + COUNT_START) |> Nat16.toNat(_);

        let parent = do {
            let p = MemoryRegion.loadNat64(btree.metadata, leaf_address + PARENT_START);
            if (p == NULL_ADDRESS) null else ?Nat64.toNat(p);
        };

        let prev_node = do {
            let n = MemoryRegion.loadNat64(btree.metadata, leaf_address + PREV_START);
            if (n == NULL_ADDRESS) null else ?Nat64.toNat(n);
        };

        let next_node = do {
            let n = MemoryRegion.loadNat64(btree.metadata, leaf_address + NEXT_START);
            if (n == NULL_ADDRESS) null else ?Nat64.toNat(n);
        };

        let leaf : Leaf = (
            [var leaf_address, index, count],
            [var parent, prev_node, next_node],
            Array.init(btree.order, null),
            Array.init(btree.order, null),
        );

        var i = 0;

        label while_loop while (i < count) {
            let key_offset = get_keys_offset(leaf_address, i);
            let mb_address = MemoryRegion.loadNat64(btree.metadata, key_offset);

            if (mb_address == NULL_ADDRESS) break while_loop;

            let key_size = MemoryRegion.loadNat16(btree.metadata, key_offset + ADDRESS_SIZE) |> Nat16.toNat(_);
            let key_block = (Nat64.toNat(mb_address), key_size);
            let key_blob = MemoryBlock.get_key(btree, key_block);

            leaf.2 [i] := ?(key_block, key_blob);

            let val_offset = get_vals_offset(btree, leaf_address, i);
            let mb_val_address = MemoryRegion.loadNat64(btree.metadata, val_offset);
            let val_size = MemoryRegion.loadNat32(btree.metadata, val_offset + ADDRESS_SIZE) |> Nat32.toNat(_);

            let val_block = (Nat64.toNat(mb_val_address), val_size);
            let val_blob = MemoryBlock.get_val(btree, val_block);

            leaf.3 [i] := ?(val_block, val_blob);

            i += 1;
        };

        leaf;
    };

    public func from_address(btree : MemoryBTree, address : Nat, update_cache : Bool) : Leaf {
        let result = if (update_cache) {
            LruCache.get(btree.nodes_cache, nhash, address);
        } else {
            LruCache.peek(btree.nodes_cache, nhash, address);
        };

        switch (result) {
            case (? #leaf(leaf)) return leaf;
            case (null) {};
            case (? #branch(_)) Debug.trap("Leaf.from_address: returned branch instead of leaf");
        };

        let leaf = Leaf.from_memory(btree, address);
        if (false) LruCache.put(btree.nodes_cache, nhash, address, #leaf(leaf));
        return leaf;
    };

    public func add_to_cache(btree : MemoryBTree, address : Nat) {
        // update node to first position in cache
        switch(LruCache.get(btree.nodes_cache, nhash, address)){
            case (? #leaf(_)) return;
            case (? #branch(_)) Debug.trap("Leaf.add_to_cache: returned branch instead of leaf");
            case (_) {};
        };

        // loading to the heap is expensive, 
        // so we want to limit the number of nodes we load into the cache
        // this is a nice heuristic that does that
        // performs well when cache is full 
        // if (address % 10 < 5) return;

        // loads from stable memory and adds to cache
        let leaf = Leaf.from_memory(btree, address);
        LruCache.put(btree.nodes_cache, nhash, address, #leaf(leaf));
    };

    public func get_count(btree : MemoryBTree, address : Nat) : Nat {
        switch(LruCache.peek(btree.nodes_cache, nhash, address)){
            case (? #leaf(leaf)) return leaf.0[AC.COUNT];
            case (? #branch(_)) Debug.trap("Leaf.get_keys: returned branch instead of leaf");
            case (_) {};
        };

        MemoryRegion.loadNat16(btree.metadata, address + COUNT_START) |> Nat16.toNat(_);
    };


    public func get_key(btree: MemoryBTree, address: Nat, i: Nat): ?(MemoryBlock, Blob) {
        switch(LruCache.peek(btree.nodes_cache, nhash, address)){
            case (? #leaf(leaf)) return leaf.2[i];
            case (? #branch(_)) Debug.trap("Leaf.get_keys: returned branch instead of leaf");
            case (_) {};
        };

        let key_offset = get_keys_offset(address, i);
        let mb_address = MemoryRegion.loadNat64(btree.metadata, key_offset);
        if (mb_address == NULL_ADDRESS) return null;

        let key_size = MemoryRegion.loadNat16(btree.metadata, key_offset + ADDRESS_SIZE) |> Nat16.toNat(_);
        let key_block = (Nat64.toNat(mb_address), key_size);
        let key_blob = MemoryBlock.get_key(btree, key_block);

        ?(key_block, key_blob);
    };

    public func get_keys(btree: MemoryBTree, address: Nat) : [var ?(MemoryBlock, Blob)]{
        switch(LruCache.peek(btree.nodes_cache, nhash, address)){
            case (? #leaf(leaf)) return leaf.2;
            case (? #branch(_)) Debug.trap("Leaf.get_keys: returned branch instead of leaf");
            case (_) {};
        };

        let keys = Array.init<?(MemoryBlock, Blob)>(btree.order, null);
        read_keys_into(btree, address, keys);
        keys;
    };

    public func get_val(btree : MemoryBTree, address : Nat, index : Nat) : ?(MemoryBlock, Blob) {
        switch(LruCache.peek(btree.nodes_cache, nhash, address)){
            case (? #leaf(leaf)) return leaf.3[index];
            case (? #branch(_)) Debug.trap("Leaf.get_keys: returned branch instead of leaf");
            case (_) {};
        };

        let val_offset = get_vals_offset(btree, address, index);
        let mb_val_address = MemoryRegion.loadNat64(btree.metadata, val_offset);
        if (mb_val_address == NULL_ADDRESS) return null;

        let val_size = MemoryRegion.loadNat32(btree.metadata, val_offset + ADDRESS_SIZE) |> Nat32.toNat(_);
        let val_block = (Nat64.toNat(mb_val_address), val_size);
        let val_blob = MemoryBlock.get_val(btree, val_block);

        ?(val_block, val_blob);
        
    };

    public func get_parent(btree : MemoryBTree, address : Nat) : ?Nat {
        switch(LruCache.peek(btree.nodes_cache, nhash, address)){
            case (? #leaf(leaf)) return leaf.1[AC.PARENT];
            case (? #branch(_)) Debug.trap("Leaf.get_keys: returned branch instead of leaf");
            case (_) {};
        };

        let parent = MemoryRegion.loadNat64(btree.metadata, address + PARENT_START);
        if (parent == NULL_ADDRESS) return null;
        ?Nat64.toNat(parent);
    };

    public func get_index(btree : MemoryBTree, address : Nat) : Nat {
        switch(LruCache.peek(btree.nodes_cache, nhash, address)){
            case (? #leaf(leaf)) return leaf.0[AC.INDEX];
            case (? #branch(_)) Debug.trap("Leaf.get_keys: returned branch instead of leaf");
            case (_) {};
        };

        MemoryRegion.loadNat16(btree.metadata, address + INDEX_START) |> Nat16.toNat(_);
    };

    public func get_next(btree : MemoryBTree, address : Nat) : ?Nat {
        switch(LruCache.peek(btree.nodes_cache, nhash, address)){
            case (? #leaf(leaf)) return leaf.1[AC.NEXT];
            case (? #branch(_)) Debug.trap("Leaf.get_keys: returned branch instead of leaf");
            case (_) {};
        };

        let next = MemoryRegion.loadNat64(btree.metadata, address + NEXT_START);
        if (next == NULL_ADDRESS) return null;
        ?Nat64.toNat(next);
    };

    public func get_prev(btree : MemoryBTree, address : Nat) : ?Nat {
        switch(LruCache.peek(btree.nodes_cache, nhash, address)){
            case (? #leaf(leaf)) return leaf.1[AC.PREV];
            case (? #branch(_)) Debug.trap("Leaf.get_keys: returned branch instead of leaf");
            case (_) {};
        };

        let prev = MemoryRegion.loadNat64(btree.metadata, address + PREV_START);
        if (prev == NULL_ADDRESS) return null;
        ?Nat64.toNat(prev);
    };

    public func binary_search<K, V>(btree: MemoryBTree, mem_utils: MemoryUtils<K, V>, address: Nat, cmp : (K, K) -> Int8, search_key : K, arr_len : Nat) : Int {
        if (arr_len == 0) return -1; // should insert at index Int.abs(i + 1)
        var l = 0;

        // arr_len will always be between 4 and 512
        var r = arr_len - 1 : Nat;

        while (l < r) {
            let mid = (l + r) / 2;

            let ?composite_key = get_key(btree, address, mid) else Debug.trap("1. binary_search_blob_seq: accessed a null value");

            let key_blob = composite_key.1;
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
        switch (get_key(btree, address, insertion)) {
            case (?(_, key_blob)) {
                let key = mem_utils.0.from_blob(key_blob);
                let result = cmp(search_key, key);

                if (result == 0) insertion
                else if (result == -1) -(insertion + 1)
                else  -(insertion + 2);
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

    public func binary_search_blob_seq(btree: MemoryBTree, address : Nat, cmp : (Blob, Blob) -> Int8, search_key : Blob, arr_len : Nat) : Int {
        if (arr_len == 0) return -1; // should insert at index Int.abs(i + 1)
        var l = 0;

        // arr_len will always be between 4 and 512
        var r = arr_len - 1 : Nat;

        while (l < r) {
            let mid = (l + r) / 2;

            let ?key = get_key(btree, address, mid) else Debug.trap("1. binary_search_blob_seq: accessed a null value");

            let key_blob = key.1;
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
        switch (get_key(btree, address,insertion)) {
            case (?(_, key_blob)) {
                let result = cmp(search_key, key_blob);

                if (result == 0) insertion
                else if (result == -1) -(insertion + 1)
                else  -(insertion + 2);
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

    public func update_count(btree : MemoryBTree, leaf : Leaf, new_count : Nat) {
        MemoryRegion.storeNat16(btree.metadata, leaf.0 [AC.ADDRESS] + COUNT_START, Nat16.fromNat(new_count));
        leaf.0 [AC.COUNT] := new_count;
    };

    public func update_index(btree : MemoryBTree, leaf : Leaf, new_index : Nat) {
        MemoryRegion.storeNat16(btree.metadata, leaf.0 [AC.ADDRESS] + INDEX_START, Nat16.fromNat(new_index));
        leaf.0 [AC.INDEX] := new_index;
    };

    public func update_parent(btree : MemoryBTree, leaf : Leaf, opt_parent : ?Nat) {
        let parent = switch (opt_parent) {
            case (null) NULL_ADDRESS;
            case (?_parent) Nat64.fromNat(_parent);
        };

        leaf.1 [AC.PARENT] := opt_parent;
        MemoryRegion.storeNat64(btree.metadata, leaf.0 [AC.ADDRESS] + PARENT_START, parent);
    };

    public func update_next(btree : MemoryBTree, leaf : Leaf, opt_next : ?Nat) {
        let next = switch(opt_next) {
            case (null) NULL_ADDRESS;
            case (?_next) Nat64.fromNat(_next);
        };

        leaf.1 [AC.NEXT] := opt_next;
        MemoryRegion.storeNat64(btree.metadata, leaf.0 [AC.ADDRESS] + NEXT_START, next);
    };

    public func update_prev(btree : MemoryBTree, leaf : Leaf, opt_prev : ?Nat) {
        let prev = switch (opt_prev) {
            case (null) NULL_ADDRESS;
            case (?_prev) Nat64.fromNat(_prev);
        };

        leaf.1 [AC.PREV] := opt_prev;
        MemoryRegion.storeNat64(btree.metadata, leaf.0 [AC.ADDRESS] + PREV_START, prev);
    };

    public func partial_update_count(btree: MemoryBTree, address: Nat, new_count: Nat){
        switch(LruCache.peek(btree.nodes_cache, nhash, address)){
            case (? #leaf(leaf)) leaf.0 [AC.COUNT] := new_count;
            case (? #branch(_)) Debug.trap("Leaf.get_keys: returned branch instead of leaf");
            case (_) {};
        };

        MemoryRegion.storeNat16(btree.metadata, address + COUNT_START, Nat16.fromNat(new_count));
    };

    public func partial_update_index(btree: MemoryBTree, address: Nat, new_index: Nat){
        switch(LruCache.peek(btree.nodes_cache, nhash, address)){
            case (? #leaf(leaf)) leaf.0 [AC.INDEX] := new_index;
            case (? #branch(_)) Debug.trap("Leaf.get_keys: returned branch instead of leaf");
            case (_) {};
        };

        MemoryRegion.storeNat16(btree.metadata, address + INDEX_START, Nat16.fromNat(new_index));
    };

    public func partial_update_parent(btree: MemoryBTree, address: Nat, opt_parent: ?Nat){
        switch(LruCache.peek(btree.nodes_cache, nhash, address)){
            case (? #leaf(leaf)) leaf.1 [AC.PARENT] := opt_parent;
            case (? #branch(_)) Debug.trap("Leaf.get_keys: returned branch instead of leaf");
            case (_) {};
        };

        let parent = switch (opt_parent) {
            case (null) NULL_ADDRESS;
            case (?_parent) Nat64.fromNat(_parent);
        };

        MemoryRegion.storeNat64(btree.metadata, address + PARENT_START, parent);
    };

    public func partial_update_next(btree: MemoryBTree, address: Nat, opt_next: ?Nat){
        switch(LruCache.peek(btree.nodes_cache, nhash, address)){
            case (? #leaf(leaf)) leaf.1 [AC.NEXT] := opt_next;
            case (? #branch(_)) Debug.trap("Leaf.get_keys: returned branch instead of leaf");
            case (_) {};
        };

        let next = switch(opt_next) {
            case (null) NULL_ADDRESS;
            case (?_next) Nat64.fromNat(_next);
        };

        MemoryRegion.storeNat64(btree.metadata, address + NEXT_START, next);
    };

    public func partial_update_prev(btree: MemoryBTree, address: Nat, opt_prev: ?Nat){
        switch(LruCache.peek(btree.nodes_cache, nhash, address)){
            case (? #leaf(leaf)) leaf.1 [AC.PREV] := opt_prev;
            case (? #branch(_)) Debug.trap("Leaf.get_keys: returned branch instead of leaf");
            case (_) {};
        };

        let prev = switch (opt_prev) {
            case (null) NULL_ADDRESS;
            case (?_prev) Nat64.fromNat(_prev);
        };

        MemoryRegion.storeNat64(btree.metadata, address + PREV_START, prev);
    };

    public func partial_insert(btree: MemoryBTree, leaf_address: Nat, index: Nat, key: (MemoryBlock, Blob), val: (MemoryBlock, Blob)){
        let count = Leaf.get_count(btree, leaf_address);
        
        assert index <= count and count < btree.order;

        let key_block = key.0;
        let key_blob = key.1;

        let val_block = val.0;
        let val_blob = val.1;

        switch(LruCache.peek(btree.nodes_cache, nhash, leaf_address)){
            case (? #leaf(leaf)) {
                var i = count;
                while (i > index) {
                    leaf.2 [i] := leaf.2 [i - 1];
                    leaf.3 [i] := leaf.3 [i - 1];
                    i -= 1;
                };

                leaf.2 [index] := ?key;
                leaf.3 [index] := ?val;
            };
            case (? #branch(_)) Debug.trap("Leaf.get_keys: returned branch instead of leaf");
            case (_) {};
        };


        let key_start = get_keys_offset(leaf_address, index);
        let key_end = get_keys_offset(leaf_address, count);

        assert (key_end - key_start) / KEY_MEMORY_BLOCK_SIZE == count - index;

        MemoryFns.shift(btree.metadata, key_start, key_end, KEY_MEMORY_BLOCK_SIZE);
        MemoryRegion.storeNat64(btree.metadata, key_start, Nat64.fromNat(key_block.0));
        MemoryRegion.storeNat16(btree.metadata, key_start + ADDRESS_SIZE, Nat16.fromNat(key_block.1));

        let val_start = get_vals_offset(btree, leaf_address, index);
        let val_end = get_vals_offset(btree, leaf_address, count);

        assert (val_end - val_start) / VALUE_MEMORY_BLOCK_SIZE == count - index;

        MemoryFns.shift(btree.metadata, val_start, val_end, VALUE_MEMORY_BLOCK_SIZE);
        MemoryRegion.storeNat64(btree.metadata, val_start, Nat64.fromNat(val_block.0));
        MemoryRegion.storeNat32(btree.metadata, val_start + ADDRESS_SIZE, Nat32.fromNat(val_block.1));

        Leaf.partial_update_count(btree, leaf_address, count + 1);
    };

    public func insert(btree : MemoryBTree, leaf : Leaf, index : Nat, key : (MemoryBlock, Blob), val : (MemoryBlock, Blob)) {
        assert index <= leaf.0 [AC.COUNT] and leaf.0 [AC.COUNT] < btree.order;

        var i = leaf.0 [AC.COUNT];
        while (i > index) {
            leaf.2 [i] := leaf.2 [i - 1];
            leaf.3 [i] := leaf.3 [i - 1];
            i -= 1;
        };

        let key_block = key.0;
        let key_blob = key.1;

        let val_block = val.0;
        let val_blob = val.1;

        leaf.2 [index] := ?key;
        leaf.3 [index] := ?val;

        let key_start = get_keys_offset(leaf.0 [AC.ADDRESS], index);
        let key_end = get_keys_offset(leaf.0 [AC.ADDRESS], leaf.0 [AC.COUNT]);

        assert (key_end - key_start) / KEY_MEMORY_BLOCK_SIZE == leaf.0 [AC.COUNT] - index;

        MemoryFns.shift(btree.metadata, key_start, key_end, KEY_MEMORY_BLOCK_SIZE);
        MemoryRegion.storeNat64(btree.metadata, key_start, Nat64.fromNat(key_block.0));
        MemoryRegion.storeNat16(btree.metadata, key_start + ADDRESS_SIZE, Nat16.fromNat(key_block.1));

        let val_start = get_vals_offset(btree, leaf.0 [AC.ADDRESS], index);
        let val_end = get_vals_offset(btree, leaf.0 [AC.ADDRESS], leaf.0 [AC.COUNT]);

        assert (val_end - val_start) / VALUE_MEMORY_BLOCK_SIZE == leaf.0 [AC.COUNT] - index;

        MemoryFns.shift(btree.metadata, val_start, val_end, VALUE_MEMORY_BLOCK_SIZE);
        MemoryRegion.storeNat64(btree.metadata, val_start, Nat64.fromNat(val_block.0));
        MemoryRegion.storeNat32(btree.metadata, val_start + ADDRESS_SIZE, Nat32.fromNat(val_block.1));

        Leaf.update_count(btree, leaf, leaf.0 [AC.COUNT] + 1);
    };

    public func put(btree : MemoryBTree, leaf : Leaf, index : Nat, key : (MemoryBlock, Blob), val: (MemoryBlock, Blob)) {

        leaf.2 [index] := ?key;
        let key_block = key.0;

        let key_offset = get_keys_offset(leaf.0 [AC.ADDRESS], index);
        MemoryRegion.storeNat64(btree.metadata, key_offset, Nat64.fromNat(key_block.0));
        MemoryRegion.storeNat16(btree.metadata, key_offset + ADDRESS_SIZE, Nat16.fromNat(key_block.1));

        put_val(btree, leaf, index, val);
    };

    public func partial_put(btree : MemoryBTree, leaf_address : Nat, index : Nat, key : (MemoryBlock, Blob), val: (MemoryBlock, Blob)) {
        switch(LruCache.peek(btree.nodes_cache, nhash, leaf_address)){
            case (? #leaf(leaf)) {
                leaf.2 [index] := ?key;
            };
            case (? #branch(_)) Debug.trap("Leaf.get_keys: returned branch instead of leaf");
            case (_) {};
        };

        let key_block = key.0;

        let key_offset = get_keys_offset(leaf_address, index);
        MemoryRegion.storeNat64(btree.metadata, key_offset, Nat64.fromNat(key_block.0));
        MemoryRegion.storeNat16(btree.metadata, key_offset + ADDRESS_SIZE, Nat16.fromNat(key_block.1));

        partial_put_val(btree, leaf_address, index, val);
    };

    public func partial_put_val(btree : MemoryBTree, leaf_address : Nat, index : Nat, val : (MemoryBlock, Blob)) {
        switch(LruCache.peek(btree.nodes_cache, nhash, leaf_address)){
            case (? #leaf(leaf)) {
                leaf.3[index] := ?val;
            };
            case (? #branch(_)) Debug.trap("Leaf.get_keys: returned branch instead of leaf");
            case (_) {};
        };

        let val_block = val.0;

        let val_offset = get_vals_offset(btree, leaf_address, index);
        MemoryRegion.storeNat64(btree.metadata, val_offset, Nat64.fromNat(val_block.0));
        MemoryRegion.storeNat32(btree.metadata, val_offset + ADDRESS_SIZE, Nat32.fromNat(val_block.1));
    };

    public func put_val(btree : MemoryBTree, leaf : Leaf, index : Nat, val: (MemoryBlock, Blob)) {
        leaf.3 [index] := ?val;
        let val_block = val.0;

        let val_offset = get_vals_offset(btree, leaf.0 [AC.ADDRESS], index);
        MemoryRegion.storeNat64(btree.metadata, val_offset, Nat64.fromNat(val_block.0));
        MemoryRegion.storeNat32(btree.metadata, val_offset + ADDRESS_SIZE, Nat32.fromNat(val_block.1));
    };

    public func partial_split(btree : MemoryBTree, leaf_address : Nat, elem_index : Nat, key : (MemoryBlock, Blob), val: (MemoryBlock, Blob)) : Nat {
        let key_block = key.0;
        let val_block = val.0;

        let arr_len = btree.order;
        let median = (arr_len / 2) + 1;

        let is_elem_added_to_right = elem_index >= median;

        var i = 0;
        let right_cnt = arr_len + 1 - median : Nat;

        let right_leaf_address = Leaf.partial_new(btree);

        var already_inserted = false;
        var offset = if (is_elem_added_to_right) 0 else 1;

        var elems_removed_from_left = 0;
        
        while (i < right_cnt) {
            let j = i + median - offset : Nat;

            if (j >= median and j == elem_index and not already_inserted) {
                offset += 1;
                already_inserted := true;
                Leaf.partial_put(btree, right_leaf_address, i, key, val);

            } else {
                // decrement left leaf count
                // let ?key = ArrayMut.extract(leaf.2, j) else Debug.trap("Leaf.split: key is null");
                // let ?val = ArrayMut.extract(leaf.3, j) else Debug.trap("Leaf.split: val is null");
                let ?key = get_key(btree, leaf_address, j) else Debug.trap("Leaf.split: key is null");
                let ?val = get_val(btree, leaf_address, j) else Debug.trap("Leaf.split: val is null");
                Leaf.partial_put(btree, right_leaf_address, i, key, val);
                elems_removed_from_left += 1;
            };

            i += 1;
        };
        
        Leaf.partial_update_count(btree, leaf_address, arr_len - elems_removed_from_left);

        if (not is_elem_added_to_right) {
            Leaf.partial_insert(btree, leaf_address, elem_index, key, val);
        };

        Leaf.partial_update_count(btree, leaf_address, median);
        Leaf.partial_update_count(btree, right_leaf_address, right_cnt);

        let left_index = Leaf.get_index(btree, leaf_address);
        Leaf.partial_update_index(btree, right_leaf_address, left_index + 1);

        let left_parent = Leaf.get_parent(btree, leaf_address);
        Leaf.partial_update_parent(btree, right_leaf_address, left_parent);

        // update leaf pointers
        Leaf.partial_update_prev(btree, right_leaf_address, ?leaf_address);

        let lefts_next_node = Leaf.get_next(btree, leaf_address);
        Leaf.partial_update_next(btree, right_leaf_address, lefts_next_node);
        Leaf.partial_update_next(btree, leaf_address, ?right_leaf_address);

        
        switch (Leaf.get_next(btree, right_leaf_address)) {
            case (?next_address) {
                Leaf.partial_update_prev(btree, next_address, ?right_leaf_address);
            };
            case (_) {};
        };

        right_leaf_address;
    };

    public func split(btree : MemoryBTree, leaf : Leaf, elem_index : Nat, key : (MemoryBlock, Blob), val: (MemoryBlock, Blob)) : Leaf {
        let key_block = key.0;
        let val_block = val.0;

        let arr_len = leaf.0 [AC.COUNT];
        let median = (arr_len / 2) + 1;

        let is_elem_added_to_right = elem_index >= median;

        var i = 0;
        let right_cnt = arr_len + 1 - median : Nat;

        let right_leaf = Leaf.new(btree);

        var already_inserted = false;
        var offset = if (is_elem_added_to_right) 0 else 1;

        while (i < right_cnt) {
            let j = i + median - offset : Nat;

            if (j >= median and j == elem_index and not already_inserted) {
                offset += 1;
                already_inserted := true;
                Leaf.put(btree, right_leaf, i, key, val);

            } else {
                // decrement left leaf count
                leaf.0 [AC.COUNT] -= 1;
                let ?key = ArrayMut.extract(leaf.2, j) else Debug.trap("Leaf.split: key is null");
                let ?val = ArrayMut.extract(leaf.3, j) else Debug.trap("Leaf.split: val is null");
                Leaf.put(btree, right_leaf, i, key, val);
            };

            i += 1;
        };

        if (not is_elem_added_to_right) {
            Leaf.insert(btree, leaf, elem_index, key, val);
        };

        Leaf.update_count(btree, leaf, median);
        Leaf.update_count(btree, right_leaf, right_cnt);

        Leaf.update_index(btree, right_leaf, leaf.0 [AC.INDEX] + 1);
        Leaf.update_parent(btree, right_leaf, leaf.1 [AC.PARENT]);

        // update leaf pointers
        Leaf.update_prev(btree, right_leaf, ?leaf.0 [AC.ADDRESS]);

        Leaf.update_next(btree, right_leaf, leaf.1 [AC.NEXT]);
        Leaf.update_next(btree, leaf, ?right_leaf.0 [AC.ADDRESS]);

        switch (right_leaf.1 [AC.NEXT]) {
            case (?next) {
                let next_leaf = Leaf.from_address(btree, next, false);
                Leaf.update_prev(btree, next_leaf, ?right_leaf.0 [AC.ADDRESS]);
            };
            case (_) {};
        };

        right_leaf;
    };

};
