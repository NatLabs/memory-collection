import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Timer "mo:base/Timer";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";

import Map "mo:map/Map";

import MemoryQueue "../src/MemoryQueue"; // "mo:memory_collection/MemoryQueue"
import TypeUtils "../src/TypeUtils"; // "mo:memory_collection/TypeUtils"

actor class Subscriber() {
    let subscribed_posts = Buffer.Buffer<Publisher.Post>(10);

    public func init() : async () {
        await PubSubService.subscribe_to_event(
            Principal.fromActor(Publisher),
            await Publisher.get_post_event_id(),
        );
    };

    public func notify(event : PubSubService.Event) {
        let ?post = from_candid (event.message) : ?Publisher.Post;
        subscribed_posts.add(post);
    };
};

actor Publisher {
    let PostEventId : Nat = 0x32;

    // functions as init
    public func init() : async () {
        await PubSubService.create_event(PostEventId);
    };

    public type Post = {
        title : Text;
        content : Text;
    };

    public func create_post(title : Text, content : Text) {
        let post : Post = { title; content };
        let candid_post = to_candid (post);

        PubSubService.emit(PostEventId, candid_post);
    };

    public func get_post_event_id() : async Nat {
        PostEventId;
    };
};

actor PubSubService {
    public type Subscriber = actor { notify : (event : Event) -> () };

    public type Event = {
        message : Blob;
        event_id : Nat;
        publisher : Principal;
    };

    let { thash; nhash; phash } = Map;

    let events_blobify_utils : TypeUtils.Blobify<Event> = {
        to_blob = func(event : Event) : Blob { to_candid (event) };
        from_blob = func(blob : Blob) : Event = switch (from_candid (blob) : ?Event) {
            case (?event) event;
            case (null) Debug.trap("events_blobify_utils: Failed to decode Event");
        };
    };

    let events_queue_utils = MemoryQueue.createUtils({
        blobify = events_blobify_utils;
    });

    stable var events_sstore = MemoryQueue.newStableStore();
    let events = MemoryQueue.MemoryQueue<Event>(events_sstore, events_queue_utils);

    type Map<K, V> = Map.Map<K, V>;
    type Buffer<A> = Buffer.Buffer<A>;

    let publishers = Map.new<Principal, Map<Nat, Buffer<Subscriber>>>();

    public shared ({ caller }) func create_event(event_id : Nat) : async () {

        let subscribers_event_map = switch (Map.get(publishers, phash, caller)) {
            case (?subscribers_event_map) subscribers_event_map;
            case (null) {
                let subscribers_event_map = Map.new<Nat, Buffer<Subscriber>>();
                ignore Map.put(publishers, phash, caller, subscribers_event_map);
                subscribers_event_map;
            };
        };

        let subscribers = Buffer.Buffer<Subscriber>(8);
        ignore Map.put(subscribers_event_map, nhash, event_id, subscribers);
    };

    public shared ({ caller }) func subscribe_to_event(by : Principal, event_id : Nat) : async () {
        let ?subscribers_event_map = Map.get(publishers, phash, by);
        let ?subscribers = Map.get(subscribers_event_map, nhash, event_id);

        let subscriber = actor (Principal.toText(caller)) : Subscriber;
        subscribers.add(subscriber);
    };

    public shared ({ caller = publisher }) func emit(event_id : Nat, message : Blob) {
        // let publish = actor(Principal.toText(caller)) : Publisher;

        let ?subscribers_event_map = Map.get(publishers, phash, publisher);
        let ?subscribers = Map.get(subscribers_event_map, nhash, event_id);

        let event : Event = { message; event_id; publisher };

        events.add(event);
    };

    func notify_subscribers(event : Event) : async () {

        let ?subscribers_event_map = Map.get(publishers, phash, event.publisher);
        let ?subscribers = Map.get(subscribers_event_map, nhash, event.event_id);

        for (sub in subscribers.vals()) {
            sub.notify(event);
        };
    };

    let EventsPerRound = 10;

    // process events at the front of the queue every 10 seconds
    ignore Timer.recurringTimer<system>(
        #seconds 10,
        func() : async () {
            for (i in Iter.range(0, Nat.min(EventsPerRound, events.size()) - 1)) {
                let ?event = events.pop();
                ignore notify_subscribers(event);
            };
        },
    );

};
