module weissfarming::events_v2;

// === Imports ===
use sui::event;
use flowx::i32::I32;
use std::ascii::String;


public struct NewStakePositionEvent has copy, drop {
    farm_id: ID,
    balance: u256,
    liquidity: u128,
    tick_lower_index: I32,
    tick_upper_index: I32
}

public struct NewStakePositionEventV2 has copy, drop {
    holder_position_id: ID,
    farm_id: ID,
    balance: u256,
    liquidity: u128,
    tick_lower_index: I32,
    tick_upper_index: I32
}
public struct UnstakePositionEventV2 has copy, drop {
    holder_position_id: ID,
    farm_id: ID,
    balance: u256
}

public struct ClaimRewardEventV2 has copy, drop {
    holder_position_id: ID,
    farm_id: ID,
    amount: u64,
    coin_type: String
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

public fun emit_new_stake_position_event_v2_1(holder_position_id: ID, farm_id: ID, balance: u256, liquidity: u128, tick_lower_index: I32, tick_upper_index: I32 ) {
    event::emit(NewStakePositionEventV2 {
        holder_position_id,
        farm_id,
        balance,
        liquidity,
        tick_lower_index,
        tick_upper_index
    });
}

public fun emit_unstake_position_event_v2(holder_position_id: ID, farm_id: ID, balance: u256) {
    event::emit(UnstakePositionEventV2 {
        holder_position_id,
        farm_id,
        balance,
    });
}

public fun emit_claim_reward_event_v2(holder_position_id: ID, farm_id: ID, amount: u64, coin_type: String) {
    event::emit(ClaimRewardEventV2 {
        holder_position_id,
        farm_id,
        amount,
        coin_type
    });
}