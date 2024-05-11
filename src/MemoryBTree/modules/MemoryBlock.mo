import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Nat64 "mo:base/Nat64";
import Nat16 "mo:base/Nat16";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Debug "mo:base/Debug";

import MemoryRegion "mo:memory-region/MemoryRegion";
import LruCache "mo:lru-cache";
import RevIter "mo:itertools/RevIter";

import Migrations "../Migrations";
import T "Types";

module MemoryBlock {
    
    // blocks region
    // header - 64 bytes
    // Memory Layout - (6 bytes + |key| bytes + |value| bytes)
    //
    // | Field           | Size (bytes) | Description                         |
    // |-----------------|--------------|-------------------------------------|
    // | key size        |  2           | size of key blob                    |
    // | value size      |  4           | size of value blob                  |
    // | key blob        |  -           | key blob                            |
    // | value blob      |  -           | value blob                          |

    type Address = Nat;
    type MemoryRegion = MemoryRegion.MemoryRegion;
    type LruCache<K, V> = LruCache.LruCache<K, V>;
    type RevIter<A> = RevIter.RevIter<A>;

    public type MemoryBTree = Migrations.MemoryBTree;
    public type Node = Migrations.Node;
    public type MemoryBlock = T.MemoryBlock;
    type UniqueId = T.UniqueId;

    let {nhash} = LruCache;

    public let BLOCK_HEADER_SIZE = 64;
    public let BLOCK_ENTRY_METADATA_SIZE = 15;

    public let KEY_SIZE_START = 0;
    public let VAL_SIZE_START = 2;
    public let KEY_BLOB_START = 6;

    func VAL_BLOB_START(key_size : Nat) : Nat {
        KEY_BLOB_START + key_size
    };

    func get_location_from_id(id : UniqueId) : Address {
        id
    };

    func get_id_from_location(address : Address) : UniqueId {
        address
    };

    public func store(btree : MemoryBTree, key : Blob, val : Blob) : UniqueId {
        // let kv_address = store_kv_pair(btree, key, val);

        // store block in blocks region
        let block_size = BLOCK_ENTRY_METADATA_SIZE + key.size() + val.size();
        let block_address = MemoryRegion.allocate(btree.blocks, block_size);

        MemoryRegion.storeNat8(btree.blocks, block_address, 0); // reference count
        MemoryRegion.storeNat16(btree.blocks, block_address + KEY_SIZE_START, Nat16.fromNat(key.size())); // key mem block size
        MemoryRegion.storeNat32(btree.blocks, block_address + VAL_SIZE_START, Nat32.fromNat(val.size())); // val mem block size
        MemoryRegion.storeBlob(btree.blocks, block_address + KEY_BLOB_START, key); // key blob
        MemoryRegion.storeBlob(btree.blocks, block_address + VAL_BLOB_START(key.size()), val); // val blob

        get_id_from_location(block_address)
    };

    public func replace_val(btree : MemoryBTree, id : UniqueId, new_val : Blob) : UniqueId {
        let block_address = get_location_from_id(id);

        let prev_key_size = MemoryRegion.loadNat16(btree.blocks, block_address + KEY_SIZE_START) |> Nat16.toNat(_);
        let prev_val_size = MemoryRegion.loadNat16(btree.blocks, block_address + VAL_SIZE_START) |> Nat16.toNat(_);

        if (prev_val_size == new_val.size()) {
            MemoryRegion.storeBlob(btree.blocks, block_address + VAL_BLOB_START(prev_key_size), new_val);
            return id;
        };

        let key = MemoryRegion.loadBlob(btree.blocks, block_address + KEY_BLOB_START, prev_key_size);

        let prev_block_size = BLOCK_ENTRY_METADATA_SIZE + prev_key_size + prev_val_size;
        let new_block_size = BLOCK_ENTRY_METADATA_SIZE + key.size() + new_val.size();

        let new_block_address = MemoryRegion.resize(btree.blocks, block_address, prev_block_size, new_block_size);

        if (new_block_address == block_address) { // new size < old size
            MemoryRegion.storeBlob(btree.blocks, block_address + VAL_BLOB_START(prev_key_size), new_val);
            MemoryRegion.storeNat32(btree.blocks, block_address + VAL_SIZE_START, Nat32.fromNat(new_val.size()));
            return id;
        };

        MemoryRegion.storeNat8(btree.blocks, new_block_address, 0); // reference count
        MemoryRegion.storeNat16(btree.blocks, new_block_address + KEY_SIZE_START, Nat16.fromNat(key.size())); // key mem block size
        MemoryRegion.storeNat32(btree.blocks, new_block_address + VAL_SIZE_START, Nat32.fromNat(new_val.size())); // val mem block size
        MemoryRegion.storeBlob(btree.blocks, new_block_address + KEY_BLOB_START, key); // key blob
        MemoryRegion.storeBlob(btree.blocks, new_block_address + VAL_BLOB_START(key.size()), new_val); // val blob

        get_id_from_location(new_block_address);
    };

    public func get_key_blob(btree : MemoryBTree, id : UniqueId) : Blob {
        let block_address = get_location_from_id(id);

        let key_size = MemoryRegion.loadNat16(btree.blocks, block_address + KEY_SIZE_START) |> Nat16.toNat(_);
        let blob = MemoryRegion.loadBlob(btree.blocks, block_address + KEY_BLOB_START, key_size);

        blob;
    };

    public func get_key_block(btree : MemoryBTree, id : UniqueId) : MemoryBlock {
        let block_address = get_location_from_id(id);

        let key_size = MemoryRegion.loadNat16(btree.blocks, block_address + KEY_SIZE_START) |> Nat16.toNat(_);

        (block_address + KEY_BLOB_START, key_size);
    };

    public func get_val_block(btree : MemoryBTree, id : UniqueId) : MemoryBlock {
        let block_address = get_location_from_id(id);

        let key_size = MemoryRegion.loadNat16(btree.blocks, block_address + KEY_SIZE_START) |> Nat16.toNat(_);
        let val_size = MemoryRegion.loadNat32(btree.blocks, block_address + VAL_SIZE_START) |> Nat32.toNat(_);

        (block_address + VAL_BLOB_START(key_size), val_size);
    };

    public func get_val_blob(btree : MemoryBTree, id : UniqueId) : Blob {
        let block_address = get_location_from_id(id);

        let key_size = MemoryRegion.loadNat16(btree.blocks, block_address + KEY_SIZE_START) |> Nat16.toNat(_);
        let val_size = MemoryRegion.loadNat32(btree.blocks, block_address + VAL_SIZE_START) |> Nat32.toNat(_);

        let blob = MemoryRegion.loadBlob(btree.blocks, block_address + VAL_BLOB_START(key_size), val_size);

        blob;
    };

    public func remove(btree : MemoryBTree, id : UniqueId) {
        let block_address = get_location_from_id(id);

        let key_size = MemoryRegion.loadNat16(btree.blocks, block_address + KEY_SIZE_START) |> Nat16.toNat(_);
        let val_size = MemoryRegion.loadNat16(btree.blocks, block_address + VAL_SIZE_START) |> Nat16.toNat(_);

        MemoryRegion.deallocate(btree.blocks, block_address, BLOCK_ENTRY_METADATA_SIZE + key_size + val_size);
    };


};
