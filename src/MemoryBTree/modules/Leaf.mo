/// Leaf Node Operations

import Debug "mo:base@0.14.13/Debug";
import Array "mo:base@0.14.13/Array";
import Nat "mo:base@0.14.13/Nat";
import Nat8 "mo:base@0.14.13/Nat8";
import Nat16 "mo:base@0.14.13/Nat16";
import Nat64 "mo:base@0.14.13/Nat64";
import Int "mo:base@0.14.13/Int";
import Float "mo:base@0.14.13/Float";
import Blob "mo:base@0.14.13/Blob";

import MemoryRegion "mo:memory-region@1.4.0/MemoryRegion";

import MemoryFns "MemoryFns";
import MemoryBlock "MemoryBlock";
import T "Types";
import Migrations "../Migrations";
import Utils "../../Utils";
import Common "Common";

module Leaf {
  public type Leaf = Migrations.Leaf;
  type Address = T.Address;
  type MemoryBTree = Migrations.MemoryBTree;
  type MemoryBlock = T.MemoryBlock;
  type BTreeUtils<K, V> = T.BTreeUtils<K, V>;
  type UniqueId = T.UniqueId;

  public let HEADER_SIZE = 64;

  public let MAGIC_START = 0;
  public let MAGIC_SIZE = 3;

  public let DEPTH_START = 3;
  public let DEPTH_SIZE = 1;

  public let INDEX_START = 4;
  public let INDEX_SIZE = 2;

  public let COUNT_START = 6;
  public let COUNT_SIZE = 2;

  public let PARENT_START = 8;
  public let ADDRESS_SIZE = 8;

  public let PREV_START = 16;

  public let NEXT_START = 24;

  public let KV_IDS_START = HEADER_SIZE;

  // access constants
  public let AC = {
    ADDRESS = 0;
    INDEX = 1;
    COUNT = 2;

    PARENT = 0;
    PREV = 1;
    NEXT = 2;
  };

  public let NULL_ADDRESS : Nat64 = 0;

  public let MAGIC : Blob = "LND";

  public let DEPTH : Nat8 = 1;

  public let NODE_TYPE : Nat8 = 1; // leaf

  public func get_memory_size(node_capacity : Nat) : Nat {
    let bytes_per_node = HEADER_SIZE + (ADDRESS_SIZE * node_capacity); // key-value pairs

    bytes_per_node;
  };

  public func get_kv_address_offset(leaf_address : Nat, i : Nat) : Nat {
    leaf_address + KV_IDS_START + (i * Leaf.ADDRESS_SIZE);
  };

  public func new(btree : MemoryBTree) : Nat {
    let bytes_per_node = Leaf.get_memory_size(btree.node_capacity);

    let leaf_address = MemoryRegion.allocate(btree.leaves, bytes_per_node);

    MemoryRegion.storeBlob(btree.leaves, leaf_address, Leaf.MAGIC);
    MemoryRegion.storeNat8(btree.leaves, leaf_address + Leaf.DEPTH_START, Leaf.DEPTH); // depth

    MemoryRegion.storeNat16(btree.leaves, leaf_address + Leaf.INDEX_START, 0); // node's position in parent node
    MemoryRegion.storeNat16(btree.leaves, leaf_address + Leaf.COUNT_START, 0); // number of elements in the node

    // adjacent nodes
    MemoryRegion.storeNat64(btree.leaves, leaf_address + Leaf.PARENT_START, NULL_ADDRESS);
    MemoryRegion.storeNat64(btree.leaves, leaf_address + Leaf.PREV_START, NULL_ADDRESS);
    MemoryRegion.storeNat64(btree.leaves, leaf_address + Leaf.NEXT_START, NULL_ADDRESS);

    var i = 0;

    // keys
    while (i < btree.node_capacity) {
      let key_offset = get_kv_address_offset(leaf_address, i);
      MemoryRegion.storeNat64(btree.leaves, key_offset, NULL_ADDRESS);
      i += 1;
    };

    // loads from stable memory and adds to cache

    leaf_address;
  };

