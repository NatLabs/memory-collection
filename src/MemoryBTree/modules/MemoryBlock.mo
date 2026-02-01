import Nat "mo:base@0.14.13/Nat";
import Blob "mo:base@0.14.13/Blob";
import Nat64 "mo:base@0.14.13/Nat64";
import Nat16 "mo:base@0.14.13/Nat16";
import Nat8 "mo:base@0.14.13/Nat8";
import Nat32 "mo:base@0.14.13/Nat32";
import Debug "mo:base@0.14.13/Debug";

import MemoryRegion "mo:memory-region@1.3.2/MemoryRegion";
import RevIter "mo:itertools@0.2.2/RevIter";

import Migrations "../Migrations";
import T "Types";

module MemoryBlock {

  type Address = Nat;
  type MemoryRegion = MemoryRegion.MemoryRegion;
  type RevIter<A> = RevIter.RevIter<A>;

  public type MemoryBTree = Migrations.MemoryBTree;
  public type MemoryBlock = T.MemoryBlock;
  type UniqueId = T.UniqueId;

  public module Branch {

    // Branch Key Memory Layout
    //      | Field           | Size (bytes) | Description                             |
    //      |-----------------|--------------|-----------------------------------------|
    //      | key size        |  2           | key size                               |
    //      | key blob        |  key size    | serialized key                          |
    //      |-----------------|--------------|-----------------------------------------|

    public let KEY_SIZE_START = 0;
    public let KEY_BLOB_START = 2;

    public func store_key_blob(btree : MemoryBTree, key : Blob) : UniqueId {
      let key_address = MemoryRegion.allocate(btree.data, KEY_BLOB_START + key.size());

      MemoryRegion.storeNat16(btree.data, key_address + KEY_SIZE_START, Nat16.fromNat(key.size())); // key mem block size
      MemoryRegion.storeBlob(btree.data, key_address + KEY_BLOB_START, key);

      key_address;
    };

    public func get_key_blob(btree : MemoryBTree, key_address : UniqueId) : Blob {
      let key_size = MemoryRegion.loadNat16(btree.data, key_address + KEY_SIZE_START) |> Nat16.toNat(_);
      let blob = MemoryRegion.loadBlob(btree.data, key_address + KEY_BLOB_START, key_size);

      blob;
    };

    public func get_key_block(btree : MemoryBTree, key_address : UniqueId) : MemoryBlock {
      let key_size = MemoryRegion.loadNat16(btree.data, key_address + KEY_SIZE_START) |> Nat16.toNat(_);

      (key_address + KEY_BLOB_START, key_size);
    };

    public func remove_key_blob(btree : MemoryBTree, key_address : UniqueId) {
      let key_size = MemoryRegion.loadNat16(btree.data, key_address + KEY_SIZE_START) |> Nat16.toNat(_);
      MemoryRegion.deallocate(btree.data, key_address, KEY_BLOB_START + key_size);
    };

    // Replaces the key blob at 'prev_key_address' with 'new_key'.
    // If the memory block address remains the same after resizing, it returns null.
    // Otherwise, it returns the new memory block address.
    public func replace_key_blob(btree : MemoryBTree, prev_key_address : UniqueId, new_key : Blob) : ?UniqueId {

      let prev_key_size = MemoryRegion.loadNat16(btree.data, prev_key_address + KEY_SIZE_START) |> Nat16.toNat(_);

      if (prev_key_size == new_key.size()) {
        MemoryRegion.storeBlob(btree.data, prev_key_address + KEY_BLOB_START, new_key);
        return null;
      };

      let new_key_address = MemoryRegion.resize(btree.data, prev_key_address, prev_key_size + KEY_SIZE_START, new_key.size() + KEY_SIZE_START);

      MemoryRegion.storeNat16(btree.data, new_key_address + KEY_SIZE_START, Nat16.fromNat(new_key.size()));
      MemoryRegion.storeBlob(btree.data, new_key_address + KEY_BLOB_START, new_key);

      if (new_key_address == prev_key_address) return null;

      ?new_key_address;
    };

  };

  //      Leaf Entry Memory Layout - (15 bytes)
  //
  //      | Field           | Size (bytes) | Description                             |
  //      |-----------------|--------------|-----------------------------------------|
  //      | reference count |  1           | reference count                         |
  // ┌--- | value address   |  8           | address of value blob in current region |
  // |    | value size      |  4           | size of value blob                      |
  // |    | key size        |  2           | size of key blob                        |
  // |    | key blob        |  key size    | serialized key                          |
  // |
  // └--> value blob of 'value size' stored at this address

  let BLOCK_ENTRY_SIZE = 15;

  let REFERENCE_COUNT_START = 0;
  let KEY_SIZE_START = 1;
  let VAL_POINTER_START = 3;
  let VAL_SIZE_START = 11;
  let KEY_BLOB_START = 15;

  public func id_exists(btree : MemoryBTree, block_address : UniqueId) : Bool {
    MemoryRegion.isAllocated(btree.data, block_address, 0);
  };

