// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {PoolId} from "@uniswap/v4-core/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {RewardMath} from "./RewardMath.sol";

/**
 * @title ActivityTracking
 * @notice Library for tracking user activity and engagement
 */
library ActivityTracking {
    using RewardMath for uint256;

    /// @notice User activity structure
    struct UserActivity {
        uint256 totalLiquidity;
        uint256 swapVolume;
        uint256 positionDuration;
        uint256 lastActivity;
        uint256 loyaltyScore;
        uint256 transactionCount;
        uint256 averagePositionSize;
        uint256 consistencyScore;
        mapping(PoolId => uint256) poolLiquidity;
        mapping(PoolId => uint256) poolSwapVolume;
    }

    /// @notice Activity update types
    enum ActivityType {
        LIQUIDITY_PROVISION,
        LIQUIDITY_REMOVAL,
        SWAP,
        CLAIM_REWARDS
    }

    /// @notice Constants
    uint256 public constant LOYALTY_DECAY_RATE = 1e15; // 0.1% per day
    uint256 public constant CONSISTENCY_WINDOW = 7 days;
    uint256 public constant MAX_LOYALTY_SCORE = 100;
    uint256 public constant MIN_LOYALTY_SCORE = 0;

    /// @notice Update liquidity provision activity
    function updateLiquidityProvision(
        UserActivity storage activity,
        BalanceDelta delta,
        PoolKey calldata key
    ) internal {
        uint256 liquidityAmount = _calculateLiquidityAmount(delta);
        PoolId poolId = key.toId();
        
        // Update total liquidity
        activity.totalLiquidity += liquidityAmount;
        
        // Update pool-specific liquidity
        activity.poolLiquidity[poolId] += liquidityAmount;
        
        // Update average position size
        activity.averagePositionSize = _calculateAveragePositionSize(activity);
        
        // Update last activity
        activity.lastActivity = block.timestamp;
        
        // Update transaction count
        activity.transactionCount++;
        
        // Update loyalty score
        _updateLoyaltyScore(activity, ActivityType.LIQUIDITY_PROVISION);
        
        // Update consistency score
        _updateConsistencyScore(activity);
    }

    /// @notice Update swap volume activity
    function updateSwapVolume(
        UserActivity storage activity,
        uint256 swapVolume
    ) internal {
        activity.swapVolume += swapVolume;
        activity.lastActivity = block.timestamp;
        activity.transactionCount++;
        
        _updateLoyaltyScore(activity, ActivityType.SWAP);
        _updateConsistencyScore(activity);
    }

    /// @notice Update pool-specific swap volume
    function updatePoolSwapVolume(
        UserActivity storage activity,
        PoolId poolId,
        uint256 swapVolume
    ) internal {
        activity.poolSwapVolume[poolId] += swapVolume;
        activity.swapVolume += swapVolume;
        activity.lastActivity = block.timestamp;
        
        _updateLoyaltyScore(activity, ActivityType.SWAP);
    }

    /// @notice Calculate liquidity amount from delta
    function _calculateLiquidityAmount(BalanceDelta delta) internal pure returns (uint256) {
        uint256 delta0 = uint256(int256(delta.amount0()));
        uint256 delta1 = uint256(int256(delta.amount1()));
        
        // Use the larger delta as liquidity amount
        return delta0 > delta1 ? delta0 : delta1;
    }

    /// @notice Calculate average position size
    function _calculateAveragePositionSize(
        UserActivity storage activity
    ) internal view returns (uint256) {
        if (activity.transactionCount == 0) return 0;
        
        return activity.totalLiquidity / activity.transactionCount;
    }

    /// @notice Update loyalty score based on activity
    function _updateLoyaltyScore(
        UserActivity storage activity,
        ActivityType activityType
    ) internal {
        uint256 baseIncrease = 0;
        
        // Base increase based on activity type
        if (activityType == ActivityType.LIQUIDITY_PROVISION) {
            baseIncrease = 2; // 2 points for liquidity provision
        } else if (activityType == ActivityType.SWAP) {
            baseIncrease = 1; // 1 point for swap
        } else if (activityType == ActivityType.CLAIM_REWARDS) {
            baseIncrease = 3; // 3 points for claiming rewards (shows engagement)
        }
        
        // Apply time decay
        uint256 timeSinceLastActivity = block.timestamp - activity.lastActivity;
        uint256 decayAmount = timeSinceLastActivity * LOYALTY_DECAY_RATE / 1 days;
        
        if (decayAmount > activity.loyaltyScore) {
            activity.loyaltyScore = 0;
        } else {
            activity.loyaltyScore -= decayAmount;
        }
        
        // Add new points
        activity.loyaltyScore += baseIncrease;
        
        // Cap at maximum
        if (activity.loyaltyScore > MAX_LOYALTY_SCORE) {
            activity.loyaltyScore = MAX_LOYALTY_SCORE;
        }
    }

    /// @notice Update consistency score
    function _updateConsistencyScore(UserActivity storage activity) internal {
        // Calculate consistency based on regular activity
        uint256 daysSinceStart = (block.timestamp - activity.lastActivity) / 1 days;
        uint256 expectedTransactions = daysSinceStart / 7; // Expected weekly transactions
        
        if (expectedTransactions > 0) {
            activity.consistencyScore = (activity.transactionCount * 100) / expectedTransactions;
        } else {
            activity.consistencyScore = 100; // Perfect if no time has passed
        }
        
        // Cap at 100
        if (activity.consistencyScore > 100) {
            activity.consistencyScore = 100;
        }
    }

    /// @notice Get user engagement score
    function getEngagementScore(
        UserActivity storage activity
    ) internal view returns (uint256) {
        // Weighted combination of different metrics
        uint256 liquidityScore = _normalizeScore(activity.totalLiquidity, 1000e18); // Normalize to 1000 ETH
        uint256 volumeScore = _normalizeScore(activity.swapVolume, 10000e18); // Normalize to 10000 ETH
        uint256 loyaltyScore = activity.loyaltyScore;
        uint256 consistencyScore = activity.consistencyScore;
        
        // Weighted average
        uint256 engagementScore = (
            liquidityScore * 30 +
            volumeScore * 25 +
            loyaltyScore * 25 +
            consistencyScore * 20
        ) / 100;
        
        return engagementScore;
    }

    /// @notice Normalize score to 0-100 range
    function _normalizeScore(
        uint256 value,
        uint256 maxValue
    ) internal pure returns (uint256) {
        if (value >= maxValue) return 100;
        return (value * 100) / maxValue;
    }

    /// @notice Get user tier based on activity
    function getUserTier(
        UserActivity storage activity
    ) internal view returns (uint8) {
        uint256 engagementScore = getEngagementScore(activity);
        
        if (engagementScore >= 90) return 4; // Diamond
        if (engagementScore >= 75) return 3; // Platinum
        if (engagementScore >= 50) return 2; // Gold
        if (engagementScore >= 25) return 1; // Silver
        return 0; // Bronze
    }

    /// @notice Check if user is active
    function isUserActive(
        UserActivity storage activity,
        uint256 inactiveThreshold
    ) internal view returns (bool) {
        return block.timestamp - activity.lastActivity <= inactiveThreshold;
    }

    /// @notice Get activity summary
    function getActivitySummary(
        UserActivity storage activity
    ) internal view returns (
        uint256 totalLiquidity,
        uint256 swapVolume,
        uint256 positionDuration,
        uint256 lastActivity,
        uint256 loyaltyScore,
        uint256 engagementScore,
        uint8 tier
    ) {
        return (
            activity.totalLiquidity,
            activity.swapVolume,
            activity.positionDuration,
            activity.lastActivity,
            activity.loyaltyScore,
            getEngagementScore(activity),
            getUserTier(activity)
        );
    }

    /// @notice Reset user activity (for testing)
    function resetActivity(UserActivity storage activity) internal {
        activity.totalLiquidity = 0;
        activity.swapVolume = 0;
        activity.positionDuration = 0;
        activity.lastActivity = 0;
        activity.loyaltyScore = 0;
        activity.transactionCount = 0;
        activity.averagePositionSize = 0;
        activity.consistencyScore = 0;
    }
}
