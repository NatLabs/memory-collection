# Benchmark Results


2026-04-04 00:17:01.797074781 UTC: [Canister lc6ij-px777-77777-aaadq-cai] 
📊 Data Generation Stats:
2026-04-04 00:17:01.797074781 UTC: [Canister lc6ij-px777-77777-aaadq-cai]    • Total keys generated: 10000
2026-04-04 00:17:01.797074781 UTC: [Canister lc6ij-px777-77777-aaadq-cai]    • Unique prefixes: 107
2026-04-04 00:17:01.797074781 UTC: [Canister lc6ij-px777-77777-aaadq-cai]    • Average prefix size: 28 chars
2026-04-04 00:17:01.797074781 UTC: [Canister lc6ij-px777-77777-aaadq-cai]    • Average key size: 64 chars
2026-04-04 00:17:01.797074781 UTC: [Canister lc6ij-px777-77777-aaadq-cai]    • Prefix reuse rate: 99%
2026-04-04 00:17:01.797074781 UTC: [Canister lc6ij-px777-77777-aaadq-cai]    • Prefix truncate rate: 20%
2026-04-04 00:17:01.797074781 UTC: [Canister lc6ij-px777-77777-aaadq-cai] 
2026-04-04 00:17:05.655692176 UTC: [Canister lf7o5-cp777-77777-aaada-cai] 
📊 Data Generation Stats:
2026-04-04 00:17:05.655692176 UTC: [Canister lf7o5-cp777-77777-aaada-cai]    • Total keys generated: 10000
2026-04-04 00:17:05.655692176 UTC: [Canister lf7o5-cp777-77777-aaada-cai]    • Unique prefixes: 107
2026-04-04 00:17:05.655692176 UTC: [Canister lf7o5-cp777-77777-aaada-cai]    • Average prefix size: 28 chars
2026-04-04 00:17:05.655692176 UTC: [Canister lf7o5-cp777-77777-aaada-cai]    • Average key size: 64 chars
2026-04-04 00:17:05.655692176 UTC: [Canister lf7o5-cp777-77777-aaada-cai]    • Prefix reuse rate: 99%
2026-04-04 00:17:05.655692176 UTC: [Canister lf7o5-cp777-77777-aaada-cai]    • Prefix truncate rate: 20%
2026-04-04 00:17:05.655692176 UTC: [Canister lf7o5-cp777-77777-aaada-cai] 

<details>

<summary>bench/MemoryBTree/BTree-specific-fns.bench.mo $({\color{green}-569620.00\%})$</summary>

### Comparing B+Tree and MemoryBTree

_Benchmarking the performance with 10k entries_


Instructions: ${\color{red}+24.92\\%}$
Heap: ${\color{green}-570168.39\\%}$
Stable Memory: ${\color{gray}0\\%}$
Garbage Collection: ${\color{red}+523.46\\%}$


**Instructions**

|                |                                  B+Tree |                              MemoryBTree |
| :------------- | --------------------------------------: | ---------------------------------------: |
| getFromIndex() |    59_207_793 $({\color{red}+7.52\\%})$ |    379_692_397 $({\color{red}+5.52\\%})$ |
| getIndex()     |   148_647_032 $({\color{red}+5.05\\%})$ |  796_479_033 $({\color{green}-8.58\\%})$ |
| getFloor()     |    73_552_341 $({\color{red}+5.23\\%})$ |   416_010_005 $({\color{red}+43.74\\%})$ |
| getCeiling()   |    73_552_866 $({\color{red}+5.23\\%})$ |   416_010_830 $({\color{red}+43.74\\%})$ |
| removeMin()    | 131_231_787 $({\color{green}-1.18\\%})$ | 1_429_002_278 $({\color{red}+94.63\\%})$ |
| removeMax()    |   102_294_770 $({\color{red}+2.32\\%})$ | 1_341_909_949 $({\color{red}+95.87\\%})$ |


**Heap**