  public func store(btree : MemoryBTree, key : Blob, val : Blob) : UniqueId {
    let block_address = MemoryRegion.allocate(btree.data, KEY_BLOB_START + key.size());

    let val_address = MemoryRegion.addBlob(btree.values, val);

    MemoryRegion.storeNat8(btree.data, block_address, 0); // reference count
    MemoryRegion.storeNat64(btree.data, block_address + VAL_POINTER_START, Nat64.fromNat(val_address)); // value mem block address
    MemoryRegion.storeNat32(btree.data, block_address + VAL_SIZE_START, Nat32.fromNat(val.size())); // value mem block size

    MemoryRegion.storeNat16(btree.data, block_address + KEY_SIZE_START, Nat16.fromNat(key.size())); // key mem block size
    MemoryRegion.storeBlob(btree.data, block_address + KEY_BLOB_START, key);

    block_address;
  };

  public func next_id(btree : MemoryBTree) : UniqueId {
    let block_address = MemoryRegion.allocate(btree.data, BLOCK_ENTRY_SIZE);

    let _next_id = block_address;
    MemoryRegion.deallocate(btree.data, block_address, BLOCK_ENTRY_SIZE);
    _next_id;
  };

  public func get_ref_count(btree : MemoryBTree, block_address : UniqueId) : Nat {
    let ref_count = MemoryRegion.loadNat8(btree.data, block_address + REFERENCE_COUNT_START);
    Nat8.toNat(ref_count);
  };

  public func increment_ref_count(btree : MemoryBTree, block_address : UniqueId) {
    let ref_count = MemoryRegion.loadNat8(btree.data, block_address + REFERENCE_COUNT_START);
    MemoryRegion.storeNat8(btree.data, block_address + REFERENCE_COUNT_START, ref_count + 1);
  };

  public func decrement_ref_count(btree : MemoryBTree, block_address : UniqueId) : Nat {
    let ref_count = MemoryRegion.loadNat8(btree.data, block_address + REFERENCE_COUNT_START);

    if (ref_count == 0) return 0;
    MemoryRegion.storeNat8(btree.data, block_address + REFERENCE_COUNT_START, ref_count - 1);

    Nat8.toNat(ref_count - 1);
  };

  public func replace_val(btree : MemoryBTree, block_address : UniqueId, new_val : Blob) : Blob {

    let prev_val_address = MemoryRegion.loadNat64(btree.data, block_address + VAL_POINTER_START) |> Nat64.toNat(_);
    let prev_val_size = MemoryRegion.loadNat16(btree.data, block_address + VAL_SIZE_START) |> Nat16.toNat(_);
    let prev_val_blob = MemoryRegion.loadBlob(btree.values, prev_val_address, prev_val_size);

    if (prev_val_size == new_val.size()) {
      MemoryRegion.storeBlob(btree.values, prev_val_address, new_val);
      return prev_val_blob;
    };

    let new_val_address = MemoryRegion.resize(btree.values, prev_val_address, prev_val_size, new_val.size());

    MemoryRegion.storeBlob(btree.values, new_val_address, new_val);
    MemoryRegion.storeNat32(btree.data, block_address + VAL_SIZE_START, Nat32.fromNat(new_val.size()));

    if (new_val_address == prev_val_address) return prev_val_blob;

    MemoryRegion.storeNat64(btree.data, block_address + VAL_POINTER_START, Nat64.fromNat(new_val_address));

    prev_val_blob;
  };

  public func get_key_blob(btree : MemoryBTree, block_address : UniqueId) : Blob {
    let key_size = MemoryRegion.loadNat16(btree.data, block_address + KEY_SIZE_START) |> Nat16.toNat(_);
    let blob = MemoryRegion.loadBlob(btree.data, block_address + KEY_BLOB_START, key_size);

    blob;
  };

  public func get_key_block(btree : MemoryBTree, block_address : UniqueId) : MemoryBlock {
    let key_size = MemoryRegion.loadNat16(btree.data, block_address + KEY_SIZE_START) |> Nat16.toNat(_);

    (block_address + KEY_BLOB_START, key_size);
  };

  public func get_val_block(btree : MemoryBTree, block_address : UniqueId) : MemoryBlock {

    let val_address = MemoryRegion.loadNat64(btree.data, block_address + VAL_POINTER_START) |> Nat64.toNat(_);
    let val_size = MemoryRegion.loadNat32(btree.data, block_address + VAL_SIZE_START) |> Nat32.toNat(_);

    (val_address, val_size);
  };

  public func get_val_blob(btree : MemoryBTree, block_address : UniqueId) : Blob {

    let val_address = MemoryRegion.loadNat64(btree.data, block_address + VAL_POINTER_START) |> Nat64.toNat(_);
    let val_size = MemoryRegion.loadNat32(btree.data, block_address + VAL_SIZE_START) |> Nat32.toNat(_);

    let blob = MemoryRegion.loadBlob(btree.values, val_address, val_size);

    blob;
  };

  public func remove(btree : MemoryBTree, block_address : UniqueId) {

    assert MemoryRegion.loadNat8(btree.data, block_address + REFERENCE_COUNT_START) == 0;

    let val_address = MemoryRegion.loadNat64(btree.data, block_address + VAL_POINTER_START) |> Nat64.toNat(_);
    let key_size = MemoryRegion.loadNat16(btree.data, block_address + KEY_SIZE_START) |> Nat16.toNat(_);
    let val_size = MemoryRegion.loadNat16(btree.data, block_address + VAL_SIZE_START) |> Nat16.toNat(_);

    MemoryRegion.deallocate(btree.values, val_address, val_size);
    MemoryRegion.deallocate(btree.data, block_address, KEY_BLOB_START + key_size);
  };

};
