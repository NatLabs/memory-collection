import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";

import RevIter "mo:itertools/RevIter";
import BufferDeque "mo:buffer-deque/BufferDeque";
// import Branch "mo:augmented-btrees/BpTree/Branch";

import T "Types";
import Leaf "Leaf";
import Branch "Branch";
import Migrations "../Migrations";

module {
    type MemoryBTree = Migrations.MemoryBTree;
    type MemoryBlock = T.MemoryBlock;

    type Address = Nat;
    type RevIter<A> = RevIter.RevIter<A>;
    public type BTreeUtils<K, V> = T.BTreeUtils<K, V>;

    public func get_leaf_address<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, key : K, _opt_key_blob : ?Blob) : Nat {
        var curr_address = btree.root;
        var is_address_a_leaf = btree.is_root_a_leaf;
        var opt_key_blob : ?Blob = _opt_key_blob;

        loop {
            switch (is_address_a_leaf) {
                case (true) {
                    assert Leaf.validate(btree, curr_address);
                    return curr_address;
                };
                case (false) {
                    // load breanch from stable memory

                    assert Branch.get_magic(btree, curr_address) == Branch.MC.MAGIC;

                    let count = Branch.get_count(btree, curr_address);

                    let int_index = switch (btree_utils.key.cmp) {
                        case (#GenCmp(cmp)) Branch.binary_search<K, V>(btree, btree_utils, curr_address, cmp, key, count - 1);
                        case (#BlobCmp(cmp)) {

                            let key_blob = switch (opt_key_blob) {
                                case (null) {
                                    let key_blob = btree_utils.key.blobify.to_blob(key);
                                    opt_key_blob := ?key_blob;
                                    key_blob;
                                };
                                case (?key_blob) key_blob;
                            };

                            Branch.binary_search_blob_seq(btree, curr_address, cmp, key_blob, count - 1);
                        };
                    };

                    let child_index = if (int_index >= 0) Int.abs(int_index) + 1 else Int.abs(int_index + 1);
                    let parent_address = curr_address;
                    let ?child_address = Branch.get_child(btree, curr_address, child_index) else Debug.trap("get_leaf_node: accessed a null value");
                    curr_address := child_address;
                    is_address_a_leaf := Branch.has_leaves(btree, parent_address);
                };
            };
        };
    };

    public func get_leaf_address_and_update_path<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, key : K, _opt_key_blob : ?Blob, update : (MemoryBTree, Nat, Nat) -> ()) : Nat {
        var curr_address = btree.root;
        var is_address_a_leaf = btree.is_root_a_leaf;
        var opt_key_blob : ?Blob = _opt_key_blob;

        loop {
            // Debug.print("curr_address: " # debug_show curr_address);
            switch (is_address_a_leaf) {
                case (true) {
                    // Debug.print("leaf: " # debug_show curr_address);
                    assert Leaf.validate(btree, curr_address);
                    return curr_address;
                };
                case (false) {
                    // Debug.print("branch: " # debug_show curr_address);
                    // load breanch from stable memory
                    assert Branch.get_magic(btree, curr_address) == Branch.MC.MAGIC;

                    let count = Branch.get_count(btree, curr_address);

                    let int_index = switch (btree_utils.key.cmp) {
                        case (#GenCmp(cmp)) Branch.binary_search<K, V>(btree, btree_utils, curr_address, cmp, key, count - 1);
                        case (#BlobCmp(cmp)) {

                            let key_blob = switch (opt_key_blob) {
                                case (null) {
                                    let key_blob = btree_utils.key.blobify.to_blob(key);
                                    opt_key_blob := ?key_blob;
                                    key_blob;
                                };
                                case (?key_blob) key_blob;
                            };

                            Branch.binary_search_blob_seq(btree, curr_address, cmp, key_blob, count - 1);
                        };
                    };

                    let child_index = if (int_index >= 0) Int.abs(int_index) + 1 else Int.abs(int_index + 1);
                    let parent_address = curr_address;
                    let ?child_address = Branch.get_child(btree, parent_address, child_index) else Debug.trap("get_leaf_node: accessed a null value");
                    update(btree, curr_address, child_index);
                    curr_address := child_address;
                    is_address_a_leaf := Branch.has_leaves(btree, parent_address);
                };
            };
        };
    };

    public func get_min_leaf_address(btree : MemoryBTree) : Nat {
        var curr = btree.root;
        var is_address_a_leaf = btree.is_root_a_leaf;

        loop {
            switch (is_address_a_leaf) {
                case (false) {
                    let ?first_child = Branch.get_child(btree, curr, 0) else Debug.trap("get_min_leaf: accessed a null value");
                    is_address_a_leaf := Branch.has_leaves(btree, curr);
                    curr := first_child;
                };
                case (true) return curr;
            };
        };
    };

    public func get_max_leaf_address(btree : MemoryBTree) : Nat {
        var curr = btree.root;
        var is_address_a_leaf = btree.is_root_a_leaf;

        loop {
            switch (is_address_a_leaf) {
                case (false) {
                    let count = Branch.get_count(btree, curr);
                    let ?last_child = Branch.get_child(btree, curr, count - 1) else Debug.trap("get_max_leaf: accessed a null value");
                    is_address_a_leaf := Branch.has_leaves(btree, curr);
                    curr := last_child;
                };
                case (true) return curr;
            };
        };

    };

    public func update_leaf_to_root(btree : MemoryBTree, leaf_address : Nat, update : (MemoryBTree, Nat, Nat) -> ()) {
        var parent = Leaf.get_parent(btree, leaf_address);
        var child_index = Leaf.get_index(btree, leaf_address);

        loop {
            switch (parent) {
                case (?branch_address) {
                    update(btree, branch_address, child_index);
                    child_index := Branch.get_index(btree, branch_address);
                    parent := Branch.get_parent(btree, branch_address);
                };

                case (_) return;
            };
        };
    };

    public func update_branch_to_root(btree : MemoryBTree, branch_address : Nat, update : (MemoryBTree, Nat, Nat) -> ()) {
        var parent = Branch.get_parent(btree, branch_address);
        var child_index = Branch.get_index(btree, branch_address);

        loop {
            switch (parent) {
                case (?branch_address) {
                    update(btree, branch_address, child_index);
                    child_index := Branch.get_index(btree, branch_address);
                    parent := Branch.get_parent(btree, branch_address);
                };

                case (_) return;
            };
        };
    };

    // Returns the leaf node and rank of the first element in the leaf node
    public func get_leaf_node_and_index<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>, key : Blob) : (Address, Nat) {
        let branch = switch (btree.is_root_a_leaf) {
            case (true) return (btree.root, 0);
            case (false) btree.root;
        };

        var rank = Branch.get_subtree_size(btree, branch);

        func get_node(parent : Address, key : Blob) : Address {
            let parent_count = Branch.get_count(btree, parent);
            var i = parent_count - 1 : Nat;
            var is_address_a_leaf = Branch.has_leaves(btree, parent);

            label get_node_loop while (i >= 1) {
                let ?child = Branch.get_child(btree, parent, i) else Debug.trap("get_leaf_node_and_index 0: accessed a null value");
                let ?search_key = Branch.get_key_blob(btree, parent, i - 1) else Debug.trap("get_leaf_node_and_index 1: accessed a null value");

                switch (is_address_a_leaf) {
                    case (false) {

                        switch (btree_utils.key.cmp) {
                            case (#GenCmp(cmp)) {
                                let ds_key = btree_utils.key.blobify.from_blob(key);
                                let ds_search_key = btree_utils.key.blobify.from_blob(search_key);

                                if (cmp(ds_key, ds_search_key) >= 0) {
                                    return get_node(child, key);
                                };
                            };
                            case (#BlobCmp(cmp)) {
                                if (cmp(key, search_key) >= 0) {
                                    return get_node(child, key);
                                };
                            };
                        };

                        rank -= Branch.get_subtree_size(btree, child);
                    };
                    case (true) {
                        // subtract before comparison because we want the rank of the first element in the leaf node
                        rank -= Leaf.get_count(btree, child);

                        switch (btree_utils.key.cmp) {
                            case (#GenCmp(cmp)) {
                                let ds_key = btree_utils.key.blobify.from_blob(key);
                                let ds_search_key = btree_utils.key.blobify.from_blob(search_key);
                                if (cmp(ds_key, ds_search_key) >= 0) {
                                    return child;
                                };
                            };
                            case (#BlobCmp(cmp)) {
                                if (cmp(key, search_key) >= 0) {
                                    return child;
                                };
                            };
                        };

                    };
                };

                i -= 1;
            };

            let ?first_child = Branch.get_child(btree, parent, 0) else Debug.trap("get_leaf_node_and_index 2: accessed a null value");

            switch (Branch.has_leaves(btree, parent)) {
                case (false) {
                    return get_node(first_child, key);
                };
                case (true) {
                    rank -= Leaf.get_count(btree, first_child);
                    return first_child;
                };
            };
        };

        (get_node(branch, key), rank);
    };

    public func get_leaf_node_by_index<K, V>(btree : MemoryBTree, rank : Nat) : (Address, Nat) {
        let root = switch (btree.is_root_a_leaf) {
            case (false) btree.root;
            case (true) return (btree.root, rank);
        };

        var search_index = rank;

        func get_node(parent : Address) : Address {
            var i = Branch.get_count(btree, parent) - 1 : Nat;
            var parent_subtree_size = Branch.get_subtree_size(btree, parent);
            var is_address_a_leaf = Branch.has_leaves(btree, parent);

            label get_node_loop loop {
                let ?child = Branch.get_child(btree, parent, i) else Debug.trap("get_leaf_node_by_index 0: accessed a null value");

                switch (is_address_a_leaf) {
                    case (false) {
                        let child_subtree_size = Branch.get_subtree_size(btree, child);

                        parent_subtree_size -= child_subtree_size;
                        if (parent_subtree_size <= search_index) {
                            search_index -= parent_subtree_size;
                            return get_node(child);
                        };

                    };
                    case (true) {
                        let child_subtree_size = Leaf.get_count(btree, child);
                        parent_subtree_size -= child_subtree_size;

                        if (parent_subtree_size <= search_index) {
                            search_index -= parent_subtree_size;
                            return child;
                        };

                    };
                };

                i -= 1;
            };

            Debug.trap("get_leaf_node_by_index 3: reached unreachable code");
        };

        (get_node(root), search_index);
    };

    public func new_blobs_iterator(
        btree : MemoryBTree,
        start_leaf : Nat,
        start_index : Nat,
        end_leaf : Nat,
        end_index : Nat // exclusive
    ) : RevIter<(Blob, Blob)> {

        var start = start_leaf;
        var i = start_index;
        var start_count = Leaf.get_count(btree, start_leaf);

        var end = end_leaf;
        var j = end_index;

        var terminate = false;

        func next() : ?(Blob, Blob) {
            if (terminate) return null;

            if (start == end and i >= j) {
                return null;
            };

            if (i >= start_count) {
                switch (Leaf.get_next(btree, start)) {
                    case (null) {
                        terminate := true;
                    };
                    case (?next_address) {
                        start := next_address;
                        start_count := Leaf.get_count(btree, next_address);
                    };
                };

                i := 0;
                return next();
            };

            let opt_kv = Leaf.get_kv_blobs(btree, start, i);

            i += 1;
            return opt_kv;
        };

        func nextFromEnd() : ?(Blob, Blob) {
            if (terminate) return null;

            if (start == end and i >= j) return null;

            if (j == 0) {
                switch (Leaf.get_prev(btree, end)) {
                    case (null) terminate := true;
                    case (?prev_address) {
                        end := prev_address;
                        j := Leaf.get_count(btree, prev_address);
                    };
                };

                return nextFromEnd();
            };

            let opt_kv = Leaf.get_kv_blobs(btree, end, j - 1);

            j -= 1;

            return opt_kv;
        };

        RevIter.new(next, nextFromEnd);
    };

    public func key_val_blobs(btree : MemoryBTree) : RevIter<(Blob, Blob)> {
        let min_leaf = get_min_leaf_address(btree);
        let max_leaf = get_max_leaf_address(btree);
        let max_leaf_count = Leaf.get_count(btree, max_leaf);

        new_blobs_iterator(btree, min_leaf, 0, max_leaf, max_leaf_count);
    };

    public func kv_block_addresses(btree : MemoryBTree) : Iter.Iter<Address> {

        let min_leaf = get_min_leaf_address(btree);
        var i = 0;
        var leaf_count = Leaf.get_count(btree, min_leaf);
        var var_leaf = ?min_leaf;

        object {
            public func next() : ?Address {
                let ?leaf = var_leaf else return null;

                if (i >= leaf_count) {
                    switch (Leaf.get_next(btree, leaf)) {
                        case (null) var_leaf := null;
                        case (?next_address) {
                            var_leaf := ?next_address;
                            leaf_count := Leaf.get_count(btree, leaf);
                        };
                    };

                    i := 0;
                    return next();
                };

                let address = Leaf.get_kv_address(btree, leaf, i);
                i += 1;
                return address;
            };
        };

    };

    public func deserialize_kv_blobs<K, V>(btree_utils : BTreeUtils<K, V>, key_blob : Blob, val_blob : Blob) : (K, V) {
        let key = btree_utils.key.blobify.from_blob(key_blob);
        let value = btree_utils.value.blobify.from_blob(val_blob);
        (key, value);
    };

    public func entries<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : RevIter<(K, V)> {
        RevIter.map<(Blob, Blob), (K, V)>(
            key_val_blobs(btree),
            func((key_blob, val_blob) : (Blob, Blob)) : (K, V) {
                deserialize_kv_blobs(btree_utils, key_blob, val_blob);
            },
        );
    };

    public func keys<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : RevIter<(K)> {
        RevIter.map<(Blob, Blob), (K)>(
            key_val_blobs(btree),
            func((key_blob, _) : (Blob, Blob)) : (K) {
                let key = btree_utils.key.blobify.from_blob(key_blob);
                key;
            },
        );
    };

    public func vals<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : RevIter<(V)> {
        RevIter.map<(Blob, Blob), V>(
            key_val_blobs(btree),
            func((_, val_blob) : (Blob, Blob)) : V {
                let value = btree_utils.value.blobify.from_blob(val_blob);
                value;
            },
        );
    };

    public func new_leaf_address_iterator(
        btree : MemoryBTree,
        start_leaf : Nat,
        end_leaf : Nat,
    ) : RevIter<Nat> {

        var start = start_leaf;
        var end = end_leaf;

        var terminate = false;

        func next() : ?Nat {
            if (terminate) return null;

            if (start == end) terminate := true;

            let curr = start;

            switch (Leaf.get_next(btree, start)) {
                case (null) terminate := true;
                case (?next_address) start := next_address;
            };

            return ?curr;
        };

        func nextFromEnd() : ?Nat {
            if (terminate) return null;

            if (start == end) terminate := true;

            let curr = end;

            switch (Leaf.get_prev(btree, end)) {
                case (null) terminate := true;
                case (?prev_address) end := prev_address;
            };

            return ?curr;
        };

        RevIter.new(next, nextFromEnd);
    };

    public func leaf_addresses(btree : MemoryBTree) : RevIter<Nat> {
        let min_leaf = get_min_leaf_address(btree);
        let max_leaf = get_max_leaf_address(btree);

        new_leaf_address_iterator(btree, min_leaf, max_leaf);
    };

    public func leaf_nodes<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : RevIter<[?(K, V)]> {
        let min_leaf = get_min_leaf_address(btree);
        let max_leaf = get_max_leaf_address(btree);

        RevIter.map<Nat, [?(K, V)]>(
            new_leaf_address_iterator(btree, min_leaf, max_leaf),
            func(leaf_address : Nat) : [?(K, V)] {

                let count = Leaf.get_count(btree, leaf_address);
                Array.tabulate<?(K, V)>(
                    btree.node_capacity,
                    func(i : Nat) : ?(K, V) {
                        if (i >= count) return null;

                        let ?(key, val) = Leaf.get_kv_blobs(btree, leaf_address, i) else Debug.trap("leaf_nodes: accessed a null value");
                        ?(btree_utils.key.blobify.from_blob(key), btree_utils.value.blobify.from_blob(val));
                    },
                );
            },
        );
    };

    public func node_keys<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : [[(Nat, Nat, Nat, [?K])]] {
        var nodes = BufferDeque.fromArray<(Address, Bool)>([(btree.root, btree.is_root_a_leaf)]);
        var buffer = Buffer.Buffer<[(Nat, Nat, Nat, [?K])]>(btree.branch_count);

        while (nodes.size() > 0) {
            let row = Buffer.Buffer<(Nat, Nat, Nat, [?K])>(nodes.size());

            for (_ in Iter.range(1, nodes.size())) {
                let ?(node, is_node_a_leaf) = nodes.popFront() else Debug.trap("node_keys: accessed a null value");

                switch (is_node_a_leaf) {
                    case (true) {};
                    case (false) {

                        let index = Branch.get_index(btree, node);
                        let count = Branch.get_count(btree, node);

                        let keys = Array.tabulate<?K>(
                            btree.node_capacity - 1,
                            func(i : Nat) : ?K {
                                if (i + 1 >= count) return null;

                                switch (Branch.get_key_blob(btree, node, i)) {
                                    case (?key_blob) {
                                        let key = btree_utils.key.blobify.from_blob(key_blob);
                                        return ?key;
                                    };
                                    case (_) Debug.trap("node_keys: accessed a null value while getting keys");
                                };
                            },
                        );

                        row.add((node, index, count, keys));

                        for (i in Iter.range(0, Branch.get_count(btree, node) - 1)) {
                            let ?child = Branch.get_child(btree, node, i) else Debug.trap("node_keys: accessed a null value");
                            let is_child_a_leaf = Branch.has_leaves(btree, node);
                            nodes.addBack(child, is_child_a_leaf);
                        };

                    };

                };
            };

            buffer.add(Buffer.toArray(row));

        };

        Buffer.toArray(buffer);
    };

    // public func validate_nested_elements_order(btree : MemoryBTree, btree_utils : BTreeUtils<Nat, Nat>) : Bool {
    //     let nodes = node_keys(btree, btree_utils);
    //     let leaves = leaf_nodes(btree, btree_utils);

    //     var i = 1;

    //     while (i < nodes.size()) {
    //         let top_row = nodes[i - 1];
    //         let bottom_row = nodes[i ];

    //         var j = 0;
    //         var k = 0;

    //         i += 1;

    //     };

    // };
    public func validate_memory(btree : MemoryBTree, btree_utils : BTreeUtils<Nat, Nat>) : Bool {

        func _validate(address : Nat, is_address_a_leaf : Bool) : (index : Nat, subtree_size : Nat) {

            switch (is_address_a_leaf) {
                case (true) {
                    assert Leaf.validate(btree, address);
                    let leaf = Leaf.from_memory(btree, address);

                    let index = Leaf.get_index(btree, address);
                    let count = Leaf.get_count(btree, address);
                    let depth = Leaf.get_depth(btree, address);

                    assert index == leaf.0 [Leaf.AC.INDEX];
                    assert count == leaf.0 [Leaf.AC.COUNT];
                    assert address == leaf.0 [Leaf.AC.ADDRESS];
                    assert depth == 1;

                    let (left_median_key, right_median_key) = switch (Leaf.get_parent(btree, address)) {
                        case (?parent) {
                            var left_median_key : ?Nat = null;
                            var right_median_key : ?Nat = null;

                            if (index > 0) {
                                let ?left_median_key_blob = Branch.get_key_blob(btree, parent, index - 1) else Debug.trap("1. validate: accessed a null value");
                                left_median_key := ?btree_utils.key.blobify.from_blob(left_median_key_blob);

                            };

                            let parent_count = Branch.get_count(btree, parent);

                            if (index + 1 < parent_count) {
                                let ?right_median_key_blob = Branch.get_key_blob(btree, parent, index) else Debug.trap("2. validate: accessed a null value");
                                right_median_key := ?btree_utils.key.blobify.from_blob(right_median_key_blob);

                            };

                            (left_median_key, right_median_key);

                        };
                        case (null) (null, null);
                    };

                    var i = 0;

                    var opt_prev_key : ?Nat = null;
                    while (i < count) {

                        let ?key_block = Leaf.get_key_block(btree, address, i) else Debug.trap("3. validate: accessed a null value");
                        let ?val_block = Leaf.get_val_block(btree, address, i) else Debug.trap("4. validate: accessed a null value");
                        let ?key_blob = Leaf.get_key_blob(btree, address, i) else Debug.trap("5. validate: accessed a null value");
                        let ?val_blob = Leaf.get_val_blob(btree, address, i) else Debug.trap("6. validate: accessed a null value");
                        let key = btree_utils.key.blobify.from_blob(key_blob);
                        // let val = btree_utils.value.blobify.from_blob(val_blob);

                        assert leaf.2 [i] == ?key_block;
                        assert leaf.3 [i] == ?val_block;
                        assert leaf.4 [i] == ?(key_blob, val_blob);

                        switch (opt_prev_key) {
                            case (null) {};
                            case (?prev_key) if (prev_key >= key) {
                                Debug.print("key mismatch at index: " # debug_show i);
                                Debug.print("prev: " # debug_show prev_key);
                                Debug.print("key: " # debug_show key);
                            };
                        };

                        switch (left_median_key) {
                            case (?left_median_key) {
                                assert left_median_key <= key;
                            };
                            case (null) {};
                        };

                        switch (right_median_key) {
                            case (?right_median_key) {
                                assert key < right_median_key;
                            };
                            case (null) {};
                        };

                        opt_prev_key := ?key;

                        i += 1;
                    };

                    assert i == count;
                    (index, count);
                };
                case (false) {
                    assert Branch.get_magic(btree, address) == Branch.MC.MAGIC;
                    let branch = Branch.from_memory(btree, address);

                    let index = Branch.get_index(btree, address);
                    let count = Branch.get_count(btree, address);
                    let subtree_size = Branch.get_subtree_size(btree, address);
                    let is_node_a_leaf = Branch.has_leaves(btree, address);
                    var children_subtree = 0;

                    assert index == branch.0 [Branch.AC.INDEX];
                    assert count == branch.0 [Branch.AC.COUNT];
                    assert address == branch.0 [Branch.AC.ADDRESS];
                    assert subtree_size == branch.0 [Branch.AC.SUBTREE_SIZE];

                    let (left_median_key, right_median_key) = switch (Branch.get_parent(btree, address)) {
                        case (?parent) {
                            var left_median_key : ?Nat = null;
                            var right_median_key : ?Nat = null;

                            if (index > 0) {
                                let ?left_median_key_blob = Branch.get_key_blob(btree, parent, index - 1) else Debug.trap("7. validate: accessed a null value");
                                left_median_key := ?btree_utils.key.blobify.from_blob(left_median_key_blob);

                            };

                            let parent_count = Branch.get_count(btree, parent);

                            if (index + 1 < parent_count) {
                                let ?right_median_key_blob = Branch.get_key_blob(btree, parent, index) else Debug.trap("8. validate: accessed a null value");
                                right_median_key := ?btree_utils.key.blobify.from_blob(right_median_key_blob);

                            };

                            (left_median_key, right_median_key);

                        };
                        case (null) (null, null);
                    };

                    var i = 0;

                    var opt_prev_key : ?Nat = null;

                    while (i < count) {
                        if (i + 1 < count) {
                            let ?key_blob = Branch.get_key_blob(btree, address, i) else Debug.trap("9. validate: accessed a null value");
                            let key = btree_utils.key.blobify.from_blob(key_blob);

                            assert ?key_blob == branch.6 [i];

                            switch (opt_prev_key) {
                                case (null) {};
                                case (?prev_key) if (prev_key >= key) {
                                    Debug.print("key mismatch at index: " # debug_show i);
                                    Debug.print("prev: " # debug_show prev_key);
                                    Debug.print("key: " # debug_show key);
                                    Branch.display(btree, btree_utils, address);

                                    assert false;
                                };
                            };

                            switch (left_median_key) {
                                case (?left_median_key) {
                                    assert left_median_key <= key;
                                };
                                case (null) {};
                            };

                            switch (right_median_key) {
                                case (?right_median_key) {
                                    assert key < right_median_key;
                                };
                                case (null) {};
                            };

                            opt_prev_key := ?key;
                        };

                        let ?child = Branch.get_child(btree, address, i) else Debug.trap("10. validate: accessed a null value");
                        let opt_child_parent = if (is_node_a_leaf) Leaf.get_parent(btree, child) else Branch.get_parent(btree, child);
                        let (branch_parent, expected_parent) = switch (opt_child_parent) {
                            case (?parent) (parent, address);
                            case (null) (address, btree.root);
                        };

                        if (branch_parent != expected_parent) Debug.trap(
                            "
                                        branch parent mismatch
                                        branch parent " # debug_show branch_parent # "
                                        expected " # debug_show expected_parent # "
                                        "
                        );

                        // Debug.print("address: " # debug_show address # " -> child: " # debug_show child);
                        let (child_index, child_subtree_size) = _validate(child, is_node_a_leaf);

                        assert child_index == i;
                        children_subtree += child_subtree_size;

                        i += 1;
                    };

                    assert i == count;
                    if (children_subtree != subtree_size) {
                        Debug.print("accumulated children subtree size is not equal to branch subtree size");
                        Debug.print("children_subtree: " # debug_show children_subtree);
                        Debug.print("branch subtree_size: " # debug_show subtree_size);
                        Debug.print("branch address: " # debug_show address);
                        assert false;
                    };

                    (index, subtree_size);
                };
            };
        };

        let response = _validate(btree.root, btree.is_root_a_leaf);
        // Debug.print("Validate response: " # debug_show response);
        let subtree_size = if (btree.is_root_a_leaf) Leaf.get_count(btree, btree.root) else Branch.get_subtree_size(btree, btree.root);
        response == (0, subtree_size);
    };

};
