import Iter "mo:core@2.4/Iter";
import Buffer "mo:base@0.16/Buffer";
import Nat "mo:core@2.4/Nat";
import Blob "mo:core@2.4/Blob";
import Debug "mo:core@2.4/Debug";
import Runtime "mo:core@2.4/Runtime";
import Nat64 "mo:core@2.4/Nat64";

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
      "shuffle()",
      "sortUnstable() #BlobCmp",
    ]);

    let limit = 10_000;

    let fuzz = Fuzz.fromSeed(0xdeadbeef);

    let buffer = Buffer.Buffer<Blob>(limit);
    let mbuffer = MemoryBuffer.new<Blob>();

    let order = Buffer.Buffer<Nat>(limit);
    let values = Buffer.Buffer<Blob>(limit);
    let values2 = Buffer.Buffer<Blob>(limit);
    let greater = Buffer.Buffer<Blob>(limit);
    let less = Buffer.Buffer<Blob>(limit);

    for (i in Nat.rangeInclusive(0, limit - 1)) {
      let size = fuzz.nat.randomRange(25, 50);

      let blob = fuzz.blob.randomBlob(size);
      let blob2 = fuzz.blob.randomBlob(size);
      let higher = fuzz.blob.randomBlob(fuzz.nat.randomRange(50, 100));
      let lower = fuzz.blob.randomBlob(fuzz.nat.randomRange(0, 25));

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
          for (i in Nat.rangeInclusive(0, limit - 1)) {
            let val = values.get(i);
            buffer.add(val);
          };
        };
        case ("Buffer", "get()") {
          for (i in Nat.rangeInclusive(0, limit - 1)) {
            ignore buffer.get(i);
          };
        };
        case ("Buffer", "put() (new == prev)") {
          for (i in Nat.rangeInclusive(0, limit - 1)) {
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

        case ("Buffer", "sortUnstable() #BlobCmp") {};
        case ("Buffer", "shuffle()") {
          // fuzz.buffer.shuffle(buffer);
        };
        case ("Buffer", "removeLast()") {
          for (_ in Nat.rangeInclusive(0, limit - 1)) {
            ignore buffer.removeLast();
          };
        };

        case ("MemoryBuffer", "add()" or "add() reallocation") {
          for (i in Nat.rangeInclusive(0, limit - 1)) {
            let val = values.get(i);
            MemoryBuffer.add(mbuffer, TypeUtils.Blob, val);
          };

        };
        case ("MemoryBuffer", "get()") {
          for (i in Nat.rangeInclusive(0, limit - 1)) {
            ignore MemoryBuffer.get(mbuffer, TypeUtils.Blob, i);
          };

        };
        case ("MemoryBuffer", "put() (new == prev)") {
          for (i in order.vals()) {
            let val = values2.get(i);
            MemoryBuffer.put(mbuffer, TypeUtils.Blob, i, val);
          };

        };
        case ("MemoryBuffer", "put() (new > prev)") {
          for (i in order.vals()) {
            let val = greater.get(i);
            MemoryBuffer.put(mbuffer, TypeUtils.Blob, i, val);
          };

        };
        case ("MemoryBuffer", "put() (new < prev)") {
          for (i in order.vals()) {
            let val = less.get(i);
            MemoryBuffer.put(mbuffer, TypeUtils.Blob, i, val);
          };

        };
        case ("MemoryBuffer", "remove()") {
          for (i in order.vals()) {
            let j = Nat.min(i, MemoryBuffer.size(mbuffer) - 1);

            ignore MemoryBuffer.remove(mbuffer, TypeUtils.Blob, j);
          };

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

        case ("MemoryBuffer", "shuffle()") {
          MemoryBuffer.shuffle(mbuffer);
        };
        case ("MemoryBuffer", "sortUnstable() #BlobCmp") {
          MemoryBuffer.sortUnstable(mbuffer, TypeUtils.Blob, #BlobCmp(Cmp.Blob));
        };
        case ("MemoryBuffer", "removeLast()") {
          for (_ in Nat.rangeInclusive(0, limit - 1)) {
            ignore MemoryBuffer.removeLast(mbuffer, TypeUtils.Blob);
          };
        };

        case (_) {
          Runtime.trap("Should not reach with row = " # debug_show row # " and col = " # debug_show col);
        };
      }
    );

    bench;
  };
};
