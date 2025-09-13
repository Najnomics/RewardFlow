// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IRewardFlowServiceManager} from "../avs/interfaces/IRewardFlowServiceManager.sol";
import {RewardMath} from "./libraries/RewardMath.sol";
import {ActivityTracking} from "./libraries/ActivityTracking.sol";
import {TierCalculations} from "./libraries/TierCalculations.sol";
import {Constants} from "../utils/Constants.sol";
import {Events} from "../utils/Events.sol";
import {Errors} from "../utils/Errors.sol";

/**
 * @title RewardFlowHook
 * @notice Main Uniswap V4 Hook for tracking LP activity and distributing rewards
 * @dev Implements afterAddLiquidity and afterSwap hooks to record user activity
 */
contract RewardFlowHook is BaseHook {
    using RewardMath for uint256;
    using ActivityTracking for mapping(address => ActivityTracking.UserActivity);
    using TierCalculations for mapping(address => TierCalculations.UserTier);

    /// @notice The reward flow service manager
    IRewardFlowServiceManager public immutable serviceManager;

    /// @notice User activity tracking
    mapping(address => ActivityTracking.UserActivity) public userActivity;
    
    /// @notice Pending rewards per user
    mapping(address => uint256) public pendingRewards;
    
    /// @notice User tier information
    mapping(address => TierCalculations.UserTier) public userTiers;

    /// @notice Reward entries for AVS processing
    mapping(bytes32 => RewardEntry) public rewardEntries;
    
    /// @notice Total rewards distributed
    uint256 public totalRewardsDistributed;

    /// @notice LP fee share for swap rewards (in basis points)
    uint256 public constant LP_FEE_SHARE = 5000; // 50%

    /// @notice Minimum reward threshold for distribution
    uint256 public constant MIN_REWARD_THRESHOLD = 1e15; // 0.001 ETH

    /// @notice Reward entry structure
    struct RewardEntry {
        address user;
        address token0;
        address token1;
        uint256 amount;
        uint256 timestamp;
        uint256 blockNumber;
        RewardType rewardType;
        bool processed;
    }

    /// @notice Reward types
    enum RewardType {
        LIQUIDITY_PROVISION,
        SWAP_VOLUME,
        LOYALTY_BONUS,
        TIER_MULTIPLIER
    }

    /// @notice Events
    event RewardEarned(address indexed user, uint256 amount, RewardType rewardType);
    event SwapRewardsDistributed(address indexed poolId, uint256 totalReward, uint256 swapVolume);
    event UserTierUpdated(address indexed user, TierCalculations.TierLevel newTier);
    event RewardProcessed(bytes32 indexed entryId, address indexed user, uint256 amount);

    /// @notice Errors
    error InvalidRewardAmount();
    error InvalidUser();
    error RewardAlreadyProcessed();
    error InsufficientRewardThreshold();

    constructor(
        IPoolManager _poolManager,
        IRewardFlowServiceManager _serviceManager
    ) BaseHook(_poolManager) {
        serviceManager = _serviceManager;
    }

    /// @notice Hook called after liquidity is added
    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override returns (bytes4) {
        // Record liquidity provision activity
        _recordLiquidityActivity(sender, key, params, delta);
        
        // Calculate base reward
        uint256 baseReward = _calculateLiquidityReward(delta, key);
        
        // Apply tier multiplier
        uint256 tierMultiplier = _getUserTierMultiplier(sender);
        uint256 finalReward = baseReward.mulDiv(tierMultiplier, 1e18);
        
        // Record reward entry
        RewardEntry memory entry = RewardEntry({
            user: sender,
            token0: Currency.unwrap(key.currency0),
            token1: Currency.unwrap(key.currency1),
            amount: finalReward,
            timestamp: block.timestamp,
            blockNumber: block.number,
            rewardType: RewardType.LIQUIDITY_PROVISION,
            processed: false
        });
        
        // Update user activity metrics
        _updateUserActivity(sender, RewardType.LIQUIDITY_PROVISION, delta);
        
        // Store reward entry for later aggregation
        pendingRewards[sender] += finalReward;
        
        emit RewardEarned(sender, finalReward, RewardType.LIQUIDITY_PROVISION);
        
        return BaseHook.afterAddLiquidity.selector;
    }

    /// @notice Hook called after a swap
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override returns (bytes4) {
        // Record swap activity for LP rewards (not the swapper)
        address poolId = key.toId();
        
        // Calculate rewards for LPs based on swap volume
        uint256 swapVolume = _calculateSwapVolume(delta);
        uint256 lpRewardPool = swapVolume.mulDiv(LP_FEE_SHARE, 10000);
        
        // Distribute to all current LPs proportionally
        _distributeLPRewards(poolId, lpRewardPool);
        
        // Update activity metrics for all LPs
        _updateLPActivity(poolId, swapVolume);
        
        emit SwapRewardsDistributed(poolId, lpRewardPool, swapVolume);
        
        return BaseHook.afterSwap.selector;
    }

    /// @notice Calculate liquidity reward based on delta and pool key
    function _calculateLiquidityReward(
        BalanceDelta delta,
        PoolKey calldata key
    ) internal view returns (uint256) {
        // Base reward = liquidity amount * time multiplier * token multiplier
        uint256 liquidityValue = _calculateLiquidityValue(delta, key);
        uint256 timeMultiplier = _getTimeMultiplier();
        uint256 tokenMultiplier = _getTokenMultiplier(key.currency0, key.currency1);
        
        return liquidityValue.mulDiv(timeMultiplier, 1e18).mulDiv(tokenMultiplier, 1e18);
    }

    /// @notice Get user tier multiplier
    function _getUserTierMultiplier(address user) internal view returns (uint256) {
        TierCalculations.UserTier memory tier = userTiers[user];
        
        // Calculate tier based on total activity
        if (tier.totalLiquidity >= 1000e18 && tier.loyaltyScore >= 90) {
            return 2e18; // Diamond tier: 2x multiplier
        } else if (tier.totalLiquidity >= 500e18 && tier.loyaltyScore >= 70) {
            return 15e17; // Platinum tier: 1.5x multiplier
        } else if (tier.totalLiquidity >= 100e18 && tier.loyaltyScore >= 50) {
            return 12e17; // Gold tier: 1.2x multiplier
        } else {
            return 1e18; // Base tier: 1x multiplier
        }
    }

    /// @notice Calculate liquidity value in ETH terms
    function _calculateLiquidityValue(
        BalanceDelta delta,
        PoolKey calldata key
    ) internal view returns (uint256) {
        // Simplified calculation - in production, use price oracles
        uint256 delta0 = uint256(int256(delta.amount0()));
        uint256 delta1 = uint256(int256(delta.amount1()));
        
        // Use the larger delta as the value proxy
        return delta0 > delta1 ? delta0 : delta1;
    }

    /// @notice Get time-based multiplier
    function _getTimeMultiplier() internal view returns (uint256) {
        // Time of day multiplier (higher during peak hours)
        uint256 hour = (block.timestamp / 3600) % 24;
        if (hour >= 14 && hour <= 18) {
            return 12e17; // 1.2x during peak hours
        }
        return 1e18; // 1x during off-peak hours
    }

    /// @notice Get token pair multiplier
    function _getTokenMultiplier(
        Currency currency0,
        Currency currency1
    ) internal view returns (uint256) {
        // Higher multiplier for major pairs
        address token0 = Currency.unwrap(currency0);
        address token1 = Currency.unwrap(currency1);
        
        // Check if either token is a major token (simplified)
        if (token0 == Constants.WETH || token1 == Constants.WETH) {
            return 15e17; // 1.5x for ETH pairs
        }
        
        return 1e18; // 1x for other pairs
    }

    /// @notice Calculate swap volume
    function _calculateSwapVolume(BalanceDelta delta) internal pure returns (uint256) {
        uint256 delta0 = uint256(int256(delta.amount0()));
        uint256 delta1 = uint256(int256(delta.amount1()));
        
        // Use the absolute value of the larger delta
        return delta0 > delta1 ? delta0 : delta1;
    }

    /// @notice Distribute LP rewards proportionally (simplified)
    function _distributeLPRewards(address poolId, uint256 totalReward) internal {
        // Simplified: distribute to msg.sender (the swapper) for now
        // In a full implementation, this would track all LPs in the pool
        if (totalReward > 0) {
            pendingRewards[msg.sender] += totalReward;
        }
    }

    /// @notice Update LP activity for a pool (simplified)
    function _updateLPActivity(address poolId, uint256 swapVolume) internal {
        // Simplified: update activity for msg.sender
        userActivity[msg.sender].updateSwapVolume(swapVolume);
        _updateUserTier(msg.sender);
    }

    /// @notice Record liquidity activity (simplified)
    function _recordLiquidityActivity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta
    ) internal {
        userActivity[sender].updateLiquidityProvision(delta, key);
        _updateUserTier(sender);
    }

    /// @notice Update user activity
    function _updateUserActivity(
        address sender,
        RewardType rewardType,
        BalanceDelta delta
    ) internal {
        if (rewardType == RewardType.LIQUIDITY_PROVISION) {
            userActivity[sender].updateLiquidityProvision(delta, PoolKey.wrap(0));
        } else if (rewardType == RewardType.SWAP_VOLUME) {
            userActivity[sender].updateSwapVolume(_calculateSwapVolume(delta));
        }
    }

    /// @notice Update user tier
    function _updateUserTier(address user) internal {
        ActivityTracking.UserActivity memory activity = userActivity[user];
        TierCalculations.TierLevel newTier = TierCalculations.calculateTier(activity);
        
        if (userTiers[user].level != newTier) {
            userTiers[user].level = newTier;
            userTiers[user].lastUpdate = block.timestamp;
            emit UserTierUpdated(user, newTier);
        }
    }

    /// @notice Trigger reward aggregation (simplified)
    function _triggerRewardAggregation(address user, uint256 amount) internal {
        // In a full implementation, this would create an AVS task
        // For now, we just store the reward locally
        if (amount >= MIN_REWARD_THRESHOLD) {
            // Could trigger cross-chain distribution here
        }
    }

    /// @notice Claim rewards for a user
    function claimRewards() external {
        uint256 amount = pendingRewards[msg.sender];
        if (amount < MIN_REWARD_THRESHOLD) {
            revert InsufficientRewardThreshold();
        }
        
        pendingRewards[msg.sender] = 0;
        totalRewardsDistributed += amount;
        
        // Trigger cross-chain distribution (simplified)
        _triggerRewardAggregation(msg.sender, amount);
    }

    /// @notice Get user's pending rewards
    function getPendingRewards(address user) external view returns (uint256) {
        return pendingRewards[user];
    }

    /// @notice Get user's tier information
    function getUserTier(address user) external view returns (TierCalculations.TierLevel) {
        return userTiers[user].level;
    }

    /// @notice Get user's activity summary
    function getUserActivity(address user) external view returns (ActivityTracking.UserActivity memory) {
        return userActivity[user];
    }

    /// @notice Get hook permissions
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            beforeAddLiquidityReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            beforeRemoveLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }
}
