import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Float "mo:base/Float";
import Iter "mo:base/Iter";

import MemoryBTree "../src/MemoryBTree"; // "mo:memory_collection/MemoryBTree"
import TypeUtils "../src/TypeUtils"; // "mo:memory_collection/TypeUtils"

actor {
    type Time = Time.Time;
    type TypeUtils<T> = TypeUtils.TypeUtils<T>;

    type Order = {
        user_id : Principal;
        product_id : Nat;
        quantity : Nat;
        timestamp : Time;
        total_price : Float;
        order_id : Nat;
    };

    let order_candid_utils : TypeUtils.Blobify<Order> = {
        to_blob = func(order : Order) : Blob { to_candid (order) };
        from_blob = func(blob : Blob) : Order = switch (from_candid (blob) : ?Order) {
            case (?order) order;
            case (null) Debug.trap("Failed to decode Order");
        };
    };

    let orders_btree_utils = MemoryBTree.createUtils<Time, Order>(
        TypeUtils.Time,
        { blobify = order_candid_utils },
    );

    stable var orders_sstore = MemoryBTree.newStableStore(null);
    orders_sstore := MemoryBTree.upgrade(orders_sstore);

    // If two orders are placed at the same timestamp, the second order will overwrite the first
    // so for this test we assume that no two orders are placed at the same timestamp
    let orders = MemoryBTree.MemoryBTree<Time, Order>(orders_sstore, orders_btree_utils);

    let product_prices = [39.99, 7.23, 12.99, 87.00, 5.99];

    public shared ({ caller }) func make_order(product_id : Nat, quantity : Nat) : async (order_id : Nat) {
        let user_id = caller;
        let timestamp = Time.now();
        let total_price = product_prices.get(product_id) * Float.fromInt(quantity);

        let order_id = orders.nextId();

        let order : Order = {
            user_id;
            order_id;
            product_id;
            quantity;
            timestamp;
            total_price;
        };

        ignore orders.insert(timestamp, order);
        order_id;
    };

    public func get_orders_between(start : Time, end : Time) : async ([(Time, Order)]) {
        let order_iterator = orders.scan(?start, ?end);
        Iter.toArray(order_iterator);
    };

    public func get_order_at(time : Time) : async (?Order) {
        orders.get(time);
    };

    public func get_product_price(product_id : Nat) : async (Float) {
        product_prices.get(product_id);
    };

};
