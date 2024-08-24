import Debug "mo:base/Debug";
import Nat32 "mo:base/Nat32";

import MemoryRegion "mo:memory-region/MemoryRegion";

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

    public func upgrade(versions : VersionedMemoryBTree) : VersionedMemoryBTree {
        switch (versions) {
            case (#v0(v0)) {
                Debug.trap("Migration Error: Migrating from #v0 is not supported");
            };
            case (#v0_0_1(v0_0_1)) versions;
        };
    };

    public func getCurrentVersion(versions : VersionedMemoryBTree) : MemoryBTree {
        switch (versions) {
            case (#v0_0_1(curr)) curr;
            case (_) Debug.trap("Unsupported version. Please upgrade the memory buffer to the latest version.");
        };
    };

    public func addVersion(btree : MemoryBTree) : VersionedMemoryBTree {
        #v0_0_1(btree);
    };
};
