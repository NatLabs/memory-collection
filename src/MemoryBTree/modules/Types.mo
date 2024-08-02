import Nat "mo:base/Nat";

import MemoryRegion "mo:memory-region/MemoryRegion";
import LruCache "mo:lru-cache";
import RevIter "mo:itertools/RevIter";

import Blobify "../../TypeUtils/Blobify";
import MemoryCmp "../../TypeUtils/MemoryCmp";
import TypeUtils "../../TypeUtils";

module {
    public type Address = Nat;
    type Size = Nat;
    public type UniqueId = Nat;

    public type MemoryBlock = (Address, Size);

    type MemoryRegionV1 = MemoryRegion.MemoryRegionV1;
    type LruCache<K, V> = LruCache.LruCache<K, V>;
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

};
