module weissfarming::farm;
use sui::table::{Self, Table};
use sui::balance::Balance;


public struct RewardToken<phantom T> has key, store {
    id: UID,
    token_type: Balance<T>,

}

public struct Farm<phantom T> has key {
    id: UID,
    total_staked: u64,
    reward_pool: Table<ID, RewardToken<T>>,
    allowed_token_list: vector<address>,

}
