import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";

actor GameBackend {

  type Player = {
    wallet : Text;
    username : Text;
  };

  type GameSession = {
    gameId : Text;
    wallet : Text;
    username : Text;
    seed : Nat;
    score : Nat;
    timePlayed : Text;
    startedAt : Time.Time;
  };

  stable var playerList : [(Text, Player)] = [];
  stable var gameSessionsList : [(Text, GameSession)] = [];

  var players = HashMap.HashMap<Text, Player>(10, Text.equal, Text.hash);
  var gameSessions = HashMap.HashMap<Text, GameSession>(10, Text.equal, Text.hash);

  system func preupgrade() {
    playerList := Iter.toArray(players.entries());
    gameSessionsList := Iter.toArray(gameSessions.entries());
  };

  system func postupgrade() {
    players := HashMap.fromIter<Text, Player>(Iter.fromArray(playerList), 10, Text.equal, Text.hash);
    gameSessions := HashMap.fromIter<Text, GameSession>(Iter.fromArray(gameSessionsList), 10, Text.equal, Text.hash);
  };

  func generateRandomSeed() : Nat {
    let timeSeed : Int = Time.now();
    let natSeed : Nat64 = Nat64.fromIntWrap(timeSeed);
    let textSeed : Text = Nat64.toText(natSeed);

    let paddedSeed = if (Text.size(textSeed) < 20) {
      "1" # textSeed;
    } else {
      textSeed;
    };

    switch (Nat.fromText(paddedSeed)) {
      case (?validNat) { validNat };
      case null { 0 };
    };
  };

  public shared func savePlayer(wallet : Text, username : Text) : async () {
    switch (players.get(wallet)) {
      case (?existingPlayer) {
        if (existingPlayer.username == username) {} else {

          var counter = 1;
          var newUsername = username # "-" # Nat.toText(counter);

          while (players.get(newUsername) != null) {
            counter += 1;
            newUsername := username # "-" # Nat.toText(counter);
          };

          let newPlayer = { wallet = wallet; username = newUsername };
          players.put(wallet, newPlayer);
        };
      };
      case _ {
        let newPlayer = { wallet = wallet; username = username };
        players.put(wallet, newPlayer);
      };
    };
  };

  public shared func startGame(wallet : Text) : async ?GameSession {
    switch (players.get(wallet)) {
      case (?player) {
        let seed : Nat = generateRandomSeed();
        let gameId : Text = "game-" # Nat.toText(seed);

        let session = {
          gameId = gameId;
          wallet = wallet;
          username = player.username;
          seed = seed;
          score = 0;
          timePlayed = "0:00";
          startedAt = Time.now();
        };

        gameSessions.put(gameId, session);

        switch (gameSessions.get(gameId)) {
          case (?storedSession) { return ?storedSession };
          case _ { return null };
        };
      };
      case _ { return null };
    };
  };

  public shared func updateScore(gameId : Text, newScore : Nat, timePlayed : Text) : async () {
    switch (gameSessions.get(gameId)) {
      case (?session) {
        gameSessions.put(gameId, { session with score = newScore; timePlayed = timePlayed });
      };
      case _ {};
    };
  };

  public shared func finishGame(gameId : Text, finalScore : Nat, finalTimePlayed : Text) : async Bool {
    switch (gameSessions.get(gameId)) {
      case (?session) {
        let finishedSession = {
          session with score = finalScore;
          timePlayed = finalTimePlayed;
        };

        gameSessions.put(gameId, finishedSession);
        return true;
      };
      case _ { return false };
    };
  };

  public shared query func getLeaderboard() : async [(Text, Text, Text, Nat, Nat, Text)] {
    return Iter.toArray(
      Iter.map<GameSession, (Text, Text, Text, Nat, Nat, Text)>(
        gameSessions.vals(),
        func(s : GameSession) : (Text, Text, Text, Nat, Nat, Text) {
          (s.gameId, s.wallet, s.username, s.seed, s.score, s.timePlayed);
        },
      )
    );
  };

  public shared query func getPlayers() : async [(Text, Text)] {
    return Iter.toArray(
      Iter.map<Player, (Text, Text)>(
        players.vals(),
        func(p : Player) : (Text, Text) { (p.wallet, p.username) },
      )
    );
  };

  public shared query func getGameSessions() : async [(Text, Text, Text, Nat, Nat, Text, Time.Time)] {
    return Iter.toArray(
      Iter.map<GameSession, (Text, Text, Text, Nat, Nat, Text, Time.Time)>(
        gameSessions.vals(),
        func(s : GameSession) : (Text, Text, Text, Nat, Nat, Text, Time.Time) {
          (s.gameId, s.wallet, s.username, s.seed, s.score, s.timePlayed, s.startedAt);
        },
      )
    );
  };
};