|                |                                        B+Tree |                                  MemoryBTree |
| :------------- | --------------------------------------------: | -------------------------------------------: |
| getFromIndex() |     322.33 KiB $({\color{red}+121248.53\\%})$ |        6 MiB $({\color{red}+2311604.41\\%})$ |
| getIndex()     | -29.78 MiB $({\color{green}-11480610.29\\%})$ |    10.76 MiB $({\color{red}+4148120.59\\%})$ |
| getFloor()     |      213.27 KiB $({\color{red}+80191.18\\%})$ |    12.87 MiB $({\color{red}+4960616.18\\%})$ |
| getCeiling()   |      213.27 KiB $({\color{red}+80191.18\\%})$ | -15.43 MiB $({\color{green}-5948133.82\\%})$ |
| removeMin()    |      212.86 KiB $({\color{red}+80036.76\\%})$ |      2.87 MiB $({\color{red}+875355.81\\%})$ |
| removeMax()    |      206.89 KiB $({\color{red}+77786.76\\%})$ |  -7.05 MiB $({\color{green}-2148427.91\\%})$ |


**Garbage Collection**

|                |                                 B+Tree |                           MemoryBTree |
| :------------- | -------------------------------------: | ------------------------------------: |
| getFromIndex() |      0 B $({\color{green}-100.00\\%})$ |     0 B $({\color{green}-100.00\\%})$ |
| getIndex()     | 30.35 MiB $({\color{red}+6494.10\\%})$ |     0 B $({\color{green}-100.00\\%})$ |
| getFloor()     |      0 B $({\color{green}-100.00\\%})$ |     0 B $({\color{green}-100.00\\%})$ |
| getCeiling()   |      0 B $({\color{green}-100.00\\%})$ |  28.3 MiB $({\color{red}+366.79\\%})$ |
| removeMin()    |      0 B $({\color{green}-100.00\\%})$ |  30.68 MiB $({\color{red}+28.98\\%})$ |
| removeMax()    |      0 B $({\color{green}-100.00\\%})$ | 28.95 MiB $({\color{red}+191.63\\%})$ |


</details>
Saving results to .bench/BTree-specific-fns.bench.json

<details>

<summary>bench/MemoryBTree/MemoryBTree.bench.mo $({\color{red}+241964.71\%})$</summary>

### Comparing RBTree, BTree and B+Tree (BpTree)

_Benchmarking the performance with 10k entries_


Instructions: ${\color{red}+498.61\\%}$
Heap: ${\color{red}+241138.40\\%}$
Stable Memory: ${\color{gray}0\\%}$
Garbage Collection: ${\color{red}+327.70\\%}$


**Instructions**

