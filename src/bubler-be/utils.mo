import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";

module {
    public func generateRandomSeed() : Nat {
        let timeSeed : Int = Time.now();
        let natSeed : Nat64 = Nat64.fromIntWrap(timeSeed);
        Nat64.toNat(natSeed);
    };
};
