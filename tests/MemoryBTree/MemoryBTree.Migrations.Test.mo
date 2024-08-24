// @testmode wasi
import { test; suite } "mo:test";
import MemoryBTree "../../src/MemoryBTree/Base";
import StableMemoryBTree "../../src/MemoryBTree/Stable";
import Migrations "../../src/MemoryBTree/Migrations";
import OldMemoryBTree "mo:memory-collection-btree-v0-v0_0_1_migration/MemoryBTree/Stable";
import TypeUtils "../../src/TypeUtils";

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
        // test(
        //     "#v0 -> #v0_0_1",
        //     func() {
        //         let old_btree = OldMemoryBTree.new(?32);
        //         let btree_utils = MemoryBTree.createUtils(TypeUtils.Nat, TypeUtils.Nat);

        //         ignore OldMemoryBTree.insert(old_btree, btree_utils, 0, 0);
        //         ignore OldMemoryBTree.insert(old_btree, btree_utils, 1, 1);
        //         ignore OldMemoryBTree.insert(old_btree, btree_utils, 2, 2);

        //         let new_btree = Migrations.upgrade(old_btree);

        //         assert StableMemoryBTree.get(new_btree, btree_utils, 0) == ?0;
        //         assert StableMemoryBTree.toArray(new_btree, btree_utils) == [(0, 0), (1, 1), (2, 2)];

        //     },
        // );
    },
);