  public func validate(btree : MemoryBTree, leaf_address : Nat) : Bool {
    let magic_number = get_magic(btree, leaf_address);
    // Debug.print("received magic " # debug_show (magic_number, MAGIC));

    let is_valid_node = (magic_number) == MAGIC;

    let depth = get_depth(btree, leaf_address);
    // Debug.print("received depth " # debug_show (depth));

    let is_leaf_depth = depth == 1;

    return is_valid_node and is_leaf_depth;

  };

  public func from_memory(btree : MemoryBTree, leaf_address : Nat) : Leaf {
    // assert Leaf.validate(btree, address);

    let leaf : Leaf = (
      [var 0, 0, 0, 0],
      [var null, null, null],
      Array.init(btree.node_capacity, null),
      Array.init(btree.node_capacity, null),
      Array.init(btree.node_capacity, null),
      Array.init<?Nat>(btree.node_capacity, null),
      Array.init(btree.node_capacity, null),
    );

    from_memory_into(btree, leaf_address, leaf, true);

    leaf;
  };

  public func from_memory_into(btree : MemoryBTree, leaf_address : Nat, leaf : Leaf, load_keys : Bool) {
    assert MemoryRegion.loadBlob(btree.leaves, leaf_address, MAGIC_SIZE) == MAGIC;
    // assert MemoryRegion.loadNat8(btree.leaves, leaf_address + DEPTH_START) == DEPTH;
    // assert MemoryRegion.loadNat8(btree.leaves, leaf_address + NODE_TYPE_START) == NODE_TYPE;

    leaf.0 [AC.ADDRESS] := leaf_address;
    leaf.0 [AC.INDEX] := MemoryRegion.loadNat16(btree.leaves, leaf_address + INDEX_START) |> Nat16.toNat(_);
    leaf.0 [AC.COUNT] := MemoryRegion.loadNat16(btree.leaves, leaf_address + COUNT_START) |> Nat16.toNat(_);

    leaf.1 [AC.PARENT] := do {
      let p = MemoryRegion.loadNat64(btree.leaves, leaf_address + PARENT_START);
      if (p == NULL_ADDRESS) null else ?Nat64.toNat(p);
    };

    leaf.1 [AC.PREV] := do {
      let n = MemoryRegion.loadNat64(btree.leaves, leaf_address + PREV_START);
      if (n == NULL_ADDRESS) null else ?Nat64.toNat(n);
    };

    leaf.1 [AC.NEXT] := do {
      let n = MemoryRegion.loadNat64(btree.leaves, leaf_address + NEXT_START);
      if (n == NULL_ADDRESS) null else ?Nat64.toNat(n);
    };

    var i = 0;

    label while_loop while (i < leaf.0 [AC.COUNT]) {
      let key_address : Nat = get_kv_address(btree, leaf_address, i) |> Utils.unwrap(_, "Leaf.from_memory_into: key_address is null");
      // Debug.print("cmp: " # debug_show (key_address, NULL_ADDRESS));
      // Debug.print("is null = " # debug_show (Nat64.fromNat(key_address) == NULL_ADDRESS));
      // Debug.print("is null = " # debug_show (Nat64.equal(Nat64.fromNat(key_address), NULL_ADDRESS)));

      if (key_address == Nat64.toNat(NULL_ADDRESS)) {
        leaf.2 [i] := null;
        leaf.3 [i] := null;
        leaf.4 [i] := null;
        i += 1;
        continue while_loop;
      };

      // Debug.print("key_address = " # debug_show key_address);

      let key_block = MemoryBlock.get_key_block(btree, key_address);
      let key_blob = MemoryBlock.get_key_blob(btree, key_address);
      // Debug.print("key_blob = " # debug_show key_blob);

      leaf.2 [i] := ?(key_block);

      let val_block = MemoryBlock.get_val_block(btree, key_address);
      let val_blob = MemoryBlock.get_val_blob(btree, key_address);
      // Debug.print("val_blob = " # debug_show val_blob);
      leaf.3 [i] := ?(val_block);
      leaf.4 [i] := ?(key_blob, val_blob);

      i += 1;
    };

    // while (i < leaf.0[AC.COUNT]){
    //     leaf.2 [i] := null;
    //     leaf.3 [i] := null;
    //     leaf.4 [i] := null;
    //     i += 1;
    // };

    // i := 0;
    // while (i < leaf.0[AC.COUNT]) {
    //     leaf.5 [i] := null;
    //     leaf.6 [i] := null;
    //     i += 1;
    // };

  };



