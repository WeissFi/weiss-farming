module weissfarming::events_v1;

// === Imports ===
use  sui::event;
use std::ascii::String;

// === Events ===
public struct StakePositionEvent has copy, drop {
    farm_id: ID,
    balance: ID,
    index: u64,
}

// public fun emit_stake_position_event() {
//     event::emit(StakePositionEvent {
        
//     });
// }