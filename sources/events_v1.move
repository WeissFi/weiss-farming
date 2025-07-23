module weissfarming::events_v1;

// === Imports ===
use sui::event;
use std::ascii::String;
use flowx::i32::I32;
// === Events ===

public struct DistributeRewardEvent has copy, drop {
    farm_id: ID,
    amount: u64,
    coin_type: String
}

public struct NewRewardPoolCreatedEvent has copy, drop {
    farm_id: ID,
    pool_id: ID,
    coin_type: String
}


public struct NewStakePositionEvent has copy, drop {
    holder_position_id: ID,
    farm_id: ID,
    balance: u256,
    liquidity: u128,
    tick_lower_index: I32,
    tick_upper_index: I32
}
public struct UnstakePositionEvent has copy, drop {
    holder_position_id: ID,
    farm_id: ID,
    balance: u256
}

public struct ClaimRewardEvent has copy, drop {
    holder_position_id: ID,
    farm_id: ID,
    amount: u64,
    coin_type: String
}


public fun emit_new_stake_position_event(holder_position_id: ID, farm_id: ID, balance: u256, liquidity: u128, tick_lower_index: I32, tick_upper_index: I32 ) {
    event::emit(NewStakePositionEvent {
        holder_position_id,
        farm_id,
        balance,
        liquidity,
        tick_lower_index,
        tick_upper_index
    });
}

public fun emit_unstake_position_event(holder_position_id: ID, farm_id: ID, balance: u256) {
    event::emit(UnstakePositionEvent {
        holder_position_id,
        farm_id,
        balance,
    });
}

public fun emit_claim_reward_event(holder_position_id: ID, farm_id: ID, amount: u64, coin_type: String) {
    event::emit(ClaimRewardEvent {
        holder_position_id,
        farm_id,
        amount,
        coin_type
    });
}

public fun emit_distribute_reward_event(farm_id: ID, amount: u64, coin_type: String) {
    event::emit(DistributeRewardEvent {
        farm_id,
        amount,
        coin_type
    });
}

public fun emit_new_reward_pool_created_event(farm_id: ID, pool_id: ID, coin_type: String) {
    event::emit(NewRewardPoolCreatedEvent {
        farm_id,
        pool_id,
        coin_type
    });
}