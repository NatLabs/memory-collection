import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Nat64 "mo:base/Nat64";

import Bench "mo:bench";
import Fuzz "mo:fuzz";

import MemoryBuffer "../../src/MemoryBuffer/Base";

import Cmp "../../src/TypeUtils/Int8Cmp";
import TypeUtils "../../src/TypeUtils";

module {

    public func init() : Bench.Bench {
        let bench = Bench.Bench();

        bench.name("Buffer vs MemoryBuffer");
        bench.description("Benchmarking the performance with 10k entries");

        bench.cols([
            "Buffer",
            "MemoryBuffer",
        ]);

        bench.rows([
            "add()",
            "get()",
            "put() (new == prev)",
            "put() (new > prev)",
            "put() (new < prev)",
            "add() reallocation",
            "removeLast()",
            "reverse()",
            "remove()",
            "insert()",
            "shuffle()",
            "sortUnstable() #GenCmp",
            "shuffle()",
            "sortUnstable() #BlobCmp",
        ]);

        let limit = 10_000;

        func xorshift128plus(seed : Nat) : { next() : Nat } {
            var state0 : Nat64 = Nat64.fromNat(seed);
            var state1 : Nat64 = Nat64.fromNat(seed + 1);
            if (state0 == 0) state0 := 1;
            if (state1 == 0) state1 := 2;

            {
                next = func() : Nat {
                    var s1 = state0;
                    let s0 = state1;
                    state0 := s0;
                    s1 ^= s1 << 23 : Nat64;
                    state1 := s1 ^ s0 ^ (s1 >> 18 : Nat64) ^ (s0 >> 5 : Nat64);
                    Nat64.toNat(state1 +% s0); // Use wrapping addition
                };
            };
        };

        let fuzz = Fuzz.create(xorshift128plus(0xdeadbeef));

        let buffer = Buffer.Buffer<Blob>(limit);
        let mbuffer = MemoryBuffer.new<Blob>();

        let order = Buffer.Buffer<Nat>(limit);
        let values = Buffer.Buffer<Blob>(limit);
        let values2 = Buffer.Buffer<Blob>(limit);
        let greater = Buffer.Buffer<Blob>(limit);
        let less = Buffer.Buffer<Blob>(limit);

        for (i in Iter.range(0, limit - 1)) {
            let blob = fuzz.blob.randomBlob(10);
            let blob2 = fuzz.blob.randomBlob(10);
            let higher = fuzz.blob.randomBlob(20);
            let lower = fuzz.blob.randomBlob(5);

            order.add(i);
            values.add(blob);
            values2.add(blob2);
            greater.add(higher);

            less.add(lower);
        };

        fuzz.buffer.shuffle(order);

        bench.runner(
            func(row, col) = switch (col, row) {

                case ("Buffer", "add()" or "add() reallocation") {
                    for (i in Iter.range(0, limit - 1)) {
                        let val = values.get(i);
                        buffer.add(val);
                    };
                };
                case ("Buffer", "get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        ignore buffer.get(i);
                    };
                };
                case ("Buffer", "put() (new == prev)") {
                    for (i in Iter.range(0, limit - 1)) {
                        let val = values2.get(i);
                        buffer.put(i, val);
                    };
                };
                case ("Buffer", "put() (new > prev)") {
                    for (i in order.vals()) {
                        let val = greater.get(i);
                        buffer.put(i, val);
                    };
                };
                case ("Buffer", "put() (new < prev)") {
                    for (i in order.vals()) {
                        let val = less.get(i);
                        buffer.put(i, val);
                    };
                };
                case ("Buffer", "remove()") {
                    for (i in order.vals()) {
                        ignore buffer.remove(Nat.min(i, buffer.size() - 1));
                    };
                };
                case ("Buffer", "insert()") {
                    for (i in order.vals()) {
                        let val = values2.get(i);
                        buffer.insert(Nat.min(i, buffer.size()), val);
                    };
                };
                case ("Buffer", "reverse()") {
                    Buffer.reverse(buffer);
                };
                case ("Buffer", "sortUnstable() #GenCmp") {
                    buffer.sort(Blob.compare);
                };
                case ("Buffer", "sortUnstable() #BlobCmp") {};
                case ("Buffer", "shuffle()") {
                    // fuzz.buffer.shuffle(buffer);
                };
                case ("Buffer", "removeLast()") {
                    for (_ in Iter.range(0, limit - 1)) {
                        ignore buffer.removeLast();
                    };
                };

                case ("MemoryBuffer", "add()" or "add() reallocation") {
                    for (i in Iter.range(0, limit - 1)) {
                        let val = values.get(i);
                        MemoryBuffer.add(mbuffer, TypeUtils.Blob, val);
                    };

                    Debug.print("mbuffer bytes: " # debug_show MemoryBuffer.bytes(mbuffer));
                    Debug.print("mbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(mbuffer));
                    Debug.print("mbuffer capacity: " # debug_show MemoryBuffer.capacity(mbuffer));

                };
                case ("MemoryBuffer", "get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        ignore MemoryBuffer.get(mbuffer, TypeUtils.Blob, i);
                    };

                };
                case ("MemoryBuffer", "put() (new == prev)") {
                    for (i in order.vals()) {
                        let val = values2.get(i);
                        MemoryBuffer.put(mbuffer, TypeUtils.Blob, i, val);
                    };
                    Debug.print("mbuffer bytes: " # debug_show MemoryBuffer.bytes(mbuffer));
                    Debug.print("mbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(mbuffer));
                    Debug.print("mbuffer capacity: " # debug_show MemoryBuffer.capacity(mbuffer));

                };
                case ("MemoryBuffer", "put() (new > prev)") {
                    for (i in order.vals()) {
                        let val = greater.get(i);
                        MemoryBuffer.put(mbuffer, TypeUtils.Blob, i, val);
                    };
                    Debug.print("mbuffer bytes: " # debug_show MemoryBuffer.bytes(mbuffer));
                    Debug.print("mbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(mbuffer));
                    Debug.print("mbuffer capacity: " # debug_show MemoryBuffer.capacity(mbuffer));

                };
                case ("MemoryBuffer", "put() (new < prev)") {
                    for (i in order.vals()) {
                        let val = less.get(i);
                        MemoryBuffer.put(mbuffer, TypeUtils.Blob, i, val);
                    };
                    Debug.print("mbuffer bytes: " # debug_show MemoryBuffer.bytes(mbuffer));
                    Debug.print("mbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(mbuffer));
                    Debug.print("mbuffer capacity: " # debug_show MemoryBuffer.capacity(mbuffer));

                };
                case ("MemoryBuffer", "remove()") {
                    for (i in order.vals()) {
                        let j = Nat.min(i, MemoryBuffer.size(mbuffer) - 1);

                        ignore MemoryBuffer.remove(mbuffer, TypeUtils.Blob, j);
                    };
                    Debug.print("mbuffer bytes: " # debug_show MemoryBuffer.bytes(mbuffer));
                    Debug.print("mbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(mbuffer));
                    Debug.print("mbuffer capacity: " # debug_show MemoryBuffer.capacity(mbuffer));

                };
                case ("MemoryBuffer", "insert()") {
                    for (i in order.vals()) {
                        let val = values2.get(i);
                        MemoryBuffer.insert(mbuffer, TypeUtils.Blob, Nat.min(i, MemoryBuffer.size(mbuffer)), val);
                    };
                };
                case ("MemoryBuffer", "reverse()") {
                    MemoryBuffer.reverse(mbuffer);
                };
                case ("MemoryBuffer", "sortUnstable() #GenCmp") {
                    MemoryBuffer.sortUnstable(mbuffer, TypeUtils.Blob, #GenCmp(Cmp.Blob));
                };
                case ("MemoryBuffer", "shuffle()") {
                    MemoryBuffer.shuffle(mbuffer);
                };
                case ("MemoryBuffer", "sortUnstable() #BlobCmp") {
                    MemoryBuffer.sortUnstable(mbuffer, TypeUtils.Blob, #BlobCmp(Cmp.Blob));
                };
                case ("MemoryBuffer", "removeLast()") {
                    for (_ in Iter.range(0, limit - 1)) {
                        ignore MemoryBuffer.removeLast(mbuffer, TypeUtils.Blob);
                    };
                };

                case (_) {
                    Debug.trap("Should not reach with row = " # debug_show row # " and col = " # debug_show col);
                };
            }
        );

        bench;
    };
};
