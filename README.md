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
| getFromIndex() |  69_204_872 |   429_536_233 |
| getIndex()     | 168_348_367 | 3_381_652_971 |
| getFloor()     |  80_759_279 |   820_213_638 |
| getCeiling()   |  80_759_860 |   820_214_357 |
| removeMin()    | 152_231_332 | 1_219_739_688 |
| removeMax()    | 116_853_990 | 1_153_536_386 |


**Heap**

|                |     B+Tree | MemoryBTree |
| :------------- | ---------: | ----------: |
| getFromIndex() | 322.33 KiB |    3.52 MiB |
| getIndex()     | 584.84 KiB |    8.82 MiB |
| getFloor()     | 213.27 KiB |   -5.63 MiB |
| getCeiling()   | 213.27 KiB |   -3.58 MiB |
| removeMin()    | 212.86 KiB |  -17.58 MiB |
| removeMax()    | 206.89 KiB |   -3.05 MiB |


**Garbage Collection**

|                | B+Tree | MemoryBTree |
| :------------- | -----: | ----------: |
| getFromIndex() |    0 B |         0 B |
| getIndex()     |    0 B |   92.35 MiB |
| getFloor()     |    0 B |    30.4 MiB |
| getCeiling()   |    0 B |   28.35 MiB |
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
| Memory B+Tree - Text (#BlobCmp)        | 341_532_103 | 283_063_602 | 310_119_379 | 44_273_064 | 388_584_302 |
| Memory B+Tree - Text (#GenCmp)         | 472_625_303 | 411_836_327 | 438_892_095 | 44_273_806 | 503_090_703 |
| Memory B+Tree - Candid Text (#BlobCmp) | 643_699_895 | 581_088_594 | 616_263_768 | 66_594_408 | 655_470_369 |
| Memory B+Tree - Candid Text (#GenCmp)  | 643_700_819 | 581_089_518 | 616_264_489 | 66_595_332 | 655_471_496 |
| Memory B+Tree - Nat (#BlobCmp)         | 701_561_350 | 639_332_272 | 677_403_445 | 83_098_994 | 716_305_985 |
| Memory B+Tree - Nat (#GenCmp)          | 701_562_067 | 639_333_190 | 677_403_959 | 83_099_710 | 716_306_894 |
| Memory B+Tree - Candid Nat (#GenCmp)   | 530_705_997 | 460_282_390 | 499_019_265 | 58_245_578 | 555_657_484 |


**Heap**

|                                        |   insert() |      get() |  replace() | entries() |   remove() |
| :------------------------------------- | ---------: | ---------: | ---------: | --------: | ---------: |
| Memory B+Tree - Text (#BlobCmp)        |   7.64 MiB | -26.57 MiB |   4.31 MiB |  1.31 MiB |   9.18 MiB |
| Memory B+Tree - Text (#GenCmp)         |  10.81 MiB | -21.44 MiB |   7.39 MiB |  1.31 MiB |  11.91 MiB |
| Memory B+Tree - Candid Text (#BlobCmp) |  -16.2 MiB |  10.41 MiB | -17.46 MiB |  1.69 MiB |  14.88 MiB |
| Memory B+Tree - Candid Text (#GenCmp)  |  -16.2 MiB |  10.41 MiB |  11.13 MiB |  1.69 MiB | -13.72 MiB |
| Memory B+Tree - Nat (#BlobCmp)         | -11.42 MiB |  15.13 MiB | -12.44 MiB |   2.3 MiB |  19.17 MiB |
| Memory B+Tree - Nat (#GenCmp)          | -11.42 MiB | -13.47 MiB |  16.16 MiB |   2.3 MiB | -11.48 MiB |
| Memory B+Tree - Candid Nat (#GenCmp)   |   9.86 MiB |   5.85 MiB | -22.17 MiB |  1.08 MiB |   10.8 MiB |


**Garbage Collection**

|                                        |  insert() |     get() | replace() | entries() |  remove() |
| :------------------------------------- | --------: | --------: | --------: | --------: | --------: |
| Memory B+Tree - Text (#BlobCmp)        |       0 B | 30.65 MiB |       0 B |       0 B |       0 B |
| Memory B+Tree - Text (#GenCmp)         |       0 B |  28.6 MiB |       0 B |       0 B |       0 B |
| Memory B+Tree - Candid Text (#BlobCmp) | 30.65 MiB |       0 B |  28.6 MiB |       0 B |       0 B |
| Memory B+Tree - Candid Text (#GenCmp)  | 30.65 MiB |       0 B |       0 B |       0 B |  28.6 MiB |
| Memory B+Tree - Nat (#BlobCmp)         | 30.65 MiB |       0 B |  28.6 MiB |       0 B |       0 B |
| Memory B+Tree - Nat (#GenCmp)          | 30.65 MiB |  28.6 MiB |       0 B |       0 B | 30.65 MiB |
| Memory B+Tree - Candid Nat (#GenCmp)   |       0 B |       0 B |  28.6 MiB |       0 B |       0 B |


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
| RBTree                   | 169_261_030 |  81_369_099 | 171_125_213 | 25_794_620 | 201_528_439 |
| BTree                    | 151_676_684 | 117_563_182 | 126_237_790 | 13_308_508 | 174_641_688 |
| B+Tree                   | 212_639_986 | 113_278_846 | 121_598_502 |  4_733_565 | 227_772_087 |
| Memory B+Tree (#BlobCmp) | 340_885_058 | 283_949_075 | 462_111_636 | 44_561_924 | 489_152_679 |
| Memory B+Tree (#GenCmp)  | 471_847_441 | 412_807_553 | 590_969_717 | 44_562_484 | 604_026_788 |


**Heap**

|                          |   insert() |      get() |  replace() |  entries() |   remove() |
| :----------------------- | ---------: | ---------: | ---------: | ---------: | ---------: |
| RBTree                   |   8.61 MiB |   9.83 KiB |   7.87 MiB |    1.8 MiB |  -17.3 MiB |
| BTree                    |   1.17 MiB | 471.22 KiB |    1.1 MiB | 589.23 KiB |   1.87 MiB |
| B+Tree                   | 671.09 KiB | 205.14 KiB | 595.77 KiB |   9.95 KiB | 205.15 KiB |
| Memory B+Tree (#BlobCmp) |   7.59 MiB |   4.08 MiB | -21.05 MiB |    1.3 MiB |    9.5 MiB |
| Memory B+Tree (#GenCmp)  |  10.76 MiB | -22.38 MiB |   9.33 MiB |    1.3 MiB |  12.24 MiB |


**Garbage Collection**

|                          | insert() |     get() | replace() | entries() |  remove() |
| :----------------------- | -------: | --------: | --------: | --------: | --------: |
| RBTree                   |      0 B |       0 B |       0 B |       0 B | 29.54 MiB |
| BTree                    |      0 B |       0 B |       0 B |       0 B |       0 B |
| B+Tree                   |      0 B |       0 B |       0 B |       0 B |       0 B |
| Memory B+Tree (#BlobCmp) |      0 B |       0 B |  27.3 MiB |       0 B |       0 B |
| Memory B+Tree (#GenCmp)  |      0 B | 29.54 MiB |       0 B |       0 B |       0 B |


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
| B+Tree               | 155_851_778 | 122_600_623 | 134_490_310 |  4_856_583 | 165_524_860 |
| Memory B+Tree (4)    | 599_069_440 | 465_264_919 | 783_411_308 | 47_134_178 | 853_656_134 |
| Memory B+Tree (32)   | 379_102_547 | 319_344_031 | 517_498_420 | 44_821_075 | 544_377_907 |
| Memory B+Tree (64)   | 363_637_492 | 312_477_804 | 510_631_193 | 44_644_368 | 520_871_077 |
| Memory B+Tree (128)  | 340_884_971 | 283_948_956 | 462_111_345 | 44_561_805 | 489_152_591 |
| Memory B+Tree (256)  | 343_025_328 | 282_785_570 | 460_947_959 | 44_520_173 | 487_830_200 |
| Memory B+Tree (512)  | 353_561_412 | 281_898_234 | 460_060_826 | 44_498_625 | 493_100_713 |
| Memory B+Tree (1024) | 376_292_603 | 280_808_982 | 458_971_168 | 44_491_420 | 509_950_735 |
| Memory B+Tree (2048) | 423_107_442 | 278_776_964 | 456_939_353 | 44_496_001 | 549_394_382 |
| Memory B+Tree (4096) | 507_518_013 | 274_873_488 | 453_035_877 | 44_513_976 | 629_447_885 |


**Heap**

|                      |    insert() |      get() |  replace() | entries() |    remove() |
| :------------------- | ----------: | ---------: | ---------: | --------: | ----------: |
| B+Tree               |  716.93 KiB | 205.14 KiB | 595.77 KiB |  9.95 KiB |  205.15 KiB |
| Memory B+Tree (4)    |    5.51 MiB |   5.76 MiB |   7.93 MiB |   1.3 MiB |  -21.07 MiB |
| Memory B+Tree (32)   |     5.3 MiB |   4.46 MiB |   6.63 MiB |   1.3 MiB |  -19.89 MiB |
| Memory B+Tree (64)   |    6.03 MiB |   4.36 MiB |   6.53 MiB |   1.3 MiB |    8.19 MiB |
| Memory B+Tree (128)  |  -21.93 MiB |   4.08 MiB |   6.25 MiB |   1.3 MiB |     9.5 MiB |
| Memory B+Tree (256)  |  -16.46 MiB |   4.06 MiB |   6.23 MiB |   1.3 MiB |  -17.13 MiB |
| Memory B+Tree (512)  |   17.69 MiB |   4.05 MiB | -21.23 MiB |   1.3 MiB |      18 MiB |
| Memory B+Tree (1024) | 1015.57 KiB | -23.43 MiB |   6.21 MiB |   1.3 MiB | -599.32 KiB |
| Memory B+Tree (2048) |   -3.96 MiB |   4.01 MiB |   6.18 MiB |   1.3 MiB |   -8.09 MiB |
| Memory B+Tree (4096) |     8.2 MiB |   3.95 MiB |   6.12 MiB |   1.3 MiB |  -28.44 MiB |


**Garbage Collection**

|                      |  insert() |     get() | replace() | entries() |   remove() |
| :------------------- | --------: | --------: | --------: | --------: | ---------: |
| B+Tree               |       0 B |       0 B |       0 B |       0 B |        0 B |
| Memory B+Tree (4)    |       0 B |       0 B |       0 B |       0 B |  29.53 MiB |
| Memory B+Tree (32)   |       0 B |       0 B |       0 B |       0 B |  27.47 MiB |
| Memory B+Tree (64)   |       0 B |       0 B |       0 B |       0 B |        0 B |
| Memory B+Tree (128)  | 29.53 MiB |       0 B |       0 B |       0 B |        0 B |
| Memory B+Tree (256)  | 27.47 MiB |       0 B |       0 B |       0 B |  29.53 MiB |
| Memory B+Tree (512)  |       0 B |       0 B | 27.45 MiB |       0 B |        0 B |
| Memory B+Tree (1024) | 29.53 MiB | 27.47 MiB |       0 B |       0 B |  29.53 MiB |
| Memory B+Tree (2048) | 59.47 MiB |       0 B |       0 B |       0 B |  59.46 MiB |
| Memory B+Tree (4096) | 91.43 MiB |       0 B |       0 B |       0 B | 123.43 MiB |


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
| add()              |  40_165_363 |
| vals()             |  45_364_384 |
| pop()              |  82_523_668 |
| random add()/pop() | 169_327_241 |


**Heap**

|                    | MemoryQueue |
| :----------------- | ----------: |
| add()              |    1.04 MiB |
| vals()             |    1.34 MiB |
| pop()              |    1.88 MiB |
| random add()/pop() |    5.14 MiB |


**Garbage Collection**

|                    | MemoryQueue |
| :----------------- | ----------: |
| add()              |         0 B |
| vals()             |         0 B |
| pop()              |         0 B |
| random add()/pop() |         0 B |


</details>
Saving results to .bench/MemoryQueue.bench.json
