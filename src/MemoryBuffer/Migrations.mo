/// A memory buffer is a data structure that stores a sequence of values in memory.

import Iter "mo:base@0.14.11/Iter";
import Nat "mo:base@0.14.11/Nat";
import Result "mo:base@0.14.11/Result";
import Order "mo:base@0.14.11/Order";

import MemoryRegion "mo:memory-region@1.3.2/MemoryRegion";

module Migrations {
    type Iter<A> = Iter.Iter<A>;
    type Result<A, B> = Result.Result<A, B>;
    type MemoryRegion = MemoryRegion.MemoryRegion;

    type MemoryRegionV0 = MemoryRegion.MemoryRegionV0;
    type MemoryRegionV1 = MemoryRegion.MemoryRegionV1;

    type Order = Order.Order;

    // current version of the memory buffer
    public type MemoryBuffer<A> = MemoryBufferV0<A>;

    public type VersionedMemoryBuffer<A> = {
        #v0 : MemoryBufferV0<A>;
    };

    public func upgrade<A>(versions : VersionedMemoryBuffer<A>) : VersionedMemoryBuffer<A> = switch (versions) {
        case (#v0(v0)) versions;
    };

    public func getCurrentVersion<A>(versions : VersionedMemoryBuffer<A>) : MemoryBuffer<A> {
        switch (versions) {
            case (#v0(v0)) v0;
            // case (_) Debug.trap("Unsupported version. Please upgrade the memory buffer to the latest version.");
        };
    };

    /// Initial version of the memory buffer
    public type MemoryBufferV0<A> = {
        /// The memory region that stores the pointers to the serialized values.
        pointers : MemoryRegionV1;

        /// The memory region that stores the serialized values.
        blobs : MemoryRegionV1;

        /// The number of values in the buffer.
        var count : Nat;
    };
};
