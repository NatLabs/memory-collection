# Benchmark Results


No previous results found "/home/runner/work/memory-collection/memory-collection/.bench/BTree-specific-fns.bench.json"

<details>

<summary>bench/MemoryBTree/BTree-specific-fns.bench.mo $({\color{gray}0\%})$</summary>

### Comparing B+Tree and MemoryBTree

_Benchmarking the performance with 10k entries_


Instructions: ${\color{gray}0\\%}$
Heap: ${\color{gray}0\\%}$
Stable Memory: ${\color{gray}0\\%}$
Garbage Collection: ${\color{gray}0\\%}$


**Instructions**

|                |      B+Tree |   MemoryBTree |
| :------------- | ----------: | ------------: |
| getFromIndex() |  69_684_956 |   482_626_750 |
| getIndex()     | 169_709_535 | 1_329_581_840 |
| getFloor()     |  80_555_899 |   850_293_968 |
| getCeiling()   |  80_556_480 |   850_294_670 |
| removeMin()    | 152_560_478 | 1_281_904_877 |
| removeMax()    | 116_475_111 | 1_233_979_567 |


**Heap**

|                |     B+Tree | MemoryBTree |
| :------------- | ---------: | ----------: |
| getFromIndex() | 322.33 KiB |    7.94 MiB |
| getIndex()     | 574.09 KiB |   -7.64 MiB |
| getFloor()     | 209.88 KiB |    -2.3 MiB |
| getCeiling()   | 209.88 KiB |   -4.36 MiB |
| removeMin()    | 209.93 KiB |   -14.7 MiB |
| removeMax()    | 206.11 KiB |    1.13 MiB |


**Garbage Collection**

|                | B+Tree | MemoryBTree |
| :------------- | -----: | ----------: |
| getFromIndex() |    0 B |         0 B |
| getIndex()     |    0 B |    30.4 MiB |
| getFloor()     |    0 B |   28.35 MiB |
| getCeiling()   |    0 B |    30.4 MiB |
| removeMin()    |    0 B |   60.65 MiB |
| removeMax()    |    0 B |      31 MiB |


</details>
Saving results to .bench/BTree-specific-fns.bench.json
No previous results found "/home/runner/work/memory-collection/memory-collection/.bench/BTree.Types.bench.json"

<details>

<summary>bench/MemoryBTree/BTree.Types.bench.mo $({\color{gray}0\%})$</summary>

### Comparing B+Tree and Memory B+Tree with different serialization formats and comparison functions

_Benchmarking the performance with 10k entries_


Instructions: ${\color{gray}0\\%}$
Heap: ${\color{gray}0\\%}$
Stable Memory: ${\color{gray}0\\%}$
Garbage Collection: ${\color{gray}0\\%}$


**Instructions**

|                                        |    insert() |       get() |   replace() |  entries() |    remove() |
| :------------------------------------- | ----------: | ----------: | ----------: | ---------: | ----------: |
| Memory B+Tree - Text (#BlobCmp)        | 340_553_734 | 283_371_672 | 310_427_643 | 44_269_150 | 388_600_488 |
| Memory B+Tree - Text (#GenCmp)         | 471_665_966 | 412_317_400 | 439_373_574 | 44_269_698 | 503_449_852 |
| Memory B+Tree - Candid Text (#BlobCmp) | 393_428_526 | 338_103_186 | 373_277_963 | 66_590_300 | 439_386_328 |
| Memory B+Tree - Candid Text (#GenCmp)  | 642_763_811 | 581_778_370 | 616_953_535 | 66_591_224 | 656_232_202 |
| Memory B+Tree - Nat (#BlobCmp)         | 404_911_029 | 324_166_738 | 385_779_023 | 71_359_620 | 436_602_592 |
| Memory B+Tree - Nat (#GenCmp)          | 668_549_491 | 579_556_392 | 641_168_677 | 71_360_336 | 663_698_914 |
| Memory B+Tree - Candid Nat (#GenCmp)   | 530_594_065 | 460_528_529 | 499_270_144 | 58_252_928 | 554_617_701 |


**Heap**

|                                        |   insert() |      get() | replace() |  entries() |  remove() |
| :------------------------------------- | ---------: | ---------: | --------: | ---------: | --------: |
| Memory B+Tree - Text (#BlobCmp)        |   7.62 MiB |   4.08 MiB |  4.31 MiB | -29.34 MiB |  9.19 MiB |
| Memory B+Tree - Text (#GenCmp)         |   10.8 MiB |   7.17 MiB | -21.2 MiB |   1.31 MiB | 11.93 MiB |
| Memory B+Tree - Candid Text (#BlobCmp) |   9.67 MiB | -24.85 MiB |  6.52 MiB |   1.69 MiB | 10.79 MiB |
| Memory B+Tree - Candid Text (#GenCmp)  | -14.16 MiB |  10.42 MiB | -19.5 MiB |   1.69 MiB |  14.9 MiB |
| Memory B+Tree - Nat (#BlobCmp)         |   8.49 MiB | -23.87 MiB |  5.93 MiB |   2.68 MiB |  9.96 MiB |
| Memory B+Tree - Nat (#GenCmp)          |  -8.32 MiB | -10.45 MiB | 19.36 MiB |   2.68 MiB | -8.76 MiB |
| Memory B+Tree - Candid Nat (#GenCmp)   |   9.86 MiB | -22.74 MiB |  6.43 MiB |   1.08 MiB |  10.8 MiB |


**Garbage Collection**

|                                        |  insert() |     get() | replace() | entries() |  remove() |
| :------------------------------------- | --------: | --------: | --------: | --------: | --------: |
| Memory B+Tree - Text (#BlobCmp)        |       0 B |       0 B |       0 B | 30.65 MiB |       0 B |
| Memory B+Tree - Text (#GenCmp)         |       0 B |       0 B |  28.6 MiB |       0 B |       0 B |
| Memory B+Tree - Candid Text (#BlobCmp) |       0 B | 30.65 MiB |       0 B |       0 B |       0 B |
| Memory B+Tree - Candid Text (#GenCmp)  |  28.6 MiB |       0 B | 30.65 MiB |       0 B |       0 B |
| Memory B+Tree - Nat (#BlobCmp)         |       0 B |  28.6 MiB |       0 B |       0 B |       0 B |
| Memory B+Tree - Nat (#GenCmp)          | 30.65 MiB |  28.6 MiB |       0 B |       0 B | 30.65 MiB |
| Memory B+Tree - Candid Nat (#GenCmp)   |       0 B |  28.6 MiB |       0 B |       0 B |       0 B |


</details>
Saving results to .bench/BTree.Types.bench.json
No previous results found "/home/runner/work/memory-collection/memory-collection/.bench/MemoryBTree.bench.json"

<details>

<summary>bench/MemoryBTree/MemoryBTree.bench.mo $({\color{gray}0\%})$</summary>

### Comparing RBTree, BTree and B+Tree (BpTree)

_Benchmarking the performance with 10k entries_


Instructions: ${\color{gray}0\\%}$
Heap: ${\color{gray}0\\%}$
Stable Memory: ${\color{gray}0\\%}$
Garbage Collection: ${\color{gray}0\\%}$


**Instructions**

|                          |    insert() |       get() |   replace() |  entries() |    remove() |
| :----------------------- | ----------: | ----------: | ----------: | ---------: | ----------: |
| RBTree                   | 168_972_309 |  81_389_785 | 171_199_309 | 25_794_620 | 201_655_302 |
| BTree                    | 151_552_130 | 116_844_590 | 125_520_406 | 13_308_229 | 174_916_733 |
| B+Tree                   | 212_222_118 | 113_439_170 | 121_758_826 |  4_731_437 | 229_355_394 |
| Memory B+Tree (#BlobCmp) | 340_207_768 | 284_272_612 | 462_699_978 | 44_552_755 | 491_377_873 |
| Memory B+Tree (#GenCmp)  | 471_273_825 | 413_341_367 | 591_768_936 | 44_553_315 | 606_317_600 |


**Heap**

|                          |   insert() |      get() |  replace() |  entries() |   remove() |
| :----------------------- | ---------: | ---------: | ---------: | ---------: | ---------: |
| RBTree                   |   8.59 MiB |   9.83 KiB |   7.88 MiB |    1.8 MiB | -17.34 MiB |
| BTree                    |   1.17 MiB | 471.32 KiB |    1.1 MiB | 589.28 KiB |   1.87 MiB |
| B+Tree                   | 667.32 KiB | 205.14 KiB | 595.77 KiB |   9.95 KiB | 205.15 KiB |
| Memory B+Tree (#BlobCmp) |   7.58 MiB | -23.43 MiB |   6.26 MiB |    1.3 MiB |   9.55 MiB |
| Memory B+Tree (#GenCmp)  | -18.82 MiB |   7.17 MiB |   9.35 MiB |    1.3 MiB | -15.22 MiB |


**Garbage Collection**

|                          |  insert() |     get() | replace() | entries() |  remove() |
| :----------------------- | --------: | --------: | --------: | --------: | --------: |
| RBTree                   |       0 B |       0 B |       0 B |       0 B | 29.57 MiB |
| BTree                    |       0 B |       0 B |       0 B |       0 B |       0 B |
| B+Tree                   |       0 B |       0 B |       0 B |       0 B |       0 B |
| Memory B+Tree (#BlobCmp) |       0 B | 27.51 MiB |       0 B |       0 B |       0 B |
| Memory B+Tree (#GenCmp)  | 29.57 MiB |       0 B |       0 B |       0 B | 27.51 MiB |


</details>
Saving results to .bench/MemoryBTree.bench.json
No previous results found "/home/runner/work/memory-collection/memory-collection/.bench/MemoryBTree.node-capacity.bench.json"

<details>

<summary>bench/MemoryBTree/MemoryBTree.node-capacity.bench.mo $({\color{gray}0\%})$</summary>

### Comparing the Memory B+Tree with different node capacities

_Benchmarking the performance with 10k entries_


Instructions: ${\color{gray}0\\%}$
Heap: ${\color{gray}0\\%}$
Stable Memory: ${\color{gray}0\\%}$
Garbage Collection: ${\color{gray}0\\%}$


**Instructions**

|                      |    insert() |       get() |   replace() |  entries() |    remove() |
| :------------------- | ----------: | ----------: | ----------: | ---------: | ----------: |
| B+Tree               | 155_999_431 | 122_576_904 | 134_466_591 |  4_855_863 | 165_391_358 |
| Memory B+Tree (4)    | 600_104_884 | 464_226_677 | 782_639_471 | 47_141_981 | 856_559_537 |
| Memory B+Tree (32)   | 379_146_429 | 319_296_905 | 517_716_708 | 44_814_922 | 546_577_139 |
| Memory B+Tree (64)   | 363_805_868 | 312_018_439 | 510_437_039 | 44_641_455 | 524_042_617 |
| Memory B+Tree (128)  | 340_207_487 | 284_272_290 | 462_699_890 | 44_552_636 | 491_377_988 |
| Memory B+Tree (256)  | 342_939_995 | 282_907_907 | 461_335_701 | 44_514_926 | 489_068_755 |
| Memory B+Tree (512)  | 353_058_549 | 281_746_018 | 460_173_618 | 44_495_004 | 495_420_095 |
| Memory B+Tree (1024) | 376_127_201 | 280_607_114 | 459_034_714 | 44_487_911 | 513_293_696 |
| Memory B+Tree (2048) | 422_570_994 | 278_488_380 | 456_915_980 | 44_493_148 | 551_197_596 |
| Memory B+Tree (4096) | 505_119_194 | 274_792_471 | 453_220_265 | 44_509_763 | 629_828_577 |


**Heap**

|                      |   insert() |      get() |  replace() | entries() |    remove() |
| :------------------- | ---------: | ---------: | ---------: | --------: | ----------: |
| B+Tree               | 716.43 KiB | 205.14 KiB | 595.77 KiB |  9.95 KiB |  205.15 KiB |
| Memory B+Tree (4)    |   5.51 MiB |   5.74 MiB | -21.49 MiB |   1.3 MiB |    8.46 MiB |
| Memory B+Tree (32)   |    5.3 MiB |   4.46 MiB | -20.69 MiB |   1.3 MiB |    7.58 MiB |
| Memory B+Tree (64)   |   6.05 MiB |   4.36 MiB |   6.53 MiB |   1.3 MiB |   -21.3 MiB |
| Memory B+Tree (128)  |   7.58 MiB |   4.09 MiB |   6.26 MiB |   1.3 MiB |  -17.95 MiB |
| Memory B+Tree (256)  |  10.97 MiB |   4.07 MiB | -23.12 MiB |   1.3 MiB |   12.42 MiB |
| Memory B+Tree (512)  |  -9.99 MiB |   4.05 MiB |   6.22 MiB |   1.3 MiB |  -11.51 MiB |
| Memory B+Tree (1024) |   3.03 MiB |   4.03 MiB |   6.21 MiB |   1.3 MiB | -102.26 KiB |
| Memory B+Tree (2048) |   -4.2 MiB |      4 MiB |   6.18 MiB |   1.3 MiB |    -8.3 MiB |
| Memory B+Tree (4096) |   6.99 MiB |   3.94 MiB | -23.41 MiB |   1.3 MiB |    2.62 MiB |


**Garbage Collection**

|                      |  insert() | get() | replace() | entries() |  remove() |
| :------------------- | --------: | ----: | --------: | --------: | --------: |
| B+Tree               |       0 B |   0 B |       0 B |       0 B |       0 B |
| Memory B+Tree (4)    |       0 B |   0 B | 29.41 MiB |       0 B |       0 B |
| Memory B+Tree (32)   |       0 B |   0 B | 27.33 MiB |       0 B |       0 B |
| Memory B+Tree (64)   |       0 B |   0 B |       0 B |       0 B | 29.56 MiB |
| Memory B+Tree (128)  |       0 B |   0 B |       0 B |       0 B |  27.5 MiB |
| Memory B+Tree (256)  |       0 B |   0 B | 29.36 MiB |       0 B |       0 B |
| Memory B+Tree (512)  |  27.5 MiB |   0 B |       0 B |       0 B | 29.56 MiB |
| Memory B+Tree (1024) |  27.5 MiB |   0 B |       0 B |       0 B | 29.56 MiB |
| Memory B+Tree (2048) |  59.5 MiB |   0 B |       0 B |       0 B |  59.5 MiB |
| Memory B+Tree (4096) | 91.46 MiB |   0 B | 29.53 MiB |       0 B | 91.48 MiB |


</details>
Saving results to .bench/MemoryBTree.node-capacity.bench.json
No previous results found "/home/runner/work/memory-collection/memory-collection/.bench/MemoryQueue.bench.json"

<details>

<summary>bench/MemoryQueue/MemoryQueue.bench.mo $({\color{gray}0\%})$</summary>

### Benchmarking the MemoryQueue

_Benchmarking the performance with 10k calls_


Instructions: ${\color{gray}0\\%}$
Heap: ${\color{gray}0\\%}$
Stable Memory: ${\color{gray}0\\%}$
Garbage Collection: ${\color{gray}0\\%}$


**Instructions**

|                    | MemoryQueue |
| :----------------- | ----------: |
| add()              |  52_747_763 |
| vals()             |  40_974_696 |
| pop()              |  78_133_980 |
| random add()/pop() | 384_133_884 |


**Heap**

|                    | MemoryQueue |
| :----------------- | ----------: |
| add()              |  745.66 KiB |
| vals()             |    1.54 MiB |
| pop()              |    2.07 MiB |
| random add()/pop() |  -17.78 MiB |


**Garbage Collection**

|                    | MemoryQueue |
| :----------------- | ----------: |
| add()              |         0 B |
| vals()             |         0 B |
| pop()              |         0 B |
| random add()/pop() |   29.91 MiB |


</details>
Saving results to .bench/MemoryQueue.bench.json
