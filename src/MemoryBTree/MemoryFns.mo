import Int "mo:base/Int";
import Array "mo:base/Array";
import Order "mo:base/Order";
import Debug "mo:base/Debug";

import MemoryRegion "mo:memory-region/MemoryRegion";
import MemoryUtils "../MemoryBTree/MemoryUtils";
import T "Types";
import MemoryBlock "../MemoryBTree/MemoryBlock";

module {
    type MemoryRegion = MemoryRegion.MemoryRegion;
    type Order = Order.Order;
    type MemoryBTree = T.MemoryBTree;
    type MemoryUtils<K, V> = T.MemoryUtils<K, V>;

    public func shift(region : MemoryRegion, start : Nat, end : Nat, bytes : Int) {
        let size = (end - start : Nat);

        let blob = MemoryRegion.loadBlob(region, start, size);

        let new_start = if (bytes >= 0) {
            Int.abs(start + bytes)
        } else {
            Int.abs(start - bytes)
        };

        MemoryRegion.storeBlob(region, new_start, blob);
    };

    public func binary_search_blob_seq(region: MemoryRegion, arr : [var ?(Nat, Nat)], cmp : (Blob, Blob) -> Int8, search_key : Blob, arr_len : Nat) : Int {
        if (arr_len == 0) return -1; // should insert at index Int.abs(i + 1)
        var l = 0;

        // arr_len will always be between 4 and 512
        var r = arr_len - 1 : Nat;

        while (l < r) {
            let mid = (l + r) / 2;

            let ?memory_block = arr[mid] else Debug.trap("1. binary_search_blob_seq: accessed a null value");
            let val = MemoryRegion.loadBlob(region, memory_block.0, memory_block.1);

            let result = cmp(search_key, val);

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
        switch (arr[insertion]) {
            case (?memory_block) {
                let val = MemoryRegion.loadBlob(region, memory_block.0, memory_block.1);
                let result = cmp(search_key, val);

                if (result == 0) insertion
                else if (result == -1) -(insertion + 1)
                else  -(insertion + 2);
            };
            case (_) {
                Debug.print("insertion = " # debug_show insertion);
                Debug.print("arr_len = " # debug_show arr_len);
                Debug.print(
                    "arr = " # debug_show Array.freeze(arr)
                );
                Debug.trap("2. binary_search_blob_seq: accessed a null value");
            };
        };
    };

    public func binary_search<K, V>(btree: MemoryBTree, mem_utils: MemoryUtils<K, V>, arr : [var ?(Nat, Nat)], cmp : (K, K) -> Int8, search_key : K, arr_len : Nat) : Int {
        if (arr_len == 0) return -1; // should insert at index Int.abs(i + 1)
        var l = 0;

        // arr_len will always be between 4 and 512
        var r = arr_len - 1 : Nat;

        while (l < r) {
            let mid = (l + r) / 2;

            let ?mb = arr[mid] else Debug.trap("1. binary_search_blob_seq: accessed a null value");
            let key_blob = MemoryBlock.get_key_alt(btree, mb.0, mb.1);
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
        switch (arr[insertion]) {
            case (?mb) {
                let key_blob = MemoryBlock.get_key_alt(btree, mb.0, mb.1);
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
                    "arr = " # debug_show Array.freeze(arr)
                );
                Debug.trap("2. binary_search_blob_seq: accessed a null value");
            };
        };
    };

    public func leaf_binary_search_blob_seq(region: MemoryRegion, arr : [var ?(Nat, Nat, Nat)], cmp : (Blob, Blob) -> Int8, search_key : Blob, arr_len : Nat) : Int {
        if (arr_len == 0) return -1; // should insert at index Int.abs(i + 1)
        var l = 0;

        // arr_len will always be between 4 and 512
        var r = arr_len - 1 : Nat;

        while (l < r) {
            let mid = (l + r) / 2;

            let ?memory_block = arr[mid] else Debug.trap("1. binary_search_blob_seq: accessed a null value");
            let val = MemoryRegion.loadBlob(region, memory_block.0, memory_block.1);

            let result = cmp(search_key, val);

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
        switch (arr[insertion]) {
            case (?memory_block) {
                let val = MemoryRegion.loadBlob(region, memory_block.0, memory_block.1);
                let result = cmp(search_key, val);

                if (result == 0) insertion
                else if (result == -1) -(insertion + 1)
                else  -(insertion + 2);
            };
            case (_) {
                Debug.print("insertion = " # debug_show insertion);
                Debug.print("arr_len = " # debug_show arr_len);
                Debug.print(
                    "arr = " # debug_show Array.freeze(arr)
                );
                Debug.trap("2. binary_search_blob_seq: accessed a null value");
            };
        };
    };

    public func leaf_binary_search<K, V>(btree: MemoryBTree, mem_utils: MemoryUtils<K, V>, arr : [var ?(Nat, Nat, Nat)], cmp : (K, K) -> Int8, search_key : K, arr_len : Nat) : Int {
        if (arr_len == 0) return -1; // should insert at index Int.abs(i + 1)
        var l = 0;

        // arr_len will always be between 4 and 512
        var r = arr_len - 1 : Nat;

        while (l < r) {
            let mid = (l + r) / 2;

            let ?mb = arr[mid] else Debug.trap("1. binary_search_blob_seq: accessed a null value");
            let key_blob = MemoryBlock.get_key(btree, mb);
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
        switch (arr[insertion]) {
            case (?mb) {
                let key_blob = MemoryBlock.get_key(btree, mb);
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
                    "arr = " # debug_show Array.freeze(arr)
                );
                Debug.trap("2. binary_search_blob_seq: accessed a null value");
            };
        };
    };
}