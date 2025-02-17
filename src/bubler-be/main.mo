import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import List "mo:base/List";
import Array "mo:base/Array";
import Order "mo:base/Order";
import Int "mo:base/Int";
// import Debug "mo:base/Debug";
import Auth "./auth";
import Types "./types";
import Utils "./utils";
actor GameBackend {

  stable var authorizedAdmins : List.List<Principal> = List.nil<Principal>();

  public shared ({ caller }) func addAdmin(newAdmin : Principal) : async Bool {
    let updatedAdmins = Auth.addAdmin(authorizedAdmins, caller, newAdmin);
    if (updatedAdmins != authorizedAdmins) {
      authorizedAdmins := updatedAdmins;
      return true;
    };
    return false;
  };

  // shitty but init admin on first deploy
  //  public shared ({ caller }) func addAdmin(newAdmin : Principal) : async Bool {
  //     if (List.isNil(authorizedAdmins)) {

  //         authorizedAdmins := List.make(newAdmin);
  //         return true;
  //     };

  //     let updatedAdmins = Auth.addAdmin(authorizedAdmins, caller, newAdmin);
  //     if (updatedAdmins != authorizedAdmins) {
  //       authorizedAdmins := updatedAdmins;
  //       return true;
  //     };
  //     return false;
  // };

  public shared ({ caller }) func removeAdmin(adminToRemove : Principal) : async Bool {
    let updatedAdmins = Auth.removeAdmin(authorizedAdmins, caller, adminToRemove);
    if (updatedAdmins != authorizedAdmins) {
      authorizedAdmins := updatedAdmins;
      return true;
    };
    return false;
  };

  public shared ({ caller }) func getAdmins() : async ?[Principal] {
    if (isAuthorized(caller)) { return ?List.toArray(authorizedAdmins) };
    return null;
  };

  func isAuthorized(caller : Principal) : Bool {
    return Auth.isAuthorized(authorizedAdmins, caller);
  };

  stable var playerList : [(Text, Types.Player)] = [];
  stable var gameSessionsList : [(Text, Types.GameSession)] = [];

  var players = HashMap.HashMap<Text, Types.Player>(10, Text.equal, Text.hash);
  var gameSessions = HashMap.HashMap<Text, Types.GameSession>(10, Text.equal, Text.hash);

  system func preupgrade() {
    playerList := Iter.toArray(players.entries());
    gameSessionsList := Iter.toArray(gameSessions.entries());
  };

  system func postupgrade() {
    players := HashMap.fromIter<Text, Types.Player>(Iter.fromArray(playerList), 10, Text.equal, Text.hash);
    gameSessions := HashMap.fromIter<Text, Types.GameSession>(Iter.fromArray(gameSessionsList), 10, Text.equal, Text.hash);
  };

  public shared ({ caller }) func savePlayer(wallet : Text, username : Text) : async Bool {
    // Debug.print("🔍 Caller Principal: " # debug_show (caller));
    assert isAuthorized(caller);

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
    return true;
  };

  public shared ({ caller }) func startGame(wallet : Text) : async ?Types.GameSession {
    assert isAuthorized(caller);

    switch (players.get(wallet)) {
      case (?player) {
        let seed : Nat = Utils.generateRandomSeed();
        let gameId : Text = "game-" # Nat.toText(seed) # "-" # wallet;
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
        return gameSessions.get(gameId);
      };
      case _ { return null };
    };
  };

  public shared ({ caller }) func finishGame(gameId : Text, finalScore : Nat, finalTimePlayed : Text) : async Bool {
    assert isAuthorized(caller);

    switch (gameSessions.get(gameId)) {
      case (?session) {
        let updatedSession = {
          session with
          score = finalScore;
          timePlayed = finalTimePlayed;
          wallet = session.wallet;
          username = session.username;
        };

        gameSessions.put(gameId, updatedSession);
        return true;
      };
      case _ { return false };
    };
  };

  public shared query func getLeaderboard() : async [(Text, Text, Text, Nat, Nat, Text)] {
    return Iter.toArray(
      Iter.map<Types.GameSession, (Text, Text, Text, Nat, Nat, Text)>(
        gameSessions.vals(),
        func(s : Types.GameSession) : (Text, Text, Text, Nat, Nat, Text) {
          (s.gameId, s.wallet, s.username, s.seed, s.score, s.timePlayed);
        },
      )
    );
  };

  public shared query func getPlayers() : async [(Text, Text)] {
    return Iter.toArray(
      Iter.map<Types.Player, (Text, Text)>(
        players.vals(),
        func(p : Types.Player) : (Text, Text) { (p.wallet, p.username) },
      )
    );
  };

  public shared query func getGameSessions() : async [(Text, Text, Text, Nat, Nat, Text, Time.Time)] {
    return Iter.toArray(
      Iter.map<Types.GameSession, (Text, Text, Text, Nat, Nat, Text, Time.Time)>(
        gameSessions.vals(),
        func(s : Types.GameSession) : (Text, Text, Text, Nat, Nat, Text, Time.Time) {
          (s.gameId, s.wallet, s.username, s.seed, s.score, s.timePlayed, s.startedAt);
        },
      )
    );
  };

  public shared ({ caller }) func clearLeaderboard() : async Bool {
    assert isAuthorized(caller);

    gameSessions := HashMap.HashMap<Text, Types.GameSession>(10, Text.equal, Text.hash);
    return true;
  };

  public shared ({ caller }) func clearCompletedGames() : async Bool {
    assert isAuthorized(caller);

    let activeSessions = HashMap.HashMap<Text, Types.GameSession>(10, Text.equal, Text.hash);

    for ((gameId, session) in gameSessions.entries()) {
      if (session.score == 0) {
        activeSessions.put(gameId, session);
      };
    };

    gameSessions := activeSessions;
    return true;
  };

  public shared query func getTopLeaderboard(onlyCurrentWeek : Bool) : async [(Text, Text, Text, Nat, Nat, Text)] {
    let now : Nat = Int.abs(Time.now());
    let oneWeekInNano : Nat = 7 * 24 * 60 * 60 * 1_000_000_000;

    let oneWeekAgo : Nat = if (now >= oneWeekInNano) {
      now - oneWeekInNano;
    } else {
      0;
    };

    let sortedGames = Iter.toArray(
      Iter.sort<Types.GameSession>(
        gameSessions.vals(),
        func(a : Types.GameSession, b : Types.GameSession) : {
          #less;
          #equal;
          #greater;
        } {
          if (a.score > b.score) { #less } else if (a.score < b.score) {
            #greater;
          } else { #equal };
        },
      )
    );

    let filteredGames = if (onlyCurrentWeek) {
      Array.filter<Types.GameSession>(
        sortedGames,
        func(s : Types.GameSession) : Bool {
          Int.abs(s.startedAt) >= oneWeekAgo;
        },
      );
    } else {
      sortedGames;
    };

    let top10 = Array.subArray<Types.GameSession>(filteredGames, 0, Nat.min(10, filteredGames.size()));

    return Array.map<Types.GameSession, (Text, Text, Text, Nat, Nat, Text)>(
      top10,
      func(s : Types.GameSession) : (Text, Text, Text, Nat, Nat, Text) {
        (s.gameId, s.wallet, s.username, s.seed, s.score, s.timePlayed);
      },
    );
  }

};
