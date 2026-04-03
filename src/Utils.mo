import Blob "mo:core@2.4/Blob";
import Buffer "mo:base@0.16/Buffer";
import Array "mo:core@2.4/Array";
import Nat8 "mo:core@2.4/Nat8";
import Nat64 "mo:core@2.4/Nat64";
import Prelude "mo:core@2.4/Runtime";
import Iter "mo:core@2.4/Iter";
import Debug "mo:core@2.4/Debug";
import Runtime "mo:core@2.4/Runtime";
import Result "mo:core@2.4/Result";

import Itertools "mo:itertools@0.2/Iter";
module {

  type Buffer<A> = Buffer.Buffer<A>;
  type Iter<A> = Iter.Iter<A>;
  type Result<A, B> = Result.Result<A, B>;

  public let NULL_ADDRESS = 0x00;

  public func sized_iter_to_array<A>(iter : Iter<A>, size : Nat) : [A] {
    Array.tabulate(
      size,
      func(_i : Nat) : A {
        switch (iter.next()) {
          case (null) Runtime.trap("sized_iter_to_array: found null before end of iter");
          case (?(a)) return a;
        };
      },
    );
  };

  public func unwrap<T>(optional : ?T, trap_msg : Text) : T {
    switch (optional) {
      case (?v) return v;
      case (_) return Runtime.trap(trap_msg);
    };
  };

  public func send_error<OldOk, NewOk, Error>(res : Result<OldOk, Error>) : Result<NewOk, Error> {
    switch (res) {
      case (#ok(_)) Prelude.unreachable();
      case (#err(errorMsg)) #err(errorMsg);
    };
  };

  public func nat_to_blob(num : Nat, nbytes : Nat) : Blob {
    var n = num;

    let bytes = Array.reverse(
      Array.tabulate(
        nbytes,
        func(_ : Nat) : Nat8 {
          if (n == 0) {
            return 0;
          };

          let byte = Nat8.fromNat(n % 256);
          n /= 256;
          byte;
        },
      )
    );

    return Blob.fromArray(bytes);
  };

  public func blob_to_nat(blob : Blob) : Nat {
    var n = 0;

    for (byte in blob.vals()) {
      n *= 256;
      n += Nat8.toNat(byte);
    };

    return n;
  };

  public func nat_to_bytes(n : Nat) : [Nat8] {
    var num = n;
    var nbytes = 0;

    while (num > 0) {
      num /= 255;
      nbytes += 1;
    };

    num := n;

    let arr = Array.reverse(
      Array.tabulate(
        nbytes,
        func(_ : Nat) : Nat8 {
          let tmp = num % 255;
          num /= 255;
          Nat8.fromNat(tmp);
        },
      )
    );

    arr;
  };

  public func bytes_to_nat(bytes : Iter.Iter<Nat8>) : Nat {
    var n = 0;
    let bytes_arr : [Nat8] = Iter.toArray(bytes);

    var j = bytes_arr.size();

    while (j > 0) {
      let byte = bytes_arr.get(j - 1);
      n *= 255;
      n += Nat8.toNat(byte);

      j -= 1;
    };

    n;
  };

  public func byte_iter_to_nat(iter : Iter<Nat8>) : Nat {
    var n = 0;

    for (byte in iter) {
      n *= 256;
      n += Nat8.toNat(byte);
    };

    return n;
  };

  public func concat_blobs(blobs : [Blob]) : Blob {
    var total_size = 0;

    var i = 0;
    while (i < blobs.size()) {
      total_size += blobs[i].size();
      i += 1;
    };

    let nested_bytes = Array.tabulate(
      blobs.size(),
      func(i : Nat) : [Nat8] {
        Blob.toArray(blobs[i]);
      },
    );

    let bytes = Array.flatten(nested_bytes);
    Blob.fromArray(bytes);
  };

  public func blob_slice(blob : Blob, start : Nat, size : Nat) : Blob {
    if (size == 0) return "";

    Blob.fromArray(
      Array.tabulate(
        size,
        func(i : Nat) : Nat8 {
          blob.get(start + i);
        },
      )
    );
  };

  public func encode_leb128(n : Nat) : Blob {
    let nat64_bound = 18_446_744_073_709_551_616;

    if (n < nat64_bound) {
      // more performant than the general leb128
      var n64 : Nat64 = Nat64.fromNat(n);
      var bit_length = Nat64.toNat(64 - Nat64.bitcountLeadingZero(n64));
      var nbytes = if (bit_length == 0) 1 else (bit_length + 6) / 7; // div_ceil

      let bytes = Array.tabulate(
        nbytes,
        func(i : Nat) : Nat8 {
          let byte = n64 & 0x7F |> Nat64.toNat(_) |> Nat8.fromNat(_);
          n64 >>= 7;

          if (n64 > 0) return (byte | 0x80);

          return byte;
        },
      );

      return Blob.fromArray(bytes);
    };

    var num = n;
    var nbytes = 0;

    while (num > 0) {
      num /= 255;
      nbytes += 1;
    };

    num := n;

    let bytes = Array.tabulate(
      nbytes,
      func(i : Nat) : Nat8 {
        var byte = num % 0x80 |> Nat8.fromNat(_);
        num /= 0x80;

        if (num > 0) byte := (byte | 0x80);
        byte;
      },
    );

    Blob.fromArray(bytes);
  };

  public func decode_leb_64(bytes : [Nat8]) : Nat {
    var n64 : Nat64 = 0;
    var shift : Nat64 = 0;
    var i = 0;

    label decoding_leb while (i < bytes.size()) {
      let byte = bytes[i];

      n64 |= (Nat64.fromNat(Nat8.toNat(byte & 0x7f)) << shift);

      if (byte & 0x80 == 0) break decoding_leb;
      shift += 7;
      i += 1;
    };

    Nat64.toNat(n64);
  };

};
