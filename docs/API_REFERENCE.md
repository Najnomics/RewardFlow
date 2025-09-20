# RewardFlow API Reference

## Contract Interfaces

### RewardFlowHook

Primary Uniswap V4 hook for tracking liquidity provider activity and distributing rewards.

#### Functions

##### `afterAddLiquidity`
```solidity
function afterAddLiquidity(
    address sender,
    PoolKey calldata key,
    IPoolManager.ModifyLiquidityParams calldata params,
    BalanceDelta delta,
    bytes calldata hookData
) external override returns (bytes4)
```
Records liquidity provision activity and calculates base rewards.

**Parameters:**
- `sender`: Address of the liquidity provider
- `key`: Pool identification key
- `params`: Liquidity modification parameters
- `delta`: Balance changes from liquidity provision
- `hookData`: Additional hook data

**Returns:** Hook selector for proper integration

##### `afterSwap`
```solidity
function afterSwap(
    address sender,
    PoolKey calldata key,
    IPoolManager.SwapParams calldata params,
    BalanceDelta delta,
    bytes calldata hookData
) external override returns (bytes4)
```
Records swap activity and distributes rewards to liquidity providers.

**Parameters:**
- `sender`: Address of the swapper
- `key`: Pool identification key
- `params`: Swap parameters
- `delta`: Balance changes from swap
- `hookData`: Additional hook data

**Returns:** Hook selector for proper integration

##### `claimRewards`
```solidity
function claimRewards() external
```
Allows users to claim their accumulated rewards.

**Requirements:**
- User must have rewards above minimum threshold
- Contract must not be paused

##### `getPendingRewards`
```solidity
function getPendingRewards(address user) external view returns (uint256)
```
Returns the pending rewards for a specific user.

**Parameters:**
- `user`: User address to check

**Returns:** Amount of pending rewards

##### `getUserActivity`
```solidity
function getUserActivity(address user) external view returns (
    uint256 totalLiquidity,
    uint256 swapVolume,
    uint256 positionDuration,
    uint256 lastActivity,
    uint256 loyaltyScore,
    uint256 engagementScore,
    uint8 tier
)
```
Returns comprehensive user activity data.

**Parameters:**
- `user`: User address to query

**Returns:** Tuple of activity metrics

### RewardDistributor

Cross-chain reward distribution engine using Across Protocol.

#### Functions

##### `executeRewardDistribution`
```solidity
function executeRewardDistribution(
    address user,
    uint256 amount,
    uint256 targetChain
) external onlyAuthorized
```
Executes cross-chain reward distribution.

**Parameters:**
- `user`: Recipient address
- `amount`: Amount to distribute
- `targetChain`: Target chain ID

**Requirements:**
- Caller must be authorized
- Contract must not be paused
- Amount must be above minimum threshold

##### `setUserPreferences`
```solidity
function setUserPreferences(
    uint256 preferredChain,
    uint256 claimThreshold,
    uint256 claimFrequency,
    bool autoClaimEnabled
) external
```
Sets user preferences for reward distribution.

**Parameters:**
- `preferredChain`: Preferred chain for receiving rewards
- `claimThreshold`: Minimum amount to trigger distribution
- `claimFrequency`: Frequency of automatic claims
- `autoClaimEnabled`: Whether to enable automatic claiming

##### `getUserPreferences`
```solidity
function getUserPreferences(address user) external view returns (
    uint256 preferredChain,
    uint256 claimThreshold,
    uint256 claimFrequency,
    bool autoClaimEnabled,
    uint256 lastUpdate
)
```
Returns user preferences for reward distribution.

**Parameters:**
- `user`: User address to query

**Returns:** Tuple of user preferences

##### `calculateDistributionFees`
```solidity
function calculateDistributionFees(
    uint256 amount,
    uint256 targetChain
) external view returns (uint256)
```
Calculates distribution fees for cross-chain transfers.

**Parameters:**
- `amount`: Amount to transfer
- `targetChain`: Target chain ID

**Returns:** Fee amount in wei

### CrossChainPositionTracker

Multi-chain position tracking and management.

#### Functions

##### `updatePosition`
```solidity
function updatePosition(
    address user,
    PoolKey calldata key,
    BalanceDelta delta
) external onlyAuthorized
```
Updates user position across chains.

**Parameters:**
- `user`: User address
- `key`: Pool identification key
- `delta`: Position change

**Requirements:**
- Caller must be authorized

##### `getUserPosition`
```solidity
function getUserPosition(
    address user,
    PoolId poolId
) external view returns (IPositionTracker.Position memory)
```
Returns user position for a specific pool.

**Parameters:**
- `user`: User address
- `poolId`: Pool identifier

**Returns:** Position struct with details

##### `getPoolInfo`
```solidity
function getPoolInfo(PoolId poolId) external view returns (
    IPositionTracker.PoolInfo memory
)
```
Returns pool information and statistics.

**Parameters:**
- `poolId`: Pool identifier

**Returns:** Pool info struct

## Events

### RewardFlowHook Events

##### `RewardEarned`
```solidity
event RewardEarned(
    address indexed user,
    uint256 amount,
    RewardType rewardType
)
```
Emitted when a user earns rewards.

##### `ActivityUpdated`
```solidity
event ActivityUpdated(
    address indexed user,
    uint256 totalLiquidity,
    uint256 swapVolume,
    uint256 tier
)
```
Emitted when user activity is updated.

### RewardDistributor Events

##### `RewardDistributionInitiated`
```solidity
event RewardDistributionInitiated(
    bytes32 indexed requestId,
    address indexed user,
    uint256 amount,
    uint256 targetChain
)
```
Emitted when reward distribution is initiated.

##### `PreferencesUpdated`
```solidity
event PreferencesUpdated(
    address indexed user,
    uint256 preferredChain,
    uint256 claimThreshold
)
```
Emitted when user preferences are updated.

## Error Codes

### Common Errors
- `InsufficientRewardThreshold`: Reward amount below minimum threshold
- `Unauthorized`: Caller not authorized for operation
- `Paused`: Contract is paused
- `InvalidChain`: Unsupported target chain
- `InvalidAmount`: Invalid amount specified

### Custom Errors
```solidity
error InsufficientRewardThreshold();
error Unauthorized();
error Paused();
error InvalidChain(uint256 chainId);
error InvalidAmount(uint256 amount);
```

## Usage Examples

### Basic Reward Claiming
```solidity
// Check pending rewards
uint256 pending = hook.getPendingRewards(user);

// Claim rewards if above threshold
if (pending >= MIN_REWARD_THRESHOLD) {
    hook.claimRewards();
}
```

### Setting User Preferences
```solidity
// Set preferences for automatic claiming
distributor.setUserPreferences(
    1,      // Ethereum mainnet
    1000e18, // 1000 token threshold
    86400,   // Daily claims
    true     // Auto-claim enabled
);
```

### Cross-Chain Distribution
```solidity
// Execute reward distribution to Arbitrum
distributor.executeRewardDistribution(
    user,
    5000e18, // 5000 tokens
    42161    // Arbitrum chain ID
);
```

## Integration Guide

### Hook Integration
1. Deploy RewardFlowHook with proper pool manager address
2. Register hook with Uniswap V4 hook manager
3. Configure reward distributor address
4. Set up monitoring and alerting

### Frontend Integration
1. Connect to deployed contracts
2. Implement reward tracking UI
3. Add cross-chain distribution features
4. Integrate with user preference management

### Backend Integration
1. Set up event monitoring
2. Implement reward calculation logic
3. Configure cross-chain communication
4. Set up automated distribution systems
