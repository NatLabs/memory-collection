# Copilot Instructions

## Project Overview

**memory-collection** is a Motoko library for the Internet Computer (ICP) that provides persistent data structures backed by stable memory: `MemoryBTree`, `MemoryBuffer`, and `MemoryQueue`. Each structure uses the class+ pattern to separate a mutable stable store from a class interface, enabling data to survive canister upgrades.

## Language & Tooling

- **Language**: Motoko (`moc`)
- **Package manager**: `mops`
- **Testing**: `mops test`
- **Benchmarking**: `mops bench --gc incremental`
- **Type checking**: `mops toolchain bin moc` with `-Werror`

## Running Tests

Always run the full test output without truncation. Do **not** pipe test commands through filters like `head`, `tail`, or `grep` unless specifically asked:

```sh
# correct
mops test

# incorrect - truncates output
mops test | head -80
```

## Code Conventions

- Data structures live under `src/<StructureName>/`.
- Each structure exposes a `lib.mo` (class+ API), a `Stable.mo` (raw stable API), a `Base.mo` (core logic), and a `Migrations/` or `migrations/` directory for upgrade paths.
- `TypeUtils` provides `Blobify` and `MemoryCmp` helpers required during initialization of any data structure.
- Dependencies are declared in `mops.toml`; do not add npm or cargo dependencies.
