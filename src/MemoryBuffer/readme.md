## MemoryBuffer

### Design
The buffer is built using two [MemoryRegion](https://github.com/NatLabs/memory-region). A blob region and a memory block region.

- **Blob Region**: 
  - Stores all your elements as blobs in stable memory, re-allocating memory as needed. This region is not contiguous, as elements are stored in memory blocks of varying sizes and can be removed on demand, leaving gaps in memory that can be reused in the future.
- **Pointer Region**: 
  - Keeps track of the memory blocks (address and size) of the elements in the Blob Region. This region is contiguous as it allocates a fixed size of 12 bytes for each memory block. The address takes 8 bytes, and the size takes 4 bytes. Allowing values of up to 4 GiB to be stored as a single element. 
  - This region acts as the buffer's index to value map. Once elements are accessed by the index, the buffer retrieves the memory block by multiplying the index by 12 to get the address and size, then retrieves the element from the Blob Region.

### Characteristics

The characteristics of the buffer are determined by how you decide to use it. The is built as a general purpose buffer that can be used in a variety of ways. Its internal structure allows users to interact with it as a list, queue or double-ended queue. he way these data-structures are represented in memory are very similar, which makes it possible to not only add all these features to create a general purpose buffer, but to also do it without affecting the performance of the buffer.
However, there is one difference which concerns when the buffer grows. Using only buffer operations, when the array grows, it doesn't need to shift elements internally, it just allocates new pages and adds new elements to the end.
Using it as a double ended queue, might require shifting of elements to either either ends of the buffer when the buffer grows.

The buffer also benefits from the queue like structure to add and remove elements from either end. For example, remove() performs better than if it was just implemented as list. The worst case is divided by 2, because we can shift the minimum number of elements to the left or right to remove an element from anywhere in the buffer instead of just shifting all the elements to the left.


#### Pros and Cons
- **Pros**
  - Allows for random access to elements with different byte sizes.
  - Prevents internal fragmentation, a common issue in designs where each element is allocated a memory block equivalent to the maximum element's size.
- **Cons**
  - 12 bytes of overhead per element
    - 8 bytes for the address where the blob of the element is stored
    - 4 bytes for the size of the element
  - Each element's size when converted to a `Blob` must be between 1 and 4 GiB.
  - Additional instructions and heap allocations required for storing and retrieving free memory blocks.
  - Could potentially cause external fragmentation during memory block reallocations, resulting in a number small blocks that sum up to the needed size but can't be re-allocated because they are not contiguous.

## Getting Started
#### Import modules

```motoko
    import Blobify "mo:memory-buffer/Blobify";
    import MemoryBuffer "mo:memory-buffer/MemoryBuffer";
```

#### Usage Examples
```motoko
  stable var mem_store = MemoryBufferClass.newStableStore<Nat>();

  let buffer = MemoryBufferClass.MemoryBufferClass<Nat>(mem_store, Blobify.Nat);
  buffer.add(1);
  buffer.add(3);
  buffer.insert(1, 2);
  assert buffer.toArray() == [1, 2, 3];

  for (i in Iter.range(0, buffer.size(mem_buffer) - 1)) {
    let n = buffer.get(i);
    buffer.put(i, n ** 2);
  };

  assert buffer.toArray() == [1, 4, 9];
  assert buffer.remove(1) == ?4;
  assert buffer.removeLast() == ?9;
```

#### Upgrading to a new version
The MemoryRegion that stores deallocated memory for future use is under development and may have breaking changes in the future. 
To account for this, the `MemoryBuffer` has a versioning system that allows you to upgrade without losing your data.

Steps to upgrade:
- Install new version via mops: `mops add memory-buffer@<version>`
- Call `upgrade()` on the buffer's memory store to upgrade to the new version.
- Replace the old memory store with the upgraded one.

```motoko
  stable var mem_store = MemoryBufferClass.newStableStore<Nat>();
  mem_store := MemoryBufferClass.upgrade(mem_store);
```

## Benchmarks
### Buffer vs MemoryBuffer
Benchmarking the performance with 10k `Nat` entries

- **put()** (new == prev) - updating elements in the buffer where number of bytes of the new element is equal to the number of bytes of the previous element
- **put() (new > prev)** - updating elements in the buffer where number of bytes of the new element is greater than the number of bytes of the previous element
- **sortUnstable() - #GenCmp**   - quicksort on the buffer - an unstable sort algorithm
- **blobSortUnstable() - #BlobCmp** - sorting without serializing the elements. Requires that the elements can be orderable in their serialized form.

#### Instructions

Benchmarking the performance with 10k entries

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

#### Heap

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

Encoding to Candid is more efficient than using a custom encoding function.
However, a custom encoding can be implemented to use less stable memory because it's more flexible and is not required to store the type information with the serialized data.
