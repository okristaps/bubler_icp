import List "mo:base/List";
import Principal "mo:base/Principal";

module {

    public func addAdmin(admins : List.List<Principal>, caller : Principal, newAdmin : Principal) : List.List<Principal> {
        if (List.some<Principal>(admins, func(p : Principal) : Bool { p == caller })) {
            return List.push(newAdmin, admins);
        };
        return admins;
    };

    public func removeAdmin(admins : List.List<Principal>, caller : Principal, adminToRemove : Principal) : List.List<Principal> {
        if (List.some<Principal>(admins, func(p : Principal) : Bool { p == caller })) {
            return List.filter<Principal>(admins, func(p : Principal) : Bool { p != adminToRemove });
        };
        return admins;
    };

    public func isAuthorized(admins : List.List<Principal>, caller : Principal) : Bool {
        return List.some<Principal>(admins, func(admin : Principal) : Bool { admin == caller });
    };

    public func getAdmins(admins : List.List<Principal>) : [Principal] {
        return List.toArray<Principal>(admins);
    };
};
