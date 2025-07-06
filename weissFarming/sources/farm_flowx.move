module weissfarming::farm_flowx;
use sui::table::{Self, Table};
use sui::object_table::{Self, ObjectTable};
use sui::balance::Balance;
use weissfarming::wf_decimal::Decimal;
use weissfarming::errors::{ENotAllowedTypeName, ERewardPoolAlreadyExist};
use weissfarming::reward_pool::{intern_create_reward_pool, RewardPool};
use std::type_name::{Self, TypeName};
use sui::dynamic_object_field;
use weissfarming::reward_pool;


 public struct RewardPoolInfo has store {
      token_type: TypeName,
      global_index: u256,
      pool_id: ID,
  }


public struct Farm has key {
    id: UID,
    total_staked: u64,
    allowed_token_list: vector<TypeName>,
    reward_pools: vector<RewardPoolInfo>,
}


public struct HolderPositionCap has key, store {
    id: UID,
    balance: u256,
    reward_indices: Table<TypeName, u256>,  // Track index per reward token
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

// === Admin Functions ===
entry public fun create_reward_pool<T>(farm: &mut Farm, ctx: &mut TxContext){
    let reward_pool = intern_create_reward_pool<T>(ctx);
    // Get the reward pool type name
    let tn = type_name::get<T>();
    // Assert the reward pool doesnt exist
    assert!(!vec_contains(&farm.reward_pools, tn), ERewardPoolAlreadyExist());
    
    // Add the reward pool to the farm
    vector::push_back(&mut farm.reward_pools, RewardPoolInfo {
        token_type: tn,
        global_index: 0,
        pool_id: object::id(&reward_pool),
    });
   
    // Share the reward pool as a shared object
    transfer::public_share_object(reward_pool);
}

// === Public Functions ===
entry public fun stake_position(position: Position, farm: &mut Farm, ctx: &mut TxContext){
    // Assert position is allowed to stake
    assert!(farm.allowed_token_list.contains(&position.coin_type_x), ENotAllowedTypeName());
    assert!(farm.allowed_token_list.contains(&position.coin_type_y), ENotAllowedTypeName());

    let reward_indices = table::new(ctx);
    let pending_rewards = table::new(ctx);

    let i = 0;
    // Initialize with actual global indices from reward pools
    while (i < vector::length(&farm.reward_pools)) {
        // Get the reward pool
        let  reward_pool = vector::borrow(&farm.reward_pools, i);
        
        // Add to the table the tokens configs
        reward_indices.add(reward_pool.token_type, reward_pool.global_index);
        pending_rewards.add(reward_pool.token_type, 0);

        i = i + 1;
    };

    let holder_position = HolderPositionCap {
        id: object::new(ctx),
        balance: position.liquidity as u256,
        reward_indices: reward_indices,
        pending_rewards: pending_rewards,
        position,
    };
    // TODO: Add position pref by position liquidity:

    
    // Update farm total staked
    farm.total_staked = farm.total_staked + position.liquidity;

    // Transfer actual position embeded to the user so only him own his position
    transfer::public_transfer(holder_position, ctx.sender());
}


// === Private Functions ===
fun vec_contains(v: &vector<RewardPoolInfo>, tn: TypeName): bool {
  let len = vector::length(v);
  let mut i = 0;
  while (i < len) {
    if (vector::borrow(v, i).token_type == tn) {
      return true;
    };
    i = i + 1;
  };
  false
}