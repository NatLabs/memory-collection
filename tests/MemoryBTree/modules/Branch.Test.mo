// @testmode wasi
import { test; suite } "mo:test";
import Debug "mo:core@2.4/Debug";
import Runtime "mo:core@2.4/Runtime";
import Iter "mo:core@2.4/Iter";
import Nat "mo:core@2.4/Nat";

import MemoryBTree "../../../src/MemoryBTree/Base";
import TypeUtils "../../../src/TypeUtils";
import Branch "../../../src/MemoryBTree/modules/Branch";
import Leaf "../../../src/MemoryBTree/modules/Leaf";

let btree_utils = MemoryBTree.createUtils(TypeUtils.Nat, TypeUtils.Nat);

suite(
    "Branch Module Tests",
    func() {
        suite(
            "get_child_boundary_keys",
            func() {
                test(
                    "boundaries are ordered and only null at the edges",
                    func() {
                        // order=4 forces many splits and a multi-level tree even for small N
                        let btree = MemoryBTree.new(?4);

                        let limit = 200;
                        for (i in Nat.rangeInclusive(0, limit - 1)) {
                            ignore MemoryBTree.insert(btree, btree_utils, i, i);
                        };

                        assert MemoryBTree.leafCount(btree) > 1;

                        // Find the leftmost leaf by descending through child[0]
                        let first_leaf : Nat = if (btree.is_root_a_leaf) {
                            btree.root;
                        } else {
                            var node = btree.root;
                            // Walk down until we're at a branch whose children are leaves
                            while (not Branch.has_leaves(btree, node)) {
                                let ?child = Branch.get_child(btree, node, 0) else Runtime.trap("null child during leftmost descent");
                                node := child;
                            };
                            let ?leaf = Branch.get_child(btree, node, 0) else Runtime.trap("null leftmost leaf");
                            leaf;
                        };

                        // Traverse the sorted leaf linked list and verify boundary keys
                        var cur_leaf = first_leaf;
                        var is_first = true;
                        var opt_prev_right : ?Blob = null;

                        label leaf_loop loop {
                            let opt_next = Leaf.get_next(btree, cur_leaf);

                            let (left_boundary, right_boundary) : (?Blob, ?Blob) = switch (Leaf.get_parent(btree, cur_leaf)) {
                                case (null) (null, null); // single-leaf tree (root is leaf)
                                case (?parent) {
                                    let leaf_index = Leaf.get_index(btree, cur_leaf);
                                    Branch.get_child_boundary_keys(btree, parent, leaf_index);
                                };
                            };

                            // Left boundary is null only for the leftmost leaf
                            if (is_first) {
                                assert left_boundary == null;
                                is_first := false;
                            } else {
                                assert left_boundary != null;
                            };

                            // Right boundary is null only for the rightmost leaf (no successor)
                            switch (opt_next) {
                                case (null) assert right_boundary == null;
                                case (?_) assert right_boundary != null;
                            };

                            // The right boundary of the previous leaf must equal the left
                            // boundary of the current leaf — they share the same separator key
                            switch (opt_prev_right, left_boundary) {
                                case (null, null) {}; // first leaf, no previous right
                                case (?prev_right, ?cur_left) {
                                    assert prev_right == cur_left;
                                };
                                case _ Runtime.trap("boundary mismatch between consecutive leaves");
                            };

                            opt_prev_right := right_boundary;

                            switch (opt_next) {
                                case (null) break leaf_loop;
                                case (?next) cur_leaf := next;
                            };
                        };
                    },
                );

                test(
                    "works for shuffled insertions",
                    func() {
                        let btree = MemoryBTree.new(?4);

                        // Insert in a non-sequential pattern to stress splits
                        let limit = 150;
                        var i = 0;
                        while (i < limit) {
                            // interleave: 0, 148, 2, 146, 4, 144, ...
                            let k = if (i % 2 == 0) i else limit - 1 - i;
                            ignore MemoryBTree.insert(btree, btree_utils, k, k);
                            i += 1;
                        };

                        assert MemoryBTree.leafCount(btree) > 1;

                        let first_leaf : Nat = if (btree.is_root_a_leaf) {
                            btree.root;
                        } else {
                            var node = btree.root;
                            while (not Branch.has_leaves(btree, node)) {
                                let ?child = Branch.get_child(btree, node, 0) else Runtime.trap("null child during leftmost descent");
                                node := child;
                            };
                            let ?leaf = Branch.get_child(btree, node, 0) else Runtime.trap("null leftmost leaf");
                            leaf;
                        };

                        var cur_leaf = first_leaf;
                        var is_first = true;
                        var opt_prev_right : ?Blob = null;

                        label leaf_loop loop {
                            let opt_next = Leaf.get_next(btree, cur_leaf);

                            let (left_boundary, right_boundary) : (?Blob, ?Blob) = switch (Leaf.get_parent(btree, cur_leaf)) {
                                case (null) (null, null);
                                case (?parent) {
                                    let leaf_index = Leaf.get_index(btree, cur_leaf);
                                    Branch.get_child_boundary_keys(btree, parent, leaf_index);
                                };
                            };

                            if (is_first) {
                                assert left_boundary == null;
                                is_first := false;
                            } else {
                                assert left_boundary != null;
                            };

                            switch (opt_next) {
                                case (null) assert right_boundary == null;
                                case (?_) assert right_boundary != null;
                            };

                            switch (opt_prev_right, left_boundary) {
                                case (null, null) {};
                                case (?prev_right, ?cur_left) assert prev_right == cur_left;
                                case _ Runtime.trap("boundary mismatch between consecutive leaves");
                            };

                            opt_prev_right := right_boundary;

                            switch (opt_next) {
                                case (null) break leaf_loop;
                                case (?next) cur_leaf := next;
                            };
                        };
                    },
                );
            },
        );
    },
);
