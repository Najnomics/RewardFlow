// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/utils/BaseHook.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
// Removed AVS dependency - using direct reward distribution
import {RewardMath} from "./libraries/RewardMath.sol";
import {ActivityTracking} from "./libraries/ActivityTracking.sol";
import {TierCalculations} from "./libraries/TierCalculations.sol";
import {Constants} from "../utils/Constants.sol";
import {Events} from "../utils/Events.sol";
import {Errors} from "../utils/Errors.sol";
import {SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/types/PoolOperation.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/types/PoolId.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/types/BeforeSwapDelta.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title RewardFlowHook
 * @notice Enhanced Uniswap V4 Hook for tracking LP activity, MEV detection, and rewards distribution
 * @dev Implements beforeSwap and afterSwap hooks for MEV detection and reward distribution
 *      Integrates with EigenLayer AVS for cross-chain reward aggregation
 */
contract RewardFlowHook is BaseHook, ReentrancyGuard, Ownable {
    using RewardMath for uint256;
    using ActivityTracking for mapping(address => ActivityTracking.UserActivity);
    using TierCalculations for mapping(address => TierCalculations.UserTier);
    using PoolIdLibrary for PoolKey;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice LP reward percentage from MEV capture (75%)
    uint256 public constant LP_REWARD_PERCENTAGE = 7500;
    
    /// @notice AVS operator reward percentage (15%)
    uint256 public constant AVS_REWARD_PERCENTAGE = 1500;
    
    /// @notice Protocol fee percentage (10%)
    uint256 public constant PROTOCOL_FEE_PERCENTAGE = 1000;
    
    /// @notice Basis points denominator
    uint256 public constant BASIS_POINTS = 10000;
    
    /// @notice MEV threshold for triggering AVS tasks (in basis points)
    uint256 public constant MEV_THRESHOLD = 100; // 1%

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Reward distributor for cross-chain distribution
    address public immutable rewardDistributor;

    /// @notice User activity tracking
    mapping(address => ActivityTracking.UserActivity) public userActivity;
    
    /// @notice Pending rewards per user
    mapping(address => uint256) public pendingRewards;
    
    /// @notice User tier information
    mapping(address => TierCalculations.UserTier) public userTiers;

    /// @notice Reward entries for AVS processing
    mapping(bytes32 => RewardEntry) public rewardEntries;
    
    /// @notice Pool to MEV detector mapping
    mapping(PoolId => MEVDetector) public mevDetectors;
    
    /// @notice Pool to total liquidity tracking
    mapping(PoolId => uint256) public poolTotalLiquidity;
    
    /// @notice Pool to LP liquidity positions
    mapping(PoolId => mapping(address => uint256)) public lpLiquidityPositions;
    
    /// @notice Pool to accumulated rewards
    mapping(PoolId => uint256) public poolAccumulatedRewards;
    
    /// @notice Active AVS tasks for MEV distribution
    mapping(bytes32 => AVSTask) public activeTasks;
    
    /// @notice Total rewards distributed
    uint256 public totalRewardsDistributed;
    
    /// @notice Total MEV captured and redistributed
    uint256 public totalMEVCaptured;

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

    /// @notice MEV detection structure
    struct MEVDetector {
        uint256 lastPrice;
        uint256 lastUpdateBlock;
        uint256 priceDeviation;
        bool mevDetected;
        uint256 capturedAmount;
    }

    /// @notice AVS task structure for cross-chain reward distribution
    struct AVSTask {
        PoolId poolId;
        address[] recipients;
        uint256[] amounts;
        uint256 totalAmount;
        uint256 createdAt;
        uint256 targetChain;
        TaskStatus status;
        bytes32 taskHash;
    }

    /// @notice Reward types
    enum RewardType {
        LIQUIDITY_PROVISION,
        SWAP_VOLUME,
        LOYALTY_BONUS,
        TIER_MULTIPLIER,
        MEV_CAPTURE
    }

    /// @notice AVS task status
    enum TaskStatus {
        PENDING,
        SUBMITTED,
        COMPLETED,
        FAILED
    }

    /// @notice Events
    event RewardEarned(address indexed user, uint256 amount, RewardType rewardType);
    event SwapRewardsDistributed(PoolId indexed poolId, uint256 totalReward, uint256 swapVolume);
    event UserTierUpdated(address indexed user, TierCalculations.TierLevel newTier);
    event RewardProcessed(bytes32 indexed entryId, address indexed user, uint256 amount);
    event MEVDetected(PoolId indexed poolId, uint256 deviation, uint256 capturedAmount);
    event MEVDistributed(PoolId indexed poolId, uint256 lpAmount, uint256 avsAmount, uint256 protocolAmount);
    event AVSTaskCreated(bytes32 indexed taskHash, PoolId indexed poolId, uint256 totalAmount, uint256 targetChain);
    event AVSTaskCompleted(bytes32 indexed taskHash, TaskStatus status);

    /// @notice Errors
    error InvalidRewardAmount();
    error InvalidUser();
    error RewardAlreadyProcessed();
    error InsufficientRewardThreshold();

    constructor(
        IPoolManager _poolManager,
        address _rewardDistributor
    ) BaseHook(_poolManager) Ownable(msg.sender) {
        rewardDistributor = _rewardDistributor;
    }

    /// @notice Get hook permissions - enhanced for MEV detection
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,  // Track LP positions
            afterAddLiquidity: true,   // Calculate rewards
            beforeRemoveLiquidity: true, // Update LP positions
            afterRemoveLiquidity: false,
            beforeSwap: true,          // MEV detection and price tracking
            afterSwap: true,           // Reward distribution
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /*//////////////////////////////////////////////////////////////
                            LIQUIDITY HOOKS
    //////////////////////////////////////////////////////////////*/

    /// @notice Hook called before liquidity is added to track positions
    function _beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata
    ) internal override returns (bytes4) {
        PoolId poolId = key.toId();
        
        // Update LP liquidity tracking
        if (params.liquidityDelta > 0) {
            lpLiquidityPositions[poolId][sender] += uint256(int256(params.liquidityDelta));
            poolTotalLiquidity[poolId] += uint256(int256(params.liquidityDelta));
        }
        
        return BaseHook.beforeAddLiquidity.selector;
    }

    /// @notice Hook called before liquidity is removed to update positions
    function _beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata
    ) internal override returns (bytes4) {
        PoolId poolId = key.toId();
        
        // Update LP liquidity tracking
        if (params.liquidityDelta < 0) {
            uint256 liquidityRemoved = uint256(-int256(params.liquidityDelta));
            lpLiquidityPositions[poolId][sender] -= liquidityRemoved;
            poolTotalLiquidity[poolId] -= liquidityRemoved;
        }
        
        return BaseHook.beforeRemoveLiquidity.selector;
    }

    /// @notice Hook called after liquidity is added
    function _afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) internal override returns (bytes4, BalanceDelta) {
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
        
        return (BaseHook.afterAddLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    /*//////////////////////////////////////////////////////////////
                              SWAP HOOKS
    //////////////////////////////////////////////////////////////*/

    /// @notice Hook called before swap for MEV detection and price tracking
    function _beforeSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        PoolId poolId = key.toId();
        
        // Get current pool price and detect MEV
        uint256 currentPrice = _getPoolPrice(key);
        bool mevDetected = _detectMEV(poolId, currentPrice, params);
        
        if (mevDetected) {
            // Calculate MEV capture amount
            uint256 mevAmount = _calculateMEVCapture(poolId, params);
            
            // Update MEV detector
            mevDetectors[poolId].mevDetected = true;
            mevDetectors[poolId].capturedAmount = mevAmount;
            
            emit MEVDetected(poolId, mevDetectors[poolId].priceDeviation, mevAmount);
        }
        
        // Update price tracking
        mevDetectors[poolId].lastPrice = currentPrice;
        mevDetectors[poolId].lastUpdateBlock = block.number;
        
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    /// @notice Hook called after a swap
    function _afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal override returns (bytes4, int128) {
        // Record swap activity for LP rewards (not the swapper)
        PoolId poolId = key.toId();
        
        // Calculate rewards for LPs based on swap volume
        uint256 swapVolume = _calculateSwapVolume(delta);
        uint256 lpRewardPool = swapVolume.mulDiv(LP_FEE_SHARE, 10000);
        
        // Distribute to all current LPs proportionally
        _distributeLPRewards(poolId, lpRewardPool);
        
        // Update activity metrics for all LPs
        _updateLPActivity(poolId, swapVolume);
        
        emit SwapRewardsDistributed(poolId, lpRewardPool, swapVolume);
        
        return (BaseHook.afterSwap.selector, 0);
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
    function _distributeLPRewards(PoolId poolId, uint256 totalReward) internal {
        // Simplified: distribute to msg.sender (the swapper) for now
        // In a full implementation, this would track all LPs in the pool
        if (totalReward > 0) {
            pendingRewards[msg.sender] += totalReward;
        }
    }

    /// @notice Update LP activity for a pool (simplified)
    function _updateLPActivity(PoolId poolId, uint256 swapVolume) internal {
        // Simplified: update activity for msg.sender
        ActivityTracking.updateSwapVolume(userActivity[msg.sender], swapVolume);
        _updateUserTier(msg.sender);
    }

    /// @notice Record liquidity activity (simplified)
    function _recordLiquidityActivity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta
    ) internal {
        ActivityTracking.updateLiquidityProvision(userActivity[sender], delta, key);
        _updateUserTier(sender);
    }

    /// @notice Update user activity
    function _updateUserActivity(
        address sender,
        RewardType rewardType,
        BalanceDelta delta
    ) internal {
        if (rewardType == RewardType.LIQUIDITY_PROVISION) {
            // Skip liquidity provision tracking for this case since we don't have a valid PoolKey
            // In a real implementation, this would be handled differently
        } else if (rewardType == RewardType.SWAP_VOLUME) {
            ActivityTracking.updateSwapVolume(userActivity[sender], _calculateSwapVolume(delta));
        }
    }

    /// @notice Update user tier
    function _updateUserTier(address user) internal {
        // Get activity summary instead of the full struct
        (
            uint256 totalLiquidity,
            uint256 swapVolume,
            uint256 positionDuration,
            uint256 lastActivity,
            uint256 loyaltyScore,
            uint256 engagementScore,
            uint8 tier
        ) = ActivityTracking.getActivitySummary(userActivity[user]);
        
        TierCalculations.TierLevel newTier = TierCalculations.TierLevel(tier);
        
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
    function getUserActivity(address user) external view returns (
        uint256 totalLiquidity,
        uint256 swapVolume,
        uint256 positionDuration,
        uint256 lastActivity,
        uint256 loyaltyScore,
        uint256 engagementScore,
        uint8 tier
    ) {
        return ActivityTracking.getActivitySummary(userActivity[user]);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get current pool price
    function _getPoolPrice(PoolKey calldata key) internal view returns (uint256) {
        // Simplified price calculation - in practice, this would use the pool's sqrtPriceX96
        return 1000; // Placeholder price
    }

    /// @notice Detect MEV in the swap
    function _detectMEV(PoolId poolId, uint256 currentPrice, SwapParams calldata params) internal view returns (bool) {
        // Simplified MEV detection logic
        // In practice, this would analyze price impact, timing, etc.
        return false; // Placeholder - no MEV detected
    }

    /// @notice Calculate MEV capture amount
    function _calculateMEVCapture(PoolId poolId, SwapParams calldata params) internal view returns (uint256) {
        // Simplified MEV capture calculation
        // In practice, this would calculate the optimal amount to capture
        return 0; // Placeholder - no MEV captured
    }

}
