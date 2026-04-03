/// Leaf Node Operations

import Debug "mo:core@2.4/Debug";
import Runtime "mo:core@2.4/Runtime";
import Array "mo:core@2.4/Array";
import VarArray "mo:core@2.4/VarArray";
import Nat "mo:core@2.4/Nat";
import Nat8 "mo:core@2.4/Nat8";
import Nat16 "mo:core@2.4/Nat16";
import Nat64 "mo:core@2.4/Nat64";
import Int "mo:core@2.4/Int";
import Float "mo:core@2.4/Float";
import Blob "mo:core@2.4/Blob";
import Option "mo:core@2.4/Option";

import MemoryRegion "mo:memory-region@1.5/MemoryRegion";

import MemoryFns "MemoryFns";
import MemoryBlock "MemoryBlock";
import T "Types";
import Migrations "../Migrations";
import Utils "../../Utils";
import Common "Common";
import Constants "../../Constants";

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

  // Prefix key address for key compression (null == no compression)
  public let PREFIX_KEY_ADDRESS_START = 32;

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

  /// Minimum per-key byte gain required before recompression is applied during a leaf split.
  /// If the new prefix saves fewer than this many bytes per stored key, the recompression
  /// pass is skipped and the current prefix is kept (slightly larger blobs, less CPU work).
  public let PREFIX_COMPRESSION_THRESHOLD : Nat = 3;

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

    // prefix key for compression (null = no prefix compression)
    MemoryRegion.storeNat64(btree.leaves, leaf_address + Leaf.PREFIX_KEY_ADDRESS_START, NULL_ADDRESS);

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
      VarArray.repeat(null, btree.node_capacity),
      VarArray.repeat(null, btree.node_capacity),
      VarArray.repeat(null, btree.node_capacity),
      VarArray.repeat<?Nat>(null, btree.node_capacity),
      VarArray.repeat(null, btree.node_capacity),
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

    // Get the prefix for prepending to keys (if any)
    let prefix_key = get_prefix_key(btree, leaf_address);

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

      let key_block = MemoryBlock.KV.get_key_block(btree, key_address);
      let key_suffix = MemoryBlock.KV.get_key_blob(btree, key_address);
      // Prepend prefix to get full key
      let key_blob = Common.prepend_prefix(prefix_key, key_suffix);
      // Debug.print("key_blob = " # debug_show key_blob);

      leaf.2 [i] := ?(key_block);

      let val_block = MemoryBlock.KV.get_val_block(btree, key_address);
      let val_blob = MemoryBlock.KV.get_val_blob(btree, key_address);
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

  public func display(btree : MemoryBTree, btree_utils : BTreeUtils<Nat, Nat>, leaf_address : Nat) {};

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
    ?MemoryBlock.KV.get_key_block(btree, id);
  };

  public func get_val_block(btree : MemoryBTree, leaf_address : Nat, i : Nat) : ?MemoryBlock {
    // assert Leaf.validate(btree, leaf_address);
    let ?id = get_kv_address(btree, leaf_address, i) else return null;
    ?MemoryBlock.KV.get_val_block(btree, id);
  };

  // Prefix key compression functions
  public func get_prefix_key_address(btree : MemoryBTree, leaf_address : Nat) : ?Nat {
    let address = MemoryRegion.loadNat64(btree.leaves, leaf_address + PREFIX_KEY_ADDRESS_START);
    if (address == NULL_ADDRESS) null else ?Nat64.toNat(address);
  };

  public func get_prefix_key(btree : MemoryBTree, leaf_address : Nat) : Blob {
    if (not btree.is_prefix_compression_enabled) return Constants.EMPTY_BLOB;
    let ?address = get_prefix_key_address(btree, leaf_address) else return Constants.EMPTY_BLOB;
    let prefix = MemoryBlock.PrefixKey.get(btree, address);
    prefix;
  };

  public func get_prefix_key_size(btree : MemoryBTree, leaf_address : Nat) : Nat {
    let ?address = get_prefix_key_address(btree, leaf_address) else return 0;
    MemoryBlock.PrefixKey.get_size(btree, address);
  };

  public func set_prefix_key_address(btree : MemoryBTree, leaf_address : Nat, opt_address : ?Nat) {
    let address = switch (opt_address) {
      case (?addr) Nat64.fromNat(addr);
      case (null) NULL_ADDRESS;
    };
    MemoryRegion.storeNat64(btree.leaves, leaf_address + PREFIX_KEY_ADDRESS_START, address);
  };

  /// Replace the prefix key with a new one, deallocating the old one if present
  public func replace_prefix_key(btree : MemoryBTree, leaf_address : Nat, new_prefix : Blob) {
    let opt_prev_address = get_prefix_key_address(btree, leaf_address);

    switch (opt_prev_address, new_prefix) {
      case (?prev_address, "") { // new prefix is empty, just deallocate old prefix and clear address
        MemoryBlock.PrefixKey.deallocate(btree, prev_address);
        set_prefix_key_address(btree, leaf_address, null);
      };
      case (?prev_address, _) { // both old and new prefixes are non-empty, replace in place if possible
        let new_address = MemoryBlock.PrefixKey.replace(btree, prev_address, new_prefix);
        if (new_address != prev_address) set_prefix_key_address(btree, leaf_address, ?new_address);
      };
      case (null, "") {}; // no existing prefix, new prefix is empty → no-op
      case (null, _) { // no existing prefix, just store the new one
        let new_address = MemoryBlock.PrefixKey.store(btree, new_prefix);
        set_prefix_key_address(btree, leaf_address, ?new_address);
      };
    };
  };

  /// Get the raw key blob without prefix (suffix only)
  public func get_key_blob_suffix(btree : MemoryBTree, leaf_address : Nat, i : Nat) : ?(Blob) {
    let ?id = get_kv_address(btree, leaf_address, i) else return null;
    ?MemoryBlock.KV.get_key_blob(btree, id);
  };

  /// Get the full key blob with prefix prepended
  /// Takes an optional cached prefix to avoid repeated stable memory reads
  public func get_key_blob(btree : MemoryBTree, leaf_address : Nat, i : Nat, opt_cached_prefix : ?(Blob)) : ?(Blob) {
    // assert Leaf.validate(btree, leaf_address);
    let ?suffix = Leaf.get_key_blob_suffix(btree, leaf_address, i) else return null;

    // Use cached prefix if provided, otherwise fetch from memory
    let prefix_key : Blob = switch (opt_cached_prefix) {
      case (null) get_prefix_key(btree, leaf_address);
      case (?cached) cached;
    };

    let result = Common.prepend_prefix(prefix_key, suffix);

    ?result;
  };

  public func set_key_to_null(btree : MemoryBTree, leaf_address : Nat, i : Nat) {
    // assert Leaf.validate(btree, leaf_address);

    let id_offset = get_kv_address_offset(leaf_address, i);
    MemoryRegion.storeNat64(btree.leaves, id_offset, NULL_ADDRESS);
  };

  public func get_val_blob(btree : MemoryBTree, leaf_address : Nat, index : Nat) : ?(Blob) {
    // assert Leaf.validate(btree, leaf_address);

    let ?id = get_kv_address(btree, leaf_address, index) else return null;
    ?MemoryBlock.KV.get_val_blob(btree, id);
  };

  public func set_kv_to_null(btree : MemoryBTree, leaf_address : Nat, i : Nat) {
    // assert Leaf.validate(btree, leaf_address);

    let key_offset = get_kv_address_offset(leaf_address, i);
    MemoryRegion.storeNat64(btree.leaves, key_offset, NULL_ADDRESS);
  };

  public func get_kv_blobs(btree : MemoryBTree, leaf_address : Nat, index : Nat, opt_cached_prefix : ?(Blob)) : ?(Blob, Blob) {
    // assert Leaf.validate(btree, leaf_address);
    // Look up the block address once and reuse it for both key and value reads.
    let ?id = get_kv_address(btree, leaf_address, index) else return null;

    let key_suffix = MemoryBlock.KV.get_key_blob(btree, id);
    let prefix = switch (opt_cached_prefix) {
      case (null) get_prefix_key(btree, leaf_address);
      case (?cached) cached;
    };
    let key_blob = Common.prepend_prefix(prefix, key_suffix);

    let val_blob = MemoryBlock.KV.get_val_blob(btree, id);
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

  /// Compare two blobs where the first blob starts from an offset
  /// Returns: -1 if blob1[offset..] < blob2, 0 if equal, 1 if greater
  func compare_blob_from_offset(cmp : (Blob, Blob) -> Int8, blob1 : Blob, offset : Nat, blob2 : Blob) : Int8 {
    let len1 = blob1.size();
    let len2 = blob2.size();

    // Check bounds
    if (offset > len1) return if (len2 == 0) 0 else -1;

    let remaining1 = len1 - offset;

    // Compare byte by byte
    var i = 0;
    while (i < remaining1 and i < len2) {
      let byte1 = blob1.get(offset + i);
      let byte2 = blob2.get(i);

      if (byte1 < byte2) return -1;
      if (byte1 > byte2) return 1;

      i += 1;
    };

    // All compared bytes are equal, check lengths
    if (remaining1 < len2) return -1;
    if (remaining1 > len2) return 1;
    return 0;
  };

  public func binary_search<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, leaf_address : Nat, cmp : (K, K) -> Int8, search_key : K, arr_len : Nat) : Int {
    // assert Leaf.validate(btree, leaf_address);
    if (arr_len == 0) return -1; // should insert at index Int.abs(i + 1)
    var l = 0;

    // arr_len will always be between 4 and 512
    var r = arr_len - 1 : Nat;

    // Get prefix once for efficiency (only needed when prefix compression is enabled)
    let prefix = get_prefix_key(btree, leaf_address);

    while (l < r) {
      let mid = (l + r) / 2;

      let ?key_suffix = Leaf.get_key_blob_suffix(btree, leaf_address, mid) else Runtime.trap("1. binary_search: accessed a null value");
      let key_blob = Common.prepend_prefix(prefix, key_suffix);
      let key = btree_utils.key.blobify.from_blob(key_blob);

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
    switch (Leaf.get_key_blob_suffix(btree, leaf_address, insertion)) {
      case (?(key_suffix)) {
        let key_blob = Common.prepend_prefix(prefix, key_suffix);
        let key = btree_utils.key.blobify.from_blob(key_blob);
        let result = cmp(search_key, key);

        if (result == 0) insertion else if (result == -1) -(insertion + 1) else -(insertion + 2);
      };
      case (_) {
        Debug.print("insertion = " # debug_show insertion);
        Debug.print("arr_len = " # debug_show arr_len);
        // Debug.print(
        //     "arr = " # debug_show Array.freeze(get_keys(btree, address))
        // );
        Runtime.trap("2. binary_search: accessed a null value");
      };
    };
  };

  public func binary_search_blob_seq(btree : MemoryBTree, leaf_address : Nat, cmp : (Blob, Blob) -> Int8, search_key : Blob, arr_len : Nat) : Int {
    // assert Leaf.validate(btree, leaf_address);
    if (arr_len == 0) return -1; // should insert at index Int.abs(i + 1)
    var l = 0;

    // arr_len will always be between 4 and 512
    var r = arr_len - 1 : Nat;

    // When prefix compression is enabled, compare search_key against the shared prefix once.
    // - search_key < prefix  → it is less than every key in this leaf → return -1
    // - search_key > prefix  → it is greater than every key in this leaf → return -(arr_len + 1)
    // - search_key starts with prefix → extract its suffix once and compare suffixes directly,
    //   avoiding one Blob allocation per comparison in the loop below.
    let leaf_prefix = get_prefix_key(btree, leaf_address);
    let search_key_suffix : Blob = if (leaf_prefix.size() == 0) {
      search_key;
    } else {
        // Compare only the bytes we have; a shorter search_key can still be > the prefix start.
        let cmp_len = Nat.min(leaf_prefix.size(), search_key.size());
        let search_key_prefix = Utils.blob_slice(search_key, 0, cmp_len);

        let prefix_cmp = cmp(search_key_prefix, leaf_prefix);

        switch (prefix_cmp) {
          case (-1) return -1;
          case (1) return -(arr_len + 1);
          case (_) {
            Utils.blob_slice(search_key, leaf_prefix.size(), search_key.size() - leaf_prefix.size());
          };
        };
    };
    
   
    while (l < r) {
      let mid = (l + r) / 2;

      let ?key_suffix = Leaf.get_key_blob_suffix(btree, leaf_address, mid) else Runtime.trap("1. binary_search_blob_seq: accessed a null value");
      let result = cmp(search_key_suffix, key_suffix);

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
    switch (Leaf.get_key_blob_suffix(btree, leaf_address, insertion)) {
      case (?(key_suffix)) {
        let result = cmp(search_key_suffix, key_suffix);
        if (result == 0) insertion else if (result == -1) -(insertion + 1) else -(insertion + 2);
      };
      case (_) {
        Debug.print("insertion = " # debug_show insertion);
        Debug.print("arr_len = " # debug_show arr_len);
        Runtime.trap("2. binary_search_blob_seq: accessed a null value");
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

  /// Update the prefix key and re-compress all keys in the leaf.
  /// If the new prefix is the same as the old prefix, this is a no-op.
  /// If new_prefix is empty (""), the prefix key is cleared.
  public func update_prefix_and_recompress(btree : MemoryBTree, leaf_address : Nat, new_prefix : Blob) {
    let old_prefix : Blob = get_prefix_key(btree, leaf_address);

    // No change needed if prefix is  same
    if (old_prefix == new_prefix) return;

    let count = get_count(btree, leaf_address);

    // Re-compress each key: prepend old prefix, strip new prefix
    var i = 0;
    label recompress while (i < count) {
      let kv_address = switch (get_kv_address(btree, leaf_address, i)) {
        case (?addr) addr;
        case (null) {
          i += 1;
          continue recompress;
        };
      };

      // Get the stored suffix and reconstruct full key
      let suffix = MemoryBlock.KV.get_key_blob(btree, kv_address);

      // Strip new prefix to get new suffix
      let new_suffix = Common.get_new_suffix(old_prefix, new_prefix, suffix);

      // Replace the key blob with the new suffix
      // Note: This may change the kv_address if size changes - we need to update the leaf pointer
      switch (MemoryBlock.KV.replace_key_blob(btree, kv_address, new_suffix)) {
        case (?new_kv_address) {
          // Address changed, update leaf pointer
          put(btree, leaf_address, i, new_kv_address);
        };
        case (null) {
          // Address unchanged, no action needed
        };
      };

      i += 1;
    };

    // Update the prefix
    replace_prefix_key(btree, leaf_address, new_prefix);
  };

  public func insert(btree : MemoryBTree, leaf_address : Nat, index : Nat, new_entry_kv_address : Address) {
    // assert Leaf.validate(btree, leaf_address);
    let count = Leaf.get_count(btree, leaf_address);

    assert index <= count and count < btree.node_capacity;

    let start = get_kv_address_offset(leaf_address, index);
    let end = get_kv_address_offset(leaf_address, count);

    assert (end - start : Nat) / ADDRESS_SIZE == (count - index : Nat);

    MemoryFns.shift_by(btree.leaves.region, start, end, ADDRESS_SIZE);
    MemoryRegion.storeNat64(btree.leaves, start, Nat64.fromNat(new_entry_kv_address));

    Leaf.update_count(btree, leaf_address, count + 1);
  };

  public func insert_with_count(btree : MemoryBTree, leaf_address : Nat, index : Nat, new_entry_kv_address : Address, count : Nat) {
    // assert Leaf.validate(btree, leaf_address);
    assert index <= count and count < btree.node_capacity;

    let start = get_kv_address_offset(leaf_address, index);
    let end = get_kv_address_offset(leaf_address, count);

    assert (end - start : Nat) / ADDRESS_SIZE == (count - index : Nat);

    MemoryFns.shift_by(btree.leaves.region, start, end, ADDRESS_SIZE);
    MemoryRegion.storeNat64(btree.leaves, start, Nat64.fromNat(new_entry_kv_address));

    Leaf.update_count(btree, leaf_address, count + 1);
  };

  public func put(btree : MemoryBTree, leaf_address : Nat, index : Nat, new_entry_kv_address : Address) {
    // assert Leaf.validate(btree, leaf_address);
    let id_offset = get_kv_address_offset(leaf_address, index);
    MemoryRegion.storeNat64(btree.leaves, id_offset, Nat64.fromNat(new_entry_kv_address));
  };

  func get_kv_address_at_split_virtual_index(btree: MemoryBTree, leaf_address: Nat, elem_index: Nat, new_entry_kv_address: Address, virtual_index : Nat) : ?Nat {
    if (virtual_index == elem_index) {
      ?new_entry_kv_address;
    } else {
      let actual_index = if (virtual_index > elem_index) virtual_index - 1 else virtual_index;
      get_kv_address(btree, leaf_address, actual_index);
    };
  };

  // Returns the full (un-prefixed) key at a virtual index, accounting for the new element.
  // Keys stored in MemoryBlocks are suffixes relative to old_prefix; prepend it to recover
  // the full key used for separator / prefix-bound comparisons.
  func get_key_suffix_at_split_virtual_index(btree: MemoryBTree, leaf_address: Nat, elem_index: Nat, new_entry_kv_address: Address, virtual_index : Nat) : Blob {
    let ?kv_address = get_kv_address_at_split_virtual_index(btree, leaf_address, elem_index, new_entry_kv_address, virtual_index) 
      else Runtime.trap("get_key_suffix_at_split_virtual_index: null kv_address at virtual index " # debug_show (virtual_index));
    MemoryBlock.KV.get_key_blob(btree, kv_address);
  };

  /// Finds the split position that maximises total prefix-compression savings across both child leaves
  public func get_optimal_split_position_for_prefix_compression(
    btree : MemoryBTree,
    leaf_address : Nat,
    elem_index : Nat,
    new_entry_kv_address : Address,
    old_prefix : Blob,
    opt_left_sep : ?Blob,
    opt_right_sep : ?Blob,
  ) : ?Nat {
    let node_capacity = btree.node_capacity;
    let merge_threshold_count = btree.merge_threshold_count;
    let total_after_insert = node_capacity + 1;

    let min_split = merge_threshold_count + 1;
    let max_split = total_after_insert - merge_threshold_count;

    if (min_split > max_split or (opt_left_sep == null and opt_right_sep == null)) {
      return null;
    };

    // splits in a prefix compressed leaf produce leaves with a longer or equal prefix
    // but never shorter than the previous one, so we can strip the old prefix and compare them 
    // directly against the keys suffixes to get the new prefix lengths without needing to reconstruct full keys or separators.
    let opt_left_sep_suffix = switch (opt_left_sep) {
      case (?ls) ?Common.strip_prefix(old_prefix, ls);
      case (null) null;
    };

    let opt_right_sep_suffix = switch (opt_right_sep) {
      case (?rs) ?Common.strip_prefix(old_prefix, rs);
      case (null) null;
    };

    var best_pos = min_split;
    var best_savings : Nat = 0;

    var s = min_split;
    while (s <= max_split) {
      let separator_key = get_key_suffix_at_split_virtual_index(btree, leaf_address, elem_index, new_entry_kv_address, s);

      // How many bytes of prefix can each child leaf strip from its keys?
      var left_prefix_len : Nat = switch (opt_left_sep_suffix) {
        case (null) 0;
        case (?ls) Common.get_prefix_length(ls, separator_key);
      };

      var right_prefix_len : Nat = switch (opt_right_sep_suffix) {
        case (null) 0;
        case (?rs) Common.get_prefix_length(separator_key, rs);
      };

      // only consider prefix compression if it meets a minimum threshold of bytes saved, 
      // otherwise the overhead of storing the prefix key may outweigh the benefits
      if (left_prefix_len < PREFIX_COMPRESSION_THRESHOLD) {
        left_prefix_len := 0;
      };

      if (right_prefix_len < PREFIX_COMPRESSION_THRESHOLD) {
        right_prefix_len := 0;
      };

      // Total bytes saved across both child leaves. Ties favour the first (smaller) split position,
      // which keeps the split more balanced.
      let savings : Nat = (s * left_prefix_len) + ((total_after_insert - s) * right_prefix_len);

      if (savings > best_savings) {
        best_savings := savings;
        best_pos := s;
      };

      s += 1;
    };

    // If no split position produced any threshold-qualifying savings, the prefix
    // optimisation cannot help — fall back to the separator-length heuristic so we
    // still get a well-balanced split rather than the degenerate min_split position.
    if (best_savings == 0) {
      return null;
    };

    ?best_pos;
  };

  // Copy a sequence of addresses from one leaf to another
  // Intervals are inclusive of start_index and exclusive of end_index - i.e. [start_index, end_index)
  // dest_start_index is the index in the destination leaf where the first copied address will be written
  func copy_kv_addresses_to_leaf(btree: MemoryBTree, source_leaf_address : Nat, start_index : Nat, end_index : Nat, dest_leaf_address : Nat, dest_start_index : Nat) {
    let start = get_kv_address_offset(source_leaf_address, start_index);
    let end = get_kv_address_offset(source_leaf_address, end_index);

    let new_start = get_kv_address_offset(dest_leaf_address, dest_start_index);
    let blob = MemoryRegion.loadBlob(btree.leaves, start, end - start);
    MemoryRegion.storeBlob(btree.leaves, new_start, blob);
  };

  // Phase 1 of two-pass recompression: for each KV address in [start_index, end_index) on
  // source_leaf_address, compute the new key suffix, then deallocate the old KV block –
  // freeing all old memory before any new blocks are allocated.
  //
  // WHY BATCH-DEALLOCATE FIRST?
  // If we interleaved dealloc+alloc per entry (i.e. resize one block at a time), the
  // allocator would hand out a new block before it has seen the next old block freed.
  // This means it cannot reuse the memory just released, so each new block lands in a
  // fresh gap and the freed slots sit stranded between occupied ranges – fragmentation.
  //
  // By freeing every old block here (Phase 1) before allocating any new block (Phase 2),
  // we return all the soon-to-be-reused memory to the free pool at once.  The allocator
  // then fills those gaps in order when Phase 2 runs, keeping the data region dense.
  //
  // Returns an array of (new_suffix, ref_count, val_ptr, val_size) for each index in order.
  func deallocate_kv_range_for_recompression(
    btree : MemoryBTree,
    source_leaf_address : Nat,
    start_index : Nat,
    end_index : Nat,
    old_prefix : Blob,
    new_prefix : Blob,
  ) : [(Blob, Nat8, Nat64, Nat32)] {
    let count = end_index - start_index : Nat;
    Array.tabulate<(Blob, Nat8, Nat64, Nat32)>(count, func(j) {
      let i = start_index + j;
      let ?kv_address = get_kv_address(btree, source_leaf_address, i) else Runtime.trap("deallocate_kv_range_for_recompression: null kv_address at index " # debug_show i);
      let old_suffix = MemoryBlock.KV.get_key_blob(btree, kv_address);
      let new_suffix = Common.get_new_suffix(old_prefix, new_prefix, old_suffix);
      let (ref_count, val_ptr, val_size) = MemoryBlock.KV.deallocate_key(btree, kv_address);
      (new_suffix, ref_count, val_ptr, val_size);
    });
  };

  // Phase 2 of two-pass recompression: allocates new KV blocks from the saved info produced
  // by deallocate_kv_range_for_recompression and writes the new addresses into dest_leaf_address
  // starting at dest_start_index.  Because all old blocks were already freed in Phase 1,
  // the allocator can satisfy these requests from the reclaimed pool rather than appending
  // to the end of the region.
  func reallocate_kv_range_from_saved(
    btree : MemoryBTree,
    saved : [(Blob, Nat8, Nat64, Nat32)],
    dest_leaf_address : Nat,
    dest_start_index : Nat,
  ) {
    var dest_i = dest_start_index;
    for ((new_suffix, ref_count, val_ptr, val_size) in saved.vals()) {
      let new_kv_address = MemoryBlock.KV.allocate_key(btree, new_suffix, ref_count, val_ptr, val_size);
      put(btree, dest_leaf_address, dest_i, new_kv_address);
      dest_i += 1;
    };
  };

  func recompress_key_suffix_at(btree: MemoryBTree, leaf_address : Nat, i : Nat, old_prefix : Blob, new_prefix : Blob) {
    let ?kv_addr = get_kv_address(btree, leaf_address, i) else Runtime.trap("recompress_key_suffix_at: null kv_address at index " # debug_show (i));
    let old_suffix = MemoryBlock.KV.get_key_blob(btree, kv_addr);
    let new_suffix = Common.get_new_suffix(old_prefix, new_prefix, old_suffix);
    switch (MemoryBlock.KV.replace_key_blob(btree, kv_addr, new_suffix)) {
      case (?new_kv_addr) { put(btree, leaf_address, i, new_kv_addr); };
      case (null) {};
    };
  };

  func batch_copy_and_recompress_keys(
    btree: MemoryBTree, 
    source_leaf_address : Nat, 
    start_index : Nat, 
    end_index : Nat, 
    dest_leaf_address : Nat, 
    dest_start_index : Nat, 
    old_prefix : Blob, 
    new_prefix : Blob
  ) {
    let saved = deallocate_kv_range_for_recompression(btree, source_leaf_address, start_index, end_index, old_prefix, new_prefix);
    reallocate_kv_range_from_saved(btree, saved, dest_leaf_address, dest_start_index);
  };

  /// Split a leaf node, inserting new_entry_kv_address at elem_index.
  public func split(
    btree : MemoryBTree,
    leaf_address : Nat,
    elem_index : Nat,
    new_entry_kv_address : Address,
    old_prefix : Blob,
    leaf_boundary_keys : (?Blob, ?Blob),
  ) : Nat {
    // assert Leaf.validate(btree, leaf_address);
    let arr_len = btree.node_capacity;
    let (opt_left_sep, opt_right_sep) = leaf_boundary_keys;

    // Determine split point (separator_index = first index of right node after split)
    var virtual_split_point = (arr_len / 2) + 1;

    if (btree.is_prefix_compression_enabled) {
      switch (get_optimal_split_position_for_prefix_compression(btree, leaf_address, elem_index, new_entry_kv_address, old_prefix, opt_left_sep, opt_right_sep)) {
        case (?pos) virtual_split_point := pos;
        case (null) {};
      };
    };

    // Compute the final prefix for each half from the parent bounds and the split-point key.
    // When no bounds are given (compression disabled, no parent, or boundary leaf),
    // both halves get an empty prefix — no per-key rewriting is needed.

    let virtual_split_key_suffix = get_key_suffix_at_split_virtual_index(btree, leaf_address, elem_index, new_entry_kv_address, virtual_split_point);
    let virtual_split_key = Common.prepend_prefix(old_prefix, virtual_split_key_suffix);

    let left_new_prefix : Blob = switch (opt_left_sep) {
      case (?left_sep) Common.get_common_prefix(left_sep, virtual_split_key);
      case (null) Constants.EMPTY_BLOB;
    };

    let right_new_prefix :Blob = switch (opt_right_sep) {
      case (?right_sep) Common.get_common_prefix(virtual_split_key, right_sep);
      case (null) Constants.EMPTY_BLOB;
    };

    assert left_new_prefix.size() >= old_prefix.size(); // prefix length should never shrink after split, only stay the same or grow
    let must_recompress_left = left_new_prefix.size() >= old_prefix.size() + PREFIX_COMPRESSION_THRESHOLD;

    assert right_new_prefix.size() >= old_prefix.size();
    var must_recompress_right = right_new_prefix.size() >= old_prefix.size() + PREFIX_COMPRESSION_THRESHOLD;

    let is_elem_added_to_right = elem_index >= virtual_split_point;

    let left_cnt = virtual_split_point;
    let right_cnt = arr_len + 1 - virtual_split_point : Nat;

    // create and set up the right leaf
    let right_leaf_address = Leaf.new(btree);
    let depth = Leaf.get_depth(btree, leaf_address);
    replace_prefix_key(btree, right_leaf_address, old_prefix);
    Leaf.update_depth(btree, right_leaf_address, depth);

    // copy all the right leaf addresses from the left leaf
    // since the new element is added to the left leaf, we can copy all 
    // the sequence of addresses in one go without needing to split it
    let leaf_split_point = if (is_elem_added_to_right) (virtual_split_point) else (virtual_split_point - 1);
    copy_kv_addresses_to_leaf(btree, leaf_address, leaf_split_point, arr_len, right_leaf_address, 0);

    let elems_moved_to_right = arr_len - leaf_split_point;

    Leaf.update_count(btree, leaf_address, arr_len - elems_moved_to_right);
    Leaf.update_count(btree, right_leaf_address, elems_moved_to_right);

    if (is_elem_added_to_right) {
      Leaf.insert(btree, right_leaf_address, elem_index - virtual_split_point, new_entry_kv_address);
    } else {
      Leaf.insert(btree, leaf_address, elem_index, new_entry_kv_address);
    };

    assert Leaf.get_count(btree, leaf_address) == left_cnt;
    assert Leaf.get_count(btree, right_leaf_address) == right_cnt;
    
    if (must_recompress_left) {
      // Deallocate all the left leaf's kv blocks to prevent fragementation before allocating any new blocks for either side.
      let saved_left = deallocate_kv_range_for_recompression(btree, leaf_address, 0, left_cnt, old_prefix, left_new_prefix);

      if (must_recompress_right) {
        // same with the right leaf if it also needs recompression
        let saved_right = deallocate_kv_range_for_recompression(btree, right_leaf_address, 0, right_cnt, old_prefix, right_new_prefix);
        reallocate_kv_range_from_saved(btree, saved_right, right_leaf_address, 0);
        replace_prefix_key(btree, right_leaf_address, right_new_prefix);
      };

      reallocate_kv_range_from_saved(btree, saved_left, leaf_address, 0);
      replace_prefix_key(btree, leaf_address, left_new_prefix);

    } else if (must_recompress_right) {
      let saved_right = deallocate_kv_range_for_recompression(btree, right_leaf_address, 0, right_cnt, old_prefix, right_new_prefix);
      reallocate_kv_range_from_saved(btree, saved_right, right_leaf_address, 0);
      replace_prefix_key(btree, right_leaf_address, right_new_prefix);
    };


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

    MemoryFns.shift_by(btree.leaves.region, _start, _end, offset * ADDRESS_SIZE);

  };

  public func remove(btree : MemoryBTree, leaf_address : Nat, index : Nat) {
    // assert Leaf.validate(btree, leaf_address);
    let count = Leaf.get_count(btree, leaf_address);

    Leaf.shift(btree, leaf_address, index + 1, count, -1); // updates the cache
    Leaf.update_count(btree, leaf_address, count - 1); // updates the cache as well
  };

  public func deallocate_prefix(btree : MemoryBTree, leaf : Nat) {
    // assert Leaf.validate(btree, leaf);
     switch(get_prefix_key_address(btree, leaf)){
      case (?prefix_address){
        MemoryBlock.PrefixKey.deallocate(btree, prefix_address);
        set_prefix_key_address(btree, leaf, null);
      };
      case (null) {};
     };
  };

  // only deallocates the memory allocated in the metadata region
  // the values stored in the blob region are not deallocated
  // as they could have been moved to a different leaf node
  public func deallocate(btree : MemoryBTree, leaf : Nat) {
    // assert Leaf.validate(btree, leaf);

    deallocate_prefix(btree, leaf);

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

  // Merges right into left (caller must ensure left has a lower index than right).
  // When prefix compression is enabled, keys are re-encoded to the new common prefix
  // in a single pass.  Otherwise a plain bulk-copy is used.
  public func merge(btree : MemoryBTree, left : Nat, right : Nat) {
    let left_count  = Leaf.get_count(btree, left);
    let right_count = Leaf.get_count(btree, right);

    if (btree.is_prefix_compression_enabled) {
      let left_prefix  : Blob = Leaf.get_prefix_key(btree, left);
      let right_prefix : Blob = Leaf.get_prefix_key(btree, right);
      let new_prefix   : Blob = Common.get_common_prefix(left_prefix, right_prefix);

      let needs_left_recompress  = left_prefix  != new_prefix;
      let needs_right_recompress = right_prefix != new_prefix;

      // Deallocate all KV blocks that will be recompressed, before any new allocations.
      let saved_left = if (needs_left_recompress) {
        ?deallocate_kv_range_for_recompression(btree, left, 0, left_count, left_prefix, new_prefix);
      } else { null };

      let saved_right = if (needs_right_recompress) {
        ?deallocate_kv_range_for_recompression(btree, right, 0, right_count, right_prefix, new_prefix);
      } else { null };

      // Reallocate new KV blocks with the new key suffixes.
      switch (saved_left) {
        case (?saved) reallocate_kv_range_from_saved(btree, saved, left, 0);
        case (null)   {};
      };

      // Append right keys to left.
      switch (saved_right) {
        case (?saved) reallocate_kv_range_from_saved(btree, saved, left, left_count);
        case (null)   {
          // No recompression needed for right: bulk pointer copy.
          copy_kv_addresses_to_leaf(btree, right, 0, right_count, left, left_count);
        };
      };

      // Update prefix on merged leaf.
      replace_prefix_key(btree, left, new_prefix);
    } else {
      copy_kv_addresses_to_leaf(btree, right, 0, right_count, left, left_count);
    };

    Leaf.update_count(btree, left, left_count + right_count);
    Leaf.unlink(btree, right);
    Leaf.update_count(btree, right, 0);
  };

};
