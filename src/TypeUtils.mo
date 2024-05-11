import Blobify "Blobify";
import MemoryCmp "MemoryCmp";
import Int8Cmp "Int8Cmp";

module {

    public type Blobify<A> = Blobify.Blobify<A>;
    public type MemoryCmp<A> = MemoryCmp.MemoryCmp<A>;
    public type Hash<A> = (A) -> Nat64;   

    /// Common utilities for a given type
    /// Contains blobify, cmp and hash functions
    public type TypeUtils<K> = {
        blobify: Blobify<K>;
        cmp: MemoryCmp<K>;
    };

    public module BigEndian = {
        public let Nat : TypeUtils<Nat> = {
            blobify = Blobify.BigEndian.Nat;
            cmp = MemoryCmp.BigEndian.Nat;
        };

        public let Nat8 : TypeUtils<Nat8> = {
            blobify = Blobify.BigEndian.Nat8;
            cmp = MemoryCmp.BigEndian.Nat8;
        };

        public let Nat16 : TypeUtils<Nat16> = {
            blobify = Blobify.BigEndian.Nat16;
            cmp = MemoryCmp.BigEndian.Nat16;
        };

        public let Nat32 : TypeUtils<Nat32> = {
            blobify = Blobify.BigEndian.Nat32;
            cmp = MemoryCmp.BigEndian.Nat32;
        };

        public let Nat64 : TypeUtils<Nat64> = {
            blobify = Blobify.BigEndian.Nat64;
            cmp = MemoryCmp.BigEndian.Nat64;
        };

    };

    public let Nat  : TypeUtils<Nat> = {
        blobify = Blobify.Nat;
        cmp = MemoryCmp.Nat;
    };

    public let Nat8  : TypeUtils<Nat8> = {
        blobify = Blobify.Nat8;
        cmp = MemoryCmp.Nat8;
    };

    public let Nat16  : TypeUtils<Nat16> = {
        blobify = Blobify.Nat16;
        cmp = MemoryCmp.Nat16;
    };

    public let Nat32  : TypeUtils<Nat32> = {
        blobify = Blobify.Nat32;
        cmp = MemoryCmp.Nat32;
    };

    public let Nat64  : TypeUtils<Nat64> = {
        blobify = Blobify.Nat64;
        cmp = MemoryCmp.Nat64;
    };

    public let Blob  : TypeUtils<Blob> = {
        blobify = Blobify.Blob;
        cmp = MemoryCmp.Blob;
    };

    public let Bool  : TypeUtils<Bool> = {
        blobify = Blobify.Bool;
        cmp = MemoryCmp.Bool;
    };

    public let Text  : TypeUtils<Text> = {
        blobify = Blobify.Text;
        cmp = MemoryCmp.Text;
    };

    public let Char  : TypeUtils<Char> = {
        blobify = Blobify.Char;
        cmp = MemoryCmp.Char;
    };

    public let Principal  : TypeUtils<Principal> = {
        blobify = Blobify.Principal;
        cmp = MemoryCmp.Principal;
    };


    /// BTree Utils for motoko types using candid serialization
    public module Candid {
        public let Nat : TypeUtils<Nat> = {
            blobify = Blobify.Candid.Nat;
            cmp = #GenCmp(Int8Cmp.Nat);
        };

        public let Nat8 : TypeUtils<Nat8> = {
            blobify = Blobify.Candid.Nat8;
            cmp = #BlobCmp(Int8Cmp.Blob);
        };

        // Using #GenCmp because its serialized as little endian 
        // and must be deserialized before it can be compared
        public let Nat16 : TypeUtils<Nat16> = {
            blobify = Blobify.Candid.Nat16;
            cmp = #GenCmp(Int8Cmp.Nat16);
        };

        public let Nat32 : TypeUtils<Nat32> = {
            blobify = Blobify.Candid.Nat32;
            cmp = #GenCmp(Int8Cmp.Nat32);
        };

        public let Nat64 : TypeUtils<Nat64> = {
            blobify = Blobify.Candid.Nat64;
            cmp = #GenCmp(Int8Cmp.Nat64);
        };

        public let Int : TypeUtils<Int> = {
            blobify = Blobify.Candid.Int;
            cmp = #GenCmp(Int8Cmp.Int);
        };

        public let Int8 : TypeUtils<Int8> = {
            blobify = Blobify.Candid.Int8;
            cmp = #GenCmp(Int8Cmp.Int8);
        };

        public let Int16 : TypeUtils<Int16> = {
            blobify = Blobify.Candid.Int16;
            cmp = #GenCmp(Int8Cmp.Int16);
        };

        public let Int32 : TypeUtils<Int32> = {
            blobify = Blobify.Candid.Int32;
            cmp = #GenCmp(Int8Cmp.Int32);
        };

        public let Int64 : TypeUtils<Int64> = {
            blobify = Blobify.Candid.Int64;
            cmp = #GenCmp(Int8Cmp.Int64);
        };

        public let Float : TypeUtils<Float> = {
            blobify = Blobify.Candid.Float;
            cmp = #GenCmp(Int8Cmp.Float);
        };

        public let Bool : TypeUtils<Bool> = {
            blobify = Blobify.Candid.Bool;
            cmp = #BlobCmp(Int8Cmp.Blob);
        };

        public let Text : TypeUtils<Text> = {
            blobify = Blobify.Candid.Text;
            cmp = #BlobCmp(Int8Cmp.Blob);
        };

        public let Principal : TypeUtils<Principal> = {
            blobify = Blobify.Candid.Principal;
            cmp = #BlobCmp(Int8Cmp.Blob);
        };

        public let Char : TypeUtils<Char> = {
            blobify = Blobify.Candid.Char;
            cmp = #BlobCmp(Int8Cmp.Blob);
        };
        
    };
}