## Memory BTree

A B+Tree that stores all its data, including nodes and key-value pairs in stable memory.
The B+Tree is an ordered, self balancing tree data structure that supports searching, inserting, and deleting entries in $O(log n)$ time complexity.
It's designed to store large amounts of data that need to persist across canister upgrades.

### Design

The MemoryBTree is implemented using three seperate [MemoryRegion](https://github.com/NatLabs/memory-region).
A branch region for a the branch nodes, a leaves region for all the leaf nodes and a data region for all the key-value pairs.
Using three MemoryRegion allows us to isolate similar types of data with similar sizes, which helps reduce memory fragmentation during reallocation.

The MemoryBTree's internal structure is very much like a tree.
Branch nodes store pointers to other branch nodes or to a final leaf node.
Leaf nodes store pointers to memory blocks where the key-value pairs are stored.

#### Referencing Key-Value Pairs

Since pointers are stored in the leaf nodes instead of the actual values, we can reference the key-value pairs in other data-structures by using these pointers.
A use case for this could be as indexes in databases or even just in another data-structure to avoid duplicating the referenced entry.
Each pointer is a single `Nat` value so we expose them as unique ids that can be retrieved for each key and used later to lookup their values (i.e. `getId()`, `lookup()`).
In addition, there is also a `reference()` function that allows you to increment the number of references an entry has.
An entry can be referenced up to 255 times.
Once an entry is referenced, each call to `remove()` will decrement the reference count by one and the entry will only be deleted when the reference count is zero.
This is an optional feature so if `reference()` is not called, all entries would be deleted immediately when `remove()` is called.

### Characteristics

The MemoryBTree is designed to abstract away the memory layer and give the user as much control as possible.

During initialization of the tree users have the option to pick the `node_capacity` limit that will be used by all the nodes in the MemoryBTree.

### Required Utils

For the key, the `MemoryBTree` requires both `Blobify` and `MemoryCmp` utilities.
For the value however, only the `Blobify` utility is required.

The `MemoryCmp` utility is used in the `MemoryBTree` to compare keys in order to locate the correct entry or locate the node to insert or delete an entry.
As you might imagine, this utility is used often so it's that it is efficient when comparing these keys.

`MemoryCmp` is a variant that supports two different types of comparison functions.
The first one `#GenCmp` compares the keys in their indicated generic type (this is original type of the entry before it is serialized).
The second one `#BlobCmp` compares the keys in their serialized form as `Blob`s, avoiding the overhead required to convert to their indicated type.

Just like the other utilities, `MemoryCmp` has default values that have been set for each type within the `TypeUtils` module.

```motoko
let ascending_nat_btree_utils = MemoryBTree.createUtils(
  TypeUtils.Nat, // key,
  TypeUtils.Text // value
);

var sstore = MemoryBTree.newStableStore(null);
sstore := MemoryBTree.upgrade(sstore);

let mbtree = MemoryBTree.MemoryBTree(sstore, ascending_nat_btree_utils);

```

- replacing the comparison utility for the key with a descending order one

```motoko
func nat_cmp_descending(a: Nat, b: Nat): Int8 {
  if (a > b) { -1 }
  else if (a < b) { 1 }
  else { 0 };
};

let descending_btree_utils = MemoryBTree.createUtils(
  { TypeUtils with cmp = #GenCmp(nat_cmp_descending) }, // key
  TypeUtils.Text, // value
);

var sstore = MemoryBTree.newStableStore(null);
sstore := MemoryBTree.upgrade(sstore);

let mbtree = MemoryBTree.MemoryBTree(sstore, ascending_nat_btree_utils);
```

-

The [first benchmark](#serialization-and-comparison-functions) compares the performance between the two types of comparison functions. For example, `Text` and `Principal` are comparable as blobs, but `Int` and some `Nat` serializations can not be compared as blobs. It's good to note what i mean when i say comparable as blobs. I mean that no additional operation needs to be done to compare the two blobs. Using motoko's comparison operators should just work. Any operation, such as looping through and converting the blobs to a byte array creates overhead that builds up and slows down the comparison function.
`Int` cannot be compared without first converting with two's complement. `Nat` in little endian cannot be compared without first converting to a byte array and looping through the bytes in reverse order.
`Nat` in big endian however can be compared directly.
This is to say that the performance of the B+Tree is highly dependant on which Blobify (serialization) and comparison function you choose to use. We aim to guide you in making the best choice for your use case.

### Memory Layout

#### Branch Region

The branch region contains the nodes of the MemoryBTree that store pointers to other nodes.
It contains a fixed sized header of 64 bytes with information about the branches of the tree.

- Header

| Field          | Offset | Size | Type  | Default Value | Description                      |
| -------------- | ------ | ---- | ----- | ------------- | -------------------------------- |
| MAGIC          | 0      | 3    | Blob  | `"BRS"`       | Magic number                     |
| LAYOUT VERSION | 3      | 1    | Nat8  | `0`           | Layout version                   |
| DATA REGION ID | 4      | 4    | Nat32 | -             | Id of the main data region       |
| BRANCH COUNT   | 8      | 8    | Nat64 | -             | Number of branches in the B+Tree |
| RESERVED       | 16     | 48   | -     | -             | Extra space for future use       |

Following the header is a sequence of fixed sized memory blocks that store the information in each branch node.

- Branch Node

| Field          | Offset         | Size                   | Type  | Default Value | Description                                  |
| -------------- | -------------- | ---------------------- | ----- | ------------- | -------------------------------------------- |
| MAGIC          | 0              | 3                      | Blob  | -             | Magic number                                 |
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

The leaf region contains the nodes of the MemoryBTree that stores pointers to the key-value pairs.
This region contains a 64 byte header followed by the leaf nodes in the B+Tree.

- Header

| Field          | Offset | Size | Type  | Default Value | Description                      |
| -------------- | ------ | ---- | ----- | ------------- | -------------------------------- |
| MAGIC          | 0      | 3    | Blob  | `"LVS"`       | Magic number                     |
| LAYOUT VERSION | 3      | 1    | Nat8  | `0`           | Layout version                   |
| DATA REGION ID | 4      | 4    | Nat32 | -             | Id of the main data region       |
| LEAVES COUNT   | 8      | 8    | Nat64 | -             | Number of branches in the B+Tree |
| RESERVED       | 16     | 48   | -     | -             | Extra space for future use       |

Following the header is a sequence of fixed sized memory blocks that store the information in each leaf node.

- Leaf Node

| Field          | Offset | Size               | Type  | Default Value | Description                                                               |
| -------------- | ------ | ------------------ | ----- | ------------- | ------------------------------------------------------------------------- |
| MAGIC          | 0      | 3                  | Blob  | -             | Magic number                                                              |
| DEPTH          | 3      | 1                  | Nat8  | -             | Inverted depth of the node in the tree                                    |
| LAYOUT VERSION | 4      | 1                  | Nat8  | -             | Layout version                                                            |
| INDEX          | 5      | 2                  | Nat16 | -             | Node's position in parent node                                            |
| COUNT          | 7      | 2                  | Nat16 | -             | Number of elements in the node                                            |
| PARENT         | 9      | 8                  | Nat64 | -             | Parent address                                                            |
| PREV           | 17     | 8                  | Nat64 | -             | Previous leaf address                                                     |
| NEXT           | 25     | 8                  | Nat64 | -             | Next leaf address                                                         |
| RESERVED       | 33     | 31                 | -     | -             | Extra space from header (size 64) for future use                          |
| KV POINTERS    | 64     | 8 \* NODE_CAPACITY | Nat64 | -             | Unique addresses pointing to the key-value pair stored in the data region |

#### Key-Value Region

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

The key-value region stores pointers to the key-value pairs in stable memory, as well as their sizes and serialized values.

The module that abstracts the functions in the key-value region is the [./modules/MemoryBlock.mo](./modules/MemoryBlock.mo) file.

The structure of the initial block is as follows. It contains a reference counter, the size of both the keys and values, the serialized key and a pointer to the serialized value.
The serialized key and value are seperated because during update operations, we might need to allocate a larger memory block for the new value. This way we only need to update the pointer where the new value is stored instead of copying over the entire key-value pair and the metadata to a new memory block.

The layout of the blocks is as follows;

- Key Block

The key block stores information about the key value pair concatenated with the arbitrarily sized serialized key.

| Field           | Offset | Size (In bytes) | Type  | Default Value | Description          |
| --------------- | ------ | --------------- | ----- | ------------- | -------------------- |
| REFERENCE_COUNT | 0      | 1               | Nat8  | -             | Reference count      |
| KEY_SIZE        | 1      | 2               | Nat16 | -             | Size of the key      |
| VAL_POINTER     | 3      | 8               | Nat64 | -             | Pointer to the value |
| VALUE_SIZE      | 11     | 4               | Nat32 | -             | Size of the value    |
| KEY_BLOB        | 15     | -               | Blob  | -             | Serialized key       |

- Value Block

| Field      | Offset | Size (In bytes) | Type | Default Value | Description      |
| ---------- | ------ | --------------- | ---- | ------------- | ---------------- |
| VALUE_BLOB | 0      | -               | Blob | -             | Serialized value |

## Benchmarks

Benchmarking the performance with 10k entries

### Serialization and Comparison Functions

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

#### Notes and Limitations

- Overall, the MemoryBTree performs slower than the heap based ordered trees due to the overhead of reading and writing to stable memory.
- The comparison function is used internally to locate the correct node in the MemoryBTree during search, insertion and deletion operations.
- The MemoryBTree with the `#BlobCmp` comparison function performs better than the `#GenCmp` comparison function. This is because the `#BlobCmp` comparison function avoids the overhead of deserializing the keys but requires that the keys be comparable in their serialized format. The `#GenCmp` comparison function converts the keys to the original generic type defined by the user before comparing them. As seen in the benchmark, this conversion can be expensive and slow down the performance of the B+Tree. A data type that can be compared as Blobs is `Text` because their serialized format is a sequences of bytes that can be compared lexicographically.

### BTree fanout

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

|                          |    insert() |     get() |   replace() | entries() |    remove() |
| :----------------------- | ----------: | --------: | ----------: | --------: | ----------: |
| B+Tree                   |     730_052 |   208_960 |     608_964 |     9_084 |     208_964 |
| MemoryBTree (order 4)    |   7_297_212 | 7_244_864 |   7_644_868 |   889_552 | -21_431_736 |
| MemoryBTree (order 32)   |   6_120_864 | 4_911_008 |   5_311_012 |   889_360 | -21_221_864 |
| MemoryBTree (order 64)   |   6_861_048 | 4_806_632 |   5_206_636 |   889_360 |   9_570_264 |
| MemoryBTree (order 128)  | -23_979_732 | 4_359_672 |   4_759_676 |   889_328 |  10_790_788 |
| MemoryBTree (order 256)  | -18_315_128 | 4_341_120 |   4_741_124 |   889_328 |  13_621_712 |
| MemoryBTree (order 512)  | -13_413_108 | 4_327_608 |   4_727_612 |   889_328 | -10_334_048 |
| MemoryBTree (order 1024) |     475_600 | 4_309_008 |   4_709_012 |   889_328 |   1_398_564 |
| MemoryBTree (order 2048) |  -5_471_140 | 4_280_016 | -27_653_832 |   889_328 |  24_466_008 |
| MemoryBTree (order 4096) | -26_688_348 | 4_218_480 |   4_618_484 |   889_328 |     757_288 |

This benchmark compares different layout to yield the optimal results for each of the btree operations. This benchmark particularly measures the results for 10_000 entries. We want the optimal layout between how wide the btree is and how tall it is.
Each node capacity results in a different looking MemoryBTree. MemoryBTree's with smaller node capacities are have less elements per node, resulting in them having a large number of nodes, resulting in taller trees compared to their width.
MemoryBTrees with larger node capacities have more elements per node and require fewer nodes to house a given number of entries. This results in a shorter but wider tree, where each node on the same level from the root holds a lot of elements. The advantages of wider trees is that it reduces the amount of
Depending on the number of entries, we will get different results.

### Search Operations

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

```

```
