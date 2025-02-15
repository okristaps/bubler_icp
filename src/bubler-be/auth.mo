import List "mo:base/List";
import Principal "mo:base/Principal";

module {
    public func addAdmin(admins : List.List<Principal>, caller : Principal, newAdmin : Principal) : List.List<Principal> {
        if (List.find<Principal>(admins, func(p) { p == caller }) == null) {
            return admins;
        };
        return List.push(newAdmin, admins);
    };

    public func removeAdmin(admins : List.List<Principal>, caller : Principal, adminToRemove : Principal) : List.List<Principal> {
        if (List.some<Principal>(admins, func(p : Principal) : Bool { p == adminToRemove })) {
            return List.filter<Principal>(admins, func(p : Principal) : Bool { p != adminToRemove });
        };
        return admins;
    };

    public func isAuthorized(admins : List.List<Principal>, caller : Principal) : Bool {
        switch (List.find<Principal>(admins, func(admin) { admin == caller })) {
            case (?_) true;
            case null false;
        };
    };

    public func getAdmins(admins : List.List<Principal>) : [Principal] {
        return List.toArray(admins);
    };
};
