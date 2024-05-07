## Memory-Collection

A collection of persistent data structures in motoko that store their data in stable memory. These data structures address the heap storage limitations by allowing developers to leverage the 400GB capacity available in stable memory.
The use cases for this library include:


### Data Structures
- [MemoryBuffer](./src/MemoryBuffer/readme.md): A persistent buffer with `O(1)` random access and `O(1)` insertion and deletion at both ends.
- [MemoryBTree](./src/MemoryBTree/readme.md): A persistent B-Tree with `O(log n)` search, insertion, and deletion.

### Motivation
The heap memory in the Internet Computer is limited to 4GB, which can be a bottleneck for applications that require large amounts of data. Stable memory, on the other hand, has a capacity of 400GB, but it requires developers to manage the allocation and deallocation of memory blocks and also to serialize and deserialize data. The `Memory-Collection` library aims to bridge this gap by providing all the necessary tools to manage data in stable memory exposed through a simple and easy-to-use set of data structures. These data structures can be used to store large amounts of data that need to persist across canister upgrades. 

### Notes and Limitations
- Interacting with stable memory continuously requires significantly more instructions and heap allocations than using heap memory. Therefore, it is recommended to use these data structures only when the data size exceeds the heap memory limit.
- Each value stored in the data structure is immutable. To update a value, the data will be removed and the new value will be serialized and stored in a new memory block.
- Currently, stable memory is not garbage collected. Which means that we can't shrink the total memory used once we have allocated it. So even after one of our data structures is no longer in use and has been garbage collected from the heap, the memory it used in stable memory will still be reserved.


## Getting Started
### Installation
- Install [mops](https://docs.mops.one/quick-start)
- Run `mops add memory-collection` in your project directory
- Import the modules in your project
```motoko
    import Blobify "mo:memory-collection/Blobify";

    import MemoryBuffer "mo:memory-collection/MemoryBuffer";
    import MemoryBTree "mo:memory-collection/MemoryBTree";
```

- Depending on the implementation you want to use, each data structure provides 3 modules:
    - `Base`: The base module for the buffer.
    - `Versioned`: A module over the `Base` that stores the version and makes it easy to upgrade to a new version.
    - `Class`: A module over the `Versioned` that provides a class-like interface.

> The `Class` module is the default module and is recommended for general use.

```motoko
    import BaseMemoryBuffer "mo:memory-collection/MemoryBuffer/Base";
    import VersionedMemoryBuffer "mo:memory-collection/MemoryBuffer/Versioned";
    import MemoryBuffer "mo:memory-collection/MemoryBuffer";
```

### Usage Examples
- MemoryBuffer
```motoko
    import MemoryBuffer "mo:memory-collection/MemoryBuffer";
    import Blobify "mo:memory-collection/Blobify";
    
    let sstore = MemoryBuffer.newStableStore<Nat>();
    let mbuffer = MemoryBuffer.MemoryBuffer<Nat>(sstore, Blobify.Nat);
    mbuffer.add(1);
    mbuffer.add(3);
    mbuffer.insert(1, 2);
    assert mbuffer.toArray() == [1, 2, 3];

    for (i in Iter.range(0, mbuffer.size() - 1)) {
        let n = mbuffer.get(i);
        mbuffer.put(i, n ** 2);
    };

    assert mbuffer.toArray() == [1, 4, 9];
    assert mbuffer.remove(1) == ?4;
    assert mbuffer.removeLast() == ?9;
```

- MemoryBTree
```motoko
    import MemoryBTree "mo:memory-collection/MemoryBTree";
    import BTreeUtils "mo:memory-collection/BTreeUtils";

    let sstore = MemoryBTree.newStableStore(?256);

    let btree_utils = BTreeUtils.createUtils(BTreeUtils.BigEndian.Nat, BTreeUtils.BigEndian.Nat);
    let mbtree = MemoryBTree.new(sstore, btree_utils);

    mbtree.insert(1, 10);
    mbtree.insert(2, 20);
    mbtree.insert(3, 30);

    assert mbtree.get(2) == ?20;
    assert mbtree.getMin() == ?(1, 10);
    assert mbtree.getMax() == ?(3, 30);

    assert mbtree.remove(2) == ?20;
    assert mbtree.get(2) == null;

    assert mbtree.toArray() == [(1, 10), (3, 30)];
```

### Upgrade
The MemoryRegion that stores deallocated memory for future use is under development and may have breaking changes in the future. 
To account for this, the `MemoryBuffer` has a versioning system that allows you to upgrade without losing your data.

Steps to upgrade:
- Install new version via mops: `mops add memory-buffer@<version>`
- Call `upgrade()` on the buffer's memory store to upgrade to the new version.
- Replace the old memory store with the upgraded one.

```motoko
  stable var mem_store = MemoryBuffer.newStableStore<Nat>();
  mem_store := MemoryBuffer.upgrade(mem_store);
```

### Utilities (Serialization and Comparison)
- [Blobify](./src/Blobify/readme.md): A module that provides functions for serializing and deserializing primitive motoko types.
  - The type is simple, it's a record that contains two functions, `to_blob` and `from_blob`.
  - The `to_blob` function takes an element of your defined generic type and returns a `Blob`.
  - The `from_blob` function takes a `Blob` and returns the defined type.
  - You can define your own Blobify function for your compound types.
  ```motoko
  type Blobify<A> = { 
    to_blob : (A) -> Blob; 
    from_blob : (Blob) -> A 
  };
  ```
- [MemoryCmp](./src/MemoryCmp/readme.md): A module that provides functions for comparing elements. There are two different types of comparison functions available:
  - `#GenCmp`: A comparison function that converts the keys to the original generic type defined by the user and then compares them.
  - `#BlobCmp`: A comparison function that compares the keys directly as blobs. The `#BlobCmp` avoids the overhead of deserializing the keys but requires that the keys be comparable in their serialized format.
- [BTreeUtils](./src/BTreeUtils/readme.md): A module that provides utilities for selecting and utilizing serialization and comparison functions with the Memory B+Tree.

### Serialization Notes
- Serialization and deserialization using candid is often much more performant than using Blobify or any other serialization methods. The reason for this is because the to_candid and from_candid functions are system functions in the IC and therefore more efficient than any custom serialization methods. However, the candid contains extra type information included in the serialized data, which can make the serialized data larger than using Blobify. This difference in size can be significant if each of the pieces of data being serialized is small. For example a serialized value of Nat8 value if serialized with Blobify will be 1 bytes, but if serialized into candid will include the magic number (4 bytes), the type (1 byte) and the value (1 byte) for a total of 6 bytes. This difference in size can be significant if each of the pieces of data being serialized is small. However, if the data being serialized is large, the overhead of the extra bytes is negligible. So be mindful of the size of the data being serialized when choosing between Blobify and candid.
