import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";

import Bench "mo:bench";
import Fuzz "mo:fuzz";
import Itertools "mo:itertools/Iter";

import MemoryQueue "../../src/MemoryQueue";
import TypeUtils "../../src/TypeUtils";

module {
    public func init() : Bench.Bench {
        let bench = Bench.Bench();

        bench.name("Benchmarking the MemoryQueue");
        bench.description("Benchmarking the performance with 10k calls");

        bench.cols(["MemoryQueue"]);
        bench.rows([
            "add()",
            "vals()",
            "pop()",
            "random add()/pop()",
        ]);

        let fuzz = Fuzz.Fuzz();

        let limit = 10_000;

        let buffer = Buffer.Buffer<Nat>(limit);
        let buffer2 = Buffer.Buffer<Nat>(limit);
        let sstore = MemoryQueue.newStableStore();
        let mem_queue = MemoryQueue.MemoryQueue<Nat>(sstore, TypeUtils.Nat);

        for (i in Iter.range(0, limit - 1)) {
            let n = fuzz.nat.randomRange(0, limit ** 2);
            let n2 = fuzz.nat.randomRange(0, limit ** 2);
            buffer.add(n);
            buffer2.add(n2);
        };

        bench.runner(
            func(col, row) = switch (row, col) {

                case ("MemoryQueue", "add()") {
                    for (i in buffer.vals()) {
                        mem_queue.add(i);
                    };
                };

                case ("MemoryQueue", "vals()") {

                    var i = 0;
                    for ((a, b) in Itertools.zip(buffer.vals(), mem_queue.vals())) {
                        assert a == b;
                        i += 1;
                    };

                    assert i == limit;
                };

                case ("MemoryQueue", "pop()") {
                    for (i in buffer.vals()) {
                        assert ?i == mem_queue.pop();
                    };
                };
                case ("MemoryQueue", "random add()/pop()") {
                    var i = 0;

                    for (_ in Iter.range(0, limit - 1)) {
                        let choice = if (mem_queue.isEmpty()) false else fuzz.nat.randomRange(0, 10) <= 5;

                        if (choice) {
                            ignore mem_queue.pop();
                        } else {
                            mem_queue.add(i);
                            i += 1;
                        };
                    };

                };

                case (_) {
                    Debug.trap("Should be unreachable:\n row = \"" # debug_show row # "\" and col = \"" # debug_show col # "\"");
                };
            }
        );

        bench;
    };
};
