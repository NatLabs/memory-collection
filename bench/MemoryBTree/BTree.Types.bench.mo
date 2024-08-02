import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Nat "mo:base/Nat";

import Bench "mo:bench";
import Fuzz "mo:fuzz";
import MotokoStableBTree "mo:MotokoStableBTree/BTree";

import MemoryBTree "../../src/MemoryBTree/Base";
import TypeUtils "../../src/TypeUtils";
import Int8Cmp "../../src/TypeUtils/Int8Cmp";

module {

    type MemoryBTree = MemoryBTree.MemoryBTree;
    type TypeUtils<K> = TypeUtils.TypeUtils<K>;
    type Buffer<T> = Buffer.Buffer<T>;

    public func init() : Bench.Bench {
        let fuzz = Fuzz.fromSeed(0xdeadbeef);

        let bench = Bench.Bench();
        bench.name("Comparing B+Tree and Memory B+Tree with different serialization formats and comparison functions");
        bench.description("Benchmarking the performance with 10k entries");

        bench.rows([
            "Memory B+Tree - Text (#BlobCmp)",
            "Memory B+Tree - Text (#GenCmp)",
            "Memory B+Tree - Candid Text (#BlobCmp)",
            "Memory B+Tree - Candid Text (#GenCmp)",
            "Memory B+Tree - Nat (#BlobCmp)",
            "Memory B+Tree - Nat (#GenCmp)",
            "Memory B+Tree - Candid Nat (#GenCmp)",
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

        let mem_btree_text_gen_cmp = MemoryBTree.new(?128);
        let mem_btree_text_blob_cmp = MemoryBTree.new(?128);
        let mem_btree_candid_text_gen_cmp = MemoryBTree.new(?128);
        let mem_btree_candid_text_blob_cmp = MemoryBTree.new(?128);

        let mem_btree_nat_gen_cmp = MemoryBTree.new(?128);
        let mem_btree_nat_blob_cmp = MemoryBTree.new(?128);
        let mem_btree_candid_nat_gen_cmp = MemoryBTree.new(?128);
        let mem_btree_candid_nat_blob_cmp = MemoryBTree.new(?128);

        let entries = Buffer.Buffer<(Text, Text)>(limit);
        let nat_entries = Buffer.Buffer<(Nat, Nat)>(limit);
        // let replacements = Buffer.Buffer<(Text, Text)>(limit);

        for (i in Iter.range(0, limit - 1)) {
            let key = fuzz.text.randomAlphabetic(10);

            entries.add((key, key));

            let n = fuzz.nat.randomRange(0, limit ** 2);
            nat_entries.add((n, n));

            // let replace_val = fuzz.text.randomAlphabetic(10);

            // replacements.add((key, key));
        };

        let sorted = Buffer.clone(entries);
        sorted.sort(func(a, b) = Text.compare(a.0, b.0));

        func run_bench<K, V>(name : Text, category : Text, mem_btree : MemoryBTree, btree_utils : MemoryBTree.BTreeUtils<K, V>, entries : Buffer<(K, V)>, equal : (V, V) -> Bool) {
            switch (category) {
                case ("insert()") {
                    for ((key, val) in entries.vals()) {
                        ignore MemoryBTree.insert<K, V>(mem_btree, btree_utils, key, val);
                    };
                };
                case ("replace()") {
                    for ((key, val) in entries.vals()) {
                        ignore MemoryBTree.insert(mem_btree, btree_utils, key, val);
                    };
                };
                case ("get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        let (key, val) = entries.get(i);
                        let ?v = MemoryBTree.get(mem_btree, btree_utils, key);
                        assert equal(val, v);
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
        let gen_cmp_text_utils = MemoryBTree.createUtils({ TypeUtils.Text with cmp = #GenCmp(Int8Cmp.Text) }, TypeUtils.Text);

        let candid_text_utils = MemoryBTree.createUtils(TypeUtils.Candid.Text, TypeUtils.Candid.Text);
        let candid_text_gen_cmp_utils = MemoryBTree.createUtils({ TypeUtils.Candid.Text with cmp = #GenCmp(Int8Cmp.Text) }, TypeUtils.Candid.Text);

        let nat_btree_utils = MemoryBTree.createUtils(TypeUtils.BigEndian.Nat, TypeUtils.BigEndian.Nat);
        let nat_gen_cmp_utils = MemoryBTree.createUtils(
            { TypeUtils.BigEndian.Nat with cmp = #GenCmp(Int8Cmp.Nat) },
            TypeUtils.BigEndian.Nat,
        );

        let candid_nat_utils = MemoryBTree.createUtils(TypeUtils.Candid.Nat, TypeUtils.Candid.Nat);

        bench.runner(
            func(col, row) = switch (col, row) {

                case ("Memory B+Tree - Text (#BlobCmp)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_text_blob_cmp, btree_utils, entries, Text.equal);
                };

                case ("Memory B+Tree - Text (#GenCmp)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_text_gen_cmp, gen_cmp_text_utils, entries, Text.equal);
                };

                case ("Memory B+Tree - Candid Text (#BlobCmp)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_candid_text_blob_cmp, candid_text_utils, entries, Text.equal);
                };

                case ("Memory B+Tree - Candid Text (#GenCmp)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_candid_text_gen_cmp, candid_text_gen_cmp_utils, entries, Text.equal);
                };

                case ("Memory B+Tree - Nat (#BlobCmp)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_nat_blob_cmp, nat_btree_utils, nat_entries, Nat.equal);
                };

                case ("Memory B+Tree - Nat (#GenCmp)", category) {
                    run_bench<Nat, Nat>("Memory B+Tree", category, mem_btree_nat_gen_cmp, nat_gen_cmp_utils, nat_entries, Nat.equal);
                };

                case ("Memory B+Tree - Candid Nat (#GenCmp)", category) {
                    run_bench("Memory B+Tree", category, mem_btree_candid_nat_gen_cmp, candid_nat_utils, nat_entries, Nat.equal);
                };
                case (_) {
                    Debug.trap("Should not reach with row = " # debug_show row # " and col = " # debug_show col);
                };
            }
        );

        bench;
    };
};
