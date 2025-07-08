module weissfarming::farm_flowx;
use sui::table::{Self, Table};
use weissfarming::wf_decimal::{Self};
use weissfarming::errors::{ENotAllowedTypeName, ERewardPoolAlreadyExist, ENotUpgrade, EUnauthorized, EUnclaimedRewards, EInvalidRewardPool, EPackageVersionError, EInvalidHolderPositionCap};
use weissfarming::reward_pool::{intern_create_reward_pool, RewardPool};
use std::type_name::{Self, TypeName};
use weissfarming::reward_pool;
use weissfarming::constants::{VERSION};
use weissfarming::farm_admin::{AdminCap, intern_new_farm_admin};
use sui::coin::{Coin};
use weissfarming::wf_decimal::from_scaled_val;

public struct RewardPoolInfo has store {
    token_type: TypeName,
    global_index: u256,
    pool_id: ID,
    decimals: u8
}

// public struct TickRewardTier has store {
//     lower_tick_normalized: u64,
//     upper_tick_normalized: u64,
//     reward_multiplier_bps: u32,
// }

public struct Farm has key, store {
    id: UID,
    version: u64,
    total_staked: u256,
    allowed_token_list: vector<TypeName>,
    // tick_reward_tiers: vector<TickRewardTier>,
    reward_pools: vector<RewardPoolInfo>,
}

