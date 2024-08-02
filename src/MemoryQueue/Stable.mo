import Iter "mo:base/Iter";
import Migrations "migrations";

import BaseMemoryQueue "Base";
import Blobify "../TypeUtils/Blobify";

module StableMemoryQueue {
    public type MemoryQueueUtils<A> = BaseMemoryQueue.MemoryQueueUtils<A>;
    public type Blobify<A> = Blobify.Blobify<A>;
    public type Iter<A> = Iter.Iter<A>;
    public type StableMemoryQueue = Migrations.VersionedMemoryQueue;

    public func new() : StableMemoryQueue {
        #v0(BaseMemoryQueue.new());
    };

    public func createUtils<A>(queue_utils : MemoryQueueUtils<A>) : MemoryQueueUtils<A> {
        queue_utils;
    };

    public func add<A>(versions : StableMemoryQueue, queue_utils : MemoryQueueUtils<A>, val : A) {
        let mem_queue = Migrations.getCurrentVersion(versions);
        BaseMemoryQueue.add(mem_queue, queue_utils, val);
    };

    public func peek<A>(versions : StableMemoryQueue, queue_utils : MemoryQueueUtils<A>) : ?A {
        let mem_queue = Migrations.getCurrentVersion(versions);
        BaseMemoryQueue.peek(mem_queue, queue_utils);
    };

    public func pop<A>(versions : StableMemoryQueue, queue_utils : MemoryQueueUtils<A>) : ?A {
        let mem_queue = Migrations.getCurrentVersion(versions);
        BaseMemoryQueue.pop(mem_queue, queue_utils);
    };

    public func size<A>(versions : StableMemoryQueue) : Nat {
        let mem_queue = Migrations.getCurrentVersion(versions);
        BaseMemoryQueue.size(mem_queue);
    };

    public func isEmpty<A>(versions : StableMemoryQueue) : Bool {
        let mem_queue = Migrations.getCurrentVersion(versions);
        BaseMemoryQueue.isEmpty(mem_queue);
    };

    public func clear<A>(versions : StableMemoryQueue) {
        let mem_queue = Migrations.getCurrentVersion(versions);
        BaseMemoryQueue.clear(mem_queue);
    };

    public func vals<A>(versions : StableMemoryQueue, queue_utils : MemoryQueueUtils<A>) : Iter<A> {
        let mem_queue = Migrations.getCurrentVersion(versions);
        BaseMemoryQueue.vals(mem_queue, queue_utils);
    };

    public func toArray<A>(versions : StableMemoryQueue, queue_utils : MemoryQueueUtils<A>) : [A] {
        let mem_queue = Migrations.getCurrentVersion(versions);
        BaseMemoryQueue.toArray(mem_queue, queue_utils);
    };
};
