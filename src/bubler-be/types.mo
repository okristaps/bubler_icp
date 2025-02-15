import Time "mo:base/Time";

module {
    public type Player = {
        wallet : Text;
        username : Text;
    };

    public type GameSession = {
        gameId : Text;
        wallet : Text;
        username : Text;
        seed : Nat;
        score : Nat;
        timePlayed : Text;
        startedAt : Time.Time;
    };
};
