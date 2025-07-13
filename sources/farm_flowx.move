module weissfarming::farm_flowx;

// === Imports ===
use weissfarming::wf_decimal;
use weissfarming::errors::{ENotAllowedPool, ERewardPoolAlreadyExist, ENotUpgrade, EUnauthorized, EUnclaimedRewards, EInvalidRewardPool, EPackageVersionError, EInvalidHolderPositionCap, EInvalidPositionSource};
use weissfarming::reward_pool::{intern_create_reward_pool, RewardPool};
use weissfarming::reward_pool;
use weissfarming::constants::{VERSION, FLOWX_V3_ADDRESS};
use weissfarming::farm_admin::{AdminCap, intern_new_farm_admin};
use weissfarming::events_v1::{emit_new_stake_position_event, emit_unstake_position_event, emit_claim_reward_event, emit_distribute_reward_event, emit_new_reward_pool_created_event};
use sui::coin::{Coin};
use sui::display;
use sui::package::{Publisher};
use sui::table::{Self, Table};
use sui::address;

use std::type_name::{Self, TypeName};

// Import FlowX position types from local stub
use flowx::position::{Self, Position};

// === Structs ===
public struct RewardPoolInfo has store {
    token_type: TypeName,
    global_index: u256,
    pool_id: ID,
    decimals: u8
}

public struct Farm has key, store {
    id: UID,
    version: u64,
    total_staked: u256,
    allowed_pool_ids: vector<ID>,
    // tick_reward_tiers: vector<TickRewardTier>,
    reward_pools: vector<RewardPoolInfo>,
    flowx_v3_address: address,
}

public struct UserRewardInfo has store, drop {
    user_index: u256
}
public struct HolderPositionCap has key, store {
    id: UID,
    farm_id: ID,
    balance: u256,
    reward_info: Table<TypeName, UserRewardInfo>,
    position: Position,
}


// === Public Functions ===
entry public fun stake_position(position: Position, farm: &mut Farm, ctx: &mut TxContext){
    assert!(farm.version == VERSION(), EPackageVersionError());
    
    // Verify the Position comes from FlowX v3 package
    let position_type = type_name::get<Position>();
    let address_string = position_type.get_address();
    let position_addr = address::from_ascii_bytes(address_string.as_bytes());
    assert!(position_addr == farm.flowx_v3_address, EInvalidPositionSource());
    
    // Assert position pool is allowed to stake
    let pool_id = position::pool_id(&position);
    assert!(farm.allowed_pool_ids.contains(&pool_id), ENotAllowedPool());

    let mut reward_info = table::new(ctx);

    let mut i = 0;
    // Initialize with actual global indices from reward pools
    while (i < vector::length(&farm.reward_pools)) {
        // Get the reward pool
        let reward_pool = vector::borrow(&farm.reward_pools, i);
        
        // Add to the table the tokens configs
        reward_info.add(reward_pool.token_type, 
        UserRewardInfo { 
            user_index: reward_pool.global_index,  }
        );

        i = i + 1;
    };
    // Emit new stake position
    emit_new_stake_position_event(
        object::id(farm),
        wf_decimal::from_q64(position::liquidity(&position)).to_scaled_val(),
    );
  
    // Update farm total staked
    farm.total_staked = wf_decimal::from_scaled_val(farm.total_staked).add(wf_decimal::from_q64(position::liquidity(&position))).to_scaled_val();

    let holder_position = HolderPositionCap {
        id: object::new(ctx),
        farm_id: object::id(farm),
        balance: wf_decimal::from_q64(position::liquidity(&position)).to_scaled_val(),
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

    emit_unstake_position_event(
        object::id(farm),
        wf_decimal::from_q64(position::liquidity(&position)).to_scaled_val()
    );

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
    let farm_id= object::id(farm);
    assert!(holder_position_cap.farm_id == farm_id, EInvalidHolderPositionCap());
    assert!(reward_pool::get_farm_id(reward_pool) == farm_id, EInvalidRewardPool());

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
            let rewards_to_u64 = rewards.to_native_token(reward_pool_info.decimals);

            let reward_coin = reward_pool::intern_withdraw_balance<T>(rewards_to_u64, reward_pool);
            // Emit claim reward event
            emit_claim_reward_event(
                farm_id, 
                reward_coin.value(),
                type_name::get<T>().into_string()
            );
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
                reward_pool::intern_add_yield_gain_pending(wf_decimal::from_native_token(coin.value(), reward_pool_info.decimals).to_scaled_val(), reward_pool);
            } else {
                // Calculate new global index for active stakers
                let new_global_index = wf_decimal::from_scaled_val(reward_pool_info.global_index).add(
                    wf_decimal::add(
                        wf_decimal::from_native_token(coin.value(), reward_pool_info.decimals), 
                        wf_decimal::from_scaled_val(reward_pool::get_yield_gain_pending(reward_pool))
                    ).div(wf_decimal::from_scaled_val(farm.total_staked))
                );
                reward_pool::intern_reset_yield_gain_pending(reward_pool);
                // Update the global index of the reward pool
                reward_pool_info.global_index = new_global_index.to_scaled_val();
            };
    
            break
        };
        
        i = i + 1;
    };
    // Emit reward distribution event
    emit_distribute_reward_event(object::id(farm), coin.value(), type_name::get<T>().into_string());
    
    // Add the coin balance to the reward pool
    reward_pool::intern_add_balance(coin, reward_pool);
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

    emit_new_reward_pool_created_event(
        object::id(farm),
        object::id(&reward_pool), 
        type_name::get<T>().into_string()
    );
   
    // Share the reward pool as a shared object
    transfer::public_share_object(reward_pool);
}

entry public fun init_holder_position_cap_display(admin_cap: &AdminCap, farm: &Farm, publisher: Publisher, ctx: &mut TxContext){
    assert!(admin_cap.get_farm_id() == object::id(farm), EUnauthorized());
    // Define Display keys + template strings
    let keys = vector[
        b"name".to_string(),
        b"link".to_string(),
        b"image_url".to_string(),
        b"thumbnail_url".to_string(),
        b"description".to_string(),
        b"project_url".to_string(),
        b"creator".to_string(),
    ];

    let values = vector[
        b"WeissFi Farming Liquidity Position".to_string(),
        // For `link` one can build a URL using an `id` property
        b"https://weiss.finance/flp/{id}".to_string(),
        // `image_url` use an IPFS template
        b"https://weissfi.s3.eu-west-3.amazonaws.com/farming-512x512.png".to_string(), // 512x512 ratio 1:1 svg under 1mb
        // `thumbnail_url` use an IPFS template
        b"https://weissfi.s3.eu-west-3.amazonaws.com/farming-256x256.png".to_string(), // 256 × 256 px or 128 × 128 px svg under 100kb
        // Description is static for all `HolderPositionCap` objects.
        b"This NFT represents your staked FlowX liquidity position in WeissFi farming protocol. Use this to claim accumulated rewards, unstake your position, or transfer your farming rights to another address.".to_string(),
        // Project URL is usually static
        b"https://weiss.finance".to_string(),
        // Creator field Weiss Finance
        b"Weiss Finance".to_string(),
    ];


    // Create + publish the Display<HolderPositionCap>
    let mut disp = display::new_with_fields<HolderPositionCap>(&publisher, keys, values, ctx);
    disp.update_version();
    // Return publisher & display back to you
    transfer::public_transfer(publisher, ctx.sender());
    transfer::public_transfer(disp, ctx.sender());
}
entry fun migrate(admin_cap: &AdminCap, farm: &mut Farm) {
    assert!(admin_cap.get_farm_id() == object::id(farm), EUnauthorized());
    assert!(farm.version < VERSION(), ENotUpgrade());
    farm.version = VERSION();
}

entry public fun initialize_allowed_pool(admin_cap: &AdminCap, farm: &mut Farm, pool_id: ID) {
    assert!(admin_cap.get_farm_id() == object::id(farm), EUnauthorized());
    assert!(farm.version == VERSION(), EPackageVersionError());
    // Add pool ID
    if (!farm.allowed_pool_ids.contains(&pool_id)) {
        vector::push_back(&mut farm.allowed_pool_ids, pool_id);
    };
}

// === Private Functions ===
fun init(ctx: &mut TxContext){
    let new_farm = Farm {
        id: object::new(ctx),
        version: VERSION(),
        total_staked: 0,
        allowed_pool_ids: vector::empty<ID>(),
        // tick_reward_tiers: vector::empty(),
        reward_pools: vector::empty(),
        flowx_v3_address: FLOWX_V3_ADDRESS(),
    };

    let admin_cap = intern_new_farm_admin(object::id(&new_farm), ctx);

    transfer::public_share_object(new_farm);
    transfer::public_transfer(admin_cap, ctx.sender());
}

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



#[test_only]
use sui::coin;
#[test_only]
use sui::sui::SUI;
#[test_only]
const ADMIN: address = @0xCAFE;
#[test_only]
const BOB: address = @0xB;
#[test_only]
const ALICE: address = @0xA;
#[test_only]
const CHARLIE: address = @0xC;
#[test_only]
use sui::test_scenario::{Self, Scenario};
#[test_only]
use std::unit_test::assert_eq;
#[test_only]
use std::debug::print;
#[test_only]
use flowx::i32::from_u32;
// Test token types representing DORI and USDC
#[test_only]
public struct TEST_DORI has drop {}
#[test_only]
public struct TEST_USDC has drop {}
#[test_only]
public struct TEST_FLX has drop {}
#[test_only]
public struct TEST_FAKE has drop {}

#[test_only]
public fun init_flowx_position(scenario: &mut Scenario): Position {
    // Create a position that mimics FlowX v3 structure
    // Note: This creates a position with our module's address, not FlowX's
    // For real testing, you need to use actual FlowX positions on testnet

    let flowx_position = position::open(
        object::id_from_address(@0xda208de7838d4922c3e0ced4e81ddbc94f3e4e6c2e3acf97194151dc1639424b),
        100,
        type_name::get<TEST_DORI>(),
        type_name::get<TEST_USDC>(),
        from_u32(4294897702),
        from_u32(4294898702),
        scenario.ctx()
    );
    flowx_position
}

#[test_only]
public fun init_package(scenario: &mut Scenario) {
    
    let new_farm = Farm {
        id: object::new(scenario.ctx()),
        version: VERSION(),
        total_staked: 0,
        allowed_pool_ids: vector::empty<ID>(),
        // tick_reward_tiers: vector::empty(),
        reward_pools: vector::empty(),
        flowx_v3_address: @flowx, // Use flowx stub address for testing
    };

    let admin_cap = intern_new_farm_admin(object::id(&new_farm), scenario.ctx());

    transfer::public_share_object(new_farm);
    transfer::public_transfer(admin_cap, scenario.ctx().sender());

}

#[test_only]
public fun init_create_reward_pool<T>(admin_cap: &mut AdminCap, farm: &mut Farm, decimals: u8, scenario: &mut Scenario){
    create_reward_pool<T>(admin_cap, farm, decimals, scenario.ctx());
}


#[test]
fun test_stake_position(){
    let mut scenario = test_scenario::begin(ADMIN);
    scenario.next_tx(ADMIN);
    {
        init_package(&mut scenario);
    };
    scenario.next_tx(ADMIN);
    let mut admin_cap = scenario.take_from_address<AdminCap>(ADMIN);
    let mut farm = scenario.take_shared<Farm>();
    {        
        init_create_reward_pool<TEST_FLX>(&mut admin_cap, &mut farm, 8, &mut scenario);
        // Add dummy pool ID for testing  
        let test_pool_id = object::id_from_address(@0xda208de7838d4922c3e0ced4e81ddbc94f3e4e6c2e3acf97194151dc1639424b);
        initialize_allowed_pool(&admin_cap, &mut farm, test_pool_id);
    
    };

    scenario.next_tx(ALICE);
    {
        let position = init_flowx_position(&mut scenario);
        stake_position(position, &mut farm,scenario.ctx());
        let reward_pool_info = vector::borrow(&farm.reward_pools, 0);
        
        assert_eq!(reward_pool_info.decimals, 8u8);
        assert_eq!(reward_pool_info.global_index, 0);
        assert_eq!(reward_pool_info.token_type, type_name::get<TEST_FLX>());
        
    };
    scenario.next_tx(ALICE);
    {
        let holder_position_cap = scenario.take_from_sender<HolderPositionCap>();
        assert_eq!(holder_position_cap.farm_id, object::id(&farm));

        let holder_reward_info = table::borrow(&holder_position_cap.reward_info, type_name::get<TEST_FLX>());
        let reward_pool_info = vector::borrow(&farm.reward_pools, 0);
        assert_eq!(holder_reward_info.user_index, reward_pool_info.global_index);
        scenario.return_to_sender(holder_position_cap);
    };
    
   
    transfer::public_share_object(farm);
    transfer::public_transfer(admin_cap, ADMIN);
    scenario.end();
}

#[test]
fun test_distribute_rewards(){
    let mut scenario = test_scenario::begin(ADMIN);
    scenario.next_tx(ADMIN);
    {
        init_package(&mut scenario);
    };
    scenario.next_tx(ADMIN);
    let mut admin_cap = scenario.take_from_address<AdminCap>(ADMIN);
    let mut farm = scenario.take_shared<Farm>();
    {        
        init_create_reward_pool<TEST_FLX>(&mut admin_cap, &mut farm, 8, &mut scenario);
        init_create_reward_pool<SUI>(&mut admin_cap, &mut farm, 9, &mut scenario);
        // Add dummy pool ID for testing  
        let test_pool_id = object::id_from_address(@0xda208de7838d4922c3e0ced4e81ddbc94f3e4e6c2e3acf97194151dc1639424b);
        initialize_allowed_pool(&admin_cap, &mut farm, test_pool_id);
    
    };

    scenario.next_tx(ADMIN);
    let mut reward_pool_flx = scenario.take_shared<RewardPool<TEST_FLX>>();
    let mut reward_pool_sui = scenario.take_shared<RewardPool<SUI>>();
    {
        // mint 10000 FLX tokens and distribute
        let coll_flx = coin::mint_for_testing<TEST_FLX>(1_000_000_000_000, scenario.ctx());
        distribute_rewards<TEST_FLX>(coll_flx, &mut reward_pool_flx, &mut farm);

        // mint 10000 SUI tokens and distribute
        let coll_sui = coin::mint_for_testing<SUI>(10_000_000_000_000, scenario.ctx());
        distribute_rewards<SUI>(coll_sui, &mut reward_pool_sui, &mut farm);

    };

    scenario.next_tx(ADMIN);
    {
        assert_eq!(reward_pool_flx.get_balance(),  1_000_000_000_000);
        assert_eq!(reward_pool_flx.get_farm_id(),  object::id(&farm));
        assert_eq!(reward_pool_flx.get_yield_gain_pending(),  wf_decimal::from_native_token(1_000_000_000_000, 8).to_scaled_val());

        assert_eq!(reward_pool_sui.get_balance(),  10_000_000_000_000);
        assert_eq!(reward_pool_sui.get_farm_id(),  object::id(&farm));
        assert_eq!(reward_pool_sui.get_yield_gain_pending(),  wf_decimal::from_native_token(10_000_000_000_000, 9).to_scaled_val());
    };
    
    transfer::public_share_object(farm);
    transfer::public_transfer(admin_cap, ADMIN);
    transfer::public_share_object(reward_pool_flx); 
    transfer::public_share_object(reward_pool_sui); 
    scenario.end();
}

#[test]
fun test_claim_rewards(){
    let mut scenario = test_scenario::begin(ADMIN);
    scenario.next_tx(ADMIN);
    {
        init_package(&mut scenario);
    };
    scenario.next_tx(ADMIN);
    let mut admin_cap = scenario.take_from_address<AdminCap>(ADMIN);
    let mut farm = scenario.take_shared<Farm>();
    {        
        init_create_reward_pool<TEST_FLX>(&mut admin_cap, &mut farm, 8, &mut scenario);
        init_create_reward_pool<SUI>(&mut admin_cap, &mut farm, 9, &mut scenario);
        // Add dummy pool ID for testing  
        let test_pool_id = object::id_from_address(@0xda208de7838d4922c3e0ced4e81ddbc94f3e4e6c2e3acf97194151dc1639424b);
        initialize_allowed_pool(&admin_cap, &mut farm, test_pool_id);
    
    };

    scenario.next_tx(ALICE);
    {
        let position = init_flowx_position(&mut scenario);
        stake_position(position, &mut farm,scenario.ctx());
        let reward_pool_info = vector::borrow(&farm.reward_pools, 0);
        
        assert_eq!(reward_pool_info.decimals, 8u8);
        assert_eq!(reward_pool_info.global_index, 0);
        assert_eq!(reward_pool_info.token_type, type_name::get<TEST_FLX>());
        
    };

    scenario.next_tx(ADMIN);
    let mut reward_pool_flx = scenario.take_shared<RewardPool<TEST_FLX>>();
    let mut reward_pool_sui = scenario.take_shared<RewardPool<SUI>>();
    {
        // mint 10000 FLX tokens and distribute
        let coll_flx = coin::mint_for_testing<TEST_FLX>(1_000_000_000_000, scenario.ctx());
        distribute_rewards<TEST_FLX>(coll_flx, &mut reward_pool_flx, &mut farm);

        // mint 10000 SUI tokens and distribute
        let coll_sui = coin::mint_for_testing<SUI>(10_000_000_000_000, scenario.ctx());
        distribute_rewards<SUI>(coll_sui, &mut reward_pool_sui, &mut farm);

    };

    scenario.next_tx(ALICE);
    {
        let mut holder_position_cap = scenario.take_from_sender<HolderPositionCap>();
        claim_rewards(&mut holder_position_cap, &mut reward_pool_flx, &mut farm, scenario.ctx());
        scenario.return_to_sender(holder_position_cap);
    };

    scenario.next_tx(ADMIN);
    {
        assert_eq!(reward_pool_flx.get_balance(),  1);
        assert_eq!(reward_pool_flx.get_farm_id(),  object::id(&farm));
        assert_eq!(reward_pool_flx.get_yield_gain_pending(),  wf_decimal::from_native_token(0, 8).to_scaled_val());

        assert_eq!(reward_pool_sui.get_balance(),  10_000_000_000_000);
        assert_eq!(reward_pool_sui.get_farm_id(),  object::id(&farm));
        assert_eq!(reward_pool_sui.get_yield_gain_pending(),  wf_decimal::from_native_token(0, 9).to_scaled_val());
    };

    scenario.next_tx(ALICE);
    {
        let mut holder_position_cap = scenario.take_from_sender<HolderPositionCap>();
        claim_rewards(&mut holder_position_cap, &mut reward_pool_sui, &mut farm, scenario.ctx());
        scenario.return_to_sender(holder_position_cap);
    };

    scenario.next_tx(ADMIN);
    {
        assert_eq!(reward_pool_flx.get_balance(),  1);
        assert_eq!(reward_pool_flx.get_farm_id(),  object::id(&farm));
        assert_eq!(reward_pool_flx.get_yield_gain_pending(),  wf_decimal::from_native_token(0, 8).to_scaled_val());

        assert_eq!(reward_pool_sui.get_balance(),  1);
        assert_eq!(reward_pool_sui.get_farm_id(),  object::id(&farm));
        assert_eq!(reward_pool_sui.get_yield_gain_pending(),  wf_decimal::from_native_token(0, 9).to_scaled_val());
    };

 
    transfer::public_share_object(farm);
    transfer::public_transfer(admin_cap, ADMIN);
    transfer::public_share_object(reward_pool_flx); 
    transfer::public_share_object(reward_pool_sui); 
    scenario.end();
}


#[test]
fun test_unstake_position(){
    let mut scenario = test_scenario::begin(ADMIN);
    scenario.next_tx(ADMIN);
    {
        init_package(&mut scenario);
    };
    scenario.next_tx(ADMIN);
    let mut admin_cap = scenario.take_from_address<AdminCap>(ADMIN);
    let mut farm = scenario.take_shared<Farm>();
    {        
        init_create_reward_pool<TEST_FLX>(&mut admin_cap, &mut farm, 8, &mut scenario);
        // Add dummy pool ID for testing  
        let test_pool_id = object::id_from_address(@0xda208de7838d4922c3e0ced4e81ddbc94f3e4e6c2e3acf97194151dc1639424b);
        initialize_allowed_pool(&admin_cap, &mut farm, test_pool_id);
    
    };

    scenario.next_tx(ALICE);
    {
        let position = init_flowx_position(&mut scenario);
        stake_position(position, &mut farm,scenario.ctx());        
    };
    scenario.next_tx(ALICE);
    {
        let holder_position_cap = scenario.take_from_sender<HolderPositionCap>();
        unstake_position(holder_position_cap, &mut farm,scenario.ctx());                
    };
    
   
    transfer::public_share_object(farm);
    transfer::public_transfer(admin_cap, ADMIN);
    scenario.end();
}




// Check error the position staked is not allowed wrong token type
#[test, expected_failure(abort_code=0, location=weissfarming::farm_flowx)]
fun fail_test_stake_position_tokens_type_not_match(){
    let mut scenario = test_scenario::begin(ADMIN);
    scenario.next_tx(ADMIN);
    {
        init_package(&mut scenario);
    };
    scenario.next_tx(ADMIN);
    let mut admin_cap = scenario.take_from_address<AdminCap>(ADMIN);
    let mut farm = scenario.take_shared<Farm>();
    {        
        init_create_reward_pool<TEST_FLX>(&mut admin_cap, &mut farm, 8, &mut scenario);
        // Add wrong pool ID for testing (should fail)
        let wrong_pool_id = object::id_from_address(@0x1111);
        initialize_allowed_pool(&admin_cap, &mut farm, wrong_pool_id);
    };

    scenario.next_tx(ADMIN);
    {
        let position = init_flowx_position(&mut scenario);
        stake_position(position, &mut farm,scenario.ctx());
    };
    
    scenario.return_to_sender(admin_cap);
    transfer::public_share_object(farm);
    scenario.end();
}

#[test]
fun test_multiple_stakers_reward_distribution(){
    let mut scenario = test_scenario::begin(ADMIN);
    scenario.next_tx(ADMIN);
    {
        init_package(&mut scenario);
    };
    scenario.next_tx(ADMIN);
    let mut admin_cap = scenario.take_from_address<AdminCap>(ADMIN);
    let mut farm = scenario.take_shared<Farm>();
    {        
        init_create_reward_pool<TEST_FLX>(&mut admin_cap, &mut farm, 8, &mut scenario);
        // Add dummy pool ID for testing  
        let test_pool_id = object::id_from_address(@0xda208de7838d4922c3e0ced4e81ddbc94f3e4e6c2e3acf97194151dc1639424b);
        initialize_allowed_pool(&admin_cap, &mut farm, test_pool_id);
    };

    // Alice stakes first
    scenario.next_tx(ALICE);
    {
        let position = init_flowx_position(&mut scenario);
        stake_position(position, &mut farm, scenario.ctx());
    };

    // Bob stakes second
    scenario.next_tx(BOB);
    {
        let position = init_flowx_position(&mut scenario);
        stake_position(position, &mut farm, scenario.ctx());
    };

    // First reward distribution - Alice and Bob should get equal rewards
    scenario.next_tx(ADMIN);
    let mut reward_pool_flx = scenario.take_shared<RewardPool<TEST_FLX>>();
    {
        let sum_deposit = wf_decimal::from_q64(6559457486451).add(wf_decimal::from_q64(6559457486451));
        assert_eq!(farm.total_staked, sum_deposit.to_scaled_val());
        let first_reward = coin::mint_for_testing<TEST_FLX>(2_000_000_000_000, scenario.ctx());
        distribute_rewards<TEST_FLX>(first_reward, &mut reward_pool_flx, &mut farm);
    };

    // Check Alice's rewards after first distribution
    scenario.next_tx(ALICE);
    let alice_balance_before_claim;
    {
        let mut alice_holder = scenario.take_from_sender<HolderPositionCap>();
        claim_rewards(&mut alice_holder, &mut reward_pool_flx, &mut farm, scenario.ctx());
        scenario.return_to_sender(alice_holder);
    };
    scenario.next_tx(ALICE);
    {
        let alice_coin = scenario.take_from_sender<Coin<TEST_FLX>>();
        alice_balance_before_claim = alice_coin.value();
        coin::burn_for_testing(alice_coin);
    };
    // Check Bob's rewards after first distribution
    scenario.next_tx(BOB);
    let bob_balance_before_claim;
    {
       

        let mut bob_holder = scenario.take_from_sender<HolderPositionCap>();
        claim_rewards(&mut bob_holder, &mut reward_pool_flx, &mut farm, scenario.ctx());
        scenario.return_to_sender(bob_holder);
    };
    scenario.next_tx(BOB);
    {
        let bob_coin = scenario.take_from_sender<Coin<TEST_FLX>>();
        bob_balance_before_claim = bob_coin.value();
        coin::burn_for_testing(bob_coin);
    };

    // Alice and Bob should have equal rewards from first distribution
    assert_eq!(alice_balance_before_claim, bob_balance_before_claim);
    print(&b"Alice and Bob first rewards: ".to_string());
    print(&alice_balance_before_claim);

    // Second reward distribution - Alice and Bob should get more rewards
    scenario.next_tx(ADMIN);
    {
        let second_reward = coin::mint_for_testing<TEST_FLX>(1_000_000_000_000, scenario.ctx());
        distribute_rewards<TEST_FLX>(second_reward, &mut reward_pool_flx, &mut farm);
    };

    // Charlie stakes after second distribution
    scenario.next_tx(CHARLIE);
    {
        let position = init_flowx_position(&mut scenario);
        stake_position(position, &mut farm, scenario.ctx());
    };

    // Third reward distribution - all three should be included
    scenario.next_tx(ADMIN);
    {
        let third_reward = coin::mint_for_testing<TEST_FLX>(3_000_000_000_000, scenario.ctx());
        distribute_rewards<TEST_FLX>(third_reward, &mut reward_pool_flx, &mut farm);
    };

    // Check final rewards
    scenario.next_tx(ALICE);
    let alice_final_balance;
    {
        let mut alice_holder = scenario.take_from_sender<HolderPositionCap>();
        claim_rewards(&mut alice_holder, &mut reward_pool_flx, &mut farm, scenario.ctx());
        scenario.return_to_sender(alice_holder);
        
    };
    scenario.next_tx(ALICE);
    {
        let alice_coin = scenario.take_from_sender<Coin<TEST_FLX>>();
        alice_final_balance = alice_coin.value();
        coin::burn_for_testing(alice_coin);
    };

    scenario.next_tx(BOB);
    let bob_final_balance;
    {
        let mut bob_holder = scenario.take_from_sender<HolderPositionCap>();
        claim_rewards(&mut bob_holder, &mut reward_pool_flx, &mut farm, scenario.ctx());
        scenario.return_to_sender(bob_holder);
      
    };
    scenario.next_tx(BOB);
    {
        let bob_coin = scenario.take_from_sender<Coin<TEST_FLX>>();
        bob_final_balance = bob_coin.value();
        coin::burn_for_testing(bob_coin);
    };

    scenario.next_tx(CHARLIE);
    let charlie_final_balance;
    {
        let mut charlie_holder = scenario.take_from_sender<HolderPositionCap>();
        claim_rewards(&mut charlie_holder, &mut reward_pool_flx, &mut farm, scenario.ctx());
        scenario.return_to_sender(charlie_holder);
    };
    scenario.next_tx(CHARLIE);
    {
        let charlie_coin = scenario.take_from_sender<Coin<TEST_FLX>>();
        charlie_final_balance = charlie_coin.value();
        coin::burn_for_testing(charlie_coin);
    };

    // Verify reward distribution correctness:
    // 1. Alice and Bob should have equal rewards (both staked from beginning)
    assert_eq!(alice_final_balance, bob_final_balance);
    
    // 2. Alice and Bob should have MORE rewards than Charlie (who joined later)
    assert!(alice_final_balance > charlie_final_balance);
    assert!(bob_final_balance > charlie_final_balance);
    
    // 3. Charlie should receive approximately 1/3 of the third distribution only
    // Allowing for some rounding due to decimal precision
    assert!(charlie_final_balance > 900_000_000_000); // At least 90% of expected ~1B
    assert!(charlie_final_balance < 1_100_000_000_000); // At most 110% of expected ~1B
    
    // 4. Alice and Bob should have accumulated rewards from all distributions
    assert!(alice_final_balance > 1_400_000_000_000); // Should be around 1.5B
    assert!(alice_final_balance < 1_600_000_000_000);

    transfer::public_share_object(farm);
    transfer::public_transfer(admin_cap, ADMIN);
    transfer::public_share_object(reward_pool_flx);
    scenario.end();
}