  public func display(btree : MemoryBTree, btree_utils : BTreeUtils<Nat, Nat>, leaf_address : Nat) {
  };

  public func get_count(btree : MemoryBTree, leaf_address : Nat) : Nat {
    // assert Leaf.validate(btree, leaf_address);

    MemoryRegion.loadNat16(btree.leaves, leaf_address + COUNT_START) |> Nat16.toNat(_);
  };

  public func get_kv_address(btree : MemoryBTree, leaf_address : Nat, i : Nat) : ?UniqueId {
    // assert Leaf.validate(btree, leaf_address);
    let kv_address_offset = get_kv_address_offset(leaf_address, i);
    let opt_id = MemoryRegion.loadNat64(btree.leaves, kv_address_offset);

    if (opt_id == NULL_ADDRESS) null else ?(Nat64.toNat(opt_id));
  };

  public func get_key_block(btree : MemoryBTree, leaf_address : Nat, i : Nat) : ?MemoryBlock {
    // assert Leaf.validate(btree, leaf_address);
    let ?id = get_kv_address(btree, leaf_address, i) else return null;
    ?MemoryBlock.get_key_block(btree, id);
  };

  public func get_val_block(btree : MemoryBTree, leaf_address : Nat, i : Nat) : ?MemoryBlock {
    // assert Leaf.validate(btree, leaf_address);
    let ?id = get_kv_address(btree, leaf_address, i) else return null;
    ?MemoryBlock.get_val_block(btree, id);
  };

  public func get_key_blob(btree : MemoryBTree, leaf_address : Nat, i : Nat) : ?(Blob) {
    // assert Leaf.validate(btree, leaf_address);
    let ?id = get_kv_address(btree, leaf_address, i) else return null;
    ?MemoryBlock.get_key_blob(btree, id);
  };

  public func set_key_to_null(btree : MemoryBTree, leaf_address : Nat, i : Nat) {
    // assert Leaf.validate(btree, leaf_address);

    let id_offset = get_kv_address_offset(leaf_address, i);
    MemoryRegion.storeNat64(btree.leaves, id_offset, NULL_ADDRESS);
  };

  public func get_val_blob(btree : MemoryBTree, leaf_address : Nat, index : Nat) : ?(Blob) {
    // assert Leaf.validate(btree, leaf_address);

    let ?id = get_kv_address(btree, leaf_address, index) else return null;
    ?MemoryBlock.get_val_blob(btree, id);
  };

  public func set_kv_to_null(btree : MemoryBTree, leaf_address : Nat, i : Nat) {
    // assert Leaf.validate(btree, leaf_address);

    let key_offset = get_kv_address_offset(leaf_address, i);
    MemoryRegion.storeNat64(btree.leaves, key_offset, NULL_ADDRESS);
  };

  public func get_kv_blobs(btree : MemoryBTree, leaf_address : Nat, index : Nat) : ?(Blob, Blob) {
    // assert Leaf.validate(btree, leaf_address);
    let ?id = get_kv_address(btree, leaf_address, index) else return null;
    // Debug.print("get_kv_blobs: id = " # debug_show id);
    let key_blob = MemoryBlock.get_key_blob(btree, id);
    let val_blob = MemoryBlock.get_val_blob(btree, id);

    ?(key_blob, val_blob);

  };

  public func get_depth(btree : MemoryBTree, leaf_address : Nat) : Nat {
    let depth = MemoryRegion.loadNat8(btree.leaves, leaf_address + DEPTH_START) |> Nat8.toNat(_);

    depth;
  };

