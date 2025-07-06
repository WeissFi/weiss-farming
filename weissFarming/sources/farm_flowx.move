module weissfarming::farm_flowx;
use sui::table::{Self, Table};
use sui::object_table::{Self, ObjectTable};
use sui::balance::Balance;
use weissfarming::wf_decimal::Decimal;
use weissfarming::errors::{ENotAllowedTypeName};
use weissfarming::reward_pool::{intern_create_reward_pool, RewardPool};
use std::type_name::{Self, TypeName};



public struct Farm has key {
    id: UID,
    total_staked: u64,
    allowed_token_list: vector<TypeName>,
    reward_pool_types: vector<TypeName>,
}
public struct RewardPoolContainer<phantom T> has key, store {
  id: UID,
  pool: RewardPool<T>,
}

public struct HolderPosition has key, store {
    id: UID,
    balance: u256,
    reward_indices: Table<TypeName, Decimal>,  // Track index per reward token
    pending_rewards: Table<TypeName, u64>,     // Pending rewards per token
    position: Position,
}

public struct I32 has copy, drop, store {
    bits: u32
}

public struct PositionRewardInfo has copy, drop, store {
	reward_growth_inside_last: u128,
	coins_owed_reward: u64
}
public struct Position has key, store {
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
	reward_infos: vector<PositionRewardInfo>
}


/// Convert FlowX::I32 to signed value
fun decode_i32(i: &I32): (bool, u64) {
    if (i.bits <= 0x7FFFFFFF) {
        (false, i.bits as u64)
    } else {
        // Compute signed value manually from two's complement
        (true, 0x1_0000_0000 - (i.bits as u64))
    }

    /*
        let (is_neg, val) = decode_i32(&pos.tick_lower_index);
        if (is_neg) {
            // Treat as -val
        } else {
            // Treat as +val
        }
    */
}

entry public fun create_reward_pool<T>(farm: &mut Farm, ctx: &mut TxContext){
    let reward_pool = intern_create_reward_pool<T>(ctx);
    let container = RewardPoolContainer<T> {
        id: object::new(ctx),
        pool: reward_pool
    };
    let ty = type_name::get<T>();
    vector::push_back(&mut farm.reward_pool_types, ty);
}

entry public fun stake_position(position: Position, farm: &mut Farm, ctx: &mut TxContext){
    // Assert position is allowed to stake
    assert!(farm.allowed_token_list.contains(&position.coin_type_x), ENotAllowedTypeName());
    assert!(farm.allowed_token_list.contains(&position.coin_type_y), ENotAllowedTypeName());

    let holder_position = HolderPositionCap {
        id: object::new(ctx),
        balance: position.liquidity as u256,
        reward_indices: ,
        pending_rewards,
        position,
    }

}