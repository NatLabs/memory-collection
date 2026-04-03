import Int "mo:core@2.4/Int";
import Region "mo:core@2.4/Region";
import Nat64 "mo:core@2.4/Nat64";

import MemoryRegion "mo:memory-region@1.5/MemoryRegion";

module {

  public func shift_by(region : Region, start : Nat, end : Nat, offset : Int) {
    let size = (end - start : Nat);
    if (size == 0) return;

    let blob = Region.loadBlob(region, Nat64.fromNat(start), size);

    let new_start = Int.abs(start + offset);

    Region.storeBlob(region, Nat64.fromNat(new_start), blob);
  };

};
