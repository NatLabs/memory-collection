import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import TextModule "mo:base/Text";

import Itertools "mo:itertools/Iter";
import Blobify "../TypeUtils/Blobify";

module WyHash {

    type Iter<A> = Iter.Iter<A>;

    public let WYASH_PRIME : Nat64 = 0x9fb21c651e98df25;
    public let WYHAT_PRIME : Nat64 = 0x9ddfea08eb382d69;
    public let WYSEED : Nat64 = 0x123456789ABCDEF0;

    public func hash_unknown_len(data : Iter<Nat8>) : Nat64 {
        var hash : Nat64 = WYSEED;

        var data_len : Nat64 = 0;
        var payload_len : Nat64 = 0;
        var payload : Nat64 = 0;

        while (data_len % 8 == 0) {
            label inner_while_loop while (payload_len < 8) {
                let ?n = data.next() else break inner_while_loop;
                payload := payload << 8 | Nat64.fromNat(Nat8.toNat(n));
                payload_len += 1;
            };

            if (payload_len == 8) {
                payload *%= WYASH_PRIME;
                hash ^= payload;
                hash *%= WYASH_PRIME;

                payload_len := 0;
            };

            data_len += 1;
        };

        if (payload_len >= 4) {
            let extra = payload_len - 4;
            let shift = 8 * extra;
            var _payload = payload >> shift;

            _payload *%= WYASH_PRIME;
            hash ^= _payload;
            hash *%= WYASH_PRIME;
            payload_len -= 4;

            let mask = (1 << shift) - 1;
            payload &= mask;
        };

        if (payload_len >= 2) {
            let extra = payload_len - 2;
            let shift = 8 * extra;
            var _payload = payload >> shift;

            _payload *%= WYASH_PRIME;
            hash ^= _payload;
            hash *%= WYASH_PRIME;
            payload_len -= 2;

            let mask = (1 << shift) - 1;
            payload &= mask;
        };

        if (payload_len >= 1) {
            payload *%= WYASH_PRIME;
            hash ^= payload;
            hash *%= WYASH_PRIME;
        };

        hash ^= data_len;

        hash ^= hash >> 32;
        hash *%= WYHAT_PRIME;
        hash ^= hash >> 16;
        hash *%= WYHAT_PRIME;

        hash;
    };

    public func hash(len : Nat, data : Iter<Nat8>) : Nat64 {
        let seed : Nat64 = 0x123456789ABCDEF0;
        var var_len = len;

        var hash : Nat64 = seed ^ Nat64.fromNat(len);

        while (var_len >= 8) {
            var x : Nat64 = 0;

            var i = 0;
            while (i < 8) {
                let ?n = data.next() else Debug.trap("WyHash.hash: not enough data");
                x := x << 8 | Nat64.fromNat(Nat8.toNat(n));

                i += 1;
            };

            x *%= WYASH_PRIME;
            hash ^= x;
            hash *%= WYASH_PRIME;
            var_len -= 8;
        };

        if (var_len >= 4) {
            var x : Nat64 = 0;

            var i = 0;
            while (i < 4) {
                let ?n = data.next() else Debug.trap("WyHash.hash: not enough data");
                x := x << 8 | Nat64.fromNat(Nat8.toNat(n));
                i += 1;
            };

            x *%= WYASH_PRIME;
            hash ^= x;
            hash *%= WYASH_PRIME;
            var_len -= 4;
        };

        if (var_len >= 2) {
            var x : Nat64 = 0;

            var i = 0;
            while (i < 2) {
                let ?n = data.next() else Debug.trap("WyHash.hash: not enough data");
                x := x << 8 | Nat64.fromNat(Nat8.toNat(n));
                i += 1;
            };

            x *%= WYASH_PRIME;
            hash ^= x;
            hash *%= WYASH_PRIME;
            var_len -= 2;
        };

        if (var_len >= 1) {
            let ?n = data.next() else Debug.trap("WyHash.hash: not enough data");
            var x = Nat64.fromNat(Nat8.toNat(n));
            x *%= WYASH_PRIME;
            hash ^= x;
            hash *%= WYASH_PRIME;
        };

        hash ^= hash >> 32;
        hash *%= WYHAT_PRIME;
        hash ^= hash >> 16;
        hash *%= WYHAT_PRIME;

        hash;
    };

    public func Nat(n : Nat) : Nat64 {
        let iter = object {
            var num = n;

            public func next() : ?Nat8 {
                if (num == 0) return null;
                let byte = Nat8.fromNat(num % 256);
                num /= 256;
                ?byte;
            };
        };

        hash_unknown_len(iter);
    };

    public func Text(text : Text) : Nat64 {
        let blob = TextModule.encodeUtf8(text);
        hash(blob.size(), blob.vals());
    };

    public func Blob(blob : Blob) : Nat64 {
        hash(blob.size(), blob.vals());
    };

};
