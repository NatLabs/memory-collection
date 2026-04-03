import Array "mo:core@2.4/Array";
import Blob "mo:core@2.4/Blob";
import Nat "mo:core@2.4/Nat";
import Debug "mo:core@2.4/Debug";
import Runtime "mo:core@2.4/Runtime";

import Constants "../../Constants";

module {

    /// Gets the common prefix length between two blobs
    public func get_prefix_length(a : Blob, b : Blob) : Nat {
        var common_length = 0;

        while (
            common_length < a.size() and
            common_length < b.size() and
            a.get(common_length) == b.get(common_length)
        ) {
            common_length += 1;
        };

        common_length;
    };

    /// Gets the common prefix between two blobs.
    /// Returns null when there is no common prefix (length 0).
    public func get_common_prefix(a : Blob, b : Blob) : Blob {
        let prefix_length = get_prefix_length(a, b);
        if (prefix_length == 0) return Constants.EMPTY_BLOB;

        Blob.fromArray(
            Array.tabulate(
                prefix_length,
                func(i : Nat) : Nat8 { a.get(i) },
            )
        );
    };

    /// Strips a prefix from a blob, returning the suffix
    /// Assumes the blob starts with the prefix (caller must verify)
    public func strip_prefix(prefix : Blob, key : Blob) : Blob {
        if (prefix.size() == 0) return key;
        if (prefix.size() == key.size()) return Constants.EMPTY_BLOB;
        
        let prefix_size = prefix.size();

        let suffix_size = key.size() - prefix_size : Nat;
        Blob.fromArray(
            Array.tabulate(
                suffix_size,
                func(i : Nat) : Nat8 {
                    key.get(prefix_size + i);
                },
            )
        );
    };

    /// Prepends a prefix to a suffix, returning the full key
    public func prepend_prefix(prefix : Blob, suffix : Blob) : Blob {
        if (prefix.size() == 0) return suffix;
        if (suffix.size() == 0) return prefix;

        Blob.fromArray(
            Array.tabulate(
                prefix.size() + suffix.size(),
                func(i : Nat) : Nat8 {
                    if (i < prefix.size()) {
                        prefix.get(i);
                    } else {
                        suffix.get(i - prefix.size());
                    };
                },
            )
        );
    };

    /// Checks if a blob starts with a given prefix
    public func has_prefix(prefix : Blob, key : Blob) : Bool {
        if (prefix.size() > key.size()) return false;
        
        var i = 0;
        while (i < prefix.size()) {
            if (prefix.get(i) != key.get(i)) return false;
            i += 1;
        };
        true;
    };

    /// Returns the suffix to store for the given new prefix.
    /// Converts a suffix stored under old_prefix to the suffix for new_prefix.
    /// Invariant: old_prefix + suffix == new_prefix + new_suffix
    ///
    /// new_prefix longer  → diff extra bytes are already in old suffix, just drop them from the front
    /// new_prefix shorter → diff bytes from the tail of old_prefix must be prepended to the suffix
    public func get_new_suffix(old_prefix: Blob, new_prefix: Blob, suffix: Blob) : Blob {
        let old_size = old_prefix.size();
        let new_size = new_prefix.size();
        if (old_size == new_size) return suffix;

        if (new_size > old_size) {
            // New prefix absorbed more bytes from the suffix; drop them from the front
            let diff = new_size - old_size;
            if (diff > suffix.size()) {
                Debug.print(debug_show({old_prefix; new_prefix; suffix}));
                Runtime.trap("get_new_suffix: underflow — old_prefix=" # debug_show old_prefix # " new_prefix=" # debug_show new_prefix # " suffix=" # debug_show suffix);
            };
            return Blob.fromArray(
                Array.tabulate(
                    suffix.size() - diff,
                    func(i : Nat) : Nat8 { suffix.get(i + diff) },
                )
            );
        };

        // New prefix is shorter; the bytes old_prefix[new_size..old_size] must move back into the suffix
        let diff = old_size - new_size;
        Blob.fromArray(
            Array.tabulate(
                suffix.size() + diff,
                func(i : Nat) : Nat8 {
                    if (i < diff) {
                        old_prefix.get(new_size + i);
                    } else {
                        suffix.get(i - diff);
                    };
                },
            )
        );
    };

};
