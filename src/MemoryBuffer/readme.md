## MemoryBuffer

A buffer that stores its elements in stable memory.

### Design

The `MemoryBuffer` is built using two [MemoryRegions](https://github.com/NatLabs/memory-region).
A blob region for storing the serialized values and a pointer region for storing the memory address and the size of the serialized values.
The pointer region acts as a index to value map, connecting the index of the value to the memory address where it is located.
Each entry has an overhead of 12 bytes.
The memory address takes up 8 bytes, while the stored size takes up 4 bytes.

When the `MemoryBuffer` is filled, it doesn't need to be resized and have all its elements shifted to a new MemoryRegion.
Instead it allocated more bytes in its current MemoryRegion and adds the new elements to the end of the MemoryRegion.

### Usage Example

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

### Create Custom TypeUtils

To store more complex data types, you can create your own utilities to serialize and deserialize your data.
The `MemoryBuffer` only requires that the data type implements the `Blobify` interface. This interface has two functions:

```motoko
  public type Blobify<T> = {
    to_blob: (T) -> Blob;
    from_blob: (Blob) -> T;
  }
```

Here is an example for a custom `User` data type:

```motoko
  type User = {
    id: Nat;
    name: Text;
  }
```

- Using candid

```motoko
  import MemoryBuffer "mo:memory-collection/MemoryBuffer";
  import TypeUtils "mo:memory-collection/TypeUtils";

  let blobify_user : TypeUtils.Blobify<User> = {
    to_blob = func(user: User) : Blob = to_candid(user);
    from_blob = func(blob: Blob) : User {
      let ?user : ?User = from_candid(blob) else Debug.trap("Blobify error: Failed to decode User");
      return user;
    }
  };

  // we create a super type of TypeUtils that contains
  // only the utilities we need
  let user_type_utils = { blobify = blobify_user };

  stable var sstore = MemoryBuffer.newStableStore<User>();
  sstore := MemoryBuffer.upgrade(sstore);

  let mbuffer = MemoryBuffer.MemoryBuffer<User>(sstore, user_type_utils);
```

- custom serialization

If we want to avoid the extra bytes required in candid for storing the type information we can decide to implement our own serialization function.
We will choose a simple serialization format where we serialize both fields to their `Blob` representation.
Retrieve the size of resulting blobs and serialize them as well.
We'll assume that the blob sizes of both fields are less that a 256 and concatenat them as a single byte to the resulting blob.
Then we concatenate the size blobs with the blobs of the fields.
And finally we concatenate the resulting blobs.

```motoko
  import MemoryBuffer "mo:memory-collection/MemoryBuffer";
  import TypeUtils "mo:memory-collection/TypeUtils";
  import Blobify "mo:memory-collection/TypeUtils/Blobify";

  let blobify_user : TypeUtils.Blobify<User> = {
    to_blob = func(user: User) : Blob {
      let id_blob = Blobify.Nat.to_blob(user.id)
      let id_size = Blob.fromArray([Nat8.fromNat(id_blob.size())]);

      let name_blob = Blobify.Text.to_blob(user.name);
      let name_size = Blob.fromArray([Nat8.fromNat(name_blob.size())]);

      return TypeUtils.concat_blobs(
        [id_size, id_blob, name_size, name_blob]
      );
    };
    from_blob = func(blob: Blob) : User {
      let bytes = Blob.toArray(blob);
      let id_size = Nat8.toNat(bytes[0]);

      let id_bytes = Array.slice(bytes, 1, 1 + id_size);
      let id_blob = Blob.fromArray(id_bytes);
      let id = Blobify.Nat.from_blob(id_blob);

      let name_size = Nat8.toNat(bytes[1 + id_size]);
      let name_bytes = Array.slice(bytes, 2 + id_size, 2 + id_size + name_size);
      let name_blob = Blob.fromArray(name_bytes);
      let name = Blobify.Text.from_blob(name_blob);

      return { id; name; };
    };
  };

  let user_type_utils = { blobify = blobify_user };

  stable var sstore = MemoryBuffer.newStableStore<User>();
  sstore := MemoryBuffer.upgrade(sstore);

  let mbuffer = MemoryBuffer.MemoryBuffer<User>(sstore, user_type_utils);
```

### Memory Layout

#### Pointer Region

- Header

| Field          | Offset | Size | Type  | Default Value | Description                      |
| -------------- | ------ | ---- | ----- | ------------- | -------------------------------- |
| MAGIC          | 0      | 3    | Blob  | `"BTR"`       | Magic number                     |
| LAYOUT VERSION | 3      | 1    | Nat8  | `0`           | Layout version                   |
| Blob Region Id | 4      | 4    | Nat32 | -             | Id of the Blob Region            |
| COUNT          | 8      | 4    | Nat32 | -             | Number of elements in the buffer |
| RESERVED       | 12     | 52   | Nat32 | -             | Reserved for future use          |

- Pointers

A series of 12 byte entries that point to the memory blocks of the elements in the Blob Region.
These pointers are stored contiguously in the pointer region immedialy after the header with an offset of 64 bytes.

| Field   | Offset | Size | Type  | Default Value | Description                 |
| ------- | ------ | ---- | ----- | ------------- | --------------------------- |
| Address | 0      | 8    | Nat64 | -             | Address of the memory block |
| Size    | 8      | 4    | Nat32 | -             | Size of the memory block    |

#### Blob Region

- Header

| Field             | Offset | Size | Type  | Default Value | Description              |
| ----------------- | ------ | ---- | ----- | ------------- | ------------------------ |
| MAGIC             | 0      | 3    | Blob  | `"BLB"`       | Magic number             |
| LAYOUT VERSION    | 3      | 1    | Nat8  | `0`           | Layout version           |
| POINTER REGION ID | 4      | 4    | Nat32 | -             | Id of the Pointer Region |
| RESERVED          | 8      | 56   | Nat32 | -             | Reserved for future use  |

- Memory Blocks Data

A series of randomly sized elements stored as blobs at the address and size specified by the pointers in the Pointer Region.
These blobs are stored immediately after the header with an offset of 64 bytes.

### Benchmarks

#### Buffer vs MemoryBuffer

Benchmarking the performance with 10k `Nat` entries

- **put()** (new == prev) - updating elements in the buffer where number of bytes of the new element is equal to the number of bytes of the previous element
- **put() (new > prev)** - updating elements in the buffer where number of bytes of the new element is greater than the number of bytes of the previous element
- **sortUnstable() - #GenCmp** - quicksort - sorting elements by deserializing them to their original type before comparing them
- **sortUnstable() - #BlobCmp** - sorting elements in their serialized form. Requires that the elements can be orderable in their serialized form.

**Instructions**

Benchmarking the performance with 10k `Nat` entries

|                         |        Buffer | MemoryBuffer (with Blobify) | MemoryBuffer (encode to candid) |
| :---------------------- | ------------: | --------------------------: | ------------------------------: |
| add()                   |     4_691_772 |                  55_509_319 |                      38_539_297 |
| get()                   |     2_502_553 |                  31_863_052 |                      29_825_339 |
| put() (new == prev)     |     3_893_443 |                  63_154_140 |                      35_279_406 |
| put() (new > prev)      |     4_557_041 |                 413_035_339 |                     207_344_314 |
| put() (new < prev)      |     4_235_072 |                 161_521_983 |                     158_895_293 |
| add() reallocation      |     8_868_309 |                 434_357_563 |                     162_142_959 |
| removeLast()            |     4_688_550 |                 126_960_035 |                      74_724_171 |
| reverse()               |     3_120_910 |                  13_794_169 |                      13_788_413 |
| remove()                | 3_682_590_903 |                 383_682_557 |                     380_509_119 |
| insert()                | 3_264_760_420 |                 642_877_048 |                     357_788_879 |
| sortUnstable() #GenCmp  |   101_270_997 |               2_404_559_478 |                   2_151_767_821 |
| shuffle()               |         ----- |                 219_269_838 |                     219_265_425 |
| sortUnstable() #BlobCmp |         ----- |                 988_375_542 |                          ------ |

**Heap**

|                         |    Buffer | MemoryBuffer (with Blobify) | MemoryBuffer (encode to candid) |
| :---------------------- | --------: | --------------------------: | ------------------------------: |
| add()                   |     8_960 |                   1_204_548 |                         609_692 |
| get()                   |     8_960 |                     993_528 |                         369_032 |
| put() (new == prev)     |     8_960 |                   1_367_672 |                         646_308 |
| put() (new > prev)      |     8_964 |                  11_260_020 |                       2_728_356 |
| put() (new < prev)      |     8_964 |                   2_332_688 |                       1_772_776 |
| add() reallocation      |   158_984 |                 -23_327_632 |                       3_142_896 |
| removeLast()            |     8_960 |                   1_960_312 |                         719_052 |
| reverse()               |     8_904 |                     248_960 |                         248_960 |
| remove()                |    99_136 |                   3_502_272 |                       3_017_012 |
| insert()                |   154_852 |                 -11_315_348 |                      10_800_952 |
| sortUnstable() #GenCmp  | 2_520_996 |                   3_402_300 |                     -24_828_540 |
| shuffle()               |     ----- |                   7_887_376 |                       7_887_376 |
| sortUnstable() #BlobCmp |     ----- |                  14_785_428 |                           ----- |

> Generate benchmarks by running `mops bench` in the project directory.

#### Notes and Observations

- This should come as a surprise but the `MemoryBuffer` requires significantly more instructions than the `Buffer` for most operations when performing the same operations. The reason is the `Buffer` does not need to serialize and deserialize its elements and most importantly, it does not need to access stable memory which is slower than heap memory.
- `remove()` and `insert()` perform better in the `MemoryBuffer` than the `Buffer` because the `MemoryBuffer` does not need to shift elements, it just shifts the fixed sized pointers in the pointer region.
- Encoding to candid is more efficient than using a custom encoding in most cases because `to_candid()` and `from_candid()` are system functions provided with motoko and are more efficient than most functions that can be implemented in motoko after the fact. However, candid encoding includes extra bytes for the type information which can add up to a significant amount. So, it is important to consider the trade-offs when choosing between candid and custom encoding.
- Finally, candid encoding cannot be compared in its blob form because they are not in an orderable form. This is why the `sortUnstable() #BlobCmp` benchmark is not available for candid encoding.
