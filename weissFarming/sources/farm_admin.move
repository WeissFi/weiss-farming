module weissfarming::farm_admin;


public struct AdminCap has key, store {
    id: UID,
    farm_id: ID
}

// === Private Functions ===
public(package) fun intern_new_farm_admin(farm_id: ID, ctx: &mut TxContext): AdminCap {
    let admin_cap = AdminCap {
        id: object::new(ctx),
        farm_id: farm_id
    };

    admin_cap
    // Emit creation of the admin capability
    //emit_create_admin_cap_event(object::id(&admin));
}

public(package) fun get_farm_id(admin_cap: &AdminCap): ID{
    admin_cap.farm_id
}