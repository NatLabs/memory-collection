## Memory-Collection

A collection of data structures in motoko that store their data in stable memory.
These data structures address the heap storage limitations by allowing developers to leverage the 400GB capacity available in stable memory.

### Motivation

The heap memory in the Internet Computer is limited to 4GB, which can be a bottleneck for applications that require large amounts of data. Stable memory, on the other hand, has a capacity of 400GB, but it requires developers to manage the allocation and deallocation of memory blocks and also to serialize and deserialize data. The `Memory-Collection` library aims to bridge this gap by providing all the necessary tools to manage data in stable memory exposed through a simple and easy-to-use set of data structures. These data structures can be used to store large amounts of data that need to persist across canister upgrades.

### Data Structures

- [MemoryBuffer](./src/MemoryBuffer/readme.md): A persistent buffer with `O(1)` random access.
- [MemoryBTree](./src/MemoryBTree/readme.md): A persistent B-Tree with `O(log n)` search, insertion, and deletion.
  - MemoryBTreeSet: A persistent set with `O(log n)` search, insertion, and deletion.
- [MemoryQueue](./src/MemoryQueue/readme.md): A persistent queue with `O(1)` add and pop operations.

Each data structure is implemented using the class+ pattern, which creates a mutable stable store that is wrapped around by a class object for a more familiar object oriented interface. This method allows the data to persists accross canister upgrades while also being simple and easy to use.
The data structures can be imported using the default path to the library `mo:memory-collection/<data-structure>`.
Each data structure also has a Stable module that can be used to call function on the stable store directly without wrapping it in a class object. The stable pattern can be accessed using the path `mo:memory-collection/<data-structure>/Stable`.

### TypeUtils

For each data structure we have to define a set of functions during initialization for processing the data structure's given data type so that it can be stored in stable memory.
To help with this we have provided a set of modules that can be imported and used in your project to help define those functions.

**Main Utility Module**

- [TypeUtils](./src/TypeUtils/lib.mo)

  ```motoko
    public type TypeUtils<T> = {
      blobify : Blobify<T>;
      cmp: MemoryCmp<T>;
    }
  ```

**Sub modules within TypeUtils**

- [Blobify](./src/TypeUtils/Blobify.mo): A module that provides functions for converting the given data type to a `Blob` and back using the given interface.

```motoko
  public type Blobify<T> = {
    to_blob: (T) -> Blob;
    from_blob: (Blob) -> T;
  }
```

- [MemoryCmp](./src/TypeUtils/MemoryCmp.mo): A module that provides functions for comparing two elements of the same type and retrieving their order. The comparison function can either be a `#BlobCmp` which compares the serialized version of the types, or it could be a `#GenCmp` which compares the types in their given data type, which often involves deserializing the stored `Blob` before comparing it.

```motoko
  public type MemoryCmp<T> = {
    #GenCmp: (T, T) -> Int8;
    #BlobCmp: (Blob, Blob) -> Int8;
  }
```

`TypeUtils` are provided for most of motoko's primitive types (e.g. Nat, Int, Text, etc.). However, you can define a custom function for a compound datatype using the interface above.
More information on how to create custom type utilities can be found in the **Create Custom TypeUtils** section of each data structure's readme.

## Getting Started

### Installation

- Install [mops](https://docs.mops.one/quick-start)
- Run `mops add memory-collection` in your project directory
- Import the modules in your project

```motoko
    import TypeUtils "mo:memory-collection/TypeUtils";

    import MemoryBuffer "mo:memory-collection/MemoryBuffer";
    import MemoryBTree "mo:memory-collection/MemoryBTree";
```

### Usage Examples

Usage examples using the preset `TypeUtils`

- MemoryBuffer

```motoko
    import MemoryBuffer "mo:memory-collection/MemoryBuffer";
    import TypeUtils "mo:memory-collection/TypeUtils";

    stable var sstore = MemoryBuffer.newStableStore<Nat>();
    sstore := MemoryBuffer.upgrade(sstore);

    let mbuffer = MemoryBuffer.MemoryBuffer<Nat>(sstore, TypeUtils.Nat);

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
    import TypeUtils "mo:memory-collection/TypeUtils";

    stable var sstore = MemoryBTree.newStableStore(null);
    sstore := MemoryBTree.upgrade(sstore);

    let btree_utils = MemoryBTree.createUtils(
      TypeUtils.BigEndian.Nat,
      TypeUtils.BigEndian.Nat
    );
    let mbtree = MemoryBTree.new(sstore, btree_utils);

    mbtree.insert(1, "motoko");
    mbtree.insert(2, "typescript");
    mbtree.insert(3, "rust");

    assert mbtree.get(2) == ?"typescript";
    assert mbtree.getMin() == ?(1, "typescript");
    assert mbtree.getMax() == ?(3, "rust");

    assert mbtree.remove(2) == ?"typescript";
    assert mbtree.get(2) == null;

    assert mbtree.toArray() == [(1, "typescript"), (3, "rust")];
```

> Check out the [examples](./examples) directory for more detailed usage examples.

### Migrating between mops versions

The data structures in the memory-collection are designed with backward compatibility in mind, particularly for data stored in stable memory. This approach helps prevent breaking changes between package updates. To support this compatibility, additional checks are implemented, and space is reserved in each data structure to accommodate potential future additions to stable memory.

While stable memory ensures data persistence, certain information is stored on the heap for faster access. This includes cached fields from stable memory and memory marked as deallocated in each MemoryRegion. Unlike stable memory where all data is formatted as `Blobs`, heap data utilizes various Motoko data types. This diversity in data types on the heap presents a challenge for compatibility, as adding new data types or modifying existing ones can potentially break compatibility between versions.

Future updates to this library may introduce new fields to cached data or modify the MemoryRegion to enhance performance. These changes could potentially alter the internal structure of the data, particularly on the heap where data types vary. To prevent data loss during such changes, each `StableStore` (the value returned after a call to `.newStableStore()`) is wrapped with the current version identifier. This versioning helps distinguish between different versions and facilitates the migration when the package is updated.

To upgrade your StableStore, use the following code:

```motoko
stable var sstore = MemoryBTree.newStableStore(null);
sstore := MemoryBTree.upgrade(sstore);
```

You can call `.upgrade()` either immediately after defining the stable store variable or within the `preupgrade()` system function. It's important to note that when `preupgrade()` is set or modified, the defined logic is executed on the next update to the canister, not the current one.

### Notes and Limitations

- Interacting with stable memory continuously requires significantly more instructions and heap allocations than using heap memory. For this reason, it is recommended to use these data structures only when the data you need to store exceeds the heap memory limit.
- Reallocating memory blocks, adds significant overhead to each data structure.
- Each value stored in the data structure is immutable. To update a value, the data is removed and the new value is serialized and stored in its place or in a new location.
- Currently, stable memory is not garbage collected. Which means that we can't free up a section of memory when it's not longer in use once we have allocated it. We can only mark it as deallocated and re-use it once we need to store more data. So even after one of our data structures is no longer in use and all of its data has been cleared, the `Region` and the memory it allocated will still be reserved.
- Ideally, serializing compound types can be done easily enough using a predefined serialization function for candid, but since motoko's `to_candid()` and `from_candid()` don't yet support generic types, each type need to have its own serialization utility defined.
