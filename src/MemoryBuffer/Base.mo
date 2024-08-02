/// A memory buffer is a data structure that stores a sequence of values in memory.

import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";
import Result "mo:base/Result";
import Order "mo:base/Order";

import MemoryRegion "mo:memory-region/MemoryRegion";
import RevIter "mo:itertools/RevIter";
import Itertools "mo:itertools/Iter";

import Migrations "Migrations";
import MemoryCmp "../TypeUtils/MemoryCmp";
import Blobify "../TypeUtils/Blobify";
import TypeUtils "../TypeUtils";

module MemoryBuffer {
    type Iter<A> = Iter.Iter<A>;
    type RevIter<A> = RevIter.RevIter<A>;
    type Result<A, B> = Result.Result<A, B>;
    type MemoryRegion = MemoryRegion.MemoryRegion;
    type Order = Order.Order;

    public type MemoryBufferRegion = {
        pointers : MemoryRegion;
        blobs : MemoryRegion;
    };

    public type MemoryBuffer<A> = Migrations.MemoryBuffer<A>;
    public type VersionedMemoryBuffer<A> = Migrations.VersionedMemoryBuffer<A>;

    public let REGION_HEADER_SIZE = 64;

    public let POINTER_SIZE = 12;
    public let LAYOUT_VERSION = 0;

    public let Layout = [
        {
            MAGIC_NUMBER_ADDRESS = 0;
            LAYOUT_VERSION_ADDRESS = 3;
            REGION_ID_ADDRESS = 4;
            COUNT_ADDRESS = 8;
            POINTERS_START = 64;
            BLOB_START = 64;
        },
    ];

    let C = {
        MAGIC_NUMBER_ADDRESS = 00;
        LAYOUT_VERSION_ADDRESS = 3;
        REGION_ID_ADDRESS = 4;
        COUNT_ADDRESS = 8;
        POINTERS_START = 64;
        BLOB_START = 64;
    };

    /// The Blobify typeclass is used to serialize and deserialize values.
    public type Blobify<A> = Blobify.Blobify<A>;

    public type MemoryBufferUtils<A> = {
        blobify : TypeUtils.Blobify<A>;
    };

    public func createUtils<A>(buffer_utils : MemoryBufferUtils<A>) : MemoryBufferUtils<A> {
        buffer_utils;
    };

    /// Creates a new memory buffer.
    public func new<A>() : MemoryBuffer<A> {
        let memory_region = {
            pointers = MemoryRegion.new();
            blobs = MemoryRegion.new();
            var count = 0;
        };

        init_region_header(memory_region);

        memory_region;
    };

    func init_region_header<A>(m_region : MemoryBuffer<A>) {

        // Initialize the Blob Region header
        ignore MemoryRegion.allocate(m_region.blobs, REGION_HEADER_SIZE); // Reserved Space for the Region Header
        MemoryRegion.storeBlob(m_region.blobs, C.MAGIC_NUMBER_ADDRESS, "BLB");
        MemoryRegion.storeNat8(m_region.blobs, C.LAYOUT_VERSION_ADDRESS, Nat8.fromNat(LAYOUT_VERSION));
        MemoryRegion.storeNat32(m_region.blobs, C.REGION_ID_ADDRESS, Nat32.fromNat(MemoryRegion.id(m_region.pointers))); // store the pointers region id in the blob region
        assert MemoryRegion.size(m_region.blobs) == REGION_HEADER_SIZE;

        // Initialize the Pointer Region Header
        ignore MemoryRegion.allocate(m_region.pointers, REGION_HEADER_SIZE); // Reserved Space for the Region Header
        MemoryRegion.storeBlob(m_region.pointers, C.MAGIC_NUMBER_ADDRESS, "BFR");
        MemoryRegion.storeNat8(m_region.pointers, C.LAYOUT_VERSION_ADDRESS, Nat8.fromNat(LAYOUT_VERSION));
        MemoryRegion.storeNat32(m_region.pointers, C.REGION_ID_ADDRESS, Nat32.fromNat(MemoryRegion.id(m_region.blobs))); // store the blobs region id in the pointers region
        MemoryRegion.storeNat64(m_region.pointers, C.COUNT_ADDRESS, 0);

        assert MemoryRegion.size(m_region.pointers) == REGION_HEADER_SIZE;
    };

    func update_count<A>(self : MemoryBuffer<A>, count : Nat) {
        self.count := count;
        MemoryRegion.storeNat64(self.pointers, C.COUNT_ADDRESS, Nat64.fromNat(count));
    };

