import Debug "mo:base@0.14.13/Debug";
import Nat32 "mo:base@0.14.13/Nat32";
import Float "mo:base@0.14.13/Float";
import Int "mo:base@0.14.13/Int";

import MemoryRegion "mo:memory-region@1.4.0/MemoryRegion";

import V0 "V0";
import V0_0_1 "V0_0_1";
import V1_0_0 "V1_0_0";

module Migrations {

  // should update to the latest version
  public type MemoryBTree = V1_0_0.MemoryBTree;
  public type Leaf = V1_0_0.Leaf;
  public type Branch = V1_0_0.Branch;
  public type MergeStrategy = V1_0_0.MergeStrategy;

  public type VersionedMemoryBTree = {
    #v0 : V0.MemoryBTree;
    #v0_0_1 : V0_0_1.MemoryBTree;
    #v1_0_0 : V1_0_0.MemoryBTree;
  };

  public type StableStore = VersionedMemoryBTree;

  public func upgrade(versions : VersionedMemoryBTree) : VersionedMemoryBTree {
    switch (versions) {
      case (#v0(v0)) {
        Debug.trap("Migration Error: Migrating from #v0 is not supported");
      };
      case (#v0_0_1(v0_0_1)) {
        // Migrate from v0_0_1 to v1_0_0 with default values for new fields
        let default_merge_threshold = 0.25;
        let merge_threshold_count : Nat = Float.toInt(Float.fromInt(v0_0_1.node_capacity) * default_merge_threshold)
          |> Int.abs(_);
        
        #v1_0_0({
          is_set = v0_0_1.is_set;
          node_capacity = v0_0_1.node_capacity;
          var count = v0_0_1.count;
          var root = v0_0_1.root;
          var branch_count = v0_0_1.branch_count;
          var leaf_count = v0_0_1.leaf_count;
          var depth = v0_0_1.depth;
          var is_root_a_leaf = v0_0_1.is_root_a_leaf;
          leaves = v0_0_1.leaves;
          branches = v0_0_1.branches;
          data = v0_0_1.data;
          values = v0_0_1.values;
          // Default values for new fields
          is_tail_compression_enabled = false;
          var merge_threshold_count;
        });
      };
      case (#v1_0_0(v1_0_0)) versions;
    };
  };

  public func getCurrentVersion(versions : VersionedMemoryBTree) : MemoryBTree {
    switch (versions) {
      case (#v1_0_0(curr)) curr;
      case (_) Debug.trap("Unsupported version. Please upgrade the memory buffer to the latest version.");
    };
  };

  public func addVersion(btree : MemoryBTree) : VersionedMemoryBTree {
    #v1_0_0(btree);
  };
};
