import BlobifyModule "Blobify";
import MemoryBufferModule "MemoryBuffer/Base";
import MemoryBufferClassModule "MemoryBuffer";
import VersionedMemoryBufferModule "MemoryBuffer/Versioned";

import MemoryBTreeModule "MemoryBTree/Base";
import MemoryBTreeClassModule "MemoryBTree";
import VersionedMemoryBTreeModule "MemoryBTree/Versioned";

module {
    public let BaseMemoryBuffer = MemoryBufferModule;
    public let VersionedMemoryBuffer = VersionedMemoryBufferModule;
    public let MemoryBuffer = MemoryBufferClassModule;

    public type BaseMemoryBuffer<A> = MemoryBufferModule.MemoryBuffer<A>;
    public type VersionedMemoryBuffer<A> = VersionedMemoryBufferModule.VersionedMemoryBuffer<A>;
    public type MemoryBuffer<A> = MemoryBufferClassModule.MemoryBufferClass<A>;

    public type Blobify<A> = BlobifyModule.Blobify<A>;
    public let Blobify = BlobifyModule;

    public type MemoryBTree = MemoryBTreeModule.MemoryBTree;
    public let MemoryBTree = MemoryBTreeModule;

    public type MemoryBTreeClass<K, V> = MemoryBTreeClassModule.MemoryBTreeClass<K, V>;
    public let MemoryBTreeClass = MemoryBTreeClassModule;

    public type VersionedMemoryBTree = VersionedMemoryBTreeModule.VersionedMemoryBTree;
    public let VersionedMemoryBTree = VersionedMemoryBTreeModule;
};
