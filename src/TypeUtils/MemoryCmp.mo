/// ## MemoryCmp
///
/// A module that defines a blob comparison function for memory-stored values.
/// Keys are always compared in their serialized (blob) form.
/// The blob encoding must be order-preserving so that byte comparison matches
/// the semantic ordering of the original values.

import Prim "mo:prim";

module {
  /// A comparison function over the blob-encoded form of a value.
  /// **Deprecated and removed:** `#GenCmp : (A, A) -> Int8` has been removed.
  /// All comparisons now operate directly on blobs, avoiding the overhead of
  /// deserializing keys during tree traversal and ensuring safety when
  /// tail-compressed branch separator keys are in use.
  /// Use `#BlobCmp` with an order-preserving `Blobify` encoding instead.
  public type MemoryCmp<A> = {
    #BlobCmp : (Blob, Blob) -> Int8;
  };

  /// Default: raw lexicographic byte comparison. Correct for any type whose
  /// Blobify encoding is order-preserving (ByteUtils.Sorted fixed-width types,
  /// raw UTF-8 text, raw blob bytes, etc.).
  public let Default = #BlobCmp(Prim.blobCompare);

  public let Nat       = #BlobCmp(Prim.blobCompare);
  public let Nat8      = #BlobCmp(Prim.blobCompare);
  public let Nat16     = #BlobCmp(Prim.blobCompare);
  public let Nat32     = #BlobCmp(Prim.blobCompare);
  public let Nat64     = #BlobCmp(Prim.blobCompare);
  public let Int       = #BlobCmp(Prim.blobCompare);
  public let Int8      = #BlobCmp(Prim.blobCompare);
  public let Int16     = #BlobCmp(Prim.blobCompare);
  public let Int32     = #BlobCmp(Prim.blobCompare);
  public let Int64     = #BlobCmp(Prim.blobCompare);
  public let Float     = #BlobCmp(Prim.blobCompare);
  public let Blob      = #BlobCmp(Prim.blobCompare);
  public let Bool      = #BlobCmp(Prim.blobCompare);
  public let Char      = #BlobCmp(Prim.blobCompare);
  public let Text      = #BlobCmp(Prim.blobCompare);
  public let Principal = #BlobCmp(Prim.blobCompare);
  public let Time      = Int;

  public module Legacy {
    /// Variable-length big-endian Nat: longer blob = larger value.
    public let Nat = #BlobCmp(
      func(a : Blob, b : Blob) : Int8 {
        if (a.size() > b.size()) return 1;
        if (a.size() < b.size()) return -1;
        Prim.blobCompare(a, b);
      }
    );

    /// Variable-length big-endian signed Int: sign byte first, then size, then bytes.
    public let Int = #BlobCmp(
      func(a : Blob, b : Blob) : Int8 {
        switch (a.vals().next(), b.vals().next()) {
          case (?val_a, ?val_b) {
            if (val_a > val_b) return 1;
            if (val_a < val_b) return -1;
          };
          case (null, null) return 0;
          case (null, _) return -1;
          case (_, null) return 1;
        };
        if (a.size() > b.size()) return 1;
        if (a.size() < b.size()) return -1;
        Prim.blobCompare(a, b);
      }
    );

    public module BigEndian {
      public let Nat = #BlobCmp(
        func(a : Blob, b : Blob) : Int8 {
          if (a.size() > b.size()) return 1;
          if (a.size() < b.size()) return -1;
          Prim.blobCompare(a, b);
        }
      );

      public let Int = #BlobCmp(
        func(a : Blob, b : Blob) : Int8 {
          switch (a.vals().next(), b.vals().next()) {
            case (?val_a, ?val_b) {
              if (val_a > val_b) return 1;
              if (val_a < val_b) return -1;
            };
            case (null, null) return 0;
            case (null, _) return -1;
            case (_, null) return 1;
          };
          if (a.size() > b.size()) return 1;
          if (a.size() < b.size()) return -1;
          Prim.blobCompare(a, b);
        }
      );
    };
  };
};
