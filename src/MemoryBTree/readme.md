## Memory BTree

A B+Tree that stores all its data, including nodes and key-value pairs in stable memory.
The B+Tree is an ordered, self balancing tree data structure that supports searching, inserting, and deleting entries in $O(log n)$ time complexity.
It's designed to store large amounts of data that need to persist across canister upgrades.

### Design

The MemoryBTree is implemented using three seperate [MemoryRegions](https://github.com/NatLabs/memory-region).
A branch region for the branch nodes, a leaves region for all the leaf nodes and a data region for all the key-value pairs.
Using three MemoryRegion allows us to isolate similar types of data with similar sizes, which helps reduce memory fragmentation during reallocation.

The MemoryBTree's internal structure is very much like a tree.
The branch nodes store pointers to other branch nodes or to leaf nodes.
The leaf nodes store pointers to key-value blocks where the serialized keys and values are stored.

#### Referencing Key-Value Pairs

Since pointers are stored in the leaf nodes instead of the actual values, we can reference the key-value pairs in other data-structures by using these pointers.
A use case for this could be as indexes in databases or even just in another data-structure to avoid duplicating the referenced entry.
Each pointer is a single `Nat` value so we expose them as unique ids that can be retrieved for each key and used later to lookup their values (i.e. `getId()`, `lookup()`).
In addition, there is also a `reference()` function that allows you to increment the number of references an entry has.
An entry can be referenced up to 255 times.
Once an entry is referenced, each call to `remove()` will decrement the reference count by one and the entry will only be deleted when the reference count is zero.
This is an optional feature so if `reference()` is not called, all entries would be deleted immediately when `remove()` is called.

### Usage Examples

```motoko
  import MemoryBTree "mo:memory-collection/MemoryBTree";
  import TypeUtils "mo:memory-collection/TypeUtils";

  stable var sstore = MemoryBTree.newStableStore(null);
  sstore := MemoryBTree.upgrade(sstore);

  let btree_utils = MemoryBTree.createUtils(
    TypeUtils.BigEndian.Nat,
    TypeUtils.Text
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

### Create Custom TypeUtils

The `MemoryBTree` requires three functions during initialization.
A `Blobify` and `MemoryCmp` functions for the key and another `Blobify` function for the value.

The `MemoryCmp` function here is used to locate and insert entries in their correct order by comparing the keys in different nodes until the target node is found.
As you might imagine, this function is used in almost every BTree operation because most of them need to first retrieve the leaf node where the key-value entry is stored before the operation can be executed.
As a result it is important that this function is efficient as possible.

To address this, the `MemoryCmp` was created as a variant with two different types of comparison functions.
The first one `#GenCmp` compares the keys in their generic type (this is original type of the entry before it is serialized).
The second one `#BlobCmp` compares the keys in their serialized form as `Blob`s and avoids the overhead required to convert to their generic type.

- Here is an example creating the MemoryBTree's utilities with the default `TypeUtils` module

  ```motoko
  let btree_utils = MemoryBTree.createUtils(
    TypeUtils.BigEndian.Nat, // key,
    TypeUtils.Text // value
  );

  var sstore = MemoryBTree.newStableStore(null);
  sstore := MemoryBTree.upgrade(sstore);

  let mbtree = MemoryBTree.MemoryBTree(sstore, btree_utils);
  ```

- An example using a custom `MemoryCmp` and `Blobify` utils.
  We are going to use a `Gamer` datatype as the key and `Text ` as the value in this example

  ```motoko
  type Gamer = {
    score: Nat;
    id: Nat;
    name: Text;
  }
  ```

  - `Blobify`

  ```motoko
  let { Blobify } = TypeUtils;

  let gamer_blobify : Typeutils.Blobify<Gamer> = {
    to_blob = func(gamer: Gamer) : Blob {
      let score_blob = Blobify.Nat.to_blob(gamer.score);
      let score_size = Blob.fromArray([Nat8.fromNat(score_size.size())]);

      let id_blob = Blobify.Nat.to_blob(user.id);
      let id_size = Blob.fromArray([Nat8.fromNat(id_blob.size())]);

      let name_blob = Blobify.Text.to_blob(gamer.size());
      let name_size = Blob.fromArray([Nat8.fromNat(name_blob.size())]);

      return TypeUtils.concat_blobs(
        [score_size, score_blob, id_size, id_blob, name_blob, name_size]
      );
    };

    from_blob = func(blob: Blob) : Gamer {
      let bytes = Blob.toArray(blob);

      var i = 0;
      let score_size = Nat8.toNat(bytes[i]);
      i += 1;

      let score_bytes = Array.slice(bytes, i, i + score_size);
      i += score_size;

      let score_blob = Blob.fromArray(score_bytes);
      let score = Blobify.Nat.from_blob(score_blob);

      let id_size = Nat8.toNat(bytes[i]);
      i += 1;

      let id_bytes = Array.slice(bytes, i, i + id_size);
      i += id_size;

      let id_blob = Blob.fromArray(id_bytes);
      let id = Blobify.Nat.from_blob(id_blob);

      let name_size = Nat8.toNat(bytes[i]);
      i += 1;

      let name_bytes = Array.slice(bytes, i, i + name_size);
      i += name_size;

      let name_blob = Blob.fromArray(name_bytes);
      let name = Blobify.Text.from_blob(name_blob);

      return { score; id; name };

    }
  }
  ```

  - `MemoryCmp`

    - `#GenCmp`

    ```motoko
      let gamer_cmp : TypeUtils.MemoryCmp<Gamer> = #GenCmp(
        func(g1: Gamer, g2: Gamer) : Int8 {
          if (g1.score > g2.score) return 1;
          if (g1.score < g2.score) return -1;

          // if the scores are equal compare their
          // ids, so one doesn't overwrite the other
          // and both gamer records stay unique

          if (g1.id > g2.id) return 1;
          if (g1.id < g2.id) return -1;

          return 0;
        }
      );
    ```

    - `#BlobCmp`

    ```motoko
      let gamer_cmp : TypeUtils.MemoryCmp<Gamer> = #BlobCmp(
        func(g1: Blob, g2: Blob) : Int8 {
          if (g1 > g2) return 1;
          if (g1 < g2) return -1;

          // no need to compare ids separately here because
          // they are concatenated with the score and by
          // default included in the comparison

          return 0;
        }
      );
    ```

    Why does comparing just the blobs work?

    Both `MemoryCmp` functions sort the gamers by ascending order of their score in the tree.
    It's easy to tell from the `#GenCmp` function but it is less apparent in the `#BlobCmp` function.
    The order of the keys in the `#BlobCmp` is derived from the `Blobify` function and the position of each piece of data within the returned blob.
    The position is important because the default blob comparison which is used here compares the byte at each index in the two blobs and continues this procees either until when it reaches an index where the bytes do not match or when one of the blobs terminates.
    The serialized `Gamer` value is a concatenation of all the fields in the `Gamer` record.
    First is the score, followed by the id, then finally the name:
    First is score, which starts with the size followed by the serialized value.

    `GamerBlob -> [score_size, score_blob, id_size, id_blob, name_blob, name_size]`

    During comparison, the score_size of the two blobs are compared first.
    Because the score is a nat value the order can be determined by the size of its bytes. If one has more bytes than the other, then its score is larger and vise versa. However, if the sizes are equal then the rest of the score blob needs to be compared to determine the order.

    In the case where the score blob in both serialized values are equal, the comparison would then compare the id field concatenated after the score.

    The id field here is important to differentiate between two `Gamer` records that have the same score so that they can be stored individually and avoid overwriting one another.

### Memory Layout

#### Branch Region

The branch region contains a 64 byte header followed by a sequence of branch nodes that store pointers to other nodes in the MemoryBTree.

- Header

| Field          | Offset | Size | Type  | Default Value | Description                      |
| -------------- | ------ | ---- | ----- | ------------- | -------------------------------- |
| MAGIC          | 0      | 3    | Blob  | `"BRS"`       | Magic number                     |
| LAYOUT VERSION | 3      | 1    | Nat8  | `0`           | Layout version                   |
| DATA REGION ID | 4      | 4    | Nat32 | -             | Id of the main data region       |
| BRANCH COUNT   | 8      | 8    | Nat64 | -             | Number of branches in the B+Tree |
| RESERVED       | 16     | 48   | -     | -             | Extra space for future use       |

- Branch Node

| Field          | Offset         | Size                   | Type  | Default Value | Description                                  |
| -------------- | -------------- | ---------------------- | ----- | ------------- | -------------------------------------------- |
| MAGIC          | 0              | 3                      | Blob  | "BND"         | Magic number                                 |
| DEPTH          | 3              | 1                      | Nat8  | -             | Inverted depth of the node in the tree       |
| LAYOUT VERSION | 4              | 1                      | Nat8  | -             | Layout version                               |
| INDEX          | 5              | 2                      | Nat16 | -             | Node's position in parent node               |
| COUNT          | 7              | 2                      | Nat16 | -             | Number of elements in the node               |
| SUBTREE COUNT  | 9              | 8                      | Nat64 | -             | Number of elements in the node's subtree     |
| PARENT         | 17             | 8                      | Nat64 | -             | Parent address                               |
| RESERVED       | 25             | 47                     | -     | -             | Extra space for future use                   |
| KEYS           | 64             | 8 \* NODE_CAPACITY - 1 | Nat64 | -             | Unique ids for each key stored in the branch |
| Children       | 64 + size(Ids) | 8 \* NODE_CAPACITY     | Nat64 | -             | Addresses of children nodes                  |

#### Leaf Region

This region has a 64 byte fixed header followed by a sequence of leaf nodes in the B+Tree.

- Header

  | Field          | Offset | Size | Type  | Default Value | Description                      |
  | -------------- | ------ | ---- | ----- | ------------- | -------------------------------- |
  | MAGIC          | 0      | 3    | Blob  | `"LVS"`       | Magic number                     |
  | LAYOUT VERSION | 3      | 1    | Nat8  | `0`           | Layout version                   |
  | DATA REGION ID | 4      | 4    | Nat32 | -             | Id of the main data region       |
  | LEAVES COUNT   | 8      | 8    | Nat64 | -             | Number of branches in the B+Tree |
  | RESERVED       | 16     | 48   | -     | -             | Extra space for future use       |

- Leaf Node

  A leaf node is a fixed sized memory blocks that holds pointers to key-value blocks and store information about the node's position in the tree

  | Field          | Offset | Size               | Type  | Default Value | Description                                                               |
  | -------------- | ------ | ------------------ | ----- | ------------- | ------------------------------------------------------------------------- |
  | MAGIC          | 0      | 3                  | Blob  | "LND"         | Magic number                                                              |
  | DEPTH          | 3      | 1                  | Nat8  | 1             | Inverted depth of the node in the tree                                    |
  | LAYOUT VERSION | 4      | 1                  | Nat8  | -             | Layout version                                                            |
  | INDEX          | 5      | 2                  | Nat16 | -             | Node's position in parent node                                            |
  | COUNT          | 7      | 2                  | Nat16 | -             | Number of elements in the node                                            |
  | PARENT         | 9      | 8                  | Nat64 | -             | Parent address                                                            |
  | PREV           | 17     | 8                  | Nat64 | -             | Previous leaf address                                                     |
  | NEXT           | 25     | 8                  | Nat64 | -             | Next leaf address                                                         |
  | RESERVED       | 33     | 31                 | -     | -             | Extra space from header (size 64) for future use                          |
  | KV POINTERS    | 64     | 8 \* NODE_CAPACITY | Nat64 | -             | Unique addresses pointing to the key-value pair stored in the data region |

#### Key-Value Region

This region contains a 64 byte fixed header with information about the tree like the root address and the max node capacity, followed by a sequence of key-value blocks.

- Header Section

  | Field              | Offset | Size | Type  | Default Value | Description                                           |
  | ------------------ | ------ | ---- | ----- | ------------- | ----------------------------------------------------- |
  | MAGIC              | 0      | 3    | Blob  | `"BTR"`       | Magic number                                          |
  | LAYOUT VERSION     | 3      | 1    | Nat8  | `0`           | Layout version                                        |
  | BRANCHES REGION ID | 4      | 4    | Nat32 | -             | Id of the branches region                             |
  | LEAVES REGION ID   | 4      | 4    | Nat32 | -             | Id of the leaves region                               |
  | NODE CAPACITY      | 8      | 2    | Nat16 | -             | Maximum number of elements per node                   |
  | ROOT               | 10     | 8    | Nat64 | -             | Address of the root node                              |
  | COUNT              | 18     | 8    | Nat64 | -             | Number of elements in the B+Tree                      |
  | DEPTH              | 26     | 8    | Nat64 | -             | Number of levels from the root node to the leaf nodes |
  | IS_ROOT_A_LEAF     | 34     | 1    | Bool  | -             | Flag to indicate if the root is a leaf node           |
  | RESERVED           | 35     | 29   | -     | -             | Extra space for future use                            |

- Key-Value Blocks

  - Key Block

    The key block stores a reference counter for the entry, the address pointer to the value block, the serialized key and their size.

    | Field           | Offset | Size (In bytes) | Type  | Default Value | Description          |
    | --------------- | ------ | --------------- | ----- | ------------- | -------------------- |
    | REFERENCE_COUNT | 0      | 1               | Nat8  | -             | Reference count      |
    | KEY_SIZE        | 1      | 2               | Nat16 | -             | Size of the key      |
    | VAL_POINTER     | 3      | 8               | Nat64 | -             | Pointer to the value |
    | VALUE_SIZE      | 11     | 4               | Nat32 | -             | Size of the value    |
    | KEY_BLOB        | 15     | -               | Blob  | -             | Serialized key       |

  - Value Block

    The value block only contains the serialized value.

    | Field      | Offset | Size (In bytes) | Type | Default Value | Description      |
    | ---------- | ------ | --------------- | ---- | ------------- | ---------------- |
    | VALUE_BLOB | 0      | -               | Blob | -             | Serialized value |

### Benchmarks

Benchmarking the performance with 10k entries

#### Serialization and Comparison Functions

- Comparing the heap based B+Tree with the performance of the blob and generic comparison methods.

**Instructions**

|                          |    insert() |       get() |   replace() |  entries() |    remove() |
| :----------------------- | ----------: | ----------: | ----------: | ---------: | ----------: |
| RBTree                   | 154_251_518 | 100_820_380 | 159_275_397 | 17_794_137 | 170_463_908 |
| BTree                    | 165_175_957 | 134_436_580 | 139_951_085 | 10_941_491 | 184_865_583 |
| B+Tree                   | 231_122_916 | 133_769_004 | 140_488_566 |  4_731_896 | 245_803_357 |
| Memory B+Tree (#BlobCmp) | 417_745_140 | 338_605_940 | 355_602_854 | 39_788_860 | 483_281_121 |
| Memory B+Tree (#GenCmp)  | 522_998_371 | 443_240_923 | 460_237_837 | 39_789_424 | 576_474_634 |

**Heap**

|                          |  insert() |     get() | replace() | entries() |    remove() |
| :----------------------- | --------: | --------: | --------: | --------: | ----------: |
| RBTree                   | 9_002_868 |     8_960 | 8_202_852 | 1_889_036 | -18_440_952 |
| BTree                    | 1_217_704 |   481_728 | 1_154_500 |   602_524 |   1_953_100 |
| B+Tree                   |   682_868 |   208_960 |   608_964 |     9_084 |     208_964 |
| Memory B+Tree (#BlobCmp) | 8_333_344 | 4_362_312 | 4_602_316 |   889_328 | -19_071_248 |
| Memory B+Tree (#GenCmp)  | 8_333_344 | 4_362_312 | 4_602_316 |   889_328 | -21_250_524 |

##### Notes and Limitations

- Overall, the MemoryBTree performs slower than the heap based ordered trees due to the overhead of reading and writing to stable memory.
- The comparison function is used internally to locate the correct node in the MemoryBTree during search, insertion and deletion operations.
- The MemoryBTree with the `#BlobCmp` comparison function performs better than the `#GenCmp` comparison function. This is because the `#BlobCmp` comparison function avoids the overhead of deserializing the keys but requires that the keys be comparable in their serialized format. The `#GenCmp` comparison function converts the keys to the original generic type defined by the user before comparing them. As seen in the benchmark, this conversion is expensive and negatively impacts the performance of the B+Tree.

#### BTree fanout

- Comparing the performance with different node capacities of the B+Tree.

**Instructions**

|                    |    insert() |       get() |     replace() |  entries() |      remove() |
| :----------------- | ----------: | ----------: | ------------: | ---------: | ------------: |
| B+Tree             | 175_321_548 | 144_101_415 |   154_390_977 |  4_851_558 |   184_602_098 |
| MemoryBTree (4)    | 922_483_169 | 694_818_910 | 1_015_931_824 | 48_674_343 | 1_123_705_405 |
| MemoryBTree (32)   | 554_132_203 | 451_027_102 |   554_455_016 | 44_683_690 |   644_690_502 |
| MemoryBTree (64)   | 529_100_546 | 441_496_659 |   544_916_573 | 44_399_399 |   610_079_963 |
| MemoryBTree (128)  | 487_917_817 | 395_729_727 |   462_886_641 | 44_256_110 |   555_326_995 |
| MemoryBTree (256)  | 483_818_328 | 393_881_668 |   461_038_582 | 44_183_035 |   545_110_924 |
| MemoryBTree (512)  | 490_366_041 | 392_434_089 |   459_591_003 | 44_144_864 |   547_117_261 |
| MemoryBTree (1024) | 511_739_965 | 390_561_172 |   457_718_086 | 44_129_801 |   561_298_355 |
| MemoryBTree (2048) | 553_458_184 | 387_792_544 |   454_949_675 | 44_129_046 |   595_467_035 |
| MemoryBTree (4096) | 630_554_887 | 382_160_975 |   449_317_889 | 44_144_389 |   663_961_787 |

**Heap**

|                    |    insert() |     get() |   replace() | entries() |    remove() |
| :----------------- | ----------: | --------: | ----------: | --------: | ----------: |
| B+Tree             |     730_052 |   208_960 |     608_964 |     9_084 |     208_964 |
| MemoryBTree (4)    |   7_297_212 | 7_244_864 |   7_644_868 |   889_552 | -21_431_736 |
| MemoryBTree (32)   |   6_120_864 | 4_911_008 |   5_311_012 |   889_360 | -21_221_864 |
| MemoryBTree (64)   |   6_861_048 | 4_806_632 |   5_206_636 |   889_360 |   9_570_264 |
| MemoryBTree (128)  | -23_979_732 | 4_359_672 |   4_759_676 |   889_328 |  10_790_788 |
| MemoryBTree (256)  | -18_315_128 | 4_341_120 |   4_741_124 |   889_328 |  13_621_712 |
| MemoryBTree (512)  | -13_413_108 | 4_327_608 |   4_727_612 |   889_328 | -10_334_048 |
| MemoryBTree (1024) |     475_600 | 4_309_008 |   4_709_012 |   889_328 |   1_398_564 |
| MemoryBTree (2048) |  -5_471_140 | 4_280_016 | -27_653_832 |   889_328 |  24_466_008 |
| MemoryBTree (4096) | -26_688_348 | 4_218_480 |   4_618_484 |   889_328 |     757_288 |

#### Search Operations

**Instructions**

|                |      B+Tree |   MemoryBTree |
| :------------- | ----------: | ------------: |
| getFromIndex() |  68_084_526 |   982_867_372 |
| getIndex()     | 167_272_704 | 2_056_032_208 |
| getFloor()     |  79_745_706 |   944_184_979 |
| getCeiling()   |  79_746_359 |   944_185_764 |
| removeMin()    | 151_750_473 | 1_518_343_522 |
| removeMax()    | 115_673_205 | 1_459_495_725 |

**Heap**

|                |  B+Tree | MemoryBTree |
| :------------- | ------: | ----------: |
| getFromIndex() | 328_960 | -18_588_204 |
| getIndex()     | 586_764 |    -464_796 |
| getFloor()     | 213_804 |  -3_850_692 |
| getCeiling()   | 213_804 |  -1_678_896 |
| removeMin()    | 213_864 |  18_259_436 |
| removeMax()    | 209_944 |   5_447_972 |
