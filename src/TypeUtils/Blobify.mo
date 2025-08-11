/// ## Blobify
/// A module that provides a generic interface for converting
/// values to and from blobs. It is intended to be used for serializing
/// and deserializing values that will be stored in persistent stable memory.
///

import TextModule "mo:base@0.14.11/Text";
import CharModule "mo:base@0.14.11/Char";
import BlobModule "mo:base@0.14.11/Blob";
import ArrayModule "mo:base@0.14.11/Array";
import NatModule "mo:base@0.14.11/Nat";
import Nat8Module "mo:base@0.14.11/Nat8";
import Nat16Module "mo:base@0.14.11/Nat16";
import Nat32Module "mo:base@0.14.11/Nat32";
import Nat64Module "mo:base@0.14.11/Nat64";
import IntModule "mo:base@0.14.11/Int";
import Int8Module "mo:base@0.14.11/Int8";
import Int16Module "mo:base@0.14.11/Int16";
import Int32Module "mo:base@0.14.11/Int32";
import Int64Module "mo:base@0.14.11/Int64";
import PrincipalModule "mo:base@0.14.11/Principal";
import TimeModule "mo:base@0.14.11/Time";
import Debug "mo:base@0.14.11/Debug";

import ByteUtils "mo:byte-utils@0.0.1";

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

    public module Legacy {
        public let Int : Blobify<Int> = {
            to_blob = func(n : Int) : Blob {
                let is_negative = n < 0;

                var num : Nat = Base.Int.abs(n);
                var nbytes = 0;

                while (num > 0) {
                    num /= 255;
                    nbytes += 1;
                };

                num := Base.Int.abs(n);

                let arr = ArrayModule.tabulate(
                    nbytes + 1,
                    func(i : Nat) : Nat8 {
                        if (i == nbytes) return Base.Nat8.fromNat(if (is_negative) 1 else 0);

                        let tmp = num % 255;
                        num /= 255;
                        Nat8Module.fromNat(tmp);
                    },
                );

                Base.Blob.fromArray(arr);
            };

            from_blob = func(blob : Blob) : Int {
                let bytes = Base.Blob.toArray(blob);

                var n = 0;
                var is_negative = false;

                var j = bytes.size();

                while (j > 0) {
                    let byte = bytes.get(j - 1);
                    if (j == 1) {
                        is_negative := Base.Nat8.toNat(byte) == 1;
                    } else {
                        n *= 255;
                        n += Base.Nat8.toNat(byte);
                    };

                    j -= 1;
                };

                if (is_negative) {
                    -(n);
                } else {
                    (n);
                };
            };
        };

        // Default blobify helpers return blobs in little-endian format.
        public let Nat : Blobify<Nat> = {
            to_blob = func(n : Nat) : Blob {
                var num = n;
                var nbytes = 0;

                while (num > 0) {
                    num /= 255;
                    nbytes += 1;
                };

                num := n;

                let arr = Base.Array.tabulate(
                    nbytes,
                    func(_ : Nat) : Nat8 {
                        let tmp = num % 255;
                        num /= 255;
                        Nat8Module.fromNat(tmp);
                    },
                );

                Base.Blob.fromArray(arr);
            };
            from_blob = func(blob : Blob) : Nat {
                var n = 0;
                let bytes = Base.Blob.toArray(blob);

                var j = bytes.size();

                while (j > 0) {
                    let byte = bytes.get(j - 1);
                    n *= 255;
                    n += Base.Nat8.toNat(byte);

                    j -= 1;
                };

                n;
            };
        };

        /// Default blobify helpers return blobs in big-endian format.
        public module BigEndian {
            public let Nat : Blobify<Nat> = {
                to_blob = func(n : Nat) : Blob {
                    var num = n;
                    var nbytes = 0;

                    while (num > 0) {
                        num /= 255;
                        nbytes += 1;
                    };

                    num := n;

                    let arr = ArrayModule.reverse(
                        ArrayModule.tabulate(
                            nbytes,
                            func(_ : Nat) : Nat8 {
                                let tmp = num % 255;
                                num /= 255;
                                Nat8Module.fromNat(tmp);
                            },
                        )
                    );

                    Base.Blob.fromArray(arr);
                };
                from_blob = func(blob : Blob) : Nat {

                    var n = 0;
                    let bytes = Base.Blob.toArray(blob);

                    var j = 0;

                    while (j < bytes.size()) {
                        let byte = bytes.get(j);
                        n *= 255;
                        n += Base.Nat8.toNat(byte);

                        j += 1;
                    };

                    n;
                };
            };

            public let Int : Blobify<Int> = {
                to_blob = func(n : Int) : Blob {
                    let is_negative = n < 0;

                    var num : Nat = Base.Int.abs(n);
                    var nbytes = 0;

                    while (num > 0) {
                        num /= 255;
                        nbytes += 1;
                    };

                    num := Base.Int.abs(n);

                    let arr = ArrayModule.reverse(
                        ArrayModule.tabulate(
                            nbytes + 1,
                            func(i : Nat) : Nat8 {
                                if (i == nbytes) return Base.Nat8.fromNat(if (is_negative) 1 else 0);

                                let tmp = num % 255;
                                num /= 255;
                                Nat8Module.fromNat(tmp);
                            },
                        )
                    );

                    Base.Blob.fromArray(arr);
                };

                from_blob = func(blob : Blob) : Int {
                    let bytes = Base.Blob.toArray(blob);

                    var n = 0;
                    var is_negative = false;

                    var j = 0;

                    while (j < bytes.size()) {
                        let byte = bytes.get(j);
                        if (j == bytes.size() - 1) {
                            is_negative := Base.Nat8.toNat(byte) == 1;
                        } else {
                            n *= 255;
                            n += Base.Nat8.toNat(byte);
                        };

                        j += 1;
                    };

                    if (is_negative) {
                        -(n);
                    } else {
                        (n);
                    };
                };
            };
        };

    };

};