|                          |                                insert() |                                    get() |                               replace() |                               entries() |                                  remove() |                        random ops |
| :----------------------- | --------------------------------------: | ---------------------------------------: | --------------------------------------: | --------------------------------------: | ----------------------------------------: | --------------------------------: |
| RBTree                   | 791_833_519 $({\color{red}+828.48\\%})$ | 828_234_798 $({\color{red}+1151.35\\%})$ | 900_158_463 $({\color{red}+881.80\\%})$ |  21_003_944 $({\color{red}+132.77\\%})$ |   787_341_069 $({\color{red}+806.19\\%})$ | 122_099_060 (no previous results) |
| BTree                    | 803_694_395 $({\color{red}+578.00\\%})$ |  885_073_386 $({\color{red}+822.32\\%})$ | 891_980_256 $({\color{red}+782.82\\%})$ |   11_394_054 $({\color{red}+52.00\\%})$ |   839_022_701 $({\color{red}+515.01\\%})$ | 114_789_608 (no previous results) |
| B+Tree                   | 953_886_985 $({\color{red}+429.00\\%})$ |  914_200_262 $({\color{red}+862.33\\%})$ | 920_049_913 $({\color{red}+806.09\\%})$ |     3_779_878 $({\color{red}+6.27\\%})$ |   888_191_100 $({\color{red}+337.02\\%})$ | 155_137_791 (no previous results) |
| Memory B+Tree (#BlobCmp) | 938_977_114 $({\color{red}+222.34\\%})$ |  618_750_686 $({\color{red}+159.01\\%})$ |  787_154_095 $({\color{red}+54.81\\%})$ | 164_390_743 $({\color{red}+395.22\\%})$ | 1_195_710_284 $({\color{red}+149.28\\%})$ | 776_884_537 (no previous results) |


**Heap**

|                          |                                  insert() |                                    get() |                               replace() |                                   entries() |                                    remove() |                       random ops |
| :----------------------- | ----------------------------------------: | ---------------------------------------: | --------------------------------------: | ------------------------------------------: | ------------------------------------------: | -------------------------------: |
| RBTree                   |     8.67 MiB $({\color{red}+1647.63\\%})$ |    9.83 KiB $({\color{red}+3601.47\\%})$ | -9.8 MiB $({\color{green}-2076.11\\%})$ |      1.8 MiB $({\color{red}+694805.88\\%})$ | -3.59 MiB $({\color{green}-1385770.59\\%})$ |   7.52 MiB (no previous results) |
| BTree                    |      1.17 MiB $({\color{red}+387.19\\%})$ | 471.3 KiB $({\color{red}+177330.88\\%})$ |     1.1 MiB $({\color{red}+620.75\\%})$ |   589.34 KiB $({\color{red}+221770.59\\%})$ |       1.87 MiB $({\color{red}+5670.60\\%})$ |   1.14 MiB (no previous results) |
| B+Tree                   | -16.71 MiB $({\color{green}-7630.51\\%})$ | 205.14 KiB $({\color{red}+77130.88\\%})$ |  595.77 KiB $({\color{red}+280.65\\%})$ |       9.95 KiB $({\color{red}+3647.06\\%})$ |    205.15 KiB $({\color{red}+77132.35\\%})$ | 515.65 KiB (no previous results) |
| Memory B+Tree (#BlobCmp) | 16.12 MiB $({\color{red}+5489546.75\\%})$ | 3.53 MiB $({\color{red}+1359776.47\\%})$ |   8.77 MiB $({\color{red}+5207.99\\%})$ | -6.39 MiB $({\color{green}-2462883.82\\%})$ |    15.63 MiB $({\color{red}+562571.98\\%})$ |  12.33 MiB (no previous results) |


**Garbage Collection**

|                          |                               insert() |                                 get() |                             replace() |                              entries() |                             remove() |                random ops |
| :----------------------- | -------------------------------------: | ------------------------------------: | ------------------------------------: | -------------------------------------: | -----------------------------------: | ------------------------: |
| RBTree                   |      0 B $({\color{green}-100.00\\%})$ |     0 B $({\color{green}-100.00\\%})$ | 17.63 MiB $({\color{red}+198.22\\%})$ |      0 B $({\color{green}-100.00\\%})$ |  15.7 MiB $({\color{red}+57.52\\%})$ | 0 B (no previous results) |
| BTree                    |      0 B $({\color{green}-100.00\\%})$ |     0 B $({\color{green}-100.00\\%})$ |     0 B $({\color{green}-100.00\\%})$ |      0 B $({\color{green}-100.00\\%})$ |    0 B $({\color{green}-100.00\\%})$ | 0 B (no previous results) |
| B+Tree                   | 17.36 MiB $({\color{red}+5282.30\\%})$ |     0 B $({\color{green}-100.00\\%})$ |     0 B $({\color{green}-100.00\\%})$ |      0 B $({\color{green}-100.00\\%})$ |    0 B $({\color{green}-100.00\\%})$ | 0 B (no previous results) |
| Memory B+Tree (#BlobCmp) |  15.39 MiB $({\color{red}+123.79\\%})$ | 17.41 MiB $({\color{red}+414.51\\%})$ | 15.19 MiB $({\color{red}+122.54\\%})$ | 17.05 MiB $({\color{red}+1482.21\\%})$ | 15.41 MiB $({\color{red}+72.91\\%})$ | 0 B (no previous results) |


</details>
Saving results to .bench/MemoryBTree.bench.json

<details>

<summary>bench/MemoryBTree/MemoryBTree.node-capacity.bench.mo $({\color{red}+1107388.39\%})$</summary>

### Comparing the Memory B+Tree with different node capacities

_Benchmarking the performance with 10k entries_


Instructions: ${\color{red}+76.63\\%}$
Heap: ${\color{red}+1107238.71\\%}$
Stable Memory: ${\color{gray}0\\%}$
Garbage Collection: ${\color{red}+73.06\\%}$


**Instructions**

|                      |                                  insert() |                                  get() |                              replace() |                               entries() |                                 remove() |
| :------------------- | ----------------------------------------: | -------------------------------------: | -------------------------------------: | --------------------------------------: | ---------------------------------------: |
| RBTree               |         791_833_540 (no previous results) |      828_234_819 (no previous results) |      900_158_484 (no previous results) |        21_003_965 (no previous results) |        787_341_090 (no previous results) |
| BTree                |         803_694_416 (no previous results) |      885_073_407 (no previous results) |      891_980_277 (no previous results) |        11_394_075 (no previous results) |        839_022_722 (no previous results) |
| B+Tree               |    928_412_328 $({\color{red}+13.95\\%})$ | 976_381_418 $({\color{red}+14.10\\%})$ | 984_521_093 $({\color{red}+13.85\\%})$ |     3_869_359 $({\color{red}+6.24\\%})$ |   888_256_865 $({\color{red}+12.79\\%})$ |
| Memory B+Tree (16)   |  1_233_181_733 $({\color{red}+99.05\\%})$ | 776_264_358 $({\color{red}+49.63\\%})$ | 982_234_785 $({\color{red}+37.75\\%})$ | 252_798_790 $({\color{red}+590.71\\%})$ | 1_490_838_538 $({\color{red}+80.24\\%})$ |
| Memory B+Tree (32)   |  1_121_898_100 $({\color{red}+98.88\\%})$ | 721_533_897 $({\color{red}+46.89\\%})$ | 908_707_330 $({\color{red}+36.14\\%})$ | 231_961_083 $({\color{red}+539.57\\%})$ | 1_416_723_569 $({\color{red}+84.23\\%})$ |
| Memory B+Tree (64)   | 1_064_476_421 $({\color{red}+100.10\\%})$ | 686_394_345 $({\color{red}+41.76\\%})$ | 873_568_778 $({\color{red}+32.27\\%})$ | 206_649_305 $({\color{red}+472.65\\%})$ | 1_335_656_359 $({\color{red}+80.34\\%})$ |
| Memory B+Tree (128)  |    938_978_521 $({\color{red}+88.25\\%})$ | 618_762_246 $({\color{red}+31.59\\%})$ | 787_155_679 $({\color{red}+21.76\\%})$ | 164_392_303 $({\color{red}+356.66\\%})$ | 1_195_711_868 $({\color{red}+67.05\\%})$ |
| Memory B+Tree (256)  |    799_052_170 $({\color{red}+62.88\\%})$ | 577_807_598 $({\color{red}+28.53\\%})$ | 746_211_019 $({\color{red}+22.77\\%})$ | 119_020_043 $({\color{red}+231.06\\%})$ | 1_028_164_670 $({\color{red}+50.48\\%})$ |
| Memory B+Tree (512)  |    644_750_022 $({\color{red}+28.74\\%})$ | 535_621_624 $({\color{red}+19.34\\%})$ | 704_030_045 $({\color{red}+15.97\\%})$ |  72_101_960 $({\color{red}+100.65\\%})$ |   875_984_481 $({\color{red}+27.79\\%})$ |
| Memory B+Tree (1024) |    594_831_148 $({\color{red}+12.44\\%})$ | 512_703_155 $({\color{red}+14.20\\%})$ | 681_113_761 $({\color{red}+12.17\\%})$ |   46_936_622 $({\color{red}+30.63\\%})$ |   772_190_540 $({\color{red}+10.75\\%})$ |
| Memory B+Tree (2048) |    637_702_697 $({\color{red}+12.20\\%})$ | 508_322_167 $({\color{red}+13.52\\%})$ | 676_732_600 $({\color{red}+11.66\\%})$ |   46_950_412 $({\color{red}+30.65\\%})$ |    786_018_371 $({\color{red}+8.44\\%})$ |
| Memory B+Tree (4096) |    704_051_222 $({\color{red}+10.06\\%})$ | 503_824_452 $({\color{red}+12.60\\%})$ | 672_235_058 $({\color{red}+10.98\\%})$ |   46_964_254 $({\color{red}+30.62\\%})$ |    842_514_668 $({\color{red}+5.81\\%})$ |


**Heap**

|                      |                                     insert() |                                       get() |                                replace() |                                   entries() |                                     remove() |
| :------------------- | -------------------------------------------: | ------------------------------------------: | ---------------------------------------: | ------------------------------------------: | -------------------------------------------: |
| RBTree               |               8.67 MiB (no previous results) |              9.83 KiB (no previous results) |          -9.79 MiB (no previous results) |               1.8 MiB (no previous results) |              -3.58 MiB (no previous results) |
| BTree                |               1.17 MiB (no previous results) |             471.3 KiB (no previous results) |            1.1 MiB (no previous results) |            589.34 KiB (no previous results) |               1.87 MiB (no previous results) |
| B+Tree               |       717.91 KiB $({\color{red}+175.80\\%})$ |    205.14 KiB $({\color{red}+77130.88\\%})$ |   595.77 KiB $({\color{red}+280.65\\%})$ |       9.95 KiB $({\color{red}+3647.06\\%})$ |     205.15 KiB $({\color{red}+77132.35\\%})$ |
| Memory B+Tree (16)   |   -1.83 MiB $({\color{green}-623014.29\\%})$ |   11.07 MiB $({\color{red}+4265660.29\\%})$ |   14.29 MiB $({\color{red}+4637.49\\%})$ |     1.49 MiB $({\color{red}+572832.35\\%})$ |   -2.95 MiB $({\color{green}-759269.61\\%})$ |
| Memory B+Tree (32)   |  -8.06 MiB $({\color{green}-2745276.62\\%})$ |       9 MiB $({\color{red}+3468798.53\\%})$ |   14.11 MiB $({\color{red}+4577.56\\%})$ |   15.35 MiB $({\color{red}+5917077.94\\%})$ |  -6.17 MiB $({\color{green}-1584676.47\\%})$ |
| Memory B+Tree (64)   |    17.56 MiB $({\color{red}+5979522.08\\%})$ |    5.99 MiB $({\color{red}+2310536.76\\%})$ |    11.2 MiB $({\color{red}+3613.40\\%})$ | -3.72 MiB $({\color{green}-1433336.76\\%})$ | -11.48 MiB $({\color{green}-2950550.98\\%})$ |
| Memory B+Tree (128)  |     13.8 MiB $({\color{red}+4697702.60\\%})$ |    3.26 MiB $({\color{red}+1255438.24\\%})$ |    8.51 MiB $({\color{red}+2721.72\\%})$ | -6.66 MiB $({\color{green}-2567226.47\\%})$ |    15.36 MiB $({\color{red}+3946330.39\\%})$ |
| Memory B+Tree (256)  |    11.17 MiB $({\color{red}+3803089.61\\%})$ |     2.42 MiB $({\color{red}+934433.82\\%})$ |    3.45 MiB $({\color{red}+1044.78\\%})$ |    7.52 MiB $({\color{red}+2899875.00\\%})$ |     9.26 MiB $({\color{red}+2529710.42\\%})$ |
| Memory B+Tree (512)  |    12.14 MiB $({\color{red}+4132107.79\\%})$ |  -1.02 MiB $({\color{green}-395182.35\\%})$ |   72.14 KiB $({\color{green}-76.64\\%})$ |    4.29 MiB $({\color{red}+1654423.53\\%})$ |    11.27 MiB $({\color{red}+3077381.25\\%})$ |
| Memory B+Tree (1024) |    21.23 MiB $({\color{red}+7229183.12\\%})$ |   12.65 MiB $({\color{red}+4876391.18\\%})$ |  -1.95 MiB $({\color{green}-747.01\\%})$ |     2.57 MiB $({\color{red}+990408.82\\%})$ | -13.09 MiB $({\color{green}-3575765.63\\%})$ |
| Memory B+Tree (2048) |    14.23 MiB $({\color{red}+4844788.31\\%})$ | -5.24 MiB $({\color{green}-2019148.53\\%})$ |     -332 B $({\color{green}-100.10\\%})$ |     2.57 MiB $({\color{red}+990408.82\\%})$ |      1.75 MiB $({\color{red}+476990.63\\%})$ |
| Memory B+Tree (4096) | -12.53 MiB $({\color{green}-4106310.00\\%})$ |   11.63 MiB $({\color{red}+4483216.18\\%})$ | -2.97 MiB $({\color{green}-1083.20\\%})$ |     2.57 MiB $({\color{red}+990408.82\\%})$ |     5.94 MiB $({\color{red}+1622021.88\\%})$ |


**Garbage Collection**

|                      |                               insert() |                                 get() |                            replace() |                             entries() |                               remove() |
| :------------------- | -------------------------------------: | ------------------------------------: | -----------------------------------: | ------------------------------------: | -------------------------------------: |
| RBTree               |              0 B (no previous results) |             0 B (no previous results) |      17.61 MiB (no previous results) |             0 B (no previous results) |        15.68 MiB (no previous results) |
| BTree                |              0 B (no previous results) |             0 B (no previous results) |            0 B (no previous results) |             0 B (no previous results) |              0 B (no previous results) |
| B+Tree               |      0 B $({\color{green}-100.00\\%})$ |     0 B $({\color{green}-100.00\\%})$ |    0 B $({\color{green}-100.00\\%})$ |     0 B $({\color{green}-100.00\\%})$ |      0 B $({\color{green}-100.00\\%})$ |
| Memory B+Tree (16)   |  47.63 MiB $({\color{red}+214.91\\%})$ | 17.67 MiB $({\color{red}+116.69\\%})$ | 17.48 MiB $({\color{red}+69.15\\%})$ | 15.26 MiB $({\color{red}+623.22\\%})$ |  47.68 MiB $({\color{red}+390.55\\%})$ |
| Memory B+Tree (32)   |  47.63 MiB $({\color{red}+256.57\\%})$ | 17.68 MiB $({\color{red}+112.71\\%})$ |  15.6 MiB $({\color{red}+48.71\\%})$ |     0 B $({\color{green}-100.00\\%})$ |  47.68 MiB $({\color{red}+373.97\\%})$ |
| Memory B+Tree (64)   |   17.73 MiB $({\color{red}+45.29\\%})$ | 17.67 MiB $({\color{red}+112.79\\%})$ |  15.5 MiB $({\color{red}+47.82\\%})$ | 17.32 MiB $({\color{red}+720.83\\%})$ |  47.68 MiB $({\color{red}+353.11\\%})$ |
| Memory B+Tree (128)  |   17.72 MiB $({\color{red}+39.80\\%})$ | 17.68 MiB $({\color{red}+111.62\\%})$ | 15.46 MiB $({\color{red}+46.75\\%})$ | 17.32 MiB $({\color{red}+721.09\\%})$ |   15.68 MiB $({\color{red}+29.95\\%})$ |
| Memory B+Tree (256)  |   17.72 MiB $({\color{red}+16.40\\%})$ |  15.63 MiB $({\color{red}+87.99\\%})$ | 17.63 MiB $({\color{red}+68.04\\%})$ |     0 B $({\color{green}-100.00\\%})$ |   17.74 MiB $({\color{red}+20.84\\%})$ |
| Memory B+Tree (512)  | 17.73 MiB $({\color{green}-20.38\\%})$ |  15.66 MiB $({\color{red}+85.43\\%})$ |  17.6 MiB $({\color{red}+65.62\\%})$ |     0 B $({\color{green}-100.00\\%})$ | 15.68 MiB $({\color{green}-21.78\\%})$ |
| Memory B+Tree (1024) | 17.74 MiB $({\color{green}-52.16\\%})$ |     0 B $({\color{green}-100.00\\%})$ | 17.63 MiB $({\color{red}+59.99\\%})$ |     0 B $({\color{green}-100.00\\%})$ |   47.68 MiB $({\color{red}+61.10\\%})$ |
| Memory B+Tree (2048) | 47.68 MiB $({\color{green}-18.15\\%})$ |  17.74 MiB $({\color{red}+86.29\\%})$ | 15.53 MiB $({\color{red}+32.75\\%})$ |     0 B $({\color{green}-100.00\\%})$ |  47.67 MiB $({\color{green}-5.72\\%})$ |
| Memory B+Tree (4096) |  111.65 MiB $({\color{red}+17.99\\%})$ |     0 B $({\color{green}-100.00\\%})$ | 17.62 MiB $({\color{red}+45.35\\%})$ |     0 B $({\color{green}-100.00\\%})$ | 79.67 MiB $({\color{green}-12.30\\%})$ |


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
| add()                   |     4_381_870 |   31_517_172 |
| get()                   |     2_342_450 |   13_899_298 |
| put() (new == prev)     |     3_673_206 |   18_382_182 |
| put() (new > prev)      |     3_943_860 |  346_674_906 |
| put() (new < prev)      |     3_944_545 |  277_443_027 |
| add() reallocation      |     7_908_366 |  504_750_939 |
| removeLast()            |     4_036_698 |  143_739_549 |
| reverse()               |     3_114_884 |    9_278_199 |
| remove()                | 3_321_770_125 |  631_930_093 |
| insert()                | 2_826_839_468 |  453_022_079 |
| shuffle()               |         5_438 |  198_088_861 |
| shuffle()               |         5_438 |  198_088_861 |
| sortUnstable() #BlobCmp |         5_304 |  636_549_530 |


**Heap**

|                         |     Buffer | MemoryBuffer |
| :---------------------- | ---------: | -----------: |
| add()                   |   9.83 KiB |     9.93 KiB |
| get()                   |   9.83 KiB |   508.45 KiB |
| put() (new == prev)     |   9.83 KiB |     9.84 KiB |
| put() (new > prev)      |   9.84 KiB |     4.29 MiB |
| put() (new < prev)      |   9.84 KiB |     2.46 MiB |
| add() reallocation      | 156.34 KiB |     9.44 MiB |
| removeLast()            |   9.83 KiB |      1.6 MiB |
| reverse()               |   9.78 KiB |   -29.16 MiB |
| remove()                |  97.89 KiB |     5.98 MiB |
| insert()                |  152.3 KiB |     2.98 MiB |
| shuffle()               |   9.78 KiB |     7.52 MiB |
| shuffle()               |   9.78 KiB |     7.52 MiB |
| sortUnstable() #BlobCmp |   9.78 KiB |    -7.47 MiB |


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
| reverse()               |    0 B |     29.4 MiB |
| remove()                |    0 B |   187.51 MiB |
| insert()                |    0 B |   187.49 MiB |
| shuffle()               |    0 B |          0 B |
| shuffle()               |    0 B |          0 B |
| sortUnstable() #BlobCmp |    0 B |    29.69 MiB |


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
| add()              |  35_034_739 |
| vals()             |  38_803_669 |
| pop()              |  74_673_528 |
| random add()/pop() | 181_749_548 |


**Heap**

|                    | MemoryQueue |
| :----------------- | ----------: |
| add()              |    1.04 MiB |
| vals()             |    1.34 MiB |
| pop()              |    2.07 MiB |
| random add()/pop() |    5.92 MiB |


**Garbage Collection**

|                    | MemoryQueue |
| :----------------- | ----------: |
| add()              |         0 B |
| vals()             |         0 B |
| pop()              |         0 B |
| random add()/pop() |         0 B |


</details>
Saving results to .bench/MemoryQueue.bench.json
