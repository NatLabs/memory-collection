/// ## Blobify
/// A module that provides a generic interface for converting
/// values to and from blobs. It is intended to be used for serializing
/// and deserializing values that will be stored in persistent stable memory.
///

import TextModule "mo:base/Text";
import CharModule "mo:base/Char";
import BlobModule "mo:base/Blob";
import ArrayModule "mo:base/Array";
import NatModule "mo:base/Nat";
import Nat8Module "mo:base/Nat8";
import Nat16Module "mo:base/Nat16";
import Nat32Module "mo:base/Nat32";
import Nat64Module "mo:base/Nat64";
import IntModule "mo:base/Int";
import Int8Module "mo:base/Int8";
import Int16Module "mo:base/Int16";
import Int32Module "mo:base/Int32";
import Int64Module "mo:base/Int64";
import PrincipalModule "mo:base/Principal";
import TimeModule "mo:base/Time";
import Debug "mo:base/Debug";

import ByteUtils "mo:byte-utils";

import Utils "../Utils";

module Blobify {

    let Base = {
        Array = ArrayModule;
        Blob = BlobModule;
        Nat = NatModule;
        Nat8 = Nat8Module;
        Nat16 = Nat16Module;
        Nat32 = Nat32Module;
        Nat64 = Nat64Module;
        Int = IntModule;
        Int8 = Int8Module;
        Int16 = Int16Module;
        Int32 = Int32Module;
        Int64 = Int64Module;
        Text = TextModule;
        Principal = PrincipalModule;
        Time = TimeModule;
    };

    type Time = TimeModule.Time;

    /// A `Blobify<A>` is a pair of functions that convert values of the generic type `A` to and from blobs.
    public type Blobify<A> = {
        to_blob : (A) -> Blob;
        from_blob : (Blob) -> A;
    };

    public let Nat8 : Blobify<Nat8> = {
        to_blob = func(n : Nat8) : Blob { Base.Blob.fromArray([n]) };
        from_blob = func(blob : Blob) : Nat8 { blob.get(0) };
    };

    public let Nat16 : Blobify<Nat16> = {
        to_blob = func(n : Nat16) : Blob {
            Base.Blob.fromArray(ByteUtils.Sorted.fromNat16(n));
        };
        from_blob = func(blob : Blob) : Nat16 {
            ByteUtils.Sorted.toNat16(blob.vals());
        };
    };

    public let Nat32 : Blobify<Nat32> = {
        to_blob = func(n : Nat32) : Blob {
            Base.Blob.fromArray(ByteUtils.Sorted.fromNat32(n));
        };
        from_blob = func(blob : Blob) : Nat32 {
            ByteUtils.Sorted.toNat32(blob.vals());
        };
    };

    public let Nat64 : Blobify<Nat64> = {
        to_blob = func(n : Nat64) : Blob {
            Base.Blob.fromArray(ByteUtils.Sorted.fromNat64(n));
        };
        from_blob = func(blob : Blob) : Nat64 {
            ByteUtils.Sorted.toNat64(blob.vals());
        };
    };

    public let Int8 : Blobify<Int8> = {
        to_blob = func(n : Int8) : Blob {
            Base.Blob.fromArray([Base.Int8.toNat8(n)]);
        };
        from_blob = func(blob : Blob) : Int8 {
            Base.Int8.fromNat8(blob.get(0));
        };
    };

    public let Int16 : Blobify<Int16> = {
        to_blob = func(n : Int16) : Blob {
            Base.Blob.fromArray(ByteUtils.Sorted.fromInt16(n));
        };
        from_blob = func(blob : Blob) : Int16 {
            ByteUtils.Sorted.toInt16(blob.vals());
        };
    };

    public let Int32 : Blobify<Int32> = {
        to_blob = func(n : Int32) : Blob {
            Base.Blob.fromArray(ByteUtils.Sorted.fromInt32(n));
        };
        from_blob = func(blob : Blob) : Int32 {
            ByteUtils.Sorted.toInt32(blob.vals());
        };
    };

