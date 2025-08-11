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

|                |      B+Tree | MemoryBTree |
| :------------- | ----------: | ----------: |
| getFromIndex() |  59_607_820 | 398_814_699 |
| getIndex()     | 151_145_137 | 949_385_002 |
| getFloor()     |  75_126_655 | 348_155_017 |
| getCeiling()   |  75_127_180 | 348_155_497 |
| removeMin()    | 132_330_032 | 839_357_562 |
| removeMax()    | 104_270_924 | 787_496_068 |


**Heap**

|                |     B+Tree | MemoryBTree |
| :------------- | ---------: | ----------: |
| getFromIndex() | 322.33 KiB |    3.52 MiB |
| getIndex()     | 584.76 KiB |    8.97 MiB |
| getFloor()     | 213.27 KiB |     -23 MiB |
| getCeiling()   | 213.27 KiB |    7.41 MiB |
| removeMin()    | 212.86 KiB |   -2.69 MiB |
| removeMax()    | 206.89 KiB |   12.03 MiB |


**Garbage Collection**

|                | B+Tree | MemoryBTree |
| :------------- | -----: | ----------: |
| getFromIndex() |    0 B |         0 B |
| getIndex()     |    0 B |         0 B |
| getFloor()     |    0 B |    30.4 MiB |
| getCeiling()   |    0 B |         0 B |
| removeMin()    |    0 B |   28.65 MiB |
| removeMax()    |    0 B |         0 B |


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

|                                 |    insert() |       get() |   replace() |  entries() |    remove() |
| :------------------------------ | ----------: | ----------: | ----------: | ---------: | ----------: |
| Memory B+Tree - Text (#BlobCmp) | 322_960_389 | 267_908_532 | 293_734_338 | 41_143_451 | 371_394_498 |
| Memory B+Tree - Text (#GenCmp)  | 446_607_236 | 389_244_625 | 415_070_427 | 41_144_107 | 479_295_627 |
| Memory B+Tree - Nat (#BlobCmp)  | 343_618_573 | 294_007_663 | 329_138_629 | 74_509_800 | 404_150_531 |
| Memory B+Tree - Nat (#GenCmp)   | 637_554_900 | 579_089_982 | 614_220_788 | 74_510_433 | 658_021_171 |


**Heap**

|                                 |  insert() |      get() | replace() | entries() |  remove() |
| :------------------------------ | --------: | ---------: | --------: | --------: | --------: |
| Memory B+Tree - Text (#BlobCmp) |  7.64 MiB | -26.58 MiB |  4.31 MiB |  1.31 MiB |  9.57 MiB |
| Memory B+Tree - Text (#GenCmp)  | 10.81 MiB | -21.44 MiB |  7.39 MiB |  1.31 MiB |  12.3 MiB |
| Memory B+Tree - Nat (#BlobCmp)  |   -22 MiB |   4.86 MiB |  5.89 MiB |   2.3 MiB | 10.42 MiB |
| Memory B+Tree - Nat (#GenCmp)   | -9.37 MiB | -15.52 MiB | 16.16 MiB |   2.3 MiB | -9.05 MiB |


**Garbage Collection**

|                                 |  insert() |     get() | replace() | entries() | remove() |
| :------------------------------ | --------: | --------: | --------: | --------: | -------: |
| Memory B+Tree - Text (#BlobCmp) |       0 B | 30.65 MiB |       0 B |       0 B |      0 B |
| Memory B+Tree - Text (#GenCmp)  |       0 B |  28.6 MiB |       0 B |       0 B |      0 B |
| Memory B+Tree - Nat (#BlobCmp)  | 30.65 MiB |       0 B |       0 B |       0 B |      0 B |
| Memory B+Tree - Nat (#GenCmp)   |  28.6 MiB | 30.65 MiB |       0 B |       0 B | 28.6 MiB |


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
| RBTree                   | 153_973_116 |  75_971_287 | 156_113_188 | 23_004_083 | 179_785_016 |
| BTree                    | 139_434_587 | 110_598_701 | 118_295_406 | 11_985_168 | 159_704_852 |
| B+Tree                   | 192_575_989 | 107_046_645 | 113_296_325 |  3_780_054 | 203_112_458 |
| Memory B+Tree (#BlobCmp) | 321_372_389 | 267_703_044 | 580_589_579 | 41_430_940 | 527_853_851 |
| Memory B+Tree (#GenCmp)  | 445_864_676 | 390_071_598 | 702_957_810 | 41_431_435 | 636_951_582 |


**Heap**

|                          |   insert() |      get() |  replace() |  entries() |   remove() |
| :----------------------- | ---------: | ---------: | ---------: | ---------: | ---------: |
| RBTree                   |   8.61 MiB |   9.83 KiB |   7.87 MiB |    1.8 MiB |  -17.3 MiB |
| BTree                    |   1.17 MiB | 471.22 KiB |    1.1 MiB | 589.23 KiB |   1.87 MiB |
| B+Tree                   | 671.09 KiB | 205.14 KiB | 595.77 KiB |   9.95 KiB | 205.15 KiB |
| Memory B+Tree (#BlobCmp) |   7.59 MiB |   4.08 MiB | -18.82 MiB |    1.3 MiB |  10.08 MiB |
| Memory B+Tree (#GenCmp)  |  10.76 MiB | -22.38 MiB |  11.61 MiB |    1.3 MiB | -14.67 MiB |


**Garbage Collection**

|                          | insert() |     get() | replace() | entries() |  remove() |
| :----------------------- | -------: | --------: | --------: | --------: | --------: |
| RBTree                   |      0 B |       0 B |       0 B |       0 B | 29.54 MiB |
| BTree                    |      0 B |       0 B |       0 B |       0 B |       0 B |
| B+Tree                   |      0 B |       0 B |       0 B |       0 B |       0 B |
| Memory B+Tree (#BlobCmp) |      0 B |       0 B | 27.35 MiB |       0 B |       0 B |
| Memory B+Tree (#GenCmp)  |      0 B | 29.54 MiB |       0 B |       0 B | 27.48 MiB |


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
| B+Tree               | 142_892_559 | 115_702_020 | 124_241_724 |  3_867_883 | 148_834_106 |
| Memory B+Tree (4)    | 562_743_962 | 437_654_474 | 881_854_870 | 43_768_724 | 894_163_017 |
| Memory B+Tree (32)   | 356_918_375 | 300_974_882 | 632_623_278 | 41_666_433 | 581_023_329 |
| Memory B+Tree (64)   | 342_464_994 | 294_465_659 | 626_113_055 | 41_505_845 | 558_003_964 |
| Memory B+Tree (128)  | 321_372_126 | 267_692_928 | 580_589_324 | 41_430_987 | 527_923_091 |
| Memory B+Tree (256)  | 323_817_170 | 266_593_303 | 579_489_859 | 41_393_103 | 526_776_629 |
| Memory B+Tree (512)  | 334_561_799 | 265_753_157 | 578_649_553 | 41_373_683 | 532_309_242 |
| Memory B+Tree (1024) | 357_541_677 | 264_720_441 | 577_616_837 | 41_367_723 | 549_476_014 |
| Memory B+Tree (2048) | 404_700_732 | 262_795_135 | 575_691_531 | 41_372_643 | 589_345_033 |
| Memory B+Tree (4096) | 489_632_678 | 259_095_808 | 571_992_204 | 41_390_825 | 670_065_891 |


**Heap**

|                      |   insert() |      get() |  replace() |  entries() |   remove() |
| :------------------- | ---------: | ---------: | ---------: | ---------: | ---------: |
| B+Tree               | 716.93 KiB | 205.14 KiB | 595.77 KiB |   9.95 KiB | 205.15 KiB |
| Memory B+Tree (4)    |   5.49 MiB |   5.76 MiB |  10.21 MiB |    1.3 MiB | -20.31 MiB |
| Memory B+Tree (32)   |    5.3 MiB |   4.46 MiB |   8.91 MiB |    1.3 MiB | -19.31 MiB |
| Memory B+Tree (64)   |   6.03 MiB |   4.36 MiB |   8.81 MiB |    1.3 MiB | -20.75 MiB |
| Memory B+Tree (128)  |   7.59 MiB |   4.08 MiB |   8.53 MiB | -25.98 MiB |  10.08 MiB |
| Memory B+Tree (256)  |  11.01 MiB |   4.06 MiB | -20.94 MiB |    1.3 MiB |  12.98 MiB |
| Memory B+Tree (512)  |  -9.78 MiB |   4.05 MiB |    8.5 MiB |    1.3 MiB | -10.94 MiB |
| Memory B+Tree (1024) |   3.04 MiB |   4.04 MiB |   8.48 MiB | -28.03 MiB |   2.04 MiB |
| Memory B+Tree (2048) |  -2.65 MiB |   4.01 MiB |   8.45 MiB |    1.3 MiB |  -7.53 MiB |
| Memory B+Tree (4096) |   8.21 MiB |   3.95 MiB |   8.39 MiB |    1.3 MiB | -27.89 MiB |


**Garbage Collection**

|                      |  insert() | get() | replace() | entries() |   remove() |
| :------------------- | --------: | ----: | --------: | --------: | ---------: |
| B+Tree               |       0 B |   0 B |       0 B |       0 B |        0 B |
| Memory B+Tree (4)    |       0 B |   0 B |       0 B |       0 B |  29.53 MiB |
| Memory B+Tree (32)   |       0 B |   0 B |       0 B |       0 B |  27.47 MiB |
| Memory B+Tree (64)   |       0 B |   0 B |       0 B |       0 B |  29.53 MiB |
| Memory B+Tree (128)  |       0 B |   0 B |       0 B | 27.28 MiB |        0 B |
| Memory B+Tree (256)  |       0 B |   0 B | 29.45 MiB |       0 B |        0 B |
| Memory B+Tree (512)  | 27.47 MiB |   0 B |       0 B |       0 B |  29.52 MiB |
| Memory B+Tree (1024) | 27.47 MiB |   0 B |       0 B | 29.33 MiB |  27.47 MiB |
| Memory B+Tree (2048) | 58.16 MiB |   0 B |       0 B |       0 B |  59.47 MiB |
| Memory B+Tree (4096) | 91.42 MiB |   0 B |       0 B |       0 B | 123.45 MiB |


</details>
Saving results to .bench/MemoryBTree.node-capacity.bench.json
No previous results found "/home/runner/work/memory-collection/memory-collection/.bench/MemoryBuffer.Blob.bench.json"

<details>

<summary>bench/MemoryBuffer/MemoryBuffer.Blob.bench.mo $({\color{gray}0\%})$</summary>

### Buffer vs MemoryBuffer

_Benchmarking the performance with 10k entries_


Instructions: ${\color{gray}0\\%}$
Heap: ${\color{gray}0\\%}$
Stable Memory: ${\color{gray}0\\%}$
Garbage Collection: ${\color{gray}0\\%}$


**Instructions**

|                         |        Buffer | MemoryBuffer |
| :---------------------- | ------------: | -----------: |
| add()                   |     4_381_897 |   31_547_415 |
| get()                   |     2_342_477 |   14_059_475 |
| put() (new == prev)     |     3_673_233 |   18_382_388 |
| put() (new > prev)      |     3_943_916 |  329_160_259 |
| put() (new < prev)      |     3_944_601 |  279_886_783 |
| add() reallocation      |     7_908_427 |  376_844_413 |
| removeLast()            |     4_037_158 |  144_939_196 |
| reverse()               |     3_114_880 |    9_398_189 |
| remove()                | 3_321_770_389 |  629_288_800 |
| insert()                | 2_826_839_860 |  444_302_099 |
| shuffle()               |         5_890 |  211_272_085 |
| sortUnstable() #GenCmp  |   108_327_982 |  704_705_336 |
| shuffle()               |         5_890 |  211_272_085 |
| sortUnstable() #BlobCmp |         6_101 |  662_425_806 |


**Heap**

|                         |     Buffer | MemoryBuffer |
| :---------------------- | ---------: | -----------: |
| add()                   |   9.83 KiB |     9.93 KiB |
| get()                   |   9.83 KiB |   508.45 KiB |
| put() (new == prev)     |   9.83 KiB |     9.84 KiB |
| put() (new > prev)      |   9.84 KiB |     4.04 MiB |
| put() (new < prev)      |   9.84 KiB |     2.45 MiB |
| add() reallocation      | 156.34 KiB |     8.13 MiB |
| removeLast()            |   9.83 KiB |      1.6 MiB |
| reverse()               |   9.78 KiB |   244.21 KiB |
| remove()                |  97.89 KiB |   -26.04 MiB |
| insert()                |  152.3 KiB |     2.77 MiB |
| shuffle()               |   9.78 KiB |     7.52 MiB |
| sortUnstable() #GenCmp  |   2.41 MiB |    -6.91 MiB |
| shuffle()               |   9.78 KiB |     7.52 MiB |
| sortUnstable() #BlobCmp |   9.78 KiB |    -4.68 MiB |


**Garbage Collection**

|                         | Buffer | MemoryBuffer |
| :---------------------- | -----: | -----------: |
| add()                   |    0 B |          0 B |
| get()                   |    0 B |          0 B |
| put() (new == prev)     |    0 B |          0 B |
| put() (new > prev)      |    0 B |          0 B |
| put() (new < prev)      |    0 B |          0 B |
| add() reallocation      |    0 B |          0 B |
| removeLast()            |    0 B |          0 B |
| reverse()               |    0 B |          0 B |
| remove()                |    0 B |   219.41 MiB |
| insert()                |    0 B |   187.42 MiB |
| shuffle()               |    0 B |          0 B |
| sortUnstable() #GenCmp  |    0 B |    29.69 MiB |
| shuffle()               |    0 B |          0 B |
| sortUnstable() #BlobCmp |    0 B |    27.64 MiB |


</details>
Saving results to .bench/MemoryBuffer.Blob.bench.json
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
| add()              |  35_564_828 |
| vals()             |  40_563_845 |
| pop()              |  77_153_578 |
| random add()/pop() | 177_121_291 |


**Heap**

|                    | MemoryQueue |
| :----------------- | ----------: |
| add()              |    1.04 MiB |
| vals()             |    1.34 MiB |
| pop()              |    2.07 MiB |
| random add()/pop() |    5.69 MiB |


**Garbage Collection**

|                    | MemoryQueue |
| :----------------- | ----------: |
| add()              |         0 B |
| vals()             |         0 B |
| pop()              |         0 B |
| random add()/pop() |         0 B |


</details>
Saving results to .bench/MemoryQueue.bench.json
