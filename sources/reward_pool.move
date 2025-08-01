module weissfarming::reward_pool;

// === Imports ===
use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};

// === Structs ===
public struct RewardPool<phantom T> has key, store {
    id: UID,
    farm_id: ID,
    total_balance: Balance<T>,
    yield_gain_pending: u256,
}

// === Package Functions ===
public(package) fun intern_create_reward_pool<T>(farm_id: ID, ctx: &mut TxContext): RewardPool<T> {
    // Create the treasury shared object
    let reward_pool = RewardPool<T> {
        id: object::new(ctx),
        farm_id,
        total_balance: balance::zero(),
        yield_gain_pending: 0
    };
    
    // Emit creation of a reward pool event
    //emit_reward_pool_event(object::id(&reward_pool), 0, 0);

    // Owned object transfer
    reward_pool
}

public(package) fun intern_add_balance<T>(coin: Coin<T>, reward_pool: &mut RewardPool<T>){
    // Add balance to the reward pool
    let balance = coin::into_balance(coin); 
    reward_pool.total_balance.join(balance);
}

public(package) fun intern_withdraw_balance<T>(amount: u64, reward_pool: &mut RewardPool<T>): Balance<T> {
    // Get the balance from the reward_pool
    let balance = reward_pool.total_balance.split(amount);
    balance
}

public(package) fun intern_add_yield_gain_pending<T>(amount: u256, reward_pool: &mut RewardPool<T>) {
    // Get the balance from the reward_pool
    reward_pool.yield_gain_pending = reward_pool.yield_gain_pending + amount;
}
public(package) fun intern_reset_yield_gain_pending<T>(reward_pool: &mut RewardPool<T>) {
    // Get the balance from the reward_pool
    reward_pool.yield_gain_pending = 0;
}

// === View Functions ===
public fun get_balance<T>(reward_pool: &RewardPool<T>): u64 {
    // Get the balance from the reward_pool
    reward_pool.total_balance.value()
}

public fun get_yield_gain_pending<T>(reward_pool: &RewardPool<T>): u256 {
    // Get the balance from the reward_pool
    reward_pool.yield_gain_pending
}
public fun get_farm_id<T>(reward_pool: &RewardPool<T>): ID {
    // Get the balance from the reward_pool
    reward_pool.farm_id
}

