// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RewardMath} from "../../hooks/libraries/RewardMath.sol";

/**
 * @title EngagementMetrics
 * @notice Library for user engagement metrics and scoring
 */
library EngagementMetrics {
    using RewardMath for uint256;

    /// @notice User engagement structure
    struct UserEngagement {
        uint256 totalLiquidity;
        uint256 swapVolume;
        uint256 positionDuration;
        uint256 lastActivity;
        uint256 loyaltyScore;
        uint256 transactionCount;
        uint256 averagePositionSize;
        uint256 consistencyScore;
        mapping(address => uint256) poolLiquidity;
        mapping(address => uint256) poolSwapVolume;
    }

    /// @notice Engagement update types
    enum EngagementType {
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

    /// @notice Update liquidity activity
    function updateLiquidityActivity(
        UserEngagement storage engagement,
        uint256 liquidityAmount
    ) internal {
        engagement.totalLiquidity += liquidityAmount;
        engagement.lastActivity = block.timestamp;
        engagement.transactionCount++;
        
        _updateLoyaltyScore(engagement, EngagementType.LIQUIDITY_PROVISION);
        _updateConsistencyScore(engagement);
    }

    /// @notice Update swap activity
    function updateSwapActivity(
        UserEngagement storage engagement,
        uint256 swapVolume
    ) internal {
        engagement.swapVolume += swapVolume;
        engagement.lastActivity = block.timestamp;
        engagement.transactionCount++;
        
        _updateLoyaltyScore(engagement, EngagementType.SWAP);
        _updateConsistencyScore(engagement);
    }

    /// @notice Update loyalty score based on activity
    function _updateLoyaltyScore(
        UserEngagement storage engagement,
        EngagementType engagementType
    ) internal {
        uint256 baseIncrease = 0;
        
        // Base increase based on activity type
        if (engagementType == EngagementType.LIQUIDITY_PROVISION) {
            baseIncrease = 2; // 2 points for liquidity provision
        } else if (engagementType == EngagementType.SWAP) {
            baseIncrease = 1; // 1 point for swap
        } else if (engagementType == EngagementType.CLAIM_REWARDS) {
            baseIncrease = 3; // 3 points for claiming rewards (shows engagement)
        }
        
        // Apply time decay
        uint256 timeSinceLastActivity = block.timestamp - engagement.lastActivity;
        uint256 decayAmount = timeSinceLastActivity * LOYALTY_DECAY_RATE / 1 days;
        
        if (decayAmount > engagement.loyaltyScore) {
            engagement.loyaltyScore = 0;
        } else {
            engagement.loyaltyScore -= decayAmount;
        }
        
        // Add new points
        engagement.loyaltyScore += baseIncrease;
        
        // Cap at maximum
        if (engagement.loyaltyScore > MAX_LOYALTY_SCORE) {
            engagement.loyaltyScore = MAX_LOYALTY_SCORE;
        }
    }

    /// @notice Update consistency score
    function _updateConsistencyScore(UserEngagement storage engagement) internal {
        // Calculate consistency based on regular activity
        uint256 daysSinceStart = (block.timestamp - engagement.lastActivity) / 1 days;
        uint256 expectedTransactions = daysSinceStart / 7; // Expected weekly transactions
        
        if (expectedTransactions > 0) {
            engagement.consistencyScore = (engagement.transactionCount * 100) / expectedTransactions;
        } else {
            engagement.consistencyScore = 100; // Perfect if no time has passed
        }
        
        // Cap at 100
        if (engagement.consistencyScore > 100) {
            engagement.consistencyScore = 100;
        }
    }

    /// @notice Get user engagement score
    function getEngagementScore(
        UserEngagement storage engagement
    ) internal view returns (uint256) {
        // Weighted combination of different metrics
        uint256 liquidityScore = _normalizeScore(engagement.totalLiquidity, 1000e18); // Normalize to 1000 ETH
        uint256 volumeScore = _normalizeScore(engagement.swapVolume, 10000e18); // Normalize to 10000 ETH
        uint256 loyaltyScore = engagement.loyaltyScore;
        uint256 consistencyScore = engagement.consistencyScore;
        
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

    /// @notice Get user tier based on engagement
    function getTier(
        UserEngagement storage engagement
    ) internal view returns (uint8) {
        uint256 engagementScore = getEngagementScore(engagement);
        
        if (engagementScore >= 90) return 4; // Diamond
        if (engagementScore >= 75) return 3; // Platinum
        if (engagementScore >= 50) return 2; // Gold
        if (engagementScore >= 25) return 1; // Silver
        return 0; // Bronze
    }

    /// @notice Check if user is active
    function isUserActive(
        UserEngagement storage engagement,
        uint256 inactiveThreshold
    ) internal view returns (bool) {
        return block.timestamp - engagement.lastActivity <= inactiveThreshold;
    }

    /// @notice Get engagement summary
    function getEngagementSummary(
        UserEngagement storage engagement
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
            engagement.totalLiquidity,
            engagement.swapVolume,
            engagement.positionDuration,
            engagement.lastActivity,
            engagement.loyaltyScore,
            getEngagementScore(engagement),
            getTier(engagement)
        );
    }
}
