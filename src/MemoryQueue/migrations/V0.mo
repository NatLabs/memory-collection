import MemoryRegion "mo:memory-region/MemoryRegion";

module V0 {
    type MemoryRegionV1 = MemoryRegion.MemoryRegionV1;

    public type MemoryQueue = {
        region : MemoryRegionV1;

        var head : Nat;
        var tail : Nat;
        var count : Nat;
    };
};
