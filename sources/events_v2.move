module weissfarming::events_v2;

// === Imports ===
use sui::event;
use flowx::i32::I32;

public struct NewStakePositionEvent has copy, drop {
    farm_id: ID,
    balance: u256,
    liquidity: u128,
    tick_lower_index: I32,
    tick_upper_index: I32
}

public fun emit_new_stake_position_event_v2(farm_id: ID, balance: u256, liquidity: u128, tick_lower_index: I32, tick_upper_index: I32 ) {
    event::emit(NewStakePositionEvent {
        farm_id,
        balance,
        liquidity,
        tick_lower_index,
        tick_upper_index
    });
}