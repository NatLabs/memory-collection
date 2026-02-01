import Prim "mo:prim";

import Array "mo:base@0.14.13/Array";
import Iter "mo:base@0.14.13/Iter";
import IC "mo:base@0.14.13/ExperimentalInternetComputer";
import Principal "mo:base@0.14.13/Principal";
import Debug "mo:base@0.14.13/Debug";
import Nat64 "mo:base@0.14.13/Nat64";
import Nat "mo:base@0.14.13/Nat";
import Cycles "mo:base@0.14.13/ExperimentalCycles";
import Buffer "mo:base@0.14.13/Buffer";
import Option "mo:base@0.14.13/Option";
import Time "mo:base@0.14.13/Time";
import Blob "mo:base@0.14.13/Blob";
import Nat8 "mo:base@0.14.13/Nat8";
import Int "mo:base@0.14.13/Int";

import Vector "mo:vector";
import Itertools "mo:itertools@0.2.2/Iter";
import RevIter "mo:itertools@0.2.2/RevIter";

import Ledger "ledger";
import MemoryBTree "mo:memory-collection/MemoryBTree";
import MemoryCollectionUtils "mo:memory-collection/Utils";
import TypeUtils "mo:memory-collection/TypeUtils";
import T "Types";
import BlockUtils "BlockUtils";