  public func get_magic(btree : MemoryBTree, leaf_address : Nat) : Blob {
    MemoryRegion.loadBlob(btree.leaves, leaf_address, MAGIC_SIZE);
  };

  public func get_parent(btree : MemoryBTree, leaf_address : Nat) : ?Nat {
    // assert Leaf.validate(btree, leaf_address);

    let parent = MemoryRegion.loadNat64(btree.leaves, leaf_address + PARENT_START);
    if (parent == NULL_ADDRESS) return null;
    ?Nat64.toNat(parent);
  };

  public func get_index(btree : MemoryBTree, leaf_address : Nat) : Nat {
    // assert Leaf.validate(btree, leaf_address);
    MemoryRegion.loadNat16(btree.leaves, leaf_address + INDEX_START) |> Nat16.toNat(_);
  };

  public func get_next(btree : MemoryBTree, leaf_address : Nat) : ?Nat {
    // assert Leaf.validate(btree, leaf_address);

    let next = MemoryRegion.loadNat64(btree.leaves, leaf_address + NEXT_START);
    if (next == NULL_ADDRESS) return null;
    ?Nat64.toNat(next);
  };

  public func get_prev(btree : MemoryBTree, leaf_address : Nat) : ?Nat {
    // assert Leaf.validate(btree, leaf_address);

    let prev = MemoryRegion.loadNat64(btree.leaves, leaf_address + PREV_START);
    if (prev == NULL_ADDRESS) return null;
    ?Nat64.toNat(prev);
  };

