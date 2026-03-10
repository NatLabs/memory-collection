import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Nat "mo:base/Nat";

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

    /// Computes a tail-compressed separator key.
    /// The separator must be > left_node_last_key and <= right_node_first_key.
    /// We truncate right_node_first_key to (common_prefix_length + 1) bytes,
    /// which is the shortest key that satisfies these constraints.
    public func get_tail_compressed_separator(left_node_last_key : Blob, right_node_first_key : Blob) : Blob {
        let common_prefix_length = get_prefix_length(left_node_last_key, right_node_first_key);

        // Compressed length is one more than the common prefix
        let compressed_length = common_prefix_length + 1;

        // Only compress if:
        // 1. The compressed key is shorter than the original key
        // 2. We're not truncating to zero length
        if (
            compressed_length >= right_node_first_key.size() or
            compressed_length == 0
        ) {
            return right_node_first_key;
        };

        // Create the compressed key by truncating
        Blob.fromArray(
            Array.tabulate(
                compressed_length,
                func(i : Nat) : Nat8 {
                    right_node_first_key.get(i);
                },
            )
        );
    };
};
