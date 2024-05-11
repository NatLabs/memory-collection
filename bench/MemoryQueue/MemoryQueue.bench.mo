import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Prelude "mo:base/Prelude";
import Buffer "mo:base/Buffer";

import Bench "mo:bench";
import Fuzz "mo:fuzz";
import Itertools "mo:itertools/Iter";

import MemoryQueue "../../src/MemoryQueue/Base";
import Blobify "../../src/Blobify";

module {
    public func init() : Bench.Bench {
        let bench = Bench.Bench();

        bench.name("Benchmarking the MemoryQueue");
        bench.description("Benchmarking the performance with 10k calls");

        bench.rows(["MemoryQueue"]);
        bench.cols([
            "add()",
            "vals()",
            "pop()",
        ]);

        let fuzz = Fuzz.Fuzz();

        let limit = 10_000;

        let buffer = Buffer.Buffer<Nat>(limit);
        let mem_queue = MemoryQueue.new();

        for (i in Iter.range(0, limit - 1)) {
            let n = fuzz.nat.randomRange(0, limit ** 2);

            buffer.add(n);
        };

        bench.runner(
            func(row, col) = switch (row, col) {

                case ("MemoryQueue", "add()") {
                    for (i in buffer.vals()) {
                        MemoryQueue.add(mem_queue, Blobify.Nat, i);
                    };
                };

                case ("MemoryQueue", "vals()") {

                    var i = 0;
                    for ((a, b) in Itertools.zip(buffer.vals(), MemoryQueue.vals(mem_queue, Blobify.Nat))) {
                        assert a == b;
                        i += 1;
                    };

                    assert i == limit;
                };

                case ("MemoryQueue", "pop()") {
                    for (i in buffer.vals()) {
                        assert ?i == MemoryQueue.pop(mem_queue, Blobify.Nat);
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
