/// The TypeUtils module provides common utilities for a given type.
/// - Blobify: A function that serializes a value of type A to a blob.
/// - MemoryCmp: A function that compares two values of type A in memory.
import Prim "mo:prim";

import BlobifyModule "Blobify";
import MemoryCmpModule "MemoryCmp";
import Int8CmpModule "Int8Cmp";
import WyHash64 "WyHash64";

import Utils "../Utils";

module {

    public let Blobify = BlobifyModule;
    public let MemoryCmp = MemoryCmpModule;
    public let Int8Cmp = Int8CmpModule;
    public let Hash = WyHash64;

    public let {
        concat_blobs;
    } = Utils;

    public type Blobify<A> = Blobify.Blobify<A>;
    public type MemoryCmp<A> = MemoryCmp.MemoryCmp<A>;
    public type Hash<A> = (A) -> Nat64;

    /// Common utilities for a given type
    /// Contains blobify, cmp and hash functions
    public type TypeUtils<K> = {
        blobify : Blobify<K>;
        cmp : MemoryCmp<K>;
    };

    public let Nat : TypeUtils<Nat> = {
        blobify = Blobify.Nat;
        cmp = MemoryCmp.Default;
    };

    public let Nat8 : TypeUtils<Nat8> = {
        blobify = Blobify.Nat8;
        cmp = MemoryCmp.Default;
    };

    public let Nat16 : TypeUtils<Nat16> = {
        blobify = Blobify.Nat16;
        cmp = MemoryCmp.Default;
    };

    public let Nat32 : TypeUtils<Nat32> = {
        blobify = Blobify.Nat32;
        cmp = MemoryCmp.Default;
    };

    public let Nat64 : TypeUtils<Nat64> = {
        blobify = Blobify.Nat64;
        cmp = MemoryCmp.Default;
    };

    public let Int : TypeUtils<Int> = {
        blobify = Blobify.Int;
        cmp = MemoryCmp.Default;
    };

    public let Float : TypeUtils<Float> = {
        blobify = Blobify.Float;
        cmp = MemoryCmp.Default;
    };

    public let Int8 : TypeUtils<Int8> = {
        blobify = Blobify.Int8;
        cmp = MemoryCmp.Default;
    };

    public let Int16 : TypeUtils<Int16> = {
        blobify = Blobify.Int16;
        cmp = MemoryCmp.Default;
    };

    public let Int32 : TypeUtils<Int32> = {
        blobify = Blobify.Int32;
        cmp = MemoryCmp.Default;
    };

    public let Int64 : TypeUtils<Int64> = {
        blobify = Blobify.Int64;
        cmp = MemoryCmp.Default;
    };

    public let Blob : TypeUtils<Blob> = {
        blobify = Blobify.Blob;
        cmp = MemoryCmp.Default;
    };

    public let Bool : TypeUtils<Bool> = {
        blobify = Blobify.Bool;
        cmp = MemoryCmp.Default;
    };

    public let Text : TypeUtils<Text> = {
        blobify = Blobify.Text;
        cmp = MemoryCmp.Default;
    };

    public let Char : TypeUtils<Char> = {
        blobify = Blobify.Char;
        cmp = MemoryCmp.Default;
    };

    public let Principal : TypeUtils<Principal> = {
        blobify = Blobify.Principal;
        cmp = MemoryCmp.Default;
    };

    public let Time : TypeUtils<Int> = {
        blobify = Blobify.Time;
        cmp = MemoryCmp.Default;
    };

    public module Legacy {

        public let Nat : TypeUtils<Nat> = {
            blobify = Blobify.Legacy.Nat;
            cmp = MemoryCmp.Legacy.Nat;
        };

        public let Int : TypeUtils<Int> = {
            blobify = Blobify.Int;
            cmp = MemoryCmp.Legacy.Int;
        };

        public module BigEndian {
            public let Nat : TypeUtils<Nat> = {
                blobify = Blobify.Legacy.BigEndian.Nat;
                cmp = MemoryCmp.Legacy.BigEndian.Nat;
            };

            public let Int : TypeUtils<Int> = {
                blobify = Blobify.Int;
                cmp = MemoryCmp.Legacy.BigEndian.Int;
            };
        };

    };

};
