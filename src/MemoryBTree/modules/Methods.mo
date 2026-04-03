import Debug "mo:core@2.4/Debug";
import Runtime "mo:core@2.4/Runtime";
import Array "mo:core@2.4/Array";
import Iter "mo:core@2.4/Iter";
import Int "mo:core@2.4/Int";
import Nat "mo:core@2.4/Nat";
import Nat8 "mo:core@2.4/Nat8";
import Blob "mo:core@2.4/Blob";
import Buffer "mo:base@0.16/Buffer";

import RevIter "mo:itertools@0.2/RevIter";
import BufferDeque "mo:buffer-deque@0.1/BufferDeque";
import MemoryRegion "mo:memory-region@1.5/MemoryRegion";
// import Branch "mo:augmented-btrees/BpTree/Branch";

import T "Types";
import Leaf "Leaf";
import Branch "Branch";
import Common "Common";
import Migrations "../Migrations";
import MemoryBlock "MemoryBlock";

module Methods {
  type MemoryBTree = Migrations.MemoryBTree;
  type MemoryBlock = T.MemoryBlock;

  type Address = Nat;
  type RevIter<A> = RevIter.RevIter<A>;
  public type BTreeUtils<K, V> = T.BTreeUtils<K, V>;

  // ====================================================================
  // TREE NAVIGATION & LOOKUP
  // ====================================================================

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
          assert Branch.validate(btree, curr_address);

          let count = Branch.get_count(btree, curr_address);

          let int_index = switch (btree_utils.key.cmp) {
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
          let ?child_address = Branch.get_child(btree, curr_address, child_index) else Runtime.trap("get_leaf_node: accessed a null value");
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
          assert Branch.validate(btree, curr_address);

          let count = Branch.get_count(btree, curr_address);

          let int_index = switch (btree_utils.key.cmp) {
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
          let ?child_address = Branch.get_child(btree, parent_address, child_index) else Runtime.trap("get_leaf_node: accessed a null value");
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
          let ?first_child = Branch.get_child(btree, curr, 0) else Runtime.trap("get_min_leaf: accessed a null value");
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
          let ?last_child = Branch.get_child(btree, curr, count - 1) else Runtime.trap("get_max_leaf: accessed a null value");
          is_address_a_leaf := Branch.has_leaves(btree, curr);
          curr := last_child;
        };
        case (true) return curr;
      };
    };

  };

  // ====================================================================
  // TREE UPDATE FUNCTIONS
  // ====================================================================

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
        let ?child = Branch.get_child(btree, parent, i) else Runtime.trap("get_leaf_node_and_index 0: accessed a null value");
        let ?search_key = Branch.get_key_blob(btree, parent, i - 1) else Runtime.trap("get_leaf_node_and_index 1: accessed a null value");

        switch (is_address_a_leaf) {
          case (false) {

            switch (btree_utils.key.cmp) {
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

      let ?first_child = Branch.get_child(btree, parent, 0) else Runtime.trap("get_leaf_node_and_index 2: accessed a null value");

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
        let ?child = Branch.get_child(btree, parent, i) else Runtime.trap("get_leaf_node_by_index 0: accessed a null value");

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

      Runtime.trap("get_leaf_node_by_index 3: reached unreachable code");
    };

    (get_node(root), search_index);
  };

  // ====================================================================
  // CORE ITERATOR - Foundation for all other iterators
  // ====================================================================

  /// Ultimate iterator that yields (leaf_address, elem_index, opt_prefix_key).
  /// Caches prefix_key per leaf to avoid repeated stable memory reads.
  /// This provides all necessary information for handlers to reconstruct full keys efficiently.
  public func new_leaf_index_iterator(
    btree : MemoryBTree,
    start_leaf : Nat,
    start_index : Nat,
    end_leaf : Nat,
    end_index : Nat // exclusive
  ) : RevIter<(Nat, Nat, Blob)> {

    var start = start_leaf;
    var i = start_index;
    var start_count = Leaf.get_count(btree, start_leaf);
    var start_prefix : Blob = Leaf.get_prefix_key(btree, start_leaf);

    var end = end_leaf;
    var j = end_index;
    var end_prefix : Blob = Leaf.get_prefix_key(btree, end_leaf);

    var terminate = false;

    func next() : ?(Nat, Nat, Blob) {
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
            start_prefix := Leaf.get_prefix_key(btree, next_address);
          };
        };

        i := 0;
        return next();
      };

      let result = (start, i, start_prefix);
      i += 1;
      return ?result;
    };

    func nextFromEnd() : ?(Nat, Nat, Blob) {
      if (terminate) return null;

      if (start == end and i >= j) return null;

      if (j == 0) {
        switch (Leaf.get_prev(btree, end)) {
          case (null) terminate := true;
          case (?prev_address) {
            end := prev_address;
            j := Leaf.get_count(btree, prev_address);
            end_prefix := Leaf.get_prefix_key(btree, prev_address);
          };
        };

        return nextFromEnd();
      };

      let result = (end, j - 1, end_prefix);
      j -= 1;

      return ?result;
    };

    RevIter.new(next, nextFromEnd);
  };

  // ====================================================================
  // DERIVED ITERATORS - Built on new_leaf_index_iterator
  // ====================================================================

  public func new_kv_block_address_iterator(
    btree : MemoryBTree,
    start_leaf : Nat,
    start_index : Nat,
    end_leaf : Nat,
    end_index : Nat // exclusive
  ) : RevIter<Address> {

    let index_iter = new_leaf_index_iterator(btree, start_leaf, start_index, end_leaf, end_index);

    func next() : ?Address {
      switch (index_iter.next()) {
        case (null) null;
        case (?(leaf_address, elem_index, _opt_prefix)) {
          Leaf.get_kv_address(btree, leaf_address, elem_index)
        };
      };
    };

    func nextFromEnd() : ?Address {
      switch (index_iter.nextFromEnd()) {
        case (null) null;
        case (?(leaf_address, elem_index, _opt_prefix)) {
          Leaf.get_kv_address(btree, leaf_address, elem_index)
        };
      };
    };

    RevIter.new(next, nextFromEnd);
  };

  public func KeyBlobIterator(
    btree : MemoryBTree,
    start_leaf : Nat,
    start_index : Nat,
    end_leaf : Nat,
    end_index : Nat,
  ) : RevIter<Blob> {
    RevIter.map(
      new_kv_block_address_iterator(btree, start_leaf, start_index, end_leaf, end_index),
      func(kv_block_address : Address) : Blob {
        MemoryBlock.KV.get_key_blob(btree, kv_block_address);
      },
    );
  };

  public func ValueBlobIterator(
    btree : MemoryBTree,
    start_leaf : Nat,
    start_index : Nat,
    end_leaf : Nat,
    end_index : Nat,
  ) : RevIter<Blob> {
    RevIter.map(
      Methods.new_kv_block_address_iterator(btree, start_leaf, start_index, end_leaf, end_index),
      func(kv_block_address : Address) : Blob {
        MemoryBlock.KV.get_val_blob(btree, kv_block_address);
      },
    )
  };

  public func new_blobs_iterator(
    btree : MemoryBTree,
    start_leaf : Nat,
    start_index : Nat,
    end_leaf : Nat,
    end_index : Nat // exclusive
  ) : RevIter<(Blob, Blob)> {

    let index_iter = new_leaf_index_iterator(btree, start_leaf, start_index, end_leaf, end_index);

    func next() : ?(Blob, Blob) {
      switch (index_iter.next()) {
        case (null) null;
        case (?(leaf_address, elem_index, opt_prefix)) {
          Leaf.get_kv_blobs(btree, leaf_address, elem_index, ?opt_prefix)
        };
      };
    };

    func nextFromEnd() : ?(Blob, Blob) {
      switch (index_iter.nextFromEnd()) {
        case (null) null;
        case (?(leaf_address, elem_index, opt_prefix)) {
          Leaf.get_kv_blobs(btree, leaf_address, elem_index, ?opt_prefix)
        };
      };
    };

    RevIter.new(next, nextFromEnd);
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

  // ====================================================================
  // PUBLIC API ITERATORS
  // ====================================================================

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

  // ====================================================================
  // DESERIALIZATION HELPERS
  // ====================================================================

  public func deserialize_key_blob<K>(btree_utils : BTreeUtils<K, Nat>, key_blob : Blob) : K {
    btree_utils.key.blobify.from_blob(key_blob);
  };

  public func deserialize_val_blob<V>(btree_utils : BTreeUtils<Nat, V>, val_blob : Blob) : V {
    btree_utils.value.blobify.from_blob(val_blob);
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

            let ?(key, val) = Leaf.get_kv_blobs(btree, leaf_address, i, null) else Runtime.trap("leaf_nodes: accessed a null value");
            ?(btree_utils.key.blobify.from_blob(key), btree_utils.value.blobify.from_blob(val));
          },
        );
      },
    );
  };

  // ====================================================================
  // DEBUGGING & VALIDATION
  // ====================================================================

  public type BranchNodeKeys = {
    address: Address;
    index: Nat;
    count: Nat;
    keys: [?Blob];
  };

  public func node_keys<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : [[BranchNodeKeys]] {
    var nodes = BufferDeque.fromArray<(Address, Bool)>([(btree.root, btree.is_root_a_leaf)]);
    var buffer = Buffer.Buffer<[BranchNodeKeys]>(btree.branch_count);

    while (nodes.size() > 0) {
      let row = Buffer.Buffer<BranchNodeKeys>(nodes.size());

      for (_ in Nat.rangeInclusive(1, nodes.size())) {
        let ?(node, is_node_a_leaf) = nodes.popFront() else Runtime.trap("node_keys: accessed a null value");

        switch (is_node_a_leaf) {
          case (true) {};
          case (false) {

            let index = Branch.get_index(btree, node);
            let count = Branch.get_count(btree, node);

            let keys = Array.tabulate<?Blob>(
              btree.node_capacity - 1,
              func(i : Nat) : ?Blob {
                if (i + 1 >= count) return null;
                Branch.get_key_blob(btree, node, i);
              },
            );

            row.add({
              address = node;
              index = index;
              count = count;
              keys = keys;
            });

            for (i in Nat.rangeInclusive(0, Branch.get_count(btree, node) - 1)) {
              let ?child = Branch.get_child(btree, node, i) else Runtime.trap("node_keys: accessed a null value");
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
  public func validate_memory<K, V>(btree : MemoryBTree, btree_utils : BTreeUtils<K, V>) : Bool {

    func _validate(address : Nat, is_address_a_leaf : Bool) : (index : Nat, subtree_size : Nat) {

      switch (is_address_a_leaf) {
        case (true) {
          // assert Leaf.validate(btree, address);
          let leaf = Leaf.from_memory(btree, address);

          let index = Leaf.get_index(btree, address);
          let count = Leaf.get_count(btree, address);
          let depth = Leaf.get_depth(btree, address);

          assert index == leaf.0 [Leaf.AC.INDEX];
          assert count == leaf.0 [Leaf.AC.COUNT];
          assert address == leaf.0 [Leaf.AC.ADDRESS];
          assert depth == 1;

          // Get separator key blobs from parent
          let (left_separator_key_blob, right_separator_key_blob) = switch (Leaf.get_parent(btree, address)) {
            case (?parent) {
              var left_sep : ?Blob = null;
              var right_sep : ?Blob = null;

              if (index > 0) {
                let ?blob = Branch.get_key_blob(btree, parent, index - 1) else Runtime.trap("1. validate: accessed a null value");
                left_sep := ?blob;
              };

              let parent_count = Branch.get_count(btree, parent);

              if (index + 1 < parent_count) {
                let ?blob = Branch.get_key_blob(btree, parent, index) else Runtime.trap("2. validate: accessed a null value");
                right_sep := ?blob;
              };

              (left_sep, right_sep);
            };
            case (null) (null, null);
          };

          var i = 0;

          var opt_prev_key_blob : ?Blob = null;
          while (i < count) {

            let ?key_block = Leaf.get_key_block(btree, address, i) else Runtime.trap("3. validate: accessed a null value");
            let ?val_block = Leaf.get_val_block(btree, address, i) else Runtime.trap("4. validate: accessed a null value");
            let ?key_blob = Leaf.get_key_blob(btree, address, i, null) else Runtime.trap("5. validate: accessed a null value");
            let ?val_blob = Leaf.get_val_blob(btree, address, i) else Runtime.trap("6. validate: accessed a null value");

            assert leaf.2 [i] == ?key_block;
            assert leaf.3 [i] == ?val_block;
            if (leaf.4 [i] != ?(key_blob, val_blob)) {
              Debug.print("VALIDATION FAIL: kv_blob mismatch at i=" # debug_show i);
              Debug.print("  from_memory=" # debug_show leaf.4[i]);
              Debug.print("  get_key_blob=" # debug_show key_blob);
            };
            assert leaf.4 [i] == ?(key_blob, val_blob);

            // Compare keys using btree_utils comparison (deserialize and compare)
            switch (opt_prev_key_blob) {
              case (null) {};
              case (?prev_key_blob) {
                let prev_key = btree_utils.key.blobify.from_blob(prev_key_blob);
                let key = btree_utils.key.blobify.from_blob(key_blob);
                let cmp_result = switch (btree_utils.key.cmp) {
                  case (#BlobCmp(cmp)) cmp(prev_key_blob, key_blob);
                };
                if (cmp_result >= 0) {
                  let prefix = Leaf.get_prefix_key(btree, address);
                  Debug.print("key ordering violation at index: " # debug_show i);
                  Debug.print("leaf_address: " # debug_show address # " count=" # debug_show count);
                  Debug.print("leaf prefix: " # debug_show prefix);
                  Debug.print("prev_key_blob: " # debug_show prev_key_blob);
                  Debug.print("key_blob: " # debug_show key_blob);
                  assert false;
                };
              };
            };

            // Compare leaf key blob against parent separator blobs
            // Separators include the differentiating character (common_prefix + 1 byte)
            // This ensures: left_keys < separator <= right_keys
            switch (left_separator_key_blob) {
              case (?left_sep) {
                // All keys in this leaf should be >= left_separator
                if (Blob.compare(key_blob, left_sep) == #less) {
                  Debug.print("VALIDATION FAIL: Leaf key < left_sep");
                  Debug.print("  leaf_address=" # debug_show address # ", index=" # debug_show index # ", key_index=" # debug_show i);
                  Debug.print("  key_blob=" # debug_show key_blob);
                  Debug.print("  left_sep=" # debug_show left_sep);
                  Debug.print("  right_sep=" # debug_show right_separator_key_blob);
                  Debug.print("  leaf_count=" # debug_show count);
                  let ?parent = Leaf.get_parent(btree, address) else Runtime.trap("parent should exist");
                  Debug.print("  parent=" # debug_show parent # ", parent_count=" # debug_show Branch.get_count(btree, parent));
                };
                assert Blob.compare(key_blob, left_sep) != #less;
              };
              case (null) {};
            };

            switch (right_separator_key_blob) {
              case (?right_sep) {
                // All keys in this leaf (left of the separator) should be < right_separator
                if (Blob.compare(key_blob, right_sep) != #less) {
                  Debug.print("VALIDATION FAIL (right_sep): key >= right_sep");
                  Debug.print("  leaf=" # debug_show address # " index=" # debug_show index # " key_idx=" # debug_show i);
                  Debug.print("  key_blob=" # debug_show key_blob);
                  Debug.print("  right_sep=" # debug_show right_sep);
                };
                assert Blob.compare(key_blob, right_sep) == #less;
              };
              case (null) {};
            };

            opt_prev_key_blob := ?key_blob;

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

          // Get separator key blobs from parent
          let (left_separator_key_blob, right_separator_key_blob, debug_parent_address) = switch (Branch.get_parent(btree, address)) {
            case (?parent) {
              var left_sep : ?Blob = null;
              var right_sep : ?Blob = null;

              if (index > 0) {
                let ?blob = Branch.get_key_blob(btree, parent, index - 1) else Runtime.trap("7. validate: accessed a null value");
                left_sep := ?blob;
              };

              let parent_count = Branch.get_count(btree, parent);

              if (index + 1 < parent_count) {
                let ?blob = Branch.get_key_blob(btree, parent, index) else Runtime.trap("8. validate: accessed a null value");
                right_sep := ?blob;
              };

              (left_sep, right_sep, ?parent);
            };
            case (null) (null, null, null);
          };

          var i = 0;

          var opt_prev_key_blob : ?Blob = null;

          while (i < count) {
            if (i + 1 < count) {
              let ?key_blob = Branch.get_key_blob(btree, address, i) else Runtime.trap("9. validate: accessed a null value");

              assert ?key_blob == branch.6 [i];

              // Compare branch keys as blobs
              switch (opt_prev_key_blob) {
                case (null) {};
                case (?prev_key_blob) if (Blob.compare(prev_key_blob, key_blob) != #less) {
                  Debug.print("key mismatch at index: " # debug_show i);
                  Debug.print("prev: " # debug_show prev_key_blob);
                  Debug.print("key: " # debug_show key_blob);

                  assert false;
                };
              };

              switch (left_separator_key_blob) {
                case (?left_sep) {
                  if (Blob.compare(left_sep, key_blob) == #greater) {
                    Debug.print("BRANCH FAIL: left_sep > branch_key");
                    Debug.print("  branch=" # debug_show address # " index=" # debug_show index # " i=" # debug_show i);
                    Debug.print("  parent=" # debug_show debug_parent_address);
                    let ?par = debug_parent_address else Runtime.trap("BRANCH FAIL: no parent");
                    let ?left_key_addr = Branch.get_key_address(btree, par, index - 1) else Runtime.trap("BRANCH FAIL: no key addr");
                    Debug.print("  left_key_addr=" # debug_show left_key_addr);
                    Debug.print("  left_sep size=" # debug_show left_sep.size());
                    Debug.print("  key_blob=" # debug_show key_blob);
                    Debug.print("  right_sep=" # debug_show right_separator_key_blob);
                    // Debug memory state at 192_697 and surrounding area
                    let isAlloc = MemoryRegion.isAllocated(btree.data, 192_697, 1);
                    Debug.print("  192_697 isAllocated=" # debug_show isAlloc);
                    // Read bytes 192_685..192_715 to understand surrounding allocations
                    var dbg_i = 192_685;
                    while (dbg_i <= 192_715) {
                      let byte_val = MemoryRegion.loadNat8(btree.data, dbg_i);
                      Debug.print("  data[" # debug_show dbg_i # "]=" # debug_show (Nat8.toNat(byte_val)));
                      dbg_i += 1;
                    };
                  };
                  assert Blob.compare(left_sep, key_blob) != #greater;
                };
                case (null) {};
              };

              switch (right_separator_key_blob) {
                case (?right_sep) {
                  if (Blob.compare(key_blob, right_sep) != #less) {
                    Debug.print("BRANCH FAIL: branch_key >= right_sep");
                    Debug.print("  branch=" # debug_show address # " index=" # debug_show index # " i=" # debug_show i);
                    Debug.print("  key_blob=" # debug_show key_blob);
                    Debug.print("  right_sep=" # debug_show right_sep);
                    Debug.print("  left_sep=" # debug_show left_separator_key_blob);
                  };
                  assert Blob.compare(key_blob, right_sep) == #less;
                };
                case (null) {};
              };

              opt_prev_key_blob := ?key_blob;
            };

            let ?child = Branch.get_child(btree, address, i) else Runtime.trap("10. validate: accessed a null value");
            let opt_child_parent = if (is_node_a_leaf) Leaf.get_parent(btree, child) else Branch.get_parent(btree, child);
            let (branch_parent, expected_parent) = switch (opt_child_parent) {
              case (?parent) (parent, address);
              case (null) (address, btree.root);
            };

            if (branch_parent != expected_parent) Runtime.trap(
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
    let subtree_size = if (btree.is_root_a_leaf) Leaf.get_count(btree, btree.root) else Branch.get_subtree_size(btree, btree.root);
    response == (0, subtree_size);
  };

};
