import Debug "mo:core@2.4/Debug";
import Runtime "mo:core@2.4/Runtime";

import V0 "V0";

module Migrations {
  public type MemoryQueue = V0.MemoryQueue;

  public type VersionedMemoryQueue = {
    #v0 : V0.MemoryQueue;
  };

  public func upgrade(versions : VersionedMemoryQueue) : VersionedMemoryQueue {
    switch (versions) {
      case (#v0(v0)) versions;
    };
  };

  public func getCurrentVersion(versions : VersionedMemoryQueue) : MemoryQueue {
    switch (versions) {
      case (#v0(v0)) v0;
      case (_) Runtime.trap("Unsupported version. Please upgrade the memory queue to the latest version.");
    };
  };
};
