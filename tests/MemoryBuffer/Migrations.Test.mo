// @testmode wasi
import { test; suite } "mo:test";
import MemoryBuffer "../../src/MemoryBuffer/Base";
import StableMemoryBuffer "../../src/MemoryBuffer/Stable";
import Migrations "../../src/MemoryBuffer/Migrations";

suite(
    "MemoryBuffer Migration Tests",
    func() {
        test(
            "deploys current version",
            func() {
                let vs_memory_region = StableMemoryBuffer.new();
                ignore Migrations.getCurrentVersion(vs_memory_region); // should not trap

                let memory_region = MemoryBuffer.new();
                let version = MemoryBuffer.toVersioned(memory_region);
                ignore Migrations.getCurrentVersion(version); // should not trap
            },
        );
    },
);
