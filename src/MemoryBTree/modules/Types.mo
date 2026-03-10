import Nat "mo:base@0.14.13/Nat";

import MemoryRegion "mo:memory-region@1.4.0/MemoryRegion";
import RevIter "mo:itertools@0.2.2/RevIter";

import Blobify "../../TypeUtils/Blobify";
import MemoryCmp "../../TypeUtils/MemoryCmp";
import TypeUtils "../../TypeUtils";

module {
  public type Address = Nat;
  type Size = Nat;
  public type UniqueId = Nat;

  public type MemoryBlock = (Address, Size);

  type MemoryRegionV1 = MemoryRegion.MemoryRegionV1;
  type Blobify<A> = Blobify.Blobify<A>;
  type RevIter<A> = RevIter.RevIter<A>;

  public type MemoryCmp<A> = MemoryCmp.MemoryCmp<A>;

  public type KeyUtils<K> = {
    blobify : TypeUtils.Blobify<K>;
    cmp : TypeUtils.MemoryCmp<K>;
  };

  public type ValueUtils<V> = {
    blobify : TypeUtils.Blobify<V>;
  };

  public type BTreeUtils<K, V> = {
    key : KeyUtils<K>;
    value : ValueUtils<V>;
  };

  public type NodeType = {
    #branch;
    #leaf;
  };

  public type MemoryBTreeStats = {
    allocatedPages : Nat;
    bytesPerPage : Nat;
    allocatedBytes : Nat;
    usedBytes : Nat;
    freeBytes : Nat;
    dataBytes : Nat;
    metadataBytes : Nat;
    leafBytes : Nat;
    branchBytes : Nat;
    keyBytes : Nat;
    valueBytes : Nat;
    leafCount : Nat;
    branchCount : Nat;
    totalNodeCount : Nat;
  };

};
