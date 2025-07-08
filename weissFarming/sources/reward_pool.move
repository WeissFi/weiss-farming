module weissfarming::reward_pool;
use sui::table::{Self, Table};
use sui::balance::{Self, Balance};
use weissfarming::wf_decimal::Decimal;
use weissfarming::errors::{ENotAllowedTypeName};
use std::type_name::TypeName;
use sui::coin::{Self, Coin};

public struct RewardPool<phantom T> has key, store {
    id: UID,
    global_index: u256,
    total_balance: Balance<T>,
    prev_reward_balance: u256,
}

// === Package Functions ===
public(package) fun intern_create_reward_pool<T>(ctx: &mut TxContext): RewardPool<T> {
    // Create the treasury shared object
    let reward_pool = RewardPool<T> {
        id: object::new(ctx),
        global_index: 0,
        total_balance: balance::zero(),
        prev_reward_balance: 0,
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

public(package) fun intern_get_balance<T>(amount: u64, reward_pool: &mut RewardPool<T>): Balance<T> {
    // Get the balance from the reward_pool
    let balance = reward_pool.total_balance.split(amount);
    balance
}