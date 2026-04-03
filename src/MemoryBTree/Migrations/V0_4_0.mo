import Nat "mo:core@2.4/Nat";

import MemoryRegion "mo:memory-region@1.5/MemoryRegion";
import RevIter "mo:itertools@0.2/RevIter";

import Blobify "../../TypeUtils/Blobify";
import MemoryCmp "../../TypeUtils/MemoryCmp";

module V0_4_0 {

  public type Address = Nat;
  type Size = Nat;

  public type MemoryBlock = (Address, Size);

  type MemoryRegionV1 = MemoryRegion.MemoryRegionV1;
  type Blobify<A> = Blobify.Blobify<A>;
  type RevIter<A> = RevIter.RevIter<A>;

  public type MemoryCmp<A> = MemoryCmp.MemoryCmp<A>;

  /// Merge strategy to use for node merging after deletions.
  /// - #Conservative: Merge only when BOTH nodes are below threshold.
  ///   Very few merges, separator keys stay stable. Good for read-heavy workloads.
  ///   May leave sparse nodes that never merge if neighbour is above threshold.
  /// - #Balanced: Merge when EITHER node is below threshold AND combined fits.
  ///   More merges but better memory efficiency. Cleans up sparse nodes proactively.
  public type MergeStrategy = {
    #Conservative;
    #Balanced;
  };

  public type MemoryBTree = {
    is_set : Bool; // if true, only keys are stored
    node_capacity : Nat;
    var count : Nat;
    var root : Nat;
    var branch_count : Nat; // number of branch nodes
    var leaf_count : Nat; // number of leaf nodes
    var depth : Nat;
    var is_root_a_leaf : Bool;

    leaves : MemoryRegionV1;
    branches : MemoryRegionV1;
    data : MemoryRegionV1;
    values : MemoryRegionV1;

    /// Enable prefix compression for leaf keys.
    /// When enabled, keys in leaf nodes are stored with their common prefix stripped.
    /// The prefix is calculated as common_prefix(left_separator, right_separator) from the parent.
    /// This reduces memory usage for keys with common prefixes (e.g., URLs, file paths).
    /// Note: Only works correctly with lexicographic comparison (e.g., Text, Blob keys).
    /// Requires is_prefix_compression_enabled to be true for optimal results.
    is_prefix_compression_enabled : Bool;

    /// Merge threshold count: number of elements left in a node before merging is allowed.
    /// Calculated from the original merge_threshold float by multiplying with node_capacity.
    /// Nodes are considered "sparse" when they have fewer than merge_threshold_count elements.
    /// - For #Conservative: merge only when BOTH nodes are below this threshold
    /// - For #Balanced: merge when EITHER node is below threshold AND combined fits
    var merge_threshold_count : Nat;
  };

  public type Leaf = (
    nats : [var Nat], // [address, index, count]
    adjacent_nodes : [var ?Nat], // [parent, prev, next] (is_root if parent is null)
    key_blocks : [var ?(MemoryBlock)], // [... ((key address, key size), key blob)]
    val_blocks : [var ?(MemoryBlock)],
    kv_blobs : [var ?(Blob, Blob)],
    _branch_children_nodes : [var ?Nat], // [... child address]
    _branch_keys_blobs : [var ?Blob],
  );

  public type Branch = (
    nats : [var Nat], // [address, index, count, subtree_size]
    parent : [var ?Nat], // parent
    key_blocks : [var ?(MemoryBlock)], // [... ((key address, key size), key blob)]
    _leaf_val_blocks : [var ?(MemoryBlock)],
    _leaf_kv_blobs : [var ?(Blob, Blob)],
    children_nodes : [var ?Nat], // [... child address]
    keys_blobs : [var ?Blob],
  );

};