    public let Int64 : Blobify<Int64> = {
        to_blob = func(n : Int64) : Blob {
            let int64_as_nat64 = Base.Int64.toNat64(n);
            Base.Blob.fromArray(ByteUtils.Sorted.fromNat64(int64_as_nat64));
        };
        from_blob = func(blob : Blob) : Int64 {
            let int64 = ByteUtils.Sorted.toNat64(blob.vals());
            Base.Int64.fromNat64(int64);
        };
    };

    public let Nat : Blobify<Nat> = {
        to_blob = func(n : Nat) : Blob {
            Nat64.to_blob(Base.Nat64.fromNat(n));
        };
        from_blob = func(blob : Blob) : Nat {
            Base.Nat64.toNat(Nat64.from_blob(blob));
        };
    };

    public let Int : Blobify<Int> = {
        to_blob = func(n : Int) : Blob {
            Int64.to_blob(Base.Int64.fromInt(n));
        };
        from_blob = func(blob : Blob) : Int {
            Base.Int64.toInt(Int64.from_blob(blob));
        };
    };

    public let Float : Blobify<Float> = {
        to_blob = func(f : Float) : Blob {
            Base.Blob.fromArray(ByteUtils.Sorted.fromFloat(f));
        };
        from_blob = func(blob : Blob) : Float {
            ByteUtils.Sorted.toFloat(blob.vals());
        };
    };

    public let Blob : Blobify<Blob> = {
        to_blob = func(b : Blob) : Blob = b;
        from_blob = func(blob : Blob) : Blob = blob;
    };

    public let Bool : Blobify<Bool> = {
        to_blob = func(b : Bool) : Blob = Base.Blob.fromArray([if (b) 1 else 0]);
        from_blob = func(blob : Blob) : Bool {
            blob == "\01";
        };
    };

    public let Char : Blobify<Char> = {
        to_blob = func(c : Char) : Blob = Base.Text.encodeUtf8(CharModule.toText(c));
        from_blob = func(blob : Blob) : Char {
            let ?t = TextModule.decodeUtf8(blob) else Debug.trap("from_blob() on Blobify.Char failed to decodeUtf8");
            let ?c = t.chars().next() else Debug.trap("from_blob() on Blobify.Char failed to get first char");
            c;
        };
    };

    public let Text : Blobify<Text> = {
        to_blob = func(t : Text) : Blob = TextModule.encodeUtf8(t);
        from_blob = func(blob : Blob) : Text {
            let ?text = TextModule.decodeUtf8(blob) else Debug.trap("from_blob() on Blobify.Text failed to decodeUtf8");
            text;
        };
    };

    public let Principal : Blobify<Principal> = {
        to_blob = func(p : Principal) : Blob { Base.Principal.toBlob(p) };
        from_blob = func(blob : Blob) : Principal {
            Base.Principal.fromBlob(blob);
        };
    };

    public let Time : Blobify<Time> = Int;

    /// `Blobify.Candid` provides a set of default helpers for serializing motoko types to candid blobs.
    /// Converting to candid offers better performance in terms of instructions but worse performance in
    /// terms of memory due to the extra type information stored in the blob.
    public module Candid {
        public let Nat : Blobify<Nat> = {
            to_blob = func(n : Nat) : Blob = to_candid (n);
            from_blob = func(blob : Blob) : Nat {
                let ?n : ?Nat = from_candid (blob) else Debug.trap("from_blob() on Blobify.Candid.Nat failed to decode Blob");
                n;
            };
        };

        public let Nat8 : Blobify<Nat8> = {
            to_blob = func(n : Nat8) : Blob = to_candid (n);
            from_blob = func(blob : Blob) : Nat8 {
                let ?n : ?Nat8 = from_candid (blob) else Debug.trap("from_blob() on Blobify.Candid.Nat8 failed to decode Blob");
                n;
            };
        };

        public let Nat16 : Blobify<Nat16> = {
            to_blob = func(n : Nat16) : Blob = to_candid (n);
            from_blob = func(blob : Blob) : Nat16 {
                let ?n : ?Nat16 = from_candid (blob) else Debug.trap("from_blob() on Blobify.Candid.Nat16 failed to decode Blob");
                n;
            };
        };

        public let Nat32 : Blobify<Nat32> = {
            to_blob = func(n : Nat32) : Blob = to_candid (n);
            from_blob = func(blob : Blob) : Nat32 {
                let ?n : ?Nat32 = from_candid (blob) else Debug.trap("from_blob() on Blobify.Candid.Nat32 failed to decode Blob");
                n;
            };
        };

