import Int "mo:base/Int";
import Region "mo:base/Region";
import Nat64 "mo:base/Nat64";

module {

    public func shift(region : Region, start : Nat, end : Nat, offset : Int) {
        let size = (end - start : Nat);
        if (size == 0) return;

        let blob = Region.loadBlob(region, Nat64.fromNat(start), size);

        let new_start = Int.abs(start + offset);

        Region.storeBlob(region, Nat64.fromNat(new_start), blob);
    };

};