  public func binary_search_blob_seq(btree : MemoryBTree, leaf_address : Nat, cmp : (Blob, Blob) -> Int8, search_key : Blob, arr_len : Nat) : Int {
    // assert Leaf.validate(btree, leaf_address);
    if (arr_len == 0) return -1; // should insert at index Int.abs(i + 1)
    var l = 0;

    // arr_len will always be between 4 and 512
    var r = arr_len - 1 : Nat;

    while (l < r) {
      let mid = (l + r) / 2;

      let ?key_blob = Leaf.get_key_blob(btree, leaf_address, mid) else Debug.trap("1. binary_search_blob_seq: accessed a null value");
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
    switch (Leaf.get_key_blob(btree, leaf_address, insertion)) {
      case (?(key_blob)) {
        let result = cmp(search_key, key_blob);

        if (result == 0) insertion else if (result == -1) -(insertion + 1) else -(insertion + 2);
      };
      case (_) {
        Debug.print("insertion = " # debug_show insertion);
        Debug.print("arr_len = " # debug_show arr_len);
        // Debug.print(
        //     "arr = " # debug_show Array.freeze(get_keys(btree, address))
        // );
        Debug.trap("2. binary_search_blob_seq: accessed a null value");
      };
    };
  };

  public func update_count(btree : MemoryBTree, leaf_address : Nat, new_count : Nat) {
    // assert Leaf.validate(btree, leaf_address);

    MemoryRegion.storeNat16(btree.leaves, leaf_address + COUNT_START, Nat16.fromNat(new_count));
  };

  public func update_depth(btree : MemoryBTree, leaf_address : Nat, new_depth : Nat) {
    // assert Leaf.validate(btree, leaf_address);
    MemoryRegion.storeNat8(btree.leaves, leaf_address + DEPTH_START, Nat8.fromNat(new_depth));
  };

  public func update_index(btree : MemoryBTree, leaf_address : Nat, new_index : Nat) {
    // assert Leaf.validate(btree, leaf_address);

    MemoryRegion.storeNat16(btree.leaves, leaf_address + INDEX_START, Nat16.fromNat(new_index));
  };

  public func update_parent(btree : MemoryBTree, leaf_address : Nat, opt_parent : ?Nat) {
    // assert Leaf.validate(btree, leaf_address);

    let parent = switch (opt_parent) {
      case (null) NULL_ADDRESS;
      case (?_parent) Nat64.fromNat(_parent);
    };

    MemoryRegion.storeNat64(btree.leaves, leaf_address + PARENT_START, parent);
  };

  public func update_next(btree : MemoryBTree, leaf_address : Nat, opt_next : ?Nat) {
    // assert Leaf.validate(btree, leaf_address);

    let next = switch (opt_next) {
      case (null) NULL_ADDRESS;
      case (?_next) Nat64.fromNat(_next);
    };

    MemoryRegion.storeNat64(btree.leaves, leaf_address + NEXT_START, next);
  };

  public func update_prev(btree : MemoryBTree, leaf_address : Nat, opt_prev : ?Nat) {
    // assert Leaf.validate(btree, leaf_address);

    let prev = switch (opt_prev) {
      case (null) NULL_ADDRESS;
      case (?_prev) Nat64.fromNat(_prev);
    };

    MemoryRegion.storeNat64(btree.leaves, leaf_address + PREV_START, prev);
  };

  public func clear(btree : MemoryBTree, leaf_address : Nat) {
    // assert Leaf.validate(btree, leaf_address);
    Leaf.update_index(btree, leaf_address, 0);
    Leaf.update_count(btree, leaf_address, 0);
    Leaf.update_parent(btree, leaf_address, null);
    Leaf.update_prev(btree, leaf_address, null);
    Leaf.update_next(btree, leaf_address, null);
  };

  public func insert(btree : MemoryBTree, leaf_address : Nat, index : Nat, new_id : UniqueId) {
    // assert Leaf.validate(btree, leaf_address);
    let count = Leaf.get_count(btree, leaf_address);

    assert index <= count and count < btree.node_capacity;

    let start = get_kv_address_offset(leaf_address, index);
    let end = get_kv_address_offset(leaf_address, count);

    assert (end - start : Nat) / ADDRESS_SIZE == (count - index : Nat);

    MemoryFns.shift(btree.leaves.region, start, end, ADDRESS_SIZE);
    MemoryRegion.storeNat64(btree.leaves, start, Nat64.fromNat(new_id));

    Leaf.update_count(btree, leaf_address, count + 1);
  };

  public func insert_with_count(btree : MemoryBTree, leaf_address : Nat, index : Nat, new_id : UniqueId, count : Nat) {
    // assert Leaf.validate(btree, leaf_address);
    assert index <= count and count < btree.node_capacity;

    let start = get_kv_address_offset(leaf_address, index);
    let end = get_kv_address_offset(leaf_address, count);

    assert (end - start : Nat) / ADDRESS_SIZE == (count - index : Nat);

    MemoryFns.shift(btree.leaves.region, start, end, ADDRESS_SIZE);
    MemoryRegion.storeNat64(btree.leaves, start, Nat64.fromNat(new_id));

    Leaf.update_count(btree, leaf_address, count + 1);
  };

  public func put(btree : MemoryBTree, leaf_address : Nat, index : Nat, new_id : UniqueId) {
    // assert Leaf.validate(btree, leaf_address);

    let id_offset = get_kv_address_offset(leaf_address, index);
    MemoryRegion.storeNat64(btree.leaves, id_offset, Nat64.fromNat(new_id));
  };

  /// Calculates the optimal split position for a B-tree leaf node when inserting a new key.
  /// This function finds the best place to split a full leaf node, optimizing for tail compression.
  ///
  /// The function searches within a range bounded by merge_threshold to ensure both resulting
  /// nodes have enough elements to avoid immediate merging after deletions:
  /// - min_split_index = merge_threshold_count + 1 (ensures left node has at least threshold elements)
  /// - max_split_index = node_capacity - merge_threshold_count (ensures right node has at least threshold elements)
  ///
  /// Within this range, it finds the position where the separator (first key of right node) has
  /// the smallest common prefix with the last key of the left node, maximizing tail compression benefit.
  ///
  /// Parameters:
  /// - btree: The B-tree instance
  /// - leaf_address: Address of the leaf node being split
  /// - elem_index: Position where new element would be inserted (0 to node_capacity)
  /// - new_key_blob: The key blob of the element being inserted
  /// - merge_threshold_count: The minimum number of elements allowed in a node before merging
  ///
  /// Returns: The optimal split index (first element of right node after split)
  public func get_optimal_split_position(btree : MemoryBTree, leaf_address : Nat, elem_index : Nat, new_key_blob : Blob) : Nat {
    let node_capacity = btree.node_capacity;
    let merge_threshold_count = btree.merge_threshold_count;
    
    // After split, we have node_capacity + 1 total elements (including the new one)
    let total_after_insert = node_capacity + 1;

    // Split position = first index of right node
    // Left node will have indices 0..(split_pos - 1), so split_pos elements
    // Right node will have indices split_pos..(total_after_insert - 1), so (total_after_insert - split_pos) elements
    //
    // Constraints:
    // - Left must have at least merge_threshold_count elements: split_pos >= merge_threshold_count + 1
    // - Right must have at least merge_threshold_count elements: total_after_insert - split_pos >= merge_threshold_count
    //   => split_pos <= total_after_insert - merge_threshold_count
    let min_split = merge_threshold_count + 1;
    let max_split = total_after_insert - merge_threshold_count;

    // Default to median if range is invalid
    if (min_split > max_split) {
      return (node_capacity / 2) + 1;
    };

    // Helper function to get a key at a virtual index
    // Virtual indices: 0..node_capacity (inclusive), where the new element is at elem_index
    func get_key_at_virtual_index(virtual_index : Nat) : Blob {
      if (virtual_index == elem_index) {
        new_key_blob;
      } else {
        let actual_index = if (virtual_index > elem_index) {
          virtual_index - 1;
        } else {
          virtual_index;
        };
        let ?kv_address = get_kv_address(btree, leaf_address, actual_index) else Debug.trap("get_optimal_split_position: null kv_address at virtual index " # debug_show (virtual_index));
        MemoryBlock.get_key_blob(btree, kv_address);
      };
    };

    // Binary search for optimal split position by comparing prefix lengths
    // L represents the key index before the leftmost candidate split position
    // R represents the key index at the rightmost candidate split position
    var L = min_split - 1;
    var R = max_split;

    while (L + 1 < R) {
      let mid = (L + R) / 2;
      
      // Compare prefix length on left side vs right side of mid
      let left_key = get_key_at_virtual_index(L);
      let mid_key = get_key_at_virtual_index(mid);
      let right_key = get_key_at_virtual_index(R);
      
      let left_prefix_len = Common.get_prefix_length(left_key, mid_key);
      let right_prefix_len = Common.get_prefix_length(mid_key, right_key);
      
      // For sorted keys, prefix(key[L], key[mid]) represents the minimum prefix
      // achievable by any split in range (L, mid], and prefix(key[mid], key[R])
      // represents the minimum for range (mid, R]
      // We prefer leftmost position when equal, so search left half when <=
      if (left_prefix_len <= right_prefix_len) {
        R := mid;
      } else {
        L := mid;
      };
    };

    // Return the virtual split position
    // R is the optimal split position (first element of right node after split)
    R;
  };

  /// Split a leaf node, inserting new_id at elem_index
  /// When tail compression is enabled, uses optimal split position based on merge_threshold_count
  public func split(btree : MemoryBTree, leaf_address : Nat, elem_index : Nat, new_id : UniqueId) : Nat {
    // assert Leaf.validate(btree, leaf_address);
    let arr_len = btree.node_capacity;

    // Determine split point (separator_index = first index of right node after split)
    let median = if (btree.is_tail_compression_enabled) {
      let new_key_blob = MemoryBlock.get_key_blob(btree, new_id);
      get_optimal_split_position(btree, leaf_address, elem_index, new_key_blob);
    } else {
      (arr_len / 2) + 1;
    };

    let is_elem_added_to_right = elem_index >= median;

    var i = 0;
    let right_cnt = arr_len + 1 - median : Nat;

    let right_leaf_address = Leaf.new(btree);
    let depth = Leaf.get_depth(btree, leaf_address);
    Leaf.update_depth(btree, right_leaf_address, depth);

    var offset = if (is_elem_added_to_right) 0 else 1;

    var elems_removed_from_left = 0;

    if (not is_elem_added_to_right) {
      let start = get_kv_address_offset(leaf_address, i + median - offset);
      let end = get_kv_address_offset(leaf_address, arr_len);

      let new_start = get_kv_address_offset(right_leaf_address, 0);
      var blob_slice = MemoryRegion.loadBlob(btree.leaves, start, end - start);
      MemoryRegion.storeBlob(btree.leaves, new_start, blob_slice);

      elems_removed_from_left += right_cnt;
    } else {
      // | left | elem | right |
      // left
      var size = elem_index - (i + median - offset) : Nat;
      var start = get_kv_address_offset(leaf_address, i + median - offset);
      var end = get_kv_address_offset(leaf_address, elem_index);

      var new_start = get_kv_address_offset(right_leaf_address, 0);
      var blob_slice = MemoryRegion.loadBlob(btree.leaves, start, end - start);
      MemoryRegion.storeBlob(btree.leaves, new_start, blob_slice);

      // elem
      new_start := get_kv_address_offset(right_leaf_address, size);
      MemoryRegion.storeNat64(btree.leaves, new_start, Nat64.fromNat(new_id));
      size += 1;

      // right
      start := get_kv_address_offset(leaf_address, elem_index);
      end := get_kv_address_offset(leaf_address, arr_len);

      new_start := get_kv_address_offset(right_leaf_address, size);
      blob_slice := MemoryRegion.loadBlob(btree.leaves, start, end - start);
      MemoryRegion.storeBlob(btree.leaves, new_start, blob_slice);

      size += (arr_len - elem_index : Nat);
      elems_removed_from_left += size;
    };

    Leaf.update_count(btree, leaf_address, arr_len - elems_removed_from_left);

    if (not is_elem_added_to_right) {
      Leaf.insert(btree, leaf_address, elem_index, new_id);
    };

    Leaf.update_count(btree, leaf_address, median);
    Leaf.update_count(btree, right_leaf_address, right_cnt);

    let left_index = Leaf.get_index(btree, leaf_address);
    Leaf.update_index(btree, right_leaf_address, left_index + 1);

    let left_parent = Leaf.get_parent(btree, leaf_address);
    Leaf.update_parent(btree, right_leaf_address, left_parent);

    // update leaf pointers
    Leaf.update_prev(btree, right_leaf_address, ?leaf_address);

    let lefts_next_node = Leaf.get_next(btree, leaf_address);
    Leaf.update_next(btree, right_leaf_address, lefts_next_node);
    Leaf.update_next(btree, leaf_address, ?right_leaf_address);

    switch (Leaf.get_next(btree, right_leaf_address)) {
      case (?next_address) {
        Leaf.update_prev(btree, next_address, ?right_leaf_address);
      };
      case (_) {};
    };

    right_leaf_address;
  };

  public func shift(btree : MemoryBTree, leaf_address : Nat, start : Nat, end : Nat, offset : Int) {
    // assert Leaf.validate(btree, leaf_address);
    if (offset == 0) return;

    let _start = get_kv_address_offset(leaf_address, start);
    let _end = get_kv_address_offset(leaf_address, end);

    MemoryFns.shift(btree.leaves.region, _start, _end, offset * ADDRESS_SIZE);

  };

  public func remove(btree : MemoryBTree, leaf_address : Nat, index : Nat) {
    // assert Leaf.validate(btree, leaf_address);
    let count = Leaf.get_count(btree, leaf_address);

    Leaf.shift(btree, leaf_address, index + 1, count, -1); // updates the cache
    Leaf.update_count(btree, leaf_address, count - 1); // updates the cache as well
  };

  // public func redistribute(btree : MemoryBTree, leaf : Nat, neighbour : Nat) : Bool {
  //   let leaf_count = Leaf.get_count(btree, leaf);
  //   let neighbour_count = Leaf.get_count(btree, neighbour);

  //   let sum_count = leaf_count + neighbour_count;
  //   let min_count_for_both_nodes = btree.node_capacity;

  //   if (sum_count < min_count_for_both_nodes) return false; // not enough entries to distribute

  //   // Debug.print("redistribute: leaf_count = " # debug_show leaf_count);
  //   // Debug.print("redistribute: neighbour_count = " # debug_show neighbour_count);

  //   let data_to_move = (sum_count / 2) - leaf_count : Nat;

  //   // Debug.print("data_to_move = " # debug_show data_to_move);

  //   let leaf_index = Leaf.get_index(btree, leaf);
  //   let neighbour_index = Leaf.get_index(btree, neighbour);

  //   // distribute data between adjacent nodes
  //   if (neighbour_index < leaf_index) {
  //     // neighbour is before leaf
  //     // Debug.print("neighbour is before leaf");

  //     Leaf.shift(btree, leaf, 0, leaf_count, data_to_move);

  //     let start = get_kv_address_offset(neighbour, neighbour_count - data_to_move);
  //     let end = get_kv_address_offset(neighbour, neighbour_count);

  //     let new_start = get_kv_address_offset(leaf, 0);

  //     var blob_slice = MemoryRegion.loadBlob(btree.leaves, start, end - start);
  //     MemoryRegion.storeBlob(btree.leaves, new_start, blob_slice);
  //   } else {
  //     // adj_node is after leaf_node
  //     // Debug.print("neighbour is after leaf_node");

  //     let start = get_kv_address_offset(neighbour, 0);
  //     let end = get_kv_address_offset(neighbour, data_to_move);

  //     let new_start = get_kv_address_offset(leaf, leaf_count);

  //     var blob_slice = MemoryRegion.loadBlob(btree.leaves, start, end - start);
  //     MemoryRegion.storeBlob(btree.leaves, new_start, blob_slice);

  //     Leaf.shift(btree, neighbour, data_to_move, neighbour_count, -data_to_move);

  //   };

  //   Leaf.update_count(btree, leaf, leaf_count + data_to_move);
  //   Leaf.update_count(btree, neighbour, neighbour_count - data_to_move);

  //   // Debug.print("end redistribution");
  //   true;
  // };

  // only deallocates the memory allocated in the metadata region
  // the values stored in the blob region are not deallocated
  // as they could have been moved to a different leaf node
  public func deallocate(btree : MemoryBTree, leaf : Nat) {
    // assert Leaf.validate(btree, leaf);

    let memory_size = Leaf.get_memory_size(btree.node_capacity);


    // deallocate the memory region
    MemoryRegion.deallocate(btree.leaves, leaf, memory_size);
  };

  public func unlink(btree : MemoryBTree, leaf : Nat) {
    // assert Leaf.validate(btree, leaf);
    let prev_opt = Leaf.get_prev(btree, leaf);
    let next_opt = Leaf.get_next(btree, leaf);

    switch (prev_opt) {
      case (?prev) Leaf.update_next(btree, prev, next_opt);
      case (_) {};
    };

    switch (next_opt) {
      case (?next) Leaf.update_prev(btree, next, prev_opt);
      case (_) {};
    };
  };

  public func merge(btree : MemoryBTree, leaf : Nat, neighbour : Nat) : (Nat, Nat) {
    // assert Leaf.validate(btree, leaf);
    // assert Leaf.validate(btree, neighbour);
    let leaf_index = Leaf.get_index(btree, leaf);
    let neighbour_index = Leaf.get_index(btree, neighbour);

    var left = leaf;
    var right = neighbour;
    let right_index = if (leaf_index > neighbour_index) {
      left := neighbour;
      right := leaf;
      leaf_index;
    } else {
      neighbour_index;
    };

    let left_count = Leaf.get_count(btree, left);
    let right_count = Leaf.get_count(btree, right);

    let start = get_kv_address_offset(right, 0);
    let end = get_kv_address_offset(right, right_count);

    let new_start = get_kv_address_offset(left, left_count);
    let blob_slice = MemoryRegion.loadBlob(btree.leaves, start, end - start);
    MemoryRegion.storeBlob(btree.leaves, new_start, blob_slice);

    Leaf.update_count(btree, left, left_count + right_count);

    Leaf.unlink(btree, right);

    // set right node's count to empty
    Leaf.update_count(btree, right, 0);

    (right, right_index);
  };

};
