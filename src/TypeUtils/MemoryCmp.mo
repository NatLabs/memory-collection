/// ## MemoryCmp
///
/// A module that defines a variant with two different comparison functions.

import Prim "mo:prim";

import Blob "mo:base@.v0.14.11/Blob";

import Int8Cmp "Int8Cmp";
module {
    public type MemoryCmp<A> = {
        #GenCmp : (A, A) -> Int8;
        #BlobCmp : (Blob, Blob) -> Int8;
    };

    public let Default = #BlobCmp(Int8Cmp.Blob);

    public let Nat = #GenCmp(Int8Cmp.Nat);

    public let Nat8 = #GenCmp(Int8Cmp.Nat8);
    public let Nat16 = #GenCmp(Int8Cmp.Nat16);
    public let Nat32 = #GenCmp(Int8Cmp.Nat32);
    public let Nat64 = #GenCmp(Int8Cmp.Nat64);

    public let Int = #GenCmp(Int8Cmp.Int);

    public let Int8 = #GenCmp(Int8Cmp.Int8);
    public let Int16 = #GenCmp(Int8Cmp.Int16);
    public let Int32 = #GenCmp(Int8Cmp.Int32);
    public let Int64 = #GenCmp(Int8Cmp.Int64);

    public let Float = #GenCmp(Int8Cmp.Float);

    public let Blob = #BlobCmp(Prim.blobCompare);

    public let Bool = #GenCmp(Int8Cmp.Bool);

    public let Char = #GenCmp(Int8Cmp.Char);

    public let Text = #GenCmp(Int8Cmp.Text);

    public let Principal = #GenCmp(Int8Cmp.Principal);

    public let Time = Int;

    public module Legacy {

        public let Nat = #GenCmp(Int8Cmp.Nat);
        public let Int = #GenCmp(Int8Cmp.Int);

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
