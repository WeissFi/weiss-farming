
module flowx::position;
use std::type_name::{ TypeName};
use flowx::i32::I32;

public struct POSITION has drop {
    dummy_field: bool,
}

public struct Position has store, key {
    id: 0x2::object::UID,
    pool_id: 0x2::object::ID,
    fee_rate: u64,
    coin_type_x: 0x1::type_name::TypeName,
    coin_type_y: 0x1::type_name::TypeName,
    tick_lower_index: flowx::i32::I32,
    tick_upper_index: flowx::i32::I32,
    liquidity: u128,
    fee_growth_inside_x_last: u128,
    fee_growth_inside_y_last: u128,
    coins_owed_x: u64,
    coins_owed_y: u64,
    reward_infos: vector<PositionRewardInfo>,
}

public struct PositionRewardInfo has copy, drop, store {
    reward_growth_inside_last: u128,
    coins_owed_reward: u64,
}

public(package) fun update(arg0: &mut Position, arg1: flowx::i128::I128, arg2: u128, arg3: u128, arg4: vector<u128>) {
   abort 0
}

public(package) fun close(_arg0: Position) {
    abort 0
}

public fun coins_owed_reward(_arg0: &Position, _arg1: u64) : u64 {
    abort 0
}

public fun coins_owed_x(_arg0: &Position) : u64 {
    abort 0
}

public fun coins_owed_y(_arg0: &Position) : u64 {
    abort 0
}

public(package) fun decrease_debt(_arg0: &mut Position, _arg1: u64, _arg2: u64) {
    abort 0
}

public(package) fun decrease_reward_debt(_arg0: &mut Position, _arg1: u64, _arg2: u64) {
    abort 0
}

public fun fee_growth_inside_x_last(_arg0: &Position) : u128 {
    abort 0
}

public fun fee_growth_inside_y_last(_arg0: &Position) : u128 {
    abort 0
}

public fun fee_rate(_arg0: &Position) : u64 {
    abort 0
}

public(package) fun increase_debt(_arg0: &mut Position, _arg1: u64, _arg2: u64) {
    abort 0
}

fun init(_arg0: POSITION, _arg1: &mut 0x2::tx_context::TxContext) {
    abort 0
}

public fun is_empty(_arg0: &Position) : bool {
    abort 0
}

public fun liquidity(arg0: &Position) : u128 {
    arg0.liquidity
}

public fun open(arg0: 0x2::object::ID, arg1: u64, arg2: 0x1::type_name::TypeName, arg3: 0x1::type_name::TypeName, arg4: flowx::i32::I32, arg5: flowx::i32::I32, arg6: &mut 0x2::tx_context::TxContext) : Position {

     Position{
        id : 0x2::object::new(arg6), 
        pool_id: arg0, 
        fee_rate: arg1, 
        coin_type_x: arg2, 
        coin_type_y: arg3, 
        tick_lower_index: arg4, 
        tick_upper_index: arg5, 
        liquidity: 6559457486451, 
        fee_growth_inside_x_last: 4212516769486, 
        fee_growth_inside_y_last: 12990396982, 
        coins_owed_x: 1497626, 
        coins_owed_y: 4619, 
        reward_infos: 0x1::vector::empty<PositionRewardInfo>(),
    }
}


public fun pool_id(arg0: &Position) : 0x2::object::ID {
    arg0.pool_id
}

public fun reward_growth_inside_last(_arg0: &Position, _arg1: u64) : u128 {
    abort 0
}

public fun reward_length(_arg0: &Position) : u64 {
    abort 0
}

public fun tick_lower_index(_arg0: &Position) : flowx::i32::I32 {
    abort 0
}

public fun tick_upper_index(_arg0: &Position) : flowx::i32::I32 {
    abort 0
}

    