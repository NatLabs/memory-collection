// @testmode wasi
import { test; suite } "mo:test";
import Debug "mo:base@0.14.13/Debug";
import Iter "mo:base@0.14.13/Iter";
import Buffer "mo:base@0.14.13/Buffer";
import Nat "mo:base@0.14.13/Nat";
import Blob "mo:base@0.14.13/Blob";
import Order "mo:base@0.14.13/Order";

import Fuzz "mo:fuzz";
import MemoryRegion "mo:memory-region@1.3.2/MemoryRegion";
import { MaxBpTree; Cmp } "mo:augmented-btrees";
import MaxBpTreeMethods "mo:augmented-btrees/MaxBpTree/Methods";
import BpTree "mo:augmented-btrees/BpTree";

import MemoryBTree "../../src/MemoryBTree/Base";
import TypeUtils "../../src/TypeUtils";
import Utils "../../src/Utils";
import Branch "../../src/MemoryBTree/modules/Branch";
import Leaf "../../src/MemoryBTree/modules/Leaf";
import Methods "../../src/MemoryBTree/modules/Methods";

type Buffer<A> = Buffer.Buffer<A>;
type Iter<A> = Iter.Iter<A>;
type Order = Order.Order;
type MemoryBlock = MemoryBTree.MemoryBlock;

let limit = 10_000;
let fuzz = Fuzz.fromSeed(0xcafebabe);

// Create input arrays for different blob test scenarios
let order = Buffer.Buffer<Nat>(limit);
let blob_keys = Buffer.Buffer<Blob>(limit);
let initial_blob_values = Buffer.Buffer<Blob>(limit);
let equal_size_blob_values = Buffer.Buffer<Blob>(limit);
let greater_size_blob_values = Buffer.Buffer<Blob>(limit);
let less_size_blob_values = Buffer.Buffer<Blob>(limit);

for (i in Iter.range(0, limit - 1)) {
  order.add(i);

  // Generate fixed keys - these will remain constant throughout the test
  let key_size = fuzz.nat.randomRange(16, 32);
  let key_blob = fuzz.blob.randomBlob(key_size);
  blob_keys.add(key_blob);

  // Generate values of varying sizes
  let val_size_a = fuzz.nat.randomRange(8, 24);
  let val_blob_a = fuzz.blob.randomBlob(val_size_a);
  less_size_blob_values.add(val_blob_a);

  let val_size_b = fuzz.nat.randomRange(val_size_a, 48);
  let val_blob_b = fuzz.blob.randomBlob(val_size_b);
  initial_blob_values.add(val_blob_b);

  let val_blob_c = fuzz.blob.randomBlob(val_size_b);
  equal_size_blob_values.add(val_blob_c);

  let val_size_d = fuzz.nat.randomRange(val_size_b, 96);
  let val_blob_d = fuzz.blob.randomBlob(val_size_d);
  greater_size_blob_values.add(val_blob_d);
};

fuzz.buffer.shuffle(order);

// Current expected values - will be updated as we modify the btree
let current_values = Buffer.Buffer<Blob>(limit);
for (i in Iter.range(0, limit - 1)) {
  current_values.add(initial_blob_values.get(i));
};

// Helper function to validate all entries match expected values
let run_blob_validation_test = func(btree : MemoryBTree.MemoryBTree, btree_utils : MemoryBTree.BTreeUtils<Blob, Blob>, expected_values : Buffer.Buffer<Blob>) {
  test(
    "validate all blob entries",
    func() {
      for (i in Iter.range(0, limit - 1)) {
        let expected_key = blob_keys.get(i);
        let expected_value = expected_values.get(i);
        let retrieved = MemoryBTree.get(btree, btree_utils, expected_key);

        if (retrieved != ?expected_value) {
          Debug.print("validation mismatch at index " # debug_show i);
          Debug.print("expected: " # debug_show expected_value);
          Debug.print("retrieved: " # debug_show retrieved);
          assert false;
        };
      };
    },
  );
};

// Helper function to validate memory regions
func validate_btree_memory_regions(btree : MemoryBTree.MemoryBTree) {
  if (not MaxBpTreeMethods.validate_max_path(btree.data.free_memory, Cmp.Nat)) {
    Debug.print("invalid max path discovered in data region");
    Debug.print("node keys: " # debug_show (MaxBpTree.toNodeKeys(btree.data.free_memory)));
    Debug.print("node leaves: " # debug_show (MaxBpTree.toLeafNodes(btree.data.free_memory)));
    assert false;
  };

  if (not MaxBpTreeMethods.validate_subtree_size(btree.data.free_memory)) {
    Debug.print("invalid subtree size in data region");
    Debug.print("node keys: " # debug_show (MaxBpTree.toNodeKeys(btree.data.free_memory)));
    Debug.print("node leaves: " # debug_show (MaxBpTree.toLeafNodes(btree.data.free_memory)));
    assert false;
  };

  if (not MaxBpTreeMethods.validate_max_path(btree.leaves.free_memory, Cmp.Nat)) {
    Debug.print("invalid max path discovered in keys region");
    Debug.print("node keys: " # debug_show (MaxBpTree.toNodeKeys(btree.leaves.free_memory)));
    Debug.print("node leaves: " # debug_show (MaxBpTree.toLeafNodes(btree.leaves.free_memory)));
    assert false;
  };

  if (not MaxBpTreeMethods.validate_subtree_size(btree.leaves.free_memory)) {
    Debug.print("invalid subtree size in keys region");
    Debug.print("node keys: " # debug_show (MaxBpTree.toNodeKeys(btree.leaves.free_memory)));
    Debug.print("node leaves: " # debug_show (MaxBpTree.toLeafNodes(btree.leaves.free_memory)));
    assert false;
  };

  if (not MaxBpTreeMethods.validate_max_path(btree.branches.free_memory, Cmp.Nat)) {
    Debug.print("invalid max path discovered in keys region");
    Debug.print("node keys: " # debug_show (MaxBpTree.toNodeKeys(btree.branches.free_memory)));
    Debug.print("node leaves: " # debug_show (MaxBpTree.toLeafNodes(btree.branches.free_memory)));
    assert false;
  };

  if (not MaxBpTreeMethods.validate_subtree_size(btree.branches.free_memory)) {
    Debug.print("invalid subtree size in keys region");
    Debug.print("node keys: " # debug_show (MaxBpTree.toNodeKeys(btree.branches.free_memory)));
    Debug.print("node leaves: " # debug_show (MaxBpTree.toLeafNodes(btree.branches.free_memory)));
    assert false;
  };

  if (not MaxBpTreeMethods.validate_max_path(btree.values.free_memory, Cmp.Nat)) {
    Debug.print("invalid max path discovered in values region");
    Debug.print("node keys: " # debug_show (MaxBpTree.toNodeKeys(btree.values.free_memory)));
    Debug.print("node leaves: " # debug_show (MaxBpTree.toLeafNodes(btree.values.free_memory)));
    assert false;
  };

  if (not MaxBpTreeMethods.validate_subtree_size(btree.values.free_memory)) {
    Debug.print("invalid subtree size in values region");
    Debug.print("node keys: " # debug_show (MaxBpTree.toNodeKeys(btree.values.free_memory)));
    Debug.print("node leaves: " # debug_show (MaxBpTree.toLeafNodes(btree.values.free_memory)));
    assert false;
  };
};

// Track memory blocks to detect overlaps (similar to MemoryBuffer.Load.Test.mo)
class MemoryBlocksMap() {
  let memory_blocks = BpTree.new<(Nat, Nat), Nat>(null);

  func compare(a : (Nat, Nat), b : (Nat, Nat)) : Int8 {
    if (a.0 < b.0 and a.1 <= b.0) {
      -1;
    } else if (a.0 >= b.1 and a.1 > b.0) {
      1;
    } else {
      0;
    };
  };

  public func add(_block : (Nat, Nat), index : Nat) : Bool {
    if (_block.1 == 0) return true;

    let block = (_block.0, _block.0 + _block.1);

    switch (BpTree.getEntry(memory_blocks, compare, block)) {
      case (?(existing_block, prev_index)) {
        Debug.print("Memory block already exists at index " # debug_show prev_index # ", current index: " # debug_show index);
        Debug.print("Existing block: " # debug_show existing_block # ", New block: " # debug_show block);
        return false;
      };
      case (null) {
        ignore BpTree.insert(memory_blocks, compare, block, index);
        return true;
      };
    };
  };

  public func remove(_block : (Nat, Nat)) : Bool {
    if (_block.1 == 0) return true;

    let block = (_block.0, _block.0 + _block.1);

    switch (BpTree.remove(memory_blocks, compare, block)) {
      case (?_) true;
      case (null) {
        Debug.print("Failed to remove block: " # debug_show block);
        false;
      };
    };
  };

};

func btree_load_test(node_capacity : Nat) {
  let btree = MemoryBTree.new(?node_capacity);
  let btree_utils = MemoryBTree.createUtils(TypeUtils.Blob, TypeUtils.Blob);
  suite(
    "MemoryBTree Blob Memory Load Tests",
    func() {

      test(
        "insert initial blob entries",
        func() {
          for (i in Iter.range(0, limit - 1)) {
            let key = blob_keys.get(i);
            let value = initial_blob_values.get(i);

            ignore MemoryBTree.insert(btree, btree_utils, key, value);
            assert MemoryBTree.size(btree) == i + 1;

            // Validate memory regions after each insert
            validate_btree_memory_regions(btree);

            // Verify the entry can be retrieved
            let retrieved = MemoryBTree.get(btree, btree_utils, key);
            if (retrieved != ?value) {
              Debug.print("mismatch after insert: " # debug_show (i, retrieved));
              assert false;
            };
          };

          validate_btree_memory_regions(btree);
        },
      );

      run_blob_validation_test(btree, btree_utils, initial_blob_values);

      test(
        "replace with equal size blob values",
        func() {
          let memory_blocks_map = MemoryBlocksMap();

          for (index in order.vals()) {
            let key = blob_keys.get(index);
            let old_value = initial_blob_values.get(index);
            let new_value = equal_size_blob_values.get(index);

            // Verify old entry exists
            assert MemoryBTree.get(btree, btree_utils, key) == ?old_value;

            // Get memory block info before replacement
            let ?old_id = MemoryBTree.getId(btree, btree_utils, key);
            let ?old_mem_block = MemoryBTree._lookup_mem_block(btree, old_id);
            let ?old_key_blob = MemoryBTree._lookup_key_blob(btree, old_id);
            let ?old_val_blob = MemoryBTree._lookup_val_blob(btree, old_id);

            // Verify the blobs match
            assert old_key_blob == key;
            assert old_val_blob == old_value;

            // Check memory is allocated
            if (old_mem_block.0.1 > 0) {
              assert MemoryRegion.isAllocated(btree.data, old_mem_block.0.0, old_mem_block.0.1);
            };
            if (old_mem_block.1.1 > 0) {
              assert MemoryRegion.isAllocated(btree.values, old_mem_block.1.0, old_mem_block.1.1);
            };

            // Replace with equal size value (using insert which replaces if key exists)
            let replaced = MemoryBTree.insert(btree, btree_utils, key, new_value);
            assert replaced == ?old_value;

            // Get new memory block info
            let ?new_id = MemoryBTree.getId(btree, btree_utils, key);
            let ?new_mem_block = MemoryBTree._lookup_mem_block(btree, new_id);
            let ?new_key_blob = MemoryBTree._lookup_key_blob(btree, new_id);
            let ?new_val_blob = MemoryBTree._lookup_val_blob(btree, new_id);

            // Verify new blobs match
            assert new_key_blob == key;
            assert new_val_blob == new_value;

            // Check new memory is allocated
            if (new_mem_block.1.1 > 0) {
              assert MemoryRegion.isAllocated(btree.values, new_mem_block.1.0, new_mem_block.1.1);
              assert memory_blocks_map.add(new_mem_block.1, index);
            };

            // Validate memory regions
            validate_btree_memory_regions(btree);
          };

          validate_btree_memory_regions(btree);
        },
      );

      run_blob_validation_test(btree, btree_utils, equal_size_blob_values);

      test(
        "replace with greater size blob values",
        func() {
          let memory_blocks_map = MemoryBlocksMap();

          for (index in order.vals()) {
            let key = blob_keys.get(index);
            let old_value = equal_size_blob_values.get(index);
            let new_value = greater_size_blob_values.get(index);

            // Verify old entry exists
            assert MemoryBTree.get(btree, btree_utils, key) == ?old_value;

            // Get memory info before replacement
            let ?old_id = MemoryBTree.getId(btree, btree_utils, key);
            let ?old_mem_block = MemoryBTree._lookup_mem_block(btree, old_id);

            // Check memory is allocated before replacement
            let old_key_allocated = old_mem_block.0.1 > 0 and MemoryRegion.isAllocated(btree.data, old_mem_block.0.0, old_mem_block.0.1);
            let old_val_allocated = old_mem_block.1.1 > 0 and MemoryRegion.isAllocated(btree.values, old_mem_block.1.0, old_mem_block.1.1);

            // Replace with larger value
            let replaced = MemoryBTree.insert(btree, btree_utils, key, new_value);
            assert replaced == ?old_value;

            // Get new memory info
            let ?new_id = MemoryBTree.getId(btree, btree_utils, key);
            let ?new_mem_block = MemoryBTree._lookup_mem_block(btree, new_id);
            let ?new_key_blob = MemoryBTree._lookup_key_blob(btree, new_id);
            let ?new_val_blob = MemoryBTree._lookup_val_blob(btree, new_id);

            // Verify larger value is correctly stored
            assert new_key_blob == key;
            assert new_val_blob == new_value;
            assert new_value.size() >= old_value.size();

            // Check memory allocation
            if (new_mem_block.1.1 > 0) {
              assert MemoryRegion.isAllocated(btree.values, new_mem_block.1.0, new_mem_block.1.1);
              assert memory_blocks_map.add(new_mem_block.1, index);
            };

            validate_btree_memory_regions(btree);
          };

          validate_btree_memory_regions(btree);
        },
      );

      run_blob_validation_test(btree, btree_utils, greater_size_blob_values);

      test(
        "replace with smaller size blob values",
        func() {
          for (index in order.vals()) {
            let key = blob_keys.get(index);
            let old_value = greater_size_blob_values.get(index);
            let new_value = less_size_blob_values.get(index);

            // Verify old entry exists
            assert MemoryBTree.get(btree, btree_utils, key) == ?old_value;

            // Get memory info before replacement
            let ?old_id = MemoryBTree.getId(btree, btree_utils, key);
            let ?old_mem_block = MemoryBTree._lookup_mem_block(btree, old_id);

            // Replace with smaller value
            let replaced = MemoryBTree.insert(btree, btree_utils, key, new_value);
            assert replaced == ?old_value;

            // Get new memory info
            let ?new_id = MemoryBTree.getId(btree, btree_utils, key);
            let ?new_mem_block = MemoryBTree._lookup_mem_block(btree, new_id);
            let ?new_key_blob = MemoryBTree._lookup_key_blob(btree, new_id);
            let ?new_val_blob = MemoryBTree._lookup_val_blob(btree, new_id);

            // Verify smaller value is correctly stored
            assert new_key_blob == key;
            assert new_val_blob == new_value;
            assert new_value.size() <= old_value.size();

            // Check memory allocation
            if (new_mem_block.0.1 > 0) {
              assert MemoryRegion.isAllocated(btree.data, new_mem_block.0.0, new_mem_block.0.1);
            };
            if (new_mem_block.1.1 > 0) {
              assert MemoryRegion.isAllocated(btree.values, new_mem_block.1.0, new_mem_block.1.1);
            };

            validate_btree_memory_regions(btree);
          };

          validate_btree_memory_regions(btree);
        },
      );

      run_blob_validation_test(btree, btree_utils, less_size_blob_values);

      test(
        "verify memory consistency after all operations",
        func() {
          // Final verification that all current entries are accessible
          for (i in Iter.range(0, limit - 1)) {
            let expected_key = blob_keys.get(i);
            let expected_value = less_size_blob_values.get(i);

            let ?id = MemoryBTree.getId(btree, btree_utils, expected_key);
            let ?mem_block = MemoryBTree._lookup_mem_block(btree, id);
            let ?key_blob = MemoryBTree._lookup_key_blob(btree, id);
            let ?val_blob = MemoryBTree._lookup_val_blob(btree, id);

            // Verify blobs match expected
            assert key_blob == expected_key;
            assert val_blob == expected_value;

            // Verify memory allocation
            if (mem_block.0.1 > 0) {
              assert MemoryRegion.isAllocated(btree.data, mem_block.0.0, mem_block.0.1);
            };
            if (mem_block.1.1 > 0) {
              assert MemoryRegion.isAllocated(btree.values, mem_block.1.0, mem_block.1.1);
            };

            // Verify retrieval works
            let retrieved = MemoryBTree.get(btree, btree_utils, expected_key);
            if (retrieved != ?expected_value) {
              Debug.print("final verification mismatch: " # debug_show i);
              assert false;
            };
          };

          // Final memory validation
          validate_btree_memory_regions(btree);
        },
      );

      test(
        "test btree operations on blob data",
        func() {
          // Test some of the original MemoryBTree operations with blob data
          assert MemoryBTree.size(btree) == limit;

          // Test entries iteration
          var count = 0;
          for ((key, value) in MemoryBTree.entries(btree, btree_utils)) {
            count += 1;
            // Verify this entry exists
            assert MemoryBTree.get(btree, btree_utils, key) == ?value;
          };
          assert count == limit;

          // Test scan functionality with a subset of keys
          if (limit > 10) {
            let start_key = blob_keys.get(5);
            let end_key = blob_keys.get(15);

            var scan_count = 0;
            for ((key, value) in MemoryBTree.scan(btree, btree_utils, ?start_key, ?end_key)) {
              scan_count += 1;
              assert MemoryBTree.get(btree, btree_utils, key) == ?value;
            };
            assert scan_count > 0; // Should have found some entries
          };

          validate_btree_memory_regions(btree);
        },
      );

      test(
        "clear blob btree",
        func() {
          MemoryBTree.clear(btree);
          assert MemoryBTree.size(btree) == 0;

          // Verify all entries are gone
          for (i in Iter.range(0, limit - 1)) {
            let key = blob_keys.get(i);
            assert MemoryBTree.get(btree, btree_utils, key) == null;
          };

          // Validate memory regions after clearing
          validate_btree_memory_regions(btree);
        },
      );
    },
  );
};

for (node_capacity in [16, 32, 1024, 4028].vals()) {
  suite(
    "MemoryBTree Blob Memory Load Tests with node capacity " # debug_show (node_capacity),
    func() {
      btree_load_test(node_capacity);
    },
  );
};
