import Debug "mo:core@2.4/Debug";
import Runtime "mo:core@2.4/Runtime";
import Nat32 "mo:core@2.4/Nat32";
import Float "mo:core@2.4/Float";
import Int "mo:core@2.4/Int";

import MemoryRegion "mo:memory-region@1.5/MemoryRegion";

import V0 "V0";
import V0_0_1 "V0_0_1";
import V0_4_0 "V0_4_0";

module Migrations {

  // should update to the latest version
  public type MemoryBTree = V0_4_0.MemoryBTree;
  public type Leaf = V0_4_0.Leaf;
  public type Branch = V0_4_0.Branch;
  public type MergeStrategy = V0_4_0.MergeStrategy;

  public type VersionedMemoryBTree = {
    #v0 : V0.MemoryBTree;
    #v0_0_1 : V0_0_1.MemoryBTree;
    #v0_4_0 : V0_4_0.MemoryBTree;
  };

  public type StableStore = VersionedMemoryBTree;

  public func upgrade(versions : VersionedMemoryBTree) : VersionedMemoryBTree {
    switch (versions) {
      case (#v0(v0)) {
        Runtime.trap("Migration Error: Migrating from #v0 is not supported");
      };
      case (#v0_0_1(v0_0_1)) {
        Runtime.trap("Migration Error: Migrating to #v0_4_0 from previous versions is not supported. Please create a new MemoryBTree and migrate data manually.");
        
      };
      case (#v0_4_0(v0_4_0)) versions;
    };
  };

  public func getCurrentVersion(versions : VersionedMemoryBTree) : MemoryBTree {
    switch (versions) {
      case (#v0_4_0(curr)) curr;
      case (_) Runtime.trap("Unsupported version. Please upgrade the memory buffer to the latest version.");
    };
  };

  public func addVersion(btree : MemoryBTree) : VersionedMemoryBTree {
    #v0_4_0(btree);
  };
};
