import Debug "mo:base/Debug";
import Nat32 "mo:base/Nat32";

import MemoryRegion "mo:memory-region/MemoryRegion";

import V0 "V0";
import V0_0_1 "V0_0_1";
import V0_0_2 "V0_0_2";

module Migrations {

    // should update to the latest version
    public type MemoryBTree = V0_0_2.MemoryBTree;
    public type Leaf = V0_0_2.Leaf;
    public type Branch = V0_0_2.Branch;

    public type VersionedMemoryBTree = {
        #v0 : V0.MemoryBTree;
        #v0_0_1 : V0_0_1.MemoryBTree;
        #v0_0_2 : V0_0_2.MemoryBTree;
    };

    public type StableStore = VersionedMemoryBTree;

    public func upgrade(versions : VersionedMemoryBTree) : VersionedMemoryBTree {
        switch (versions) {
            case (#v0(v0)) {
                Debug.trap("Migration Error: Migrating from #v0 is not supported");
            };
            case (#v0_0_1(v0_0_1)) #v0_0_2({
                v0_0_1 with
                var supports_key_compression = false;
                var branch_count = v0_0_1.branch_count;
                var count = v0_0_1.count;
                var root = v0_0_1.root;
                var depth = v0_0_1.depth;
                var is_root_a_leaf = v0_0_1.is_root_a_leaf;
                var leaf_count = v0_0_1.leaf_count;

            });
            case (#v0_0_2(_)) versions;
        };
    };

    public func getCurrentVersion(versions : VersionedMemoryBTree) : MemoryBTree {
        switch (versions) {
            case (#v0_0_2(curr)) curr;
            case (_) Debug.trap("Unsupported version. Please upgrade the memory buffer to the latest version.");
        };
    };

    public func addVersion(btree : MemoryBTree) : VersionedMemoryBTree {
        #v0_0_2(btree);
    };
};
