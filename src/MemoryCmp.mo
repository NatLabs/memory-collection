import Prim "mo:prim";

import Blob "mo:base/Blob";

import Int8Cmp "Int8Cmp";
module {
    public type MemoryCmp<A> = {
        #GenCmp : (A, A) -> Int8;
        #BlobCmp : (Blob, Blob) -> Int8;
    };

    public let Default = #BlobCmp(Int8Cmp.Blob);

    public module BigEndian {
        public let Nat = #BlobCmp(
            func (a: Blob, b: Blob) : Int8 {
                if (a.size() > b.size()) return 1;
                if (a.size() < b.size()) return -1;

                Prim.blobCompare(a, b);
            }
        );

        public let Nat8 = #BlobCmp(Prim.blobCompare);
        public let Nat16 = #BlobCmp(Prim.blobCompare);
        public let Nat32 = #BlobCmp(Prim.blobCompare);
        public let Nat64 = #BlobCmp(Prim.blobCompare);
    };

    public let Nat = #GenCmp(Int8Cmp.Nat);

    public let Nat8 = #GenCmp(Int8Cmp.Nat8);
    public let Nat16 = #GenCmp(Int8Cmp.Nat16);
    public let Nat32 = #GenCmp(Int8Cmp.Nat32);
    public let Nat64 = #GenCmp(Int8Cmp.Nat64);

    public let Blob = #BlobCmp(Prim.blobCompare);

    public let Bool = #BlobCmp(Prim.blobCompare);

    public let Char = #BlobCmp(Prim.blobCompare);

    public let Text = #BlobCmp(Prim.blobCompare);

    public let Principal = #BlobCmp(Prim.blobCompare);

}