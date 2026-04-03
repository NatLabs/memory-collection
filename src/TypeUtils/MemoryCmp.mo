/// ## MemoryCmp
///
/// A module that defines a comparison function variant for use with stable memory collections.

import Prim "mo:prim";

module {
  /// A comparison function over serialized `Blob` values.
  public type MemoryCmp<A> = {
    #BlobCmp : (Blob, Blob) -> Int8;
  };

  public let Default = #BlobCmp(Prim.blobCompare);

  public module Legacy {
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
