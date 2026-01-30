import Nat "mo:base@0.16.0/Nat";

import MemoryRegion "mo:memory-region@1.3.2/MemoryRegion";
import RevIter "mo:itertools@0.2.2/RevIter";

import Blobify "../../TypeUtils/Blobify";
import MemoryCmp "../../TypeUtils/MemoryCmp";

module V1_0_0 {

  public type Address = Nat;
  type Size = Nat;

  public type MemoryBlock = (Address, Size);

  type MemoryRegionV1 = MemoryRegion.MemoryRegionV1;
  type Blobify<A> = Blobify.Blobify<A>;
  type RevIter<A> = RevIter.RevIter<A>;

  public type MemoryCmp<A> = MemoryCmp.MemoryCmp<A>;

  /// Merge strategy to use for node merging after deletions.
  /// - #Conservative: Merge only when BOTH nodes are below threshold.
  ///   Very few merges, separator keys stay stable. Good for read-heavy workloads and tail compression.
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

    /// Enable tail compression for separator keys.
    /// When enabled, separator keys are truncated to the minimum length needed to
    /// distinguish between the last key of the left node and the first key of the right node.
    /// This can significantly reduce memory usage for keys with common prefixes.
    /// Note: Only works correctly with lexicographic comparison (e.g., Text, Blob keys).
    /// For numeric types like Nat that use size-based comparison, this should be disabled.
    is_tail_compression_enabled : Bool;

    /// Merge threshold count: number of elements left in a node before merging is allowed.
    /// Calculated from the original merge_threshold float by multiplying with node_capacity.
    /// Nodes are considered "sparse" when they have fewer than merge_threshold_count elements.
    /// - For #Conservative: merge only when BOTH nodes are below this threshold
    /// - For #Balanced: merge when EITHER node is below threshold AND combined fits
    /// This threshold also affects optimal split position selection when tail compression is enabled:
    /// splits occur at positions > merge_threshold_count and < (node_capacity - merge_threshold_count)
    /// to ensure both resulting nodes have enough elements to avoid immediate merging.
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
