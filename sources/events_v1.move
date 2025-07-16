module weissfarming::events_v1;

// === Imports ===
use sui::event;
use std::ascii::String;

// === Events ===
public struct NewStakePositionEvent has copy, drop {
    farm_id: ID,
    balance: u256,
}

public struct UnstakePositionEvent has copy, drop {
    farm_id: ID,
    balance: u256
}

public struct ClaimRewardEvent has copy, drop {
    farm_id: ID,
    amount: u64,
    coin_type: String
}

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

public fun emit_new_stake_position_event(farm_id: ID, balance: u256) {
    event::emit(NewStakePositionEvent {
        farm_id,
        balance,
    });
}

public fun emit_unstake_position_event(farm_id: ID, balance: u256) {
    event::emit(UnstakePositionEvent {
        farm_id,
        balance,
    });
}

public fun emit_claim_reward_event(farm_id: ID, amount: u64, coin_type: String) {
    event::emit(ClaimRewardEvent {
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