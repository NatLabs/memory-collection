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
| getFromIndex() |  59_207_700 | 395_536_054 |
| getIndex()     | 150_534_247 | 943_612_330 |
| getFloor()     |  74_923_415 | 342_500_459 |
| getCeiling()   |  74_923_940 | 342_500_920 |
| removeMin()    | 132_126_987 | 829_600_129 |
| removeMax()    | 104_070_174 | 777_925_132 |


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
| Memory B+Tree - Text (#BlobCmp) | 320_493_499 | 265_454_755 | 291_090_542 | 40_003_051 | 367_007_369 |
| Memory B+Tree - Text (#GenCmp)  | 440_671_871 | 383_429_023 | 409_064_806 | 40_003_707 | 471_924_648 |
| Memory B+Tree - Nat (#BlobCmp)  | 340_574_136 | 290_642_955 | 325_293_921 | 72_129_876 | 398_848_432 |
| Memory B+Tree - Nat (#GenCmp)   | 622_459_746 | 564_019_530 | 598_670_317 | 72_130_509 | 642_300_320 |


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
| RBTree                   | 145_536_496 |  75_971_167 | 148_385_908 | 21_003_883 | 167_811_596 |
| BTree                    | 135_702_349 | 110_008_001 | 116_914_126 | 11_393_648 | 157_585_144 |
| B+Tree                   | 191_961_133 | 106_846_525 | 112_696_205 |  3_779_814 | 202_912_338 |
| Memory B+Tree (#BlobCmp) | 318_907_156 | 265_238_132 | 573_766_586 | 40_290_540 | 522_982_442 |
| Memory B+Tree (#GenCmp)  | 439_934_393 | 384_242_555 | 692_770_647 | 40_291_035 | 629_086_567 |


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
| B+Tree               | 142_234_323 | 115_501_900 | 123_641_604 |  3_867_643 | 148_633_986 |
| Memory B+Tree (4)    | 559_578_559 | 434_039_498 | 874_151_793 | 42_628_324 | 887_690_976 |
| Memory B+Tree (32)   | 354_289_858 | 298_278_854 | 625_599_149 | 40_526_033 | 575_892_578 |
| Memory B+Tree (64)   | 339_909_944 | 291_823_151 | 619_142_446 | 40_365_445 | 552_998_195 |
| Memory B+Tree (128)  | 318_906_893 | 265_238_016 | 573_766_311 | 40_290_607 | 523_052_350 |
| Memory B+Tree (256)  | 321_364_123 | 264_147_379 | 572_675_853 | 40_252_703 | 521_931_908 |
| Memory B+Tree (512)  | 332_124_950 | 263_313_485 | 571_841_780 | 40_233_283 | 527_492_256 |
| Memory B+Tree (1024) | 355_130_828 | 262_288_965 | 570_817_260 | 40_227_342 | 544_689_340 |
| Memory B+Tree (2048) | 402_326_115 | 260_379_763 | 568_908_058 | 40_232_243 | 584_595_566 |
| Memory B+Tree (4096) | 487_307_109 | 256_711_672 | 565_239_967 | 40_250_425 | 665_368_614 |


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
| add()                   |     4_381_777 |   31_517_187 |
| get()                   |     2_342_357 |   13_939_355 |
| put() (new == prev)     |     3_673_113 |   18_382_268 |
| put() (new > prev)      |     3_943_796 |  325_127_079 |
| put() (new < prev)      |     3_944_481 |  277_617_123 |
| add() reallocation      |     7_908_275 |  368_445_237 |
| removeLast()            |     4_037_038 |  143_819_076 |
| reverse()               |     3_114_820 |    9_278_069 |
| remove()                | 3_321_770_061 |  627_649_261 |
| insert()                | 2_826_839_404 |  443_822_129 |
| shuffle()               |         5_830 |  208_242_607 |
| sortUnstable() #GenCmp  |   105_853_826 |  696_588_407 |
| shuffle()               |         5_830 |  208_242_607 |
| sortUnstable() #BlobCmp |         6_041 |  654_266_877 |


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
| add()              |  35_034_654 |
| vals()             |  39_203_605 |
| pop()              |  75_163_458 |
| random add()/pop() | 173_680_417 |


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