        public let Nat64 : Blobify<Nat64> = {
            to_blob = func(n : Nat64) : Blob = to_candid (n);
            from_blob = func(blob : Blob) : Nat64 {
                let ?n : ?Nat64 = from_candid (blob) else Debug.trap("from_blob() on Blobify.Candid.Nat64 failed to decode Blob");
                n;
            };
        };

        public let Int : Blobify<Int> = {
            to_blob = func(n : Int) : Blob = to_candid (n);
            from_blob = func(blob : Blob) : Int {
                let ?n : ?Int = from_candid (blob) else Debug.trap("from_blob() on Blobify.Candid.Int failed to decode Blob");
                n;
            };
        };

        public let Int8 : Blobify<Int8> = {
            to_blob = func(n : Int8) : Blob = to_candid (n);
            from_blob = func(blob : Blob) : Int8 {
                let ?n : ?Int8 = from_candid (blob) else Debug.trap("from_blob() on Blobify.Candid.Int8 failed to decode Blob");
                n;
            };
        };

        public let Int16 : Blobify<Int16> = {
            to_blob = func(n : Int16) : Blob = to_candid (n);
            from_blob = func(blob : Blob) : Int16 {
                let ?n : ?Int16 = from_candid (blob) else Debug.trap("from_blob() on Blobify.Candid.Int16 failed to decode Blob");
                n;
            };
        };

        public let Int32 : Blobify<Int32> = {
            to_blob = func(n : Int32) : Blob = to_candid (n);
            from_blob = func(blob : Blob) : Int32 {
                let ?n : ?Int32 = from_candid (blob) else Debug.trap("from_blob() on Blobify.Candid.Int32 failed to decode Blob");
                n;
            };
        };

        public let Int64 : Blobify<Int64> = {
            to_blob = func(n : Int64) : Blob = to_candid (n);
            from_blob = func(blob : Blob) : Int64 {
                let ?n : ?Int64 = from_candid (blob) else Debug.trap("from_blob() on Blobify.Candid.Int64 failed to decode Blob");
                n;
            };
        };

        public let Blob : Blobify<Blob> = {
            to_blob = func(b : Blob) : Blob = to_candid (b);
            from_blob = func(blob : Blob) : Blob {
                let ?b : ?Blob = from_candid (blob) else Debug.trap("from_blob() on Blobify.Candid.Blob failed to decode Blob");
                b;
            };
        };

        public let Bool : Blobify<Bool> = {
            to_blob = func(b : Bool) : Blob = to_candid (b);
            from_blob = func(blob : Blob) : Bool {
                let ?b : ?Bool = from_candid (blob) else Debug.trap("from_blob() on Blobify.Candid.Bool failed to decode Blob");
                b;
            };
        };

        public let Char : Blobify<Char> = {
            to_blob = func(c : Char) : Blob = to_candid (c);
            from_blob = func(blob : Blob) : Char {
                let ?c : ?Char = from_candid (blob) else Debug.trap("from_blob() on Blobify.Candid.Char failed to decode Blob");
                c;
            };
        };

        public let Text : Blobify<Text> = {
            to_blob = func(t : Text) : Blob = to_candid (t);
            from_blob = func(blob : Blob) : Text {
                let ?t : ?Text = from_candid (blob) else Debug.trap("from_blob() on Blobify.Candid.Text failed to decode Blob");
                t;
            };
        };

        public let Principal : Blobify<Principal> = {
            to_blob = func(p : Principal) : Blob = to_candid (p);
            from_blob = func(blob : Blob) : Principal {
                let ?p : ?Principal = from_candid (blob) else Debug.trap("from_blob() on Blobify.Candid.Principal failed to decode Blob");
                p;
            };
        };

        public let Float : Blobify<Float> = {
            to_blob = func(f : Float) : Blob = to_candid (f);
            from_blob = func(blob : Blob) : Float {
                let ?f : ?Float = from_candid (blob) else Debug.trap("from_blob() on Blobify.Candid.Float failed to decode Blob");
                f;
            };
        };

    };

};
