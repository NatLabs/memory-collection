// @testmode wasi
import { test; suite } "mo:test";
import MemoryBTree "../../src/MemoryBTree/Base";
import StableMemoryBTree "../../src/MemoryBTree/Stable";
import Migrations "../../src/MemoryBTree/Migrations";

suite(
    "MemoryBTree Migration Tests",
    func() {
        test(
            "deploys current version",
            func() {
                let vs_memory_btree = StableMemoryBTree.new(?32);
                ignore Migrations.getCurrentVersion(vs_memory_btree); // should not trap

                let memory_btree = MemoryBTree.new(?32);
                let version = MemoryBTree.toVersioned(memory_btree);
                ignore Migrations.getCurrentVersion(version); // should not trap
            },
        );
    },
);