    public func verify(region : MemoryBufferRegion) : Result<(), Text> {
        if (MemoryRegion.loadBlob(region.blobs, C.MAGIC_NUMBER_ADDRESS, 3) != "BLB") {
            return #err("Invalid Blob Region Magic Number");
        };

        if (Nat32.toNat(MemoryRegion.loadNat32(region.blobs, C.REGION_ID_ADDRESS)) != MemoryRegion.id(region.pointers)) {
            return #err("Invalid Blob Region ID");
        };

        if (MemoryRegion.loadBlob(region.pointers, C.MAGIC_NUMBER_ADDRESS, 3) != "BFR") {
            return #err("Invalid Buffer Region Magic Number");
        };

        if (Nat32.toNat(MemoryRegion.loadNat32(region.pointers, C.REGION_ID_ADDRESS)) != MemoryRegion.id(region.blobs)) {
            return #err("Invalid Buffer Region ID");
        };

        #ok(());
    };

    /// Converts from a versioned memory buffer
    public func fromVersioned<A>(self : VersionedMemoryBuffer<A>) : MemoryBuffer<A> {
        Migrations.getCurrentVersion(self);
    };

    /// Converts the memory buffer to a versioned one.
    public func toVersioned<A>(self : MemoryBuffer<A>) : VersionedMemoryBuffer<A> {
        #v0(self);
    };

    /// Initializes a memory buffer with a given value and size.
    public func init<A>(buffer_utils : MemoryBufferUtils<A>, size : Nat, val : A) : MemoryBuffer<A> {
        let mbuffer = MemoryBuffer.new<A>();

        for (_ in Iter.range(1, size - 1)) {
            MemoryBuffer.add(mbuffer, buffer_utils, val);
        };

        mbuffer;
    };

    /// Initializes a memory buffer with a given function and size.
    public func tabulate<A>(buffer_utils : MemoryBufferUtils<A>, size : Nat, fn : (i : Nat) -> A) : MemoryBuffer<A> {
        let mbuffer = MemoryBuffer.new<A>();

        for (i in Iter.range(0, size - 1)) {
            MemoryBuffer.add(mbuffer, buffer_utils, fn(i));
        };

        mbuffer;
    };

    /// Initializes a memory buffer with a given array.
    public func fromArray<A>(buffer_utils : MemoryBufferUtils<A>, arr : [A]) : MemoryBuffer<A> {
        let mbuffer = MemoryBuffer.new<A>();

        for (elem in arr.vals()) {
            add(mbuffer, buffer_utils, elem);
        };

        mbuffer;
    };

    public func fromIter<A>(buffer_utils : MemoryBufferUtils<A>, iter : Iter<A>) : MemoryBuffer<A> {
        let mbuffer = MemoryBuffer.new<A>();

        for (elem in iter) {
            add(mbuffer, buffer_utils, elem);
        };

        mbuffer;
    };

    /// Returns the number of elements in the buffer.
    public func size<A>(self : MemoryBuffer<A>) : Nat {
        return self.count;
    };

    /// Returns the number of bytes used for storing the values in the buffer.
    public func bytes<A>(self : MemoryBuffer<A>) : Nat {
        return MemoryRegion.allocated(self.blobs);
    };

    /// Returns the bytes used for storing the metadata which include the pointers, buffer size, and region headers.
    public func metadataBytes<A>(self : MemoryBuffer<A>) : Nat {
        return (self.count * 12) + (REGION_HEADER_SIZE);
    };

    public func totalBytes<A>(self : MemoryBuffer<A>) : Nat {
        return bytes(self) + metadataBytes(self);
    };

    /// Returns the capacity of the metadata region before it needs to grow.
    public func metadataCapacity<A>(self : MemoryBuffer<A>) : Nat {
        return MemoryRegion.capacity(self.pointers);
    };

    /// Returns the capacity of the blobs (value) region before it needs to grow.
    public func capacity<A>(self : MemoryBuffer<A>) : Nat {
        return MemoryRegion.capacity(self.blobs);
    };

    public type MemoryBufferStats = {
        pointers : MemoryRegion.MemoryInfo;
        data : MemoryRegion.MemoryInfo;
    };

    public func stats<A>(self : MemoryBuffer<A>) : MemoryBufferStats {
        let pointers = MemoryRegion.memoryInfo(self.pointers);
        let data = MemoryRegion.memoryInfo(self.blobs);

        { pointers; data };

    };

