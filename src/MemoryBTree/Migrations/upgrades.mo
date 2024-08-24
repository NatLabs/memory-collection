import Debug "mo:base/Debug";
import Nat32 "mo:base/Nat32";
import Nat16 "mo:base/Nat16";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Iter "mo:base/Iter";

import MemoryRegion "mo:memory-region/MemoryRegion";
import Itertools "mo:itertools/Iter";

import V0 "V0";
import V0_0_1 "V0_0_1";

module Migrations {

    // should update to the latest version
    public type MemoryBTree = V0_0_1.MemoryBTree;
    public type Leaf = V0_0_1.Leaf;
    public type Branch = V0_0_1.Branch;

    public type VersionedMemoryBTree = {
        #v0 : V0.MemoryBTree;
        #v0_0_1 : V0_0_1.MemoryBTree;
    };

    public type StableStore = VersionedMemoryBTree;
    type Address = Nat;

    public func get_depth(btree : MemoryBTree, node_address : Nat) : Nat {
        let depth = MemoryRegion.loadNat8(btree.branches, node_address + 3) |> Nat8.toNat(_);

        depth;
    };

    public func has_leaves(btree : MemoryBTree, branch_address : Nat) : Bool {
        let depth = get_depth(btree, branch_address);
        depth == 2;
    };

    public func CHILDREN_START(btree : MemoryBTree) : Nat {
        64 + ((btree.node_capacity - 1) * 8);
    };
    public func get_child_offset(btree : MemoryBTree, branch_address : Nat, i : Nat) : Nat {
        branch_address + CHILDREN_START(btree) + (i * 8);
    };
    public func get_child(btree : MemoryBTree, branch_address : Nat, i : Nat) : ?Nat {

        MemoryRegion.loadNat64(btree.branches, get_child_offset(btree, branch_address, i))
        |> ?Nat64.toNat(_);
    };

    public func get_min_leaf_address(btree : MemoryBTree) : Nat {
        var curr = btree.root;
        var is_address_a_leaf = btree.is_root_a_leaf;

        loop {
            switch (is_address_a_leaf) {
                case (false) {
                    let ?first_child = get_child(btree, curr, 0) else Debug.trap("get_min_leaf: accessed a null value");
                    is_address_a_leaf := has_leaves(btree, curr);
                    curr := first_child;
                };
                case (true) return curr;
            };
        };
    };

    public func get_kv_address_offset(leaf_address : Nat, i : Nat) : Nat {
        leaf_address + 64 + (i * 8);
    };

    public func leaf_get_kv_address(btree : MemoryBTree, address : Nat, i : Nat) : ?Nat {
        let kv_address_offset = get_kv_address_offset(address, i);
        let opt_id = MemoryRegion.loadNat64(btree.leaves, kv_address_offset);

        if (opt_id == 0x00) null else ?(Nat64.toNat(opt_id));
    };

    public func leaf_get_count(btree : MemoryBTree, address : Nat) : Nat {
        MemoryRegion.loadNat16(btree.leaves, address + 6) |> Nat16.toNat(_);
    };
    public func leaf_get_kv_address_offset(leaf_address : Nat, i : Nat) : Nat {
        leaf_address + 64 + (i * 8);
    };

    public func leaf_get_next(btree : MemoryBTree, address : Nat) : ?Nat {

        let next = MemoryRegion.loadNat64(btree.leaves, address + 24);
        if (next == 0x00) return null;
        ?Nat64.toNat(next);
    };

    public func kv_block_addresses(btree : MemoryBTree) : Iter.Iter<Address> {

        let min_leaf = get_min_leaf_address(btree);
        var i = 0;
        var leaf_count = leaf_get_count(btree, min_leaf);
        var var_leaf = ?min_leaf;

        object {
            public func next() : ?Address {
                let ?leaf = var_leaf else return null;

                if (i >= leaf_count) {
                    switch (leaf_get_next(btree, leaf)) {
                        case (null) var_leaf := null;
                        case (?next_address) {
                            var_leaf := ?next_address;
                            leaf_count := leaf_get_count(btree, leaf);
                        };
                    };

                    i := 0;
                    return next();
                };

                let address = leaf_get_kv_address(btree, leaf, i);
                i += 1;
                return address;
            };
        };

    };

    public func upgrade(versions : VersionedMemoryBTree) : VersionedMemoryBTree {
        switch (versions) {
            case (#v0(v0)) {
                let values = MemoryRegion.new();

                let VALUES_REGION_ID_ADDRESS = 32;
                MemoryRegion.storeNat32(v0.data, VALUES_REGION_ID_ADDRESS, Nat32.fromNat(MemoryRegion.id(values)));

                // move all values from data region to values region
                // might not upgrade if the data is too large

                let REFERENCE_COUNT_START = 0;
                let KEY_SIZE_START = 1;
                let VAL_POINTER_START = 3;
                let VAL_SIZE_START = 11;
                let KEY_BLOB_START = 15;

                let BLOCK_ENTRY_SIZE = 15;

                var key_block_address = 64;

                for (i in Itertools.range(0, v0.count)) {
                    let key_size = MemoryRegion.loadNat16(v0.data, key_block_address + KEY_SIZE_START) |> Nat16.toNat(_);
                    let val_size = MemoryRegion.loadNat32(v0.data, key_block_address + VAL_SIZE_START) |> Nat32.toNat(_);
                    let val_address = MemoryRegion.loadNat64(v0.data, key_block_address + VAL_POINTER_START) |> Nat64.toNat(_);

                    let val_blob = MemoryRegion.loadBlob(v0.data, val_address, val_size);
                    MemoryRegion.deallocate(v0.data, val_address, val_size);

                    let new_val_address = MemoryRegion.addBlob(values, val_blob);

                    MemoryRegion.storeNat64(v0.data, key_block_address + VAL_POINTER_START, Nat64.fromNat(new_val_address));

                    key_block_address += BLOCK_ENTRY_SIZE + key_size + val_size;

                };

                #v0_0_1({
                    v0 with values;
                    var count = v0.count;
                    var root = v0.root;
                    var branch_count = v0.branch_count;
                    var leaf_count = v0.leaf_count;
                    var depth = v0.depth;
                    var is_root_a_leaf = v0.is_root_a_leaf;
                });
            };
            case (#v0_0_1(v0_0_1)) versions;
        };
    };

};