actor class Backend() {
    type Block = T.Block;
    type Tx = T.Tx;

    stable var txs_by_tx_index_sstore = MemoryBTree.newStableStore(null);
    stable var txs_by_ts_sstore = MemoryBTree.newStableStore(null);
    stable var txs_by_amt_sstore = MemoryBTree.newStableStore(null);
    stable var txs_by_fee_sstore = MemoryBTree.newStableStore(null);

    let blobify_block = {
        to_blob = func(block : Block) : Blob {
            to_candid (block);
        };
        from_blob = func(blob : Blob) : Block {
            switch (from_candid (blob) : ?Block) {
                case (?block) block;
                case (null) Debug.trap("failed to decode block from blob");
            };
        };
    };

    let nat_block_blob_utils = MemoryBTree.createUtils(
        TypeUtils.Nat,
        { blobify = blobify_block },
    );
    let txs_by_tx_index = MemoryBTree.MemoryBTree<Nat, Block>(txs_by_tx_index_sstore, nat_block_blob_utils);

    let nat_tuple_blobify : TypeUtils.Blobify<(Nat, ?Nat)> = {
        to_blob = func(a : Nat, opt_b : ?Nat) : Blob {
            let a_bytes = MemoryCollectionUtils.nat_to_bytes(a);
            let a_size = Nat8.fromNat(a_bytes.size());

            let bytes = switch (opt_b) {
                case (?b) {
                    let b_bytes = MemoryCollectionUtils.nat_to_bytes(b);
                    let b_size = Nat8.fromNat(b_bytes.size());
                    Array.flatten([[a_size], a_bytes, [b_size], b_bytes]);
                };
                case (null) {
                    Array.flatten([[a_size], a_bytes]);
                };
            };

            Blob.fromArray(bytes);

        };
        from_blob = func(blob : Blob) : (Nat, ?Nat) {
            let bytes = Blob.toArray(blob);
            var i = 0;
            let a_size = Nat8.toNat(bytes[i]);
            i += 1;

            let a = MemoryCollectionUtils.bytes_to_nat(
                Itertools.fromArraySlice(bytes, i, i + a_size)
            );
            i += a_size;

            let opt_b = if (i == bytes.size()) {
                null;
            } else {
                let b_size = Nat8.toNat(bytes[i]);
                i += 1;

                let b = MemoryCollectionUtils.bytes_to_nat(
                    Itertools.fromArraySlice(bytes, i, i + b_size)
                );
                i += b_size;

                ?b;
            };

            (a, opt_b);

        };
    };

    let nat_tuple_type_utils : TypeUtils.TypeUtils<(Nat, ?Nat)> = {
        blobify = nat_tuple_blobify;
        cmp = TypeUtils.MemoryCmp.Default;
    };

    let nat_nat_blob_utils = MemoryBTree.createUtils(nat_tuple_type_utils, TypeUtils.Nat);
    let txs_by_ts = MemoryBTree.MemoryBTree<(Nat, ?Nat), Nat>(txs_by_ts_sstore, nat_nat_blob_utils);
    let txs_by_amt = MemoryBTree.MemoryBTree<(Nat, ?Nat), Nat>(txs_by_amt_sstore, nat_nat_blob_utils);
    let txs_by_fee = MemoryBTree.MemoryBTree<(Nat, ?Nat), Nat>(txs_by_fee_sstore, nat_nat_blob_utils);

    let txs = object {

        public func insert(block : Block) {

            let block_id = block.tx_index;

            ignore txs_by_tx_index.insert(block_id, block);
            ignore txs_by_ts.insert((Int.abs(block.ts), ?block_id), block_id);
            ignore txs_by_amt.insert((Option.get(block.tx.amt, 0), ?block_id), block_id);
            ignore txs_by_fee.insert((Option.get(block.fee, 0), ?block_id), block_id);

        };

        public func size() : Nat {
            txs_by_tx_index.size();
        };

        public func clear() : () {
            txs_by_tx_index.clear();
            txs_by_ts.clear();
            txs_by_amt.clear();
            txs_by_fee.clear();
        };
    };

    let ledger : Ledger.Service = actor ("ryjl3-tyaaa-aaaaa-aaaba-cai");

    public func upload_blocks(blocks : [Block]) : async () {
        for (block in blocks.vals()) {
            txs.insert(block);
        };
    };

    public func pull_blocks_into_db(start : Nat, length : Nat) : async () {
        let blocks = await* BlockUtils.pull_blocks_from_ledger(ledger, start, length);

        for (block in blocks.vals()) {
            txs.insert(block);
        };
    };

    type Options = {

        sort : { #Ascending; #Descending };

        pagination : {
            limit : Nat;
            offset : Nat;
        };
    };

    type GetTxsResponse = {
        blocks : [Block];
        total : Nat;
        instructions : Nat;
    };

    func paginated_interval(interval : (Nat, Nat), options : Options) : ?(Nat, Nat) {

        if (options.sort == #Ascending) {

            let left = interval.0 + options.pagination.offset;
            let right = Nat.min(interval.1, left + options.pagination.limit);

            if (left >= right) return null;

            ?(left, right);

        } else {

            let size = interval.1 - interval.0;

            if (options.pagination.offset > size) return null;

            let right = interval.1 - options.pagination.offset;
            let left = Nat.max(interval.0, right - options.pagination.limit);

            ?(left, right);

        };

    };

    func generic_get_txs<K>(txs : MemoryBTree.MemoryBTree<(K, ?Nat), Nat>, start : ?K, end : ?K, options : Options) : GetTxsResponse {

        let performance_start = IC.performanceCounter(0);
        func instructions() : Nat {
            Nat64.toNat(IC.performanceCounter(0) - performance_start);
        };

        let left = switch (start) {
            case (null) 0;
            case (?start) switch (txs.getExpectedIndex((start, null))) {
                case (#Found(index)) index;
                case (#NotFound(index)) index;
            };
        };

        let right = switch (end) {
            case (null) txs.size();
            case (?end) switch (txs.getExpectedIndex((end, ?10000000000000000000000000000000))) {
                case (#Found(index)) index;
                case (#NotFound(index)) if (index == 0) 0 else index : Nat;
            };
        };

        let total = right - left : Nat;

        let ?interval = paginated_interval((left, right), options) else return {
            blocks = [];
            total = 0;
            instructions = instructions();
        };

        Debug.print("interval: " # debug_show interval # ", size: " # debug_show txs.size());
        assert interval.1 <= txs.size();

        let block_ids : RevIter.RevIter<Nat> = txs.rangeVals(interval);

        let block_ids_iter : Iter.Iter<Nat> = if (options.sort == #Descending) {
            block_ids.rev();
        } else {
            block_ids;
        };

        let blocks_iter = Iter.map<Nat, Block>(
            block_ids_iter,
            func(id : Nat) : Block {
                let ?block = txs_by_tx_index.get(id) else Debug.trap("failed to get block by id: " # debug_show id);
                block;
            },
        );

        let blocks = Iter.toArray(blocks_iter);
        Debug.print("blocks: " # debug_show blocks.size());

        assert blocks.size() <= options.pagination.limit;

        {
            blocks;
            total;
            instructions = instructions();
        }

    };

    public query func get_txs_by_index(start : ?Nat, end : ?Nat, options : Options) : async GetTxsResponse {
        Debug.print(debug_show ({ fn_name = "get_txs_by_index"; start; end; options }));

        let performance_start = IC.performanceCounter(0);
        func instructions() : Nat {
            Nat64.toNat(IC.performanceCounter(0) - performance_start);
        };

        let left = switch (start) {
            case (null) 0;
            case (?start) switch (txs_by_tx_index.getExpectedIndex(start)) {
                case (#Found(index)) index;
                case (#NotFound(index)) index;
            };
        };

        let right = switch (end) {
            case (null) txs.size();
            case (?end) switch (txs_by_tx_index.getExpectedIndex(end)) {
                case (#Found(index)) index;
                case (#NotFound(index)) if (index == 0) 0 else index : Nat;
            };
        };

        let total = right - left : Nat;

        let ?interval = paginated_interval((left, right), options) else return {
            blocks = [];
            total = 0;
            instructions = instructions();
        };
        Debug.print("interval: " # debug_show interval # ", size: " # debug_show txs_by_tx_index.size());

        assert interval.1 <= txs_by_tx_index.size();

        let block_ids : RevIter.RevIter<Nat> = txs_by_tx_index.rangeKeys(interval);

        let block_ids_iter : Iter.Iter<Nat> = if (options.sort == #Descending) {
            block_ids.rev();
        } else {
            block_ids;
        };

        let blocks_iter = Iter.map<Nat, Block>(
            block_ids_iter,
            func(id : Nat) : Block {
                let ?block = txs_by_tx_index.get(id) else Debug.trap("failed to get block by id: " # debug_show id);
                block;
            },
        );

        let blocks = Iter.toArray(blocks_iter);
        Debug.print("blocks: " # debug_show blocks.size());

        assert blocks.size() <= options.pagination.limit;

        {
            blocks;
            total;
            instructions = instructions();
        }

    };

    public query func get_txs_by_ts(start : ?Nat, end : ?Nat, options : Options) : async GetTxsResponse {
        Debug.print(debug_show ({ fn_name = "get_txs_by_ts"; start; end; options }));
        generic_get_txs(txs_by_ts, start, end, options);
    };

    public query func get_txs_by_amt(start : ?Nat, end : ?Nat, options : Options) : async GetTxsResponse {
        Debug.print(debug_show { fn_name = "get_txs_by_amt"; start; end; options });
        generic_get_txs(txs_by_amt, start, end, options);
    };

    public query func get_txs_by_fee(start : ?Nat, end : ?Nat, options : Options) : async GetTxsResponse {
        Debug.print(debug_show { fn_name = "get_txs_by_fee"; start; end; options });
        generic_get_txs(txs_by_fee, start, end, options);
    };

    public func clear() : async () {
        txs.clear();
    };

    type CanisterStats = {
        heap_size : Nat;
        memory_size : Nat;
        stable_memory_size : Nat;
        logical_stable_memory_size : Nat;
        total_allocation : Nat;
        max_live_size : Nat;

        num_entries : Nat;
    };

    public query func get_stats() : async CanisterStats {
        {
            heap_size = Prim.rts_heap_size();
            memory_size = Prim.rts_memory_size();
            stable_memory_size = Prim.rts_stable_memory_size();
            logical_stable_memory_size = Prim.rts_logical_stable_memory_size();
            total_allocation = Prim.rts_total_allocation();
            max_live_size = Prim.rts_max_live_size();
            num_entries = txs.size();
        };
    };

    public query func get_db_size() : async Nat {
        txs.size();
    };

};
