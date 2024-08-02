import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Float "mo:base/Float";

import Bench "mo:bench";
import Fuzz "mo:fuzz";

import MemoryBuffer "../../src/MemoryBuffer/Base";
import Cmp "../../src/TypeUtils/Int8Cmp";
import TypeUtils "../../src/TypeUtils";

module {

    let candid_blobify = TypeUtils.Candid.Text;

    public func init() : Bench.Bench {
        let bench = Bench.Bench();

        bench.name("Buffer vs MemoryBuffer");
        bench.description("Benchmarking the performance with 10k entries");

        bench.cols([
            "Buffer",
            "MemoryBuffer (with Blobify)",
            "MemoryBuffer (encode to candid)",
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

        let fuzz = Fuzz.fromSeed(0x7f7f);

        let buffer = Buffer.Buffer<Text>(limit);
        let mbuffer = MemoryBuffer.new<Text>();
        let cbuffer = MemoryBuffer.new<Text>();

        let order = Buffer.Buffer<Nat>(limit);
        let values = Buffer.Buffer<Text>(limit);
        let values2 = Buffer.Buffer<Text>(limit);
        let greater = Buffer.Buffer<Text>(limit);
        let less = Buffer.Buffer<Text>(limit);

        func logn(number : Float, base : Float) : Float {
            Float.log(number) / Float.log(base);
        };

        for (i in Iter.range(0, limit - 1)) {
            let n1 = fuzz.text.randomAlphanumeric(10);
            let n2 = fuzz.text.randomAlphanumeric(10);

            let l = fuzz.text.randomAlphanumeric(5);
            let g = fuzz.text.randomAlphanumeric(15);

            order.add(i);
            values.add(n1);
            values2.add(n2);
            greater.add(g);
            less.add(l);
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
                        buffer.insert(Nat.min(i, buffer.size()), values.get(i));
                    };
                };
                case ("Buffer", "reverse()") {
                    Buffer.reverse(buffer);
                };
                case ("Buffer", "sortUnstable() #GenCmp") {
                    buffer.sort(Text.compare);
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

                case ("MemoryBuffer (encode to candid)", "add()" or "add() reallocation") {
                    for (i in Iter.range(0, limit - 1)) {
                        let val = values.get(i);
                        MemoryBuffer.add(cbuffer, candid_blobify, val);
                    };
                    Debug.print("cbuffer bytes: " # debug_show MemoryBuffer.bytes(cbuffer));
                    Debug.print("cbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(cbuffer));
                    Debug.print("cbuffer capacity: " # debug_show MemoryBuffer.capacity(cbuffer));

                };
                case ("MemoryBuffer (encode to candid)", "get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        ignore MemoryBuffer.get(cbuffer, candid_blobify, i);
                    };

                };
                case ("MemoryBuffer (encode to candid)", "put() (new == prev)") {
                    for (i in order.vals()) {
                        let val = values2.get(i);
                        MemoryBuffer.put(cbuffer, candid_blobify, i, val);
                    };
                    Debug.print("cbuffer bytes: " # debug_show MemoryBuffer.bytes(cbuffer));
                    Debug.print("cbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(cbuffer));
                    Debug.print("cbuffer capacity: " # debug_show MemoryBuffer.capacity(cbuffer));

                };
                case ("MemoryBuffer (encode to candid)", "put() (new > prev)") {
                    for (i in order.vals()) {
                        let val = greater.get(i);
                        MemoryBuffer.put(cbuffer, candid_blobify, i, val);
                    };
                    Debug.print("cbuffer bytes: " # debug_show MemoryBuffer.bytes(cbuffer));
                    Debug.print("cbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(cbuffer));
                    Debug.print("cbuffer capacity: " # debug_show MemoryBuffer.capacity(cbuffer));

                };
                case ("MemoryBuffer (encode to candid)", "put() (new < prev)") {
                    for (i in order.vals()) {
                        let val = less.get(i);
                        MemoryBuffer.put(cbuffer, candid_blobify, i, val);
                    };
                    Debug.print("cbuffer bytes: " # debug_show MemoryBuffer.bytes(cbuffer));
                    Debug.print("cbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(cbuffer));
                    Debug.print("cbuffer capacity: " # debug_show MemoryBuffer.capacity(cbuffer));

                };
                case ("MemoryBuffer (encode to candid)", "remove()") {
                    for (i in order.vals()) {
                        let j = Nat.min(i, MemoryBuffer.size(cbuffer) - 1);

                        ignore MemoryBuffer.remove(cbuffer, candid_blobify, j);
                    };
                    Debug.print("cbuffer bytes: " # debug_show MemoryBuffer.bytes(cbuffer));
                    Debug.print("cbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(cbuffer));
                    Debug.print("cbuffer capacity: " # debug_show MemoryBuffer.capacity(cbuffer));

                };
                case ("MemoryBuffer (encode to candid)", "insert()") {
                    for (i in order.vals()) {
                        MemoryBuffer.insert(cbuffer, candid_blobify, Nat.min(i, MemoryBuffer.size(cbuffer)), values.get(i));
                    };
                };
                case ("MemoryBuffer (encode to candid)", "reverse()") {
                    MemoryBuffer.reverse(cbuffer);
                };
                case ("MemoryBuffer (encode to candid)", "sortUnstable() #GenCmp") {
                    MemoryBuffer.sortUnstable(cbuffer, candid_blobify, #GenCmp(Cmp.Text));
                };
                case ("MemoryBuffer (encode to candid)", "sortUnstable() #BlobCmp") {};
                case ("MemoryBuffer (encode to candid)", "shuffle()") {
                    MemoryBuffer.shuffle(cbuffer);
                };
                case ("MemoryBuffer (encode to candid)", "removeLast()") {
                    for (_ in Iter.range(0, limit - 1)) {
                        ignore MemoryBuffer.removeLast(cbuffer, candid_blobify);
                    };
                };

                case ("MemoryBuffer (with Blobify)", "add()" or "add() reallocation") {
                    for (i in Iter.range(0, limit - 1)) {
                        let val = values.get(i);
                        MemoryBuffer.add(mbuffer, TypeUtils.Text, val);
                    };

                    Debug.print("mbuffer bytes: " # debug_show MemoryBuffer.bytes(mbuffer));
                    Debug.print("mbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(mbuffer));
                    Debug.print("mbuffer capacity: " # debug_show MemoryBuffer.capacity(mbuffer));

                };
                case ("MemoryBuffer (with Blobify)", "get()") {
                    for (i in Iter.range(0, limit - 1)) {
                        ignore MemoryBuffer.get(mbuffer, TypeUtils.Text, i);
                    };

                };
                case ("MemoryBuffer (with Blobify)", "put() (new == prev)") {
                    for (i in order.vals()) {
                        let val = values2.get(i);
                        MemoryBuffer.put(mbuffer, TypeUtils.Text, i, val);
                    };
                    Debug.print("mbuffer bytes: " # debug_show MemoryBuffer.bytes(mbuffer));
                    Debug.print("mbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(mbuffer));
                    Debug.print("mbuffer capacity: " # debug_show MemoryBuffer.capacity(mbuffer));

                };
                case ("MemoryBuffer (with Blobify)", "put() (new > prev)") {
                    for (i in order.vals()) {
                        let val = greater.get(i);
                        MemoryBuffer.put(mbuffer, TypeUtils.Text, i, val);
                    };
                    Debug.print("mbuffer bytes: " # debug_show MemoryBuffer.bytes(mbuffer));
                    Debug.print("mbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(mbuffer));
                    Debug.print("mbuffer capacity: " # debug_show MemoryBuffer.capacity(mbuffer));

                };
                case ("MemoryBuffer (with Blobify)", "put() (new < prev)") {
                    for (i in order.vals()) {
                        let val = less.get(i);
                        MemoryBuffer.put(mbuffer, TypeUtils.Text, i, val);
                    };
                    Debug.print("mbuffer bytes: " # debug_show MemoryBuffer.bytes(mbuffer));
                    Debug.print("mbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(mbuffer));
                    Debug.print("mbuffer capacity: " # debug_show MemoryBuffer.capacity(mbuffer));

                };
                case ("MemoryBuffer (with Blobify)", "remove()") {
                    for (i in order.vals()) {
                        let j = Nat.min(i, MemoryBuffer.size(mbuffer) - 1);

                        ignore MemoryBuffer.remove(mbuffer, TypeUtils.Text, j);
                    };
                    Debug.print("mbuffer bytes: " # debug_show MemoryBuffer.bytes(mbuffer));
                    Debug.print("mbuffer metadataBytes: " # debug_show MemoryBuffer.metadataBytes(mbuffer));
                    Debug.print("mbuffer capacity: " # debug_show MemoryBuffer.capacity(mbuffer));

                };
                case ("MemoryBuffer (with Blobify)", "insert()") {
                    for (i in order.vals()) {
                        MemoryBuffer.insert(mbuffer, TypeUtils.Text, Nat.min(i, MemoryBuffer.size(mbuffer)), values.get(i));
                    };
                };
                case ("MemoryBuffer (with Blobify)", "reverse()") {
                    MemoryBuffer.reverse(mbuffer);
                };
                case ("MemoryBuffer (with Blobify)", "sortUnstable() #GenCmp") {
                    MemoryBuffer.sortUnstable(mbuffer, TypeUtils.Text, #GenCmp(Cmp.Text));
                };
                case ("MemoryBuffer (with Blobify)", "shuffle()") {
                    MemoryBuffer.shuffle(mbuffer);
                };
                case ("MemoryBuffer (with Blobify)", "sortUnstable() #BlobCmp") {
                    MemoryBuffer.sortUnstable(mbuffer, TypeUtils.Text, #BlobCmp(Cmp.Blob));
                };
                case ("MemoryBuffer (with Blobify)", "removeLast()") {
                    for (_ in Iter.range(0, limit - 1)) {
                        ignore MemoryBuffer.removeLast(mbuffer, TypeUtils.Text);
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