public struct UserRewardInfo has store, drop {
    user_index: u256,
    pending_rewards: u64,
}
public struct HolderPositionCap has key, store {
    id: UID,
    farm_id: ID,
    balance: u256,
    reward_info: Table<TypeName, UserRewardInfo>,
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


// === Admin Functions ===
entry public fun create_reward_pool<T>(admin_cap: &AdminCap, farm: &mut Farm, decimals: u8, ctx: &mut TxContext){
    assert!(farm.version == VERSION(), EPackageVersionError());
    assert!(admin_cap.get_farm_id() == object::id(farm), EUnauthorized());

    let reward_pool = intern_create_reward_pool<T>(object::id(farm), ctx);
    // Get the reward pool type name
    let tn = type_name::get<T>();
    // Assert the reward pool doesnt exist
    assert!(!vec_contains(&farm.reward_pools, tn), ERewardPoolAlreadyExist());
    
    // Add the reward pool to the farm
    vector::push_back(&mut farm.reward_pools, RewardPoolInfo {
        token_type: tn,
        global_index: 0,
        pool_id: object::id(&reward_pool),
        decimals
    });
   
    // Share the reward pool as a shared object
    transfer::public_share_object(reward_pool);
}

// === Public Functions ===
entry public fun stake_position(position: Position, farm: &mut Farm, ctx: &mut TxContext){
    assert!(farm.version == VERSION(), EPackageVersionError());
    // Assert position is allowed to stake
    assert!(farm.allowed_token_list.contains(&position.coin_type_x), ENotAllowedTypeName());
    assert!(farm.allowed_token_list.contains(&position.coin_type_y), ENotAllowedTypeName());

    let mut reward_info = table::new(ctx);

    let mut i = 0;
    // Initialize with actual global indices from reward pools
    while (i < vector::length(&farm.reward_pools)) {
        // Get the reward pool
        let reward_pool = vector::borrow(&farm.reward_pools, i);
        
        // Add to the table the tokens configs
        reward_info.add(reward_pool.token_type, 
        UserRewardInfo { 
            user_index: reward_pool.global_index, 
            pending_rewards: 0 }
        );

        i = i + 1;
    };

    // Update farm total staked
    farm.total_staked = wf_decimal::from_scaled_val(farm.total_staked).add(wf_decimal::from_q64(position.liquidity)).to_scaled_val();

    let holder_position = HolderPositionCap {
        id: object::new(ctx),
        farm_id: object::id(farm),
        balance: position.liquidity as u256,
        reward_info,
        position,
    };
  
    // Transfer actual position embeded to the user so only him own his position
    transfer::public_transfer(holder_position, ctx.sender());
}

entry public fun unstake_position(holder_position_cap: HolderPositionCap, farm: &mut Farm, ctx: &mut TxContext){
    assert!(farm.version == VERSION(), EPackageVersionError());
    assert!(holder_position_cap.farm_id == object::id(farm), EInvalidHolderPositionCap());
    // Destructure the HolderPositionCap
    let HolderPositionCap {
        id,
        farm_id:_,
        balance,
        reward_info,
        position,
    } = holder_position_cap;

    let mut i = 0;
    // Initialize with actual global indices from reward pools
    while (i < vector::length(&farm.reward_pools)) {
        // Get the reward pool
        let reward_pool = vector::borrow(&farm.reward_pools, i);
        
        // Add to the table the tokens configs
        let user_reward_info = reward_info.borrow(reward_pool.token_type);

        if (user_reward_info.user_index != reward_pool.global_index){
            // Abort, the user have unclaimed reward he should claim first before closing
            abort EUnclaimedRewards()
        };

        i = i + 1;
    };

    // Update farm total staked (subtract the position's liquidity)
    farm.total_staked = wf_decimal::from_scaled_val(farm.total_staked).sub(wf_decimal::from_scaled_val(balance)).to_scaled_val();
    // Drop the wallet
    table::drop(reward_info);
    // Delete the wrapper object
    id.delete();
    
    // Transfer the original position back to the user
    transfer::public_transfer(position, ctx.sender());
}

entry public fun claim_rewards<T>(holder_position_cap: &mut HolderPositionCap, reward_pool: &mut RewardPool<T>, farm: &mut Farm, ctx: &mut TxContext){
    assert!(farm.version == VERSION(), EPackageVersionError());
    assert!(holder_position_cap.farm_id == object::id(farm), EInvalidHolderPositionCap());
    assert!(reward_pool::get_farm_id(reward_pool) == object::id(farm), EInvalidRewardPool());

    let mut i = 0;
    // Update the reward index
    while (i < vector::length(&farm.reward_pools)) {
        // Get the reward pool
        let reward_pool_info = vector::borrow_mut(&mut farm.reward_pools, i);
  
        // Only process the matching token type
        if (reward_pool_info.token_type == type_name::get<T>()) {
            let user_reward_info = table::borrow_mut(&mut holder_position_cap.reward_info, type_name::get<T>());

            // Calculate user reward
            let rewards = wf_decimal::mul(
                wf_decimal::sub(
                wf_decimal::from_scaled_val(reward_pool_info.global_index),
                wf_decimal::from_scaled_val(user_reward_info.user_index)
                ),
                wf_decimal::from_scaled_val(holder_position_cap.balance)
            );
            let rewards_to_u64 = rewards.to_native_with_decimals(reward_pool_info.decimals);

            let reward_coin = reward_pool::intern_withdraw_balance<T>(rewards_to_u64, reward_pool);
            // Update the user reward index
            user_reward_info.user_index = reward_pool_info.global_index;
            // Let the user claim his rewards
            transfer::public_transfer(reward_coin.into_coin(ctx), ctx.sender());

            break
        };
       
        i = i + 1;
    };
}

entry public fun distribute_rewards<T>(coin: Coin<T>, reward_pool: &mut RewardPool<T>, farm: &mut Farm){
    assert!(farm.version == VERSION(), EPackageVersionError());
    assert!(reward_pool::get_farm_id(reward_pool) == object::id(farm), EInvalidRewardPool());
    
    let mut i = 0;
    // Update the reward index
    while (i < vector::length(&farm.reward_pools)) {
        // Get the reward pool
        let reward_pool_info = vector::borrow_mut(&mut farm.reward_pools, i);

        if (reward_pool_info.token_type == type_name::get<T>()){
            // Verify pool ID matches
            assert!(reward_pool_info.pool_id == object::id(reward_pool), EInvalidRewardPool());
            if (farm.total_staked == 0) {
                // No stakers, just add to pool without updating index
                // Rewards will be distributed when users start staking
                reward_pool::intern_add_yield_gain_pending(wf_decimal::from_native_with_decimals(coin.value(), reward_pool_info.decimals).to_scaled_val(), reward_pool);
                reward_pool::intern_add_balance(coin, reward_pool);
                return
            };

            let new_global_index = wf_decimal::from_scaled_val(reward_pool_info.global_index).add(
                wf_decimal::add(
                    wf_decimal::from_native_with_decimals(coin.value(), reward_pool_info.decimals), 
                    wf_decimal::from_scaled_val(reward_pool::get_yield_gain_pending(reward_pool))
                ).div(wf_decimal::from_scaled_val(farm.total_staked))
            );
            reward_pool::intern_reset_yield_gain_pending(reward_pool);
            // Update the global index of the reward pool
            reward_pool_info.global_index = new_global_index.to_scaled_val();
        };
        
        i = i + 1;
    };

    // Add the coin balance to it's current reward pool
    reward_pool::intern_add_balance(coin, reward_pool);
}   


fun init(ctx: &mut TxContext){
    let new_farm = Farm {
        id: object::new(ctx),
        version: VERSION(),
        total_staked: 0,
        allowed_token_list: vector::empty(),
        // tick_reward_tiers: vector::empty(),
        reward_pools: vector::empty(),
    };

    let admin_cap = intern_new_farm_admin(object::id(&new_farm), ctx);

    transfer::public_share_object(new_farm);
    transfer::public_transfer(admin_cap, ctx.sender());
}

entry fun migrate(admin_cap: &AdminCap, farm: &mut Farm) {
    assert!(admin_cap.get_farm_id() == object::id(farm), EUnauthorized());
    assert!(farm.version < VERSION(), ENotUpgrade());
    farm.version = VERSION();
}


// === Private Functions ===
fun vec_contains(v: &vector<RewardPoolInfo>, tn: TypeName): bool {
  let len = vector::length(v);
  let mut i = 0;
  while (i < len) {
    if (vector::borrow(v, i).token_type == tn) {
      return true
    };
    i = i + 1;
  };
  false
}

// Convert FlowX::I32 to signed value
// fun decode_i32(i: &I32): (bool, u64) {
//     if (i.bits <= 0x7FFFFFFF) {
//         (false, i.bits as u64)
//     } else {
//         // Compute signed value manually from two's complement
//         (true, 0x1_0000_0000 - (i.bits as u64))
//     }

//     /*
//         let (is_neg, val) = decode_i32(&pos.tick_lower_index);
//         if (is_neg) {
//             // Treat as -val
//         } else {
//             // Treat as +val
//         }
//     */
// }

// fun normalize_tick(tick: I32): u64 {
//     let (is_neg, val) = decode_i32(&tick);
//     if (is_neg) {
//         // Map negative values to 0..0x80000000
//         0x80000000 - val
//     } else {
//         // Map positive values to 0x80000000..0x100000000
//         0x80000000 + val
//     }
// }
// fun position_matches_tier(position: &Position, tier: &TickRewardTier): bool {
//       let pos_lower_norm = normalize_tick(position.tick_lower_index);
//       let pos_upper_norm = normalize_tick(position.tick_upper_index);

//       // Simple unsigned comparison
//       pos_lower_norm >= tier.lower_tick_normalized &&
//       pos_upper_norm <= tier.upper_tick_normalized
//   }