    public func _get_pointer<A>(_ : MemoryBuffer<A>, index : Nat) : Nat {
        C.POINTERS_START + (index * POINTER_SIZE);
    };

    func _get_memory_blob<A>(self : MemoryBuffer<A>, index : Nat) : Blob {
        let ptr_address = _get_pointer(self, index);
        MemoryRegion.loadBlob(self.pointers, ptr_address, POINTER_SIZE);
    };

    public func _get_memory_address<A>(self : MemoryBuffer<A>, index : Nat) : Nat {
        let pointer_address = _get_pointer(self, index);
        let address = MemoryRegion.loadNat64(self.pointers, pointer_address);
        Nat64.toNat(address);
    };

    public func _get_memory_size<A>(self : MemoryBuffer<A>, index : Nat) : Nat {
        let pointer_address = _get_pointer(self, index);
        let value_size = MemoryRegion.loadNat32(self.pointers, pointer_address + 8);

        Nat32.toNat(value_size);
    };

    func update_pointer_at_index<A>(self : MemoryBuffer<A>, index : Nat, mb_address : Nat, mb_size : Nat) {
        let pointer_address = _get_pointer(self, index);
        MemoryRegion.storeNat64(self.pointers, pointer_address, Nat64.fromNat(mb_address));
        MemoryRegion.storeNat32(self.pointers, pointer_address + 8, Nat32.fromNat(mb_size));
    };

    func add_pointer<A>(self : MemoryBuffer<A>, mb_address : Nat, mb_size : Nat) {
        let i = self.count;
        let pointer_address = _get_pointer(self, i);

        if (MemoryRegion.size(self.pointers) >= pointer_address + POINTER_SIZE) {
            MemoryRegion.storeNat64(self.pointers, pointer_address, Nat64.fromNat(mb_address));
            MemoryRegion.storeNat32(self.pointers, pointer_address + 8, Nat32.fromNat(mb_size));
        } else {
            ignore MemoryRegion.addNat64(self.pointers, Nat64.fromNat(mb_address));
            ignore MemoryRegion.addNat32(self.pointers, Nat32.fromNat(mb_size));
        };
    };

    func internal_replace<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>, index : Nat, new_value : A) {
        let mb_address = _get_memory_address(self, index);
        let mb_size = _get_memory_size(self, index);

        let new_blob = buffer_utils.blobify.to_blob(new_value);
        let new_size = new_blob.size();

        let new_address = MemoryRegion.resize(self.blobs, mb_address, mb_size, new_size);
        // if (mb_size == new_size) assert new_address == mb_address;
        if (mb_size != new_size) update_pointer_at_index(self, index, new_address, new_size);

        MemoryRegion.storeBlob(self.blobs, new_address, new_blob);
    };

    /// Replaces the value at the given index with the given value.
    public func put<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>, index : Nat, value : A) {
        if (index >= self.count) {
            Debug.trap("MemoryBuffer put(): Index out of bounds");
        };

        internal_replace(self, buffer_utils, index, value);
    };

    /// Retrieves the value at the given index if it exists. Otherwise returns null.
    public func getOpt<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>, index : Nat) : ?A {
        if (index >= self.count) {
            return null;
        };

        let value = get(self, buffer_utils, index);

        return ?value;
    };

    public func _get_blob<A>(self : MemoryBuffer<A>, index : Nat) : Blob {
        let address = _get_memory_address(self, index);
        let size = _get_memory_size(self, index);

        let blob = MemoryRegion.loadBlob(self.blobs, address, size);
        blob;
    };

    func _get<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>, index : Nat) : A {
        let blob = _get_blob(self, index);
        buffer_utils.blobify.from_blob(blob);
    };

    /// Retrieves the value at the given index. Traps if the index is out of bounds.
    public func get<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>, index : Nat) : A {
        if (index >= self.count) {
            Debug.trap("MemoryBuffer get(): Index out of bounds");
        };

        _get(self, buffer_utils, index);
    };

    public func _get_memory_block<A>(self : MemoryBuffer<A>, index : Nat) : (Nat, Nat) {
        let address = _get_memory_address(self, index);
        let size = _get_memory_size(self, index);
        (address, size);
    };

    /// Adds a value to the end of the buffer.
    public func add<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>, value : A) {
        let blob = buffer_utils.blobify.to_blob(value);
        let mb_address = MemoryRegion.addBlob(self.blobs, blob);

        // Debug.print("Value added to mem-block at address = " # debug_show mb_address);

        add_pointer(self, mb_address, blob.size());
        update_count(self, self.count + 1);
    };

    /// Adds all the values from the given array to the end of the buffer.
    public func addFromArray<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>, values : [A]) {
        for (val in values.vals()) {
            add(self, buffer_utils, val);
        };
    };

    /// Adds all the values from the given iterator to the end of the buffer.
    public func addFromIter<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>, iter : Iter<A>) {
        for (val in iter) {
            add(self, buffer_utils, val);
        };
    };

    /// Adds all the values from the given buffer to the end of this buffer.
    public func append<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>, other : MemoryBuffer<A>) {
        switch (verify(other)) {
            case (#ok(_)) {};
            case (#err(err)) Debug.trap("MemoryBuffer append(): " # err);
        };

        for (value in vals(other, buffer_utils)) {
            add(self, buffer_utils, value);
        };
    };

    /// Adds all the values from the given array to the end of this buffer.
    public func appendArray<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>, blobs : [A]) {
        for (value in blobs.vals()) {
            add(self, buffer_utils, value);
        };
    };

    /// Adds all the values from the given buffer to the end of this buffer.
    public func appendBuffer<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>, other : { vals : () -> Iter<A> }) {
        for (value in other.vals()) {
            add(self, buffer_utils, value);
        };
    };

    public func keys<A>(self : MemoryBuffer<A>) : RevIter<Nat> {
        RevIter.range(0, self.count);
    };

    /// Returns an iterator over the values in the buffer.
    public func vals<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>) : RevIter<A> {
        return range(self, buffer_utils, 0, self.count);
    };

    public func range<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>, start : Nat, end : Nat) : RevIter<A> {
        var i = start;
        var j = end;

        func next() : ?A {
            if (i >= j) {
                return null;
            };

            let val = _get(self, buffer_utils, i);
            i += 1;
            ?val;
        };

        func nextFromEnd() : ?A {
            if (i >= j) {
                return null;
            };

            let val = _get(self, buffer_utils, j - 1 : Nat);
            j -= 1;
            ?val;
        };

        return RevIter.new(next, nextFromEnd);
    };

    /// Return an iterator over the indices and values in the buffer.
    public func items<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>) : RevIter<(index : Nat, value : A)> {
        itemsRange(self, buffer_utils, 0, self.count);
    };

    public func itemsRange<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>, start : Nat, end : Nat) : RevIter<(index : Nat, value : A)> {
        var i = start;
        var j = end;

        func next() : ?(Nat, A) {
            if (i >= j) {
                return null;
            };

            let index = i;
            let val = _get(self, buffer_utils, index);
            i += 1;
            ?(index, val);
        };

        func nextFromEnd() : ?(Nat, A) {
            if (i >= j) {
                return null;
            };

            let index = j - 1 : Nat;
            let val = _get(self, buffer_utils, index);
            j -= 1;
            ?(index, val);
        };

        RevIter.new(next, nextFromEnd);
    };

    /// An iterator over the serialized blobs in the buffer.
    public func blobs<A>(self : MemoryBuffer<A>) : RevIter<Blob> {
        var i = 0;
        var j = self.count;

        func next() : ?Blob {
            if (i >= j) {
                return null;
            };

            let blob = _get_blob(self, i);
            i += 1;
            ?blob;
        };

        func nextFromEnd() : ?Blob {
            if (i >= j) {
                return null;
            };

            let blob = _get_blob(self, j - 1 : Nat);
            j -= 1;
            ?blob;
        };

        return RevIter.new(next, nextFromEnd);
    };

    /// An iterator over the pointers to the memory blocks where the serialized values are stored.
    /// The iterator returns the address of the pointer because the size of each pointer is fixed at 12 bytes.
    public func pointers<A>(self : MemoryBuffer<A>) : RevIter<Nat> {
        var i = 0;
        var j = self.count;

        func next() : ?Nat {
            if (i >= j) {
                return null;
            };

            let address = _get_pointer(self, i);
            i += 1;
            ?address;
        };

        func nextFromEnd() : ?Nat {
            if (i >= j) {
                return null;
            };

            let address = _get_pointer(self, j - 1 : Nat);
            j -= 1;
            ?address;
        };

        return RevIter.new(next, nextFromEnd);
    };

    /// An iterator over the memory blocks where the serialized values are stored.
    public func blocks<A>(self : MemoryBuffer<A>) : RevIter<(Nat, Nat)> {
        var i = 0;
        var j = self.count;

        func next() : ?(Nat, Nat) {
            if (i >= j) {
                return null;
            };

            let address = _get_memory_address(self, i);
            let size = _get_memory_size(self, i);

            i += 1;
            ?(address, size);
        };

        func nextFromEnd() : ?(Nat, Nat) {
            if (i >= j) {
                return null;
            };

            let index = j - 1 : Nat;
            let address = _get_memory_address(self, index);
            let size = _get_memory_size(self, index);
            j -= 1;
            ?(address, size);
        };

        return RevIter.new(next, nextFromEnd);
    };

    func shift_pointers<A>(self : MemoryBuffer<A>, start : Nat, end : Nat, n : Int) {
        let start_address = _get_pointer(self, start);
        let size = (end - start : Nat) * POINTER_SIZE;
        if (size == 0) return ();

        let pointers_blob = MemoryRegion.loadBlob(self.pointers, start_address, size);

        let new_index = Int.abs(start + n);

        let new_address = _get_pointer(self, new_index);

        MemoryRegion.storeBlob(self.pointers, new_address, pointers_blob);

    };

    func remove_blob<A>(self : MemoryBuffer<A>, index : Nat) : Blob {
        // Debug.print("Retrieving memory block");
        let mb_address = _get_memory_address(self, index);
        let mb_size = _get_memory_size(self, index);

        // Debug.print("Removing Blob");
        let blob = MemoryRegion.removeBlob(self.blobs, mb_address, mb_size);
        blob;
    };

    func remove_val<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>, index : Nat) : A {
        let blob = remove_blob(self, index);
        // Debug.print("Removed blob");
        buffer_utils.blobify.from_blob(blob);
    };

    /// Removes the value at the given index. Traps if the index is out of bounds.
    public func remove<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>, index : Nat) : A {
        if (index >= self.count) {
            Debug.trap("MemoryBuffer remove(): Index out of bounds");
        };

        // Debug.print("Removing value at index = " # debug_show index);
        let value = remove_val(self, buffer_utils, index);

        // Debug.print("Shifting pointers");
        shift_pointers(self, index + 1, self.count, -1);

        update_count(self, self.count - 1 : Nat);

        return value;
    };

    /// Removes the last value in the buffer, if it exists. Otherwise returns null.
    public func removeLast<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>) : ?A {
        if (self.count == 0) return null;

        ?remove(self, buffer_utils, (self.count - 1) : Nat);
    };

    /// Swaps the values at the given indices.
    public func swap<A>(self : MemoryBuffer<A>, index_a : Nat, index_b : Nat) {
        let mem_block_a = _get_memory_blob(self, index_a);
        let mem_block_b = _get_memory_blob(self, index_b);

        let ptr_addr_a = _get_pointer(self, index_a);
        let ptr_addr_b = _get_pointer(self, index_b);

        MemoryRegion.storeBlob(self.pointers, ptr_addr_a, mem_block_b);
        MemoryRegion.storeBlob(self.pointers, ptr_addr_b, mem_block_a);
    };

    /// Swaps the value at the given index with the last index, so that it can be removed in O(1) time.
    public func swapRemove<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>, index : Nat) : A {
        if (index >= self.count) {
            Debug.trap("MemoryBuffer swapRemove(): Index out of bounds");
        };

        swap<A>(self, index, self.count - 1);
        remove<A>(self, buffer_utils, self.count - 1);
    };

    /// Reverses the order of the values in the buffer.
    public func reverse<A>(self : MemoryBuffer<A>) {
        for (i in Iter.range(0, (self.count / 2) - 1)) {
            swap<A>(self, i, self.count - i - 1);
        };
    };

    /// Clears the buffer.
    public func clear<A>(self : MemoryBuffer<A>) {
        self.count := 0;
        MemoryRegion.clear(self.pointers);
        MemoryRegion.clear(self.blobs);
        init_region_header(self);
    };

    public func clone<A>(self : MemoryBuffer<A>) : MemoryBuffer<A> {
        let new_buffer = MemoryBuffer.new<A>();

        ignore MemoryRegion.allocate(new_buffer.pointers, 12 * self.count);

        for ((i, blob) in Itertools.enumerate(blobs(self))) {
            let mb_address = MemoryRegion.addBlob(new_buffer.blobs, blob);
            let ptr_address = _get_pointer(new_buffer, i);
            MemoryRegion.storeNat64(new_buffer.pointers, ptr_address, Nat64.fromNat(mb_address));
            MemoryRegion.storeNat32(new_buffer.pointers, ptr_address + 8, Nat32.fromNat(blob.size()));
        };

        new_buffer;
    };

    /// Inserts a value at the given index.
    public func insert<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>, index : Nat, value : A) {

        if (index > self.count) {
            Debug.trap("MemoryBuffer: Index out of bounds");
        };

        if (MemoryRegion.size(self.pointers) < 64 + (POINTER_SIZE * (self.count + 1))) {
            ignore MemoryRegion.allocate(self.pointers, 12); // add space for new pointer
        };

        shift_pointers(self, index, self.count, 1);

        let blob = buffer_utils.blobify.to_blob(value);

        let mb_address = MemoryRegion.addBlob(self.blobs, blob);
        // Debug.print("inserted mb_address = " # debug_show mb_address);
        update_pointer_at_index(self, index, mb_address, blob.size());

        update_count(self, self.count + 1);
    };

    // quick sort
    public func sortUnstable<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>, mem_cmp : MemoryCmp.MemoryCmp<A>) {
        if (self.count == 0) return;

        func partition(mbuffer : MemoryBuffer<A>, mem_cmp : MemoryCmp.MemoryCmp<A>, start : Nat, end : Nat) {
            if (start >= end) {
                return;
            };

            var pivot = start;
            var i = start + 1;
            var j = start + 1;

            for (index in Iter.range(pivot + 1, end - 1)) {

                let ord = switch (mem_cmp) {
                    case (#BlobCmp(cmp)) {
                        let elem : Blob = _get_blob(mbuffer, index);
                        let pivot_elem : Blob = _get_blob(mbuffer, pivot);
                        cmp(elem, pivot_elem);
                    };
                    case (#GenCmp(cmp)) {
                        let elem : A = get(mbuffer, buffer_utils, index);
                        let pivot_elem : A = get(mbuffer, buffer_utils, pivot);
                        cmp(elem, pivot_elem);
                    };
                };

                if (ord == -1) {
                    swap(mbuffer, index, i);
                    i += 1;
                    j += 1;
                } else {
                    swap(mbuffer, index, j);
                    j += 1;
                };
            };

            pivot := Int.abs(i - 1);
            swap(mbuffer, start, pivot);

            partition(mbuffer, mem_cmp, start, pivot);

            partition(mbuffer, mem_cmp, pivot + 1, j);
        };

        partition(self, mem_cmp, 0, self.count);

    };

    /// Randomizes the order of the values in the buffer.
    public func shuffle<A>(self : MemoryBuffer<A>) {
        // shuffle utility functions ported from https://mops.one/fuzz for better performance

        if (self.count == 0) return;

        let prime = 456209410580464648418198177201;
        let prime2 = 4451889979529614097557895687536048212109;

        let seed = 0x7eadbeaf;
        var rand = seed;

        var i = 0;
        var end = self.count;

        while (i + 1 < end) {
            let start = i + 1;
            let dist = end - start : Nat;

            let j = if (dist == 1) start else {
                rand := (seed * prime + 5) % prime2;

                let max = end - 1;
                let min = start;

                let n_from_range = rand % (max - min + 1) + min;
                Int.abs(n_from_range);
            };

            swap(self, i, j);

            i += 1;
        };

    };

    public func indexOf<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>, equal : (A, A) -> Bool, element : A) : ?Nat {
        for ((i, value) in items(self, buffer_utils)) {
            if (equal(value, element)) {
                return ?i;
            };
        };

        return null;
    };

    public func lastIndexOf<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>, equal : (A, A) -> Bool, element : A) : ?Nat {
        for ((i, value) in items(self, buffer_utils).rev()) {
            if (equal(value, element)) {
                return ?i;
            };
        };

        return null;
    };

    public func contains<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>, equal : (A, A) -> Bool, element : A) : Bool {
        for (value in vals(self, buffer_utils)) {
            if (equal(value, element)) {
                return true;
            };
        };

        return false;
    };

    public func isEmpty<A>(self : MemoryBuffer<A>) : Bool {
        self.count == 0;
    };

    /// Converts a memory buffer to an array.
    public func toArray<A>(self : MemoryBuffer<A>, buffer_utils : MemoryBufferUtils<A>) : [A] {
        Array.tabulate(
            self.count,
            func(i : Nat) : A = get(self, buffer_utils, i),
        );
    };
};
