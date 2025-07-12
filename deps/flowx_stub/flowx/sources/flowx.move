
module flowx::position;

use sui::object::{UID, ID};
use std::type_name::{Self, TypeName};
public struct I32 has copy, drop, store {
    bits: u32
}
public struct PositionRewardInfo has copy, drop, store {
    reward_growth_inside_last: u128,
    coins_owed_reward: u64,
}

// This is the actual struct that represents FlowX NFT on-chain
public struct Position has store, key {
    id: UID,
    pool_id: ID,
    fee_rate: u64,
    coin_type_x: TypeName,
    coin_type_y: TypeName,
    tick_lower_index: I32,
    tick_upper_index: I32,
    liquidity: u128,
    fee_growth_inside_x_last: u128,
    fee_growth_inside_y_last: u128,
    coins_owed_x: u64,
    coins_owed_y: u64,
    reward_infos: vector<PositionRewardInfo>,
}

// Public accessor functions for Position fields
public fun coin_type_x(position: &Position): TypeName {
    position.coin_type_x
}

public fun coin_type_y(position: &Position): TypeName {
    position.coin_type_y
}

public fun liquidity(position: &Position): u128 {
    position.liquidity
}

public fun pool_id(position: &Position): ID {
    position.pool_id
}

public fun fee_rate(position: &Position): u64 {
    position.fee_rate
}

public fun tick_lower_index(position: &Position): I32 {
    position.tick_lower_index
}

public fun tick_upper_index(position: &Position): I32 {
    position.tick_upper_index
}

// Function to create I32 for testing
public fun new_i32(bits: u32): I32 {
    I32 { bits }
}

// Function to create Position for testing
public fun new_position(
    pool_id: ID,
    fee_rate: u64,
    coin_type_x: TypeName,
    coin_type_y: TypeName,
    tick_lower_index: I32,
    tick_upper_index: I32,
    liquidity: u128,
    fee_growth_inside_x_last: u128,
    fee_growth_inside_y_last: u128,
    coins_owed_x: u64,
    coins_owed_y: u64,
    ctx: &mut sui::tx_context::TxContext
): Position {
    Position {
        id: sui::object::new(ctx),
        pool_id,
        fee_rate,
        coin_type_x,
        coin_type_y,
        tick_lower_index,
        tick_upper_index,
        liquidity,
        fee_growth_inside_x_last,
        fee_growth_inside_y_last,
        coins_owed_x,
        coins_owed_y,
        reward_infos: vector::empty(),
    }
}
