// module weissfarming::farm_registry;
// use sui::table::{Self, Table};
// use sui::balance::Balance;
// use weissfarming::wf_decimal::Decimal;

// public struct RewardToken<phantom T> has key, store {
//     id: UID,
//     global_index: Decimal,
//     total_balance: Balance<T>,
//     prev_reward_balance: Decimal,
// }

// public struct FarmRegistry<phantom T> has key {
//     id: UID,
//     total_staked: u64,
//     reward_pool: Table<ID, RewardToken<T>>,
//     allowed_token_list: vector<address>,
// }
