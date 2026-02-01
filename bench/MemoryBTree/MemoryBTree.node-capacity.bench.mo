import Iter "mo:base@0.14.13/Iter";
import Debug "mo:base@0.14.13/Debug";
import Nat "mo:base@0.14.13/Nat";
import Nat64 "mo:base@0.14.13/Nat64";
import Region "mo:base@0.14.13/Region";
import Buffer "mo:base@0.14.13/Buffer";
import Text "mo:base@0.14.13/Text";

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
        bench.name("Comparing the Memory B+Tree with different node capacities");
        bench.description("Benchmarking the performance with 10k entries");

        bench.rows([
            "B+Tree",
            "Memory B+Tree (16)",
            "Memory B+Tree (32)",
            "Memory B+Tree (64)",
            "Memory B+Tree (128)",
            "Memory B+Tree (256)",
            "Memory B+Tree (512)",
            "Memory B+Tree (1024)",
            "Memory B+Tree (2048)",
            "Memory B+Tree (4096)",
        ]);
        bench.cols([
            "insert()",
            "get()",
            "replace()",
            "entries()",
            "remove()",
            // "random ops",
        ]);

        let limit = 10_000;

        let bptree = BpTree.new<Text, Text>(?32);
        let mem_btree_order_16 = MemoryBTree.new(?16);
        let mem_btree_order_32 = MemoryBTree.new(?32);
        let mem_btree_order_64 = MemoryBTree.new(?64);
        let mem_btree_order_128 = MemoryBTree.new(?128);
        let mem_btree_order_256 = MemoryBTree.new(?256);
        let mem_btree_order_512 = MemoryBTree.new(?512);
        let mem_btree_order_1024 = MemoryBTree.new(?1024);
        let mem_btree_order_2048 = MemoryBTree.new(?2048);
        let mem_btree_order_4096 = MemoryBTree.new(?4096);

        let entries = Buffer.Buffer<(Text, Text)>(limit);
        let replacements = Buffer.Buffer<(Text, Text)>(limit);
        let random_ops = Buffer.Buffer<{ #insert : (Text, Text); #replace : (Text, Text); #remove : Text }>(limit);

        for (i in Iter.range(0, limit - 1)) {
            let key = fuzz.text.randomAlphabetic(10);

            entries.add((key, key));
            let replaced_size = fuzz.nat.randomRange(5, 15);

            let replace_val = fuzz.text.randomAlphabetic(replaced_size);

            replacements.add((key, replace_val));
        };

        // Generate random operations sequence
        let inserted_keys = Buffer.Buffer<Text>(limit);
        for (i in Iter.range(0, limit - 1)) {
            let op_type = fuzz.nat.randomRange(0, 3);

            // Ensure at least 3 items are inserted first
            if (inserted_keys.size() < 3 or op_type < 2) {
                // 50% insert
                let key = fuzz.text.randomAlphabetic(10);
                let val = fuzz.text.randomAlphabetic(10);
                random_ops.add(#insert(key, val));
                inserted_keys.add(key);
            } else if (op_type == 2) {
                // 25% replace
                let idx = if (inserted_keys.size() == 1) 0 else fuzz.nat.randomRange(0, inserted_keys.size() - 1);
                let key = inserted_keys.get(idx);
                let val = fuzz.text.randomAlphabetic(fuzz.nat.randomRange(5, 15));
                random_ops.add(#replace(key, val));
            } else {
                // 25% remove
                let idx = if (inserted_keys.size() == 1) 0 else fuzz.nat.randomRange(0, inserted_keys.size() - 1);
                let key = inserted_keys.get(idx);
                random_ops.add(#remove(key));
                // Swap remove to keep track of remaining keys
                let last = inserted_keys.removeLast();
                if (idx < inserted_keys.size()) {
                    switch (last) {
                        case (?v) { inserted_keys.put(idx, v) };
                        case (null) {};
                    };
                };
            };
        };

        let sorted = Buffer.clone(entries);
        sorted.sort(func(a, b) = Text.compare(a.0, b.0));

        let btree_utils = MemoryBTree.createUtils({ TypeUtils.Text with cmp = TypeUtils.MemoryCmp.Default }, TypeUtils.Text);

        func run_bench(name : Text, category : Text, mem_btree_order : MemoryBTree) {
            switch (category) {
                case ("insert()") {
                    for ((key, val) in entries.vals()) {
                        ignore MemoryBTree.insert<Text, Text>(mem_btree_order, btree_utils, key, val);
                    };
                };
                case ("random ops") {
                    for (op in random_ops.vals()) {
                        switch (op) {
                            case (#insert(key, val)) {
                                ignore MemoryBTree.insert(mem_btree_order, btree_utils, key, val);
                            };
                            case (#replace(key, val)) {
                                ignore MemoryBTree.insert(mem_btree_order, btree_utils, key, val);
                            };
                            case (#remove(key)) {
                                ignore MemoryBTree.remove(mem_btree_order, btree_utils, key);
                            };
                        };
                    };
                };
                case ("replace()") {
                    for ((key, val) in replacements.vals()) {
                        ignore MemoryBTree.insert(mem_btree_order, btree_utils, key, val);
                    };
                };
                case ("get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        let (key, val) = entries.get(i);
                        assert ?val == MemoryBTree.get(mem_btree_order, btree_utils, key);
                    };
                };
                case ("entries()") {
                    for (kv in MemoryBTree.entries(mem_btree_order, btree_utils)) {
                        ignore kv;
                    };
                };
                case ("scan()") {};
                case ("remove()") {
                    for ((k, v) in entries.vals()) {
                        ignore MemoryBTree.remove(mem_btree_order, btree_utils, k);
                    };
                };
                case (_) {
                    Debug.trap("Should not reach with name = " # debug_show name # " and category = " # debug_show category);
                };
            };
        };

        bench.runner(
            func(col, row) = switch (col, row) {

                case ("B+Tree", "insert()") {
                    for ((key, val) in entries.vals()) {
                        ignore BpTree.insert(bptree, Cmp.Text, key, val);
                    };
                };
                case ("B+Tree", "random ops") {
                    for (op in random_ops.vals()) {
                        switch (op) {
                            case (#insert(key, val)) {
                                ignore BpTree.insert(bptree, Cmp.Text, key, val);
                            };
                            case (#replace(key, val)) {
                                ignore BpTree.insert(bptree, Cmp.Text, key, val);
                            };
                            case (#remove(key)) {
                                ignore BpTree.remove(bptree, Cmp.Text, key);
                            };
                        };
                    };
                };
                case ("B+Tree", "replace()") {
                    for ((key, val) in replacements.vals()) {
                        ignore BpTree.insert(bptree, Cmp.Text, key, val);
                    };
                };
                case ("B+Tree", "get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        let key = entries.get(i).0;
                        ignore BpTree.get(bptree, Cmp.Text, key);
                    };
                };
                case ("B+Tree", "entries()") {
                    for (kv in BpTree.entries(bptree)) { ignore kv };
                };
                case ("B+Tree", "scan()") {
                    var i = 0;

                    while (i < limit) {
                        let a = sorted.get(i).0;
                        let b = sorted.get(i + 99).0;

                        for (kv in BpTree.scan(bptree, Cmp.Text, ?a, ?b)) {
                            ignore kv;
                        };
                        i += 100;
                    };
                };
                case ("B+Tree", "remove()") {
                    for ((k, v) in entries.vals()) {
                        ignore BpTree.remove(bptree, Cmp.Text, k);
                    };
                };

                case ("Memory B+Tree (16)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_order_16);
                };
                case ("Memory B+Tree (32)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_order_32);
                };
                case ("Memory B+Tree (64)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_order_64);
                };
                case ("Memory B+Tree (128)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_order_128);
                };
                case ("Memory B+Tree (256)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_order_256);
                };
                case ("Memory B+Tree (512)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_order_512);
                };
                case ("Memory B+Tree (1024)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_order_1024);
                };
                case ("Memory B+Tree (2048)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_order_2048);
                };
                case ("Memory B+Tree (4096)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_order_4096);
                };

                case (_) {
                    Debug.trap("Should not reach with row = " # debug_show row # " and col = " # debug_show col);
                };
            }
        );

        bench;
    };
};
