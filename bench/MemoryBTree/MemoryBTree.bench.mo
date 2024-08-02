import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Nat64 "mo:base/Nat64";
import Region "mo:base/Region";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import RBTree "mo:base/RBTree";

import BTree "mo:stableheapbtreemap/BTree";
import Bench "mo:bench";
import Fuzz "mo:fuzz";
import MotokoStableBTree "mo:MotokoStableBTree/BTree";
import BTreeMap "mo:MotokoStableBTree/modules/btreemap";
import BTreeMapMemory "mo:MotokoStableBTree/modules/memory";

import { BpTree; Cmp } "mo:augmented-btrees";

import MemoryBTree "../../src/MemoryBTree/Base";
import TypeUtils "../../src/TypeUtils";
import Int8Cmp "../../src/TypeUtils/Int8Cmp";
module {

    type MemoryBTree = MemoryBTree.MemoryBTree;
    type BTreeUtils<K, V> = MemoryBTree.BTreeUtils<K, V>;

    public func init() : Bench.Bench {
        let fuzz = Fuzz.fromSeed(0xdeadbeef);

        let bench = Bench.Bench();
        bench.name("Comparing RBTree, BTree and B+Tree (BpTree)");
        bench.description("Benchmarking the performance with 10k entries");

        bench.rows([
            "RBTree",
            "BTree",
            "B+Tree",
            "Memory B+Tree (#BlobCmp)",
            "Memory B+Tree (#GenCmp)",
        ]);
        bench.cols([
            "insert()",
            "get()",
            "replace()",
            "entries()",
            // "scan()",
            "remove()",
        ]);

        let limit = 10_000;

        let { n64conv; tconv } = MotokoStableBTree;

        let tconv_10 = tconv(10);
        let rbtree = RBTree.RBTree<Text, Text>(Text.compare);
        let btree = BTree.init<Text, Text>(?32);
        let bptree = BpTree.new<Text, Text>(?128);
        let stable_btree = BTreeMap.new<Text, Text>(BTreeMapMemory.RegionMemory(Region.new()), tconv_10, tconv_10);
        let mem_btree = MemoryBTree.new(?128);
        let mem_btree_blob_cmp = MemoryBTree.new(?128);

        let entries = Buffer.Buffer<(Text, Text)>(limit);
        let replacements = Buffer.Buffer<(Text, Text)>(limit);

        for (i in Iter.range(0, limit - 1)) {
            let key = fuzz.text.randomAlphabetic(10);

            entries.add((key, key));

            let replaced_size = fuzz.nat.randomRange(5, 15);

            let replace_val = fuzz.text.randomAlphabetic(replaced_size);

            replacements.add((key, replace_val));
        };

        let sorted = Buffer.clone(entries);
        sorted.sort(func(a, b) = Text.compare(a.0, b.0));

        func run_bench<K, V>(name : Text, category : Text, mem_btree : MemoryBTree, btree_utils : BTreeUtils<Text, Text>) {
            switch (category) {
                case ("insert()") {
                    for ((key, val) in entries.vals()) {
                        ignore MemoryBTree.insert<Text, Text>(mem_btree, btree_utils, key, val);
                    };
                };
                case ("replace()") {
                    for ((key, val) in replacements.vals()) {
                        ignore MemoryBTree.insert(mem_btree, btree_utils, key, val);
                    };
                };
                case ("get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        let (key, val) = entries.get(i);
                        assert ?val == MemoryBTree.get(mem_btree, btree_utils, key);
                    };
                };
                case ("entries()") {
                    for (kv in MemoryBTree.entries(mem_btree, btree_utils)) {
                        ignore kv;
                    };
                };
                case ("scan()") {};
                case ("remove()") {
                    for ((k, v) in entries.vals()) {
                        ignore MemoryBTree.remove(mem_btree, btree_utils, k);
                    };
                };
                case (_) {
                    Debug.trap("Should not reach with name = " # debug_show name # " and category = " # debug_show category);
                };
            };
        };

        let btree_utils = MemoryBTree.createUtils(TypeUtils.Text, TypeUtils.Text);
        let ds_text_utils = MemoryBTree.createUtils({ TypeUtils.Text with cmp = #GenCmp(Int8Cmp.Text) }, TypeUtils.Text);

        bench.runner(
            func(col, row) = switch (col, row) {

                case ("RBTree", "insert()") {
                    var i = 0;

                    for ((key, val) in entries.vals()) {
                        rbtree.put(key, val);
                        i += 1;
                    };
                };
                case ("RBTree", "replace()") {
                    var i = 0;

                    for ((key, val) in replacements.vals()) {
                        rbtree.put(key, val);
                        i += 1;
                    };
                };
                case ("RBTree", "get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        let key = entries.get(i).0;
                        ignore rbtree.get(key);
                    };
                };
                case ("RBTree", "entries()") {
                    for (i in rbtree.entries()) { ignore i };
                };
                case ("RBTree", "scan()") {};
                case ("RBTree", "remove()") {
                    for ((k, v) in entries.vals()) {
                        rbtree.delete(k);
                    };
                };

                case ("BTree", "insert()") {
                    for ((key, val) in entries.vals()) {
                        ignore BTree.insert(btree, Text.compare, key, val);
                    };
                };
                case ("BTree", "replace()") {
                    for ((key, val) in replacements.vals()) {
                        ignore BTree.insert(btree, Text.compare, key, val);
                    };
                };
                case ("BTree", "get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        let key = entries.get(i).0;
                        ignore BTree.get(btree, Text.compare, key);
                    };
                };
                case ("BTree", "entries()") {
                    for (i in BTree.entries(btree)) { ignore i };
                };
                case ("BTree", "scan()") {
                    var i = 0;

                    while (i < limit) {
                        let a = sorted.get(i).0;
                        let b = sorted.get(i + 99).0;

                        for (kv in BTree.scanLimit(btree, Text.compare, a, b, #fwd, 100).results.vals()) {
                            ignore kv;
                        };
                        i += 100;
                    };
                };
                case ("BTree", "remove()") {
                    for ((k, v) in entries.vals()) {
                        ignore BTree.delete(btree, Text.compare, k);
                    };
                };
                case ("B+Tree", "insert()") {
                    for ((key, val) in entries.vals()) {
                        ignore BpTree.insert(bptree, Cmp.Text, key, val);
                    };
                };
                case ("B+Tree", "replace()") {
                    for ((key, val) in entries.vals()) {
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

                case ("MotokoStableBTree", "insert()") {
                    for ((key, val) in entries.vals()) {
                        ignore stable_btree.insert(key, tconv_10, val, tconv_10);
                    };
                };
                case ("MotokoStableBTree", "replace()") {
                    for ((key, val) in entries.vals()) {
                        ignore stable_btree.insert(key, tconv_10, val, tconv_10);
                    };
                };
                case ("MotokoStableBTree", "get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        let (key, val) = entries.get(i);
                        ignore stable_btree.get(key, tconv_10, tconv_10);
                    };
                };
                case ("MotokoStableBTree", "entries()") {
                    var i = 0;
                    for (kv in stable_btree.iter(tconv_10, tconv_10)) {
                        i += 1;
                    };

                    assert Nat64.fromNat(i) == stable_btree.getLength();
                    Debug.print("Size: " # debug_show (i, stable_btree.getLength()));
                };
                case ("MotokoStableBTree", "scan()") {};
                case ("MotokoStableBTree", "remove()") {
                    for ((k, v) in entries.vals()) {
                        ignore stable_btree.remove(k, tconv_10, tconv_10);
                    };
                };

                case ("Memory B+Tree (#BlobCmp)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_blob_cmp, btree_utils);
                };

                case ("Memory B+Tree (#GenCmp)", category) {
                    run_bench("Memory B+Tree", category, mem_btree, ds_text_utils);
                };
                case (_) {
                    Debug.trap("Should not reach with row = " # debug_show row # " and col = " # debug_show col);
                };
            }
        );

        bench;
    };
};
