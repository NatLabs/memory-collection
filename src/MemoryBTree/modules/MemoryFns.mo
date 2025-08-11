import Int "mo:base@0.14.11/Int";
import Region "mo:base@0.14.11/Region";
import Nat64 "mo:base@0.14.11/Nat64";

module {

    public func shift(region : Region, start : Nat, end : Nat, offset : Int) {
        let size = (end - start : Nat);
        if (size == 0) return;

        let blob = Region.loadBlob(region, Nat64.fromNat(start), size);

        let new_start = Int.abs(start + offset);

        Region.storeBlob(region, Nat64.fromNat(new_start), blob);
    };

};
