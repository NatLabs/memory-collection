import Debug "mo:base/Debug";

import MemoryBuffer "../src/MemoryBuffer"; // "mo:memory_collection/MemoryBuffer"
import TypeUtils "../src/TypeUtils"; // "mo:memory_collection/TypeUtils"

actor {
    type Theme = {
        #light;
        #dark;
    };

    type UserDetails = {
        name : Text;
        age : Nat;
        id : Nat;
        principal : Principal;
        settings : {
            notifications : Bool;
            theme : Theme;
        };
    };

    let user_details_candid_blobify : TypeUtils.Blobify<UserDetails> = {
        to_blob = func(user_details : UserDetails) : Blob {
            to_candid (user_details);
        };
        from_blob = func(blob : Blob) : UserDetails = switch (from_candid (blob) : ?UserDetails) {
            case (?user_details) user_details;
            case (null) Debug.trap("Failed to decode UserDetails");
        };
    };

    let user_details_candid_utils = MemoryBuffer.createUtils<UserDetails>({
        blobify = user_details_candid_blobify;
    });

    var sstore = MemoryBuffer.newStableStore();
    let buffer = MemoryBuffer.MemoryBuffer<UserDetails>(sstore, user_details_candid_utils);

    public func add_user(name : Text, age : Nat, principal : Principal) : async (id : Nat) {
        let id = buffer.size();

        let user : UserDetails = {
            name;
            age;
            principal;
            id;
            settings = { notifications = false; theme = #light };
        };

        buffer.add(user);

        id;
    };

    public func get_user(id : Nat) : async (UserDetails) {
        buffer.get(id);
    };

    public func set_user_settings(id : Nat, notifications : Bool, theme : { #light; #dark }) : async () {
        let user = buffer.get(id);

        let updated_user = {
            user with settings = { notifications; theme };
        };

        buffer.put(id, updated_user);
    };

};
