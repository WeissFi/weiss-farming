# WeissFi Farming Protocol 🌾

A secure liquidity farming protocol on Sui that allows users to stake FlowX CLMM liquidity positions and earn token rewards.

## 🚀 Overview

WeissFi Farming enables users to:
- **Stake FlowX liquidity positions** and earn additional rewards
- **Claim multiple token rewards** from different reward pools
- **Maintain liquidity position ownership** while earning farming rewards
- **Transfer farming rights** via NFT-based position caps

## 📋 Features

### Core Functionality
- ✅ **Multi-token reward pools** - Support for multiple reward tokens per farm
- ✅ **FlowX position integration** - Direct staking of FlowX CLMM positions
- ✅ **Proportional rewards** - Rewards distributed based on liquidity share
- ✅ **Secure access control** - Admin-only reward pool management
- ✅ **Version management** - Upgradeable contract with migration support

### Security Features
- ✅ **Q64 to WAD conversion** - Proper decimal handling for FlowX liquidity
- ✅ **Access control validation** - Farm ID and admin cap verification
- ✅ **Unclaimed reward protection** - Users must claim before unstaking
- ✅ **Version consistency checks** - All functions validate contract version

## 🏗️ Architecture

### Core Components

```
Farm
├── RewardPoolInfo[]     # Multiple reward token pools
├── total_staked         # Total liquidity staked (WAD format)
├── allowed_token_list   # Whitelisted token types
└── version             # Contract version

HolderPositionCap (NFT)
├── farm_id             # Associated farm ID
├── balance             # Staked liquidity amount (WAD format)
├── reward_info         # Per-token reward tracking
└── position            # Original FlowX position
```

### Reward Calculation
Uses a global index system for efficient reward distribution:
```
user_rewards = (global_index - user_index) × user_liquidity
```

## 🔧 Usage

### For Users

#### 1. Stake a FlowX Position
```move
stake_position(position: Position, farm: &mut Farm)
```
- Receives a `HolderPositionCap` NFT
- Position must be from whitelisted token pairs
- Liquidity is converted from Q64 to WAD format

#### 2. Claim Rewards
```move
claim_rewards<T>(holder_position_cap: &mut HolderPositionCap, reward_pool: &mut RewardPool<T>, farm: &mut Farm)
```
- Claims rewards for specific token type `T`
- Updates user's reward index
- Transfers reward tokens to user

#### 3. Unstake Position
```move
unstake_position(holder_position_cap: HolderPositionCap, farm: &mut Farm)
```
- Must claim all pending rewards first
- Returns original FlowX position
- Burns the `HolderPositionCap` NFT

### For Admins

#### 1. Create Reward Pool
```move
create_reward_pool<T>(admin_cap: &AdminCap, farm: &mut Farm, decimals: u8)
```
- Creates a new reward pool for token type `T`
- Requires admin capabilities
- One pool per token type

#### 2. Distribute Rewards
```move
distribute_rewards<T>(coin: Coin<T>, reward_pool: &mut RewardPool<T>, farm: &mut Farm)
```
- Adds tokens to the reward pool
- Updates global reward index
- Handles zero-staking scenarios

## 🛠️ Development

### Building
```bash
sui move build
```

### Testing
```bash
sui move test
```

### Deployment
```bash
sui client publish --gas-budget 100000000
```

## 📚 Technical Details

### Decimal Precision
- **Internal calculations**: 18 decimal precision (WAD format)
- **FlowX positions**: Converted from Q64 to WAD format
- **Reward tokens**: Support variable decimals (configured per pool)

### Security Considerations

#### ✅ Resolved Issues
- **Decimal conversion**: Fixed Q64 to WAD conversion for FlowX liquidity
- **Access control**: Added comprehensive validation checks
- **Reward logic**: Proper global index-based distribution
- **State consistency**: Version checks and farm ID validation

#### ⚠️ Recommendations
- Add input validation for edge cases (zero amounts, invalid decimals)
- Consider implementing minimum stake requirements
- Add emergency pause functionality for critical issues

### Gas Optimization
- Efficient reward calculation using global indices
- Batch operations where possible
- Minimal storage overhead

## 🔗 Integration

### FlowX CLMM Integration
The protocol integrates with FlowX CLMM positions:
- Supports standard FlowX `Position` structs
- Handles Q64-scaled liquidity values
- Maintains compatibility with FlowX ecosystem

### Token Support
- Any Sui coin type can be used as rewards
- Configurable decimal precision per token
- Support for multiple reward tokens per farm

## 📄 License

This project is licensed under the MIT License.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Run security audits on changes
4. Submit a pull request

## ⚠️ Disclaimer

This is experimental software. Use at your own risk. Always verify contract addresses and test with small amounts first.

---

**Built with ❤️ by WeissFi on Sui**