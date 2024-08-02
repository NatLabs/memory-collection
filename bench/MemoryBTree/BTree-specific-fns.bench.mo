import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Buffer "mo:base/Buffer";

import Bench "mo:bench";
import Fuzz "mo:fuzz";

import { BpTree; Cmp } "mo:augmented-btrees";

import MemoryBTree "../../src/MemoryBTree/Base";
import TypeUtils "../../src/TypeUtils";

module {
    type MemoryBTree = MemoryBTree.MemoryBTree;

    public func init() : Bench.Bench {
        let fuzz = Fuzz.fromSeed(0xdeadbeef);

        let bench = Bench.Bench();
        bench.name("Comparing B+Tree and MemoryBTree");
        bench.description("Benchmarking the performance with 10k entries");

        bench.cols(["B+Tree", "MemoryBTree"]);
        bench.rows([
            "getFromIndex()",
            "getIndex()",
            "getFloor()",
            "getCeiling()",
            "removeMin()",
            "removeMax()",
        ]);

        let limit = 10_000;

        let bptree = BpTree.new<Nat, Nat>(?32);
        let bptree2 = BpTree.new<Nat, Nat>(?32);
        let mem_btree = MemoryBTree.new(?256);
        let mem_btree2 = MemoryBTree.new(?256);

        let btree_utils = MemoryBTree.createUtils(
            TypeUtils.BigEndian.Nat,
            TypeUtils.Nat,
        );

        let entries = Buffer.Buffer<(Nat, Nat)>(limit);

        for (i in Iter.range(0, limit - 1)) {
            let key = fuzz.nat.randomRange(1, limit ** 3);
            let val = fuzz.nat.randomRange(1, limit ** 3);

            entries.add((key, val));
            ignore BpTree.insert(bptree, Cmp.Nat, key, val);
            ignore BpTree.insert(bptree2, Cmp.Nat, key, val);

            ignore MemoryBTree.insert(mem_btree, btree_utils, key, val);
            ignore MemoryBTree.insert(mem_btree2, btree_utils, key, val);
        };

        let sorted = Buffer.clone(entries);
        sorted.sort(func(a, b) = Nat.compare(a.0, b.0));

        bench.runner(
            func(col, row) = switch (row, col) {
                case ("B+Tree", "getFromIndex()") {
                    for (i in Iter.range(0, limit - 1)) {
                        ignore BpTree.getFromIndex(bptree, i);
                    };
                };
                case ("B+Tree", "getIndex()") {
                    for ((key, val) in entries.vals()) {
                        ignore BpTree.getIndex(bptree, Cmp.Nat, key);
                    };
                };
                case ("B+Tree", "getFloor()") {
                    for (kv in entries.vals()) {
                        ignore BpTree.getFloor(bptree, Cmp.Nat, kv.0);
                    };
                };
                case ("B+Tree", "getCeiling()") {
                    for (kv in entries.vals()) {
                        ignore BpTree.getFloor(bptree, Cmp.Nat, kv.0);
                    };
                };
                case ("B+Tree", "removeMin()") {
                    while (BpTree.size(bptree) > 0) {
                        ignore BpTree.removeMin(bptree, Cmp.Nat);
                    };
                };
                case ("B+Tree", "removeMax()") {
                    while (BpTree.size(bptree2) > 0) {
                        ignore BpTree.removeMax(bptree2, Cmp.Nat);
                    };
                };

                case ("MemoryBTree", "getFromIndex()") {
                    for (i in Iter.range(0, limit - 1)) {
                        ignore MemoryBTree.getFromIndex(mem_btree, btree_utils, i);
                    };
                };
                case ("MemoryBTree", "getIndex()") {
                    for ((key, val) in entries.vals()) {
                        ignore MemoryBTree.getIndex(mem_btree, btree_utils, key);
                    };
                };
                case ("MemoryBTree", "getFloor()") {
                    for (kv in entries.vals()) {
                        ignore MemoryBTree.getFloor(mem_btree, btree_utils, kv.0);
                    };
                };
                case ("MemoryBTree", "getCeiling()") {
                    for (kv in entries.vals()) {
                        ignore MemoryBTree.getFloor(mem_btree, btree_utils, kv.0);
                    };
                };
                case ("MemoryBTree", "removeMin()") {
                    while (MemoryBTree.size(mem_btree) > 0) {
                        ignore MemoryBTree.removeMin(mem_btree, btree_utils);
                    };
                };
                case ("MemoryBTree", "removeMax()") {
                    while (MemoryBTree.size(mem_btree2) > 0) {
                        ignore MemoryBTree.removeMax(mem_btree2, btree_utils);
                    };
                };

                case (_) {
                    Debug.trap("Should not reach with row = " # debug_show row # " and col = " # debug_show col);
                };
            }
        );

        bench;
    };
};
