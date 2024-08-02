## MemoryQueue

A persistent First In First Out queue.

### Design

The Memory Queue is designed to be scalable, simple and efficient.
It's implemented as a single linked list with a count variable and two extra pointers to store the addresses for the head and tail.
New elements are added at the tail and old elements are removed from the head.
This design allows for `O(1)` time complexity in the worst case for all operations.
New elements are immediately serialized and added to stable memory, ensuring that the queue is persistent across canister upgrades.
Removed elements have their memory blocks marked as deallocated and are reused when new elements are added.

Each node in the linked list stores a value, the size of that value and the next node's pointer.
The size requires 4 bytes and the pointer requires 8 bytes, resulting in 12 bytes memory overhead for each element.

### Memory Layout

The Memory Queue uses a single region to store all its data.
The region has a header, followed by the nodes data in the queue.

64 bytes is reserved for the header.

- Header Section

| Field          | Offset | Size (In bytes) | Type  | Description                     |
| -------------- | ------ | --------------- | ----- | ------------------------------- |
| MAGIC          | 0      | 3               | Blob  | Magic number                    |
| LAYOUT VERSION | 3      | 1               | Nat8  | Layout version                  |
| COUNT          | 4      | 8               | Nat64 | Number of elements in the queue |
| HEAD           | 12     | 8               | Nat64 | First node in the linked list   |
| TAIL           | 20     | 8               | Nat64 | Last node in the linked list    |
| RESERVED       | 28     | 47              | -     | Extra space for future use      |

- Node Section

After the reserved header space, a sequence of nodes with the data of the queue is stored.
This is the memory layout of each node:

| Field | Offset | Size (In bytes) | Type  | Description              |
| ----- | ------ | --------------- | ----- | ------------------------ |
| NEXT  | 0      | 8               | Nat64 | Pointer to the next node |
| SIZE  | 8      | 4               | Nat32 | Size of the value        |
| VALUE | 12     | \|SIZE\|        | Blob  | The serialized value     |

### Usage Example

```motoko
    import MemoryQueue "mo:memory-collection/MemoryQueue";
    import TypeUtils "mo:memory-collection/TypeUtils";

    stable var sstore = MemoryQueue.newStableStore<Nat>();
    sstore := MemoryQueue.upgrade(sstore);

    let queue = MemoryQueue.new<Nat>(sstore, TypeUtils.Nat);

    for (i in Iter.range(1, 10)) {
        queue.add(i);
    };

    assert queue.size() == 10;

    var i = 1;
    while (queue.size() > 0) {
        let ?n = queue.pop();
        assert n == i;
        i += 1;
    };
```

### Benchmarks

Benchmarking the performance with 10k calls

Instructions

|        | MemoryQueue |
| :----- | ----------: |
| add()  |  54_112_857 |
| vals() |  37_068_706 |
| pop()  |  74_438_819 |

Heap

|        | MemoryQueue |
| :----- | ----------: |
| add()  |     762_280 |
| vals() |   1_608_792 |
| pop()  |   2_168_580 |
