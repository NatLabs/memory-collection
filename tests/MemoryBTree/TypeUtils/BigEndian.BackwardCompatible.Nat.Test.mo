// @testmode wasi
import Prim "mo:prim";

import Array "mo:core@2.4/Array";
import Nat8 "mo:core@2.4/Nat8";
import Blob "mo:core@2.4/Blob";
import Debug "mo:core@2.4/Debug";
import Nat "mo:core@2.4/Nat";
import Nat64 "mo:core@2.4/Nat64";
import Iter "mo:core@2.4/Iter";
import Buffer "mo:base@0.16/Buffer";
import { test; suite } "mo:test";

import Fuzz "mo:fuzz";
import Itertools "mo:itertools@0.2/Iter";

import MemoryBTree "../../../src/MemoryBTree/Base";
import TypeUtils "../../../src/TypeUtils";
import Utils "../../../src/Utils";
import Branch "../../../src/MemoryBTree/modules/Branch";
import Leaf "../../../src/MemoryBTree/modules/Leaf";
import Methods "../../../src/MemoryBTree/modules/Methods";

let legacy_btree = MemoryBTree.new(?32);
let legacy_btree_utils = MemoryBTree.createUtils(TypeUtils.Legacy.BigEndian.Nat, TypeUtils.Legacy.Nat);

let btree = MemoryBTree.new(?32);
let btree_utils = MemoryBTree.createUtils(TypeUtils.Nat, TypeUtils.Nat);

let fuzz = Fuzz.fromSeed(0x29);

suite(
  "MemoryBTree Big Endian TypeUtils Test",
  func() {
    let sorted = Buffer.Buffer<(Nat, Nat)>(10_000);

    test(
      "Ensure legacy and current serializers are sorted correctly",
      func() {

        for (i in Nat.rangeInclusive(0, 10)) {
          let key = fuzz.nat.randomRange(0, (2 ** 64) - 1);
          let val = fuzz.nat.randomRange(0, (2 ** 64) - 1);

          ignore MemoryBTree.insert<Nat, Nat>(legacy_btree, legacy_btree_utils, key, val);
          ignore MemoryBTree.insert<Nat, Nat>(btree, btree_utils, key, val);
          sorted.add((key, val));
        };

        sorted.sort(func(a, b) = Nat.compare(a.0, b.0));

        assert Itertools.equal(
          MemoryBTree.entries(legacy_btree, legacy_btree_utils),
          sorted.vals(),
          func(a : (Nat, Nat), b : (Nat, Nat)) : Bool = a.0 == b.0 and a.1 == b.1,
        );

        assert Itertools.equal(
          MemoryBTree.entries(btree, btree_utils),
          sorted.vals(),
          func(a : (Nat, Nat), b : (Nat, Nat)) : Bool = a.0 == b.0 and a.1 == b.1,
        );
      },
    );

  },
);
