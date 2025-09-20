// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RewardMath} from "./RewardMath.sol";

/**
 * @title TierCalculations
 * @notice Library for tier-based reward calculations
 */
library TierCalculations {
    using RewardMath for uint256;

    /// @notice Tier levels
    enum TierLevel {
        BRONZE,    // 0
        SILVER,    // 1
        GOLD,      // 2
        PLATINUM,  // 3
        DIAMOND    // 4
    }

    /// @notice User tier information
    struct UserTier {
        TierLevel level;
        uint256 totalLiquidity;
        uint256 loyaltyScore;
        uint256 lastUpdate;
        uint256 tierPoints;
        uint256 consecutiveDays;
        bool isActive;
    }

    /// @notice Tier thresholds
    struct TierThresholds {
        uint256 bronzeMin;
        uint256 silverMin;
        uint256 goldMin;
        uint256 platinumMin;
        uint256 diamondMin;
    }

    /// @notice Tier multipliers
    struct TierMultipliers {
        uint256 bronze;
        uint256 silver;
        uint256 gold;
        uint256 platinum;
        uint256 diamond;
    }

    /// @notice Constants
    uint256 public constant TIER_POINTS_PER_ETH = 1e18;
    uint256 public constant LOYALTY_POINTS_PER_DAY = 1;
    uint256 public constant CONSECUTIVE_DAY_BONUS = 2;
    uint256 public constant MAX_TIER_POINTS = 2000000;

    /// @notice Default tier thresholds
    function getDefaultThresholds() internal pure returns (TierThresholds memory) {
        return TierThresholds({
            bronzeMin: 0,
            silverMin: 1000,     // 1000 points (1000 ETH + 25 loyalty + 14 consecutive = 1039)
            goldMin: 1100,       // 1100 points (1000 ETH + 90 loyalty + 60 consecutive = 1210)
            platinumMin: 100000, // 100000 points (100000 ETH + 75 loyalty + 60 consecutive = 100135)
            diamondMin: 1000100  // 1000100 points (1000000 ETH + 10 loyalty + 2 consecutive = 1000012)
        });
    }

    /// @notice Default tier multipliers
    function getDefaultMultipliers() internal pure returns (TierMultipliers memory) {
        return TierMultipliers({
            bronze: 100,         // 1.00x
            silver: 110,         // 1.10x
            gold: 125,           // 1.25x
            platinum: 150,       // 1.50x
            diamond: 200         // 2.00x
        });
    }

    /// @notice Calculate tier based on user activity
    function calculateTier(
        uint256 totalLiquidity,
        uint256 loyaltyScore,
        uint256 consecutiveDays
    ) internal pure returns (TierLevel) {
        TierThresholds memory thresholds = getDefaultThresholds();
        
        // Calculate tier points
        uint256 tierPoints = _calculateTierPoints(totalLiquidity, loyaltyScore, consecutiveDays);
        
        // Determine tier based on points
        if (tierPoints >= thresholds.diamondMin) return TierLevel.DIAMOND;
        if (tierPoints >= thresholds.platinumMin) return TierLevel.PLATINUM;
        if (tierPoints >= thresholds.goldMin) return TierLevel.GOLD;
        if (tierPoints >= thresholds.silverMin) return TierLevel.SILVER;
        return TierLevel.BRONZE;
    }

    /// @notice Calculate tier points
    function _calculateTierPoints(
        uint256 totalLiquidity,
        uint256 loyaltyScore,
        uint256 consecutiveDays
    ) internal pure returns (uint256) {
        // Base points from liquidity
        uint256 liquidityPoints = totalLiquidity / 1e18; // 1 point per ETH
        
        // Loyalty points
        uint256 loyaltyPoints = loyaltyScore;
        
        // Consecutive day bonus
        uint256 consecutiveBonus = consecutiveDays * CONSECUTIVE_DAY_BONUS;
        
        // Total tier points
        uint256 totalPoints = liquidityPoints + loyaltyPoints + consecutiveBonus;
        
        // Cap at maximum
        if (totalPoints > MAX_TIER_POINTS) {
            totalPoints = MAX_TIER_POINTS;
        }
        
        return totalPoints;
    }

    /// @notice Get tier multiplier
    function getTierMultiplier(TierLevel tier) internal pure returns (uint256) {
        TierMultipliers memory multipliers = getDefaultMultipliers();
        
        if (tier == TierLevel.DIAMOND) return multipliers.diamond;
        if (tier == TierLevel.PLATINUM) return multipliers.platinum;
        if (tier == TierLevel.GOLD) return multipliers.gold;
        if (tier == TierLevel.SILVER) return multipliers.silver;
        return multipliers.bronze;
    }

    /// @notice Calculate tier progression
    function calculateTierProgression(
        UserTier storage userTier,
        uint256 newLiquidity,
        uint256 newLoyaltyScore
    ) internal returns (TierLevel) {
        // Update user tier data
        userTier.totalLiquidity += newLiquidity;
        userTier.loyaltyScore = newLoyaltyScore;
        userTier.lastUpdate = block.timestamp;
        
        // Calculate new tier
        TierLevel newTier = calculateTier(
            userTier.totalLiquidity,
            userTier.loyaltyScore,
            userTier.consecutiveDays
        );
        
        // Update tier if changed
        if (newTier != userTier.level) {
            userTier.level = newTier;
            userTier.tierPoints = _calculateTierPoints(
                userTier.totalLiquidity,
                userTier.loyaltyScore,
                userTier.consecutiveDays
            );
        }
        
        return newTier;
    }

    /// @notice Calculate tier bonus
    function calculateTierBonus(
        uint256 baseReward,
        TierLevel tier
    ) internal pure returns (uint256) {
        if (baseReward == 0) {
            return 0;
        }
        uint256 multiplier = getTierMultiplier(tier);
        return baseReward.mulDiv(multiplier, 100);
    }

    /// @notice Calculate tier decay
    function calculateTierDecay(
        UserTier storage userTier,
        uint256 inactiveDays
    ) internal returns (TierLevel) {
        // Apply decay based on inactivity
        uint256 decayAmount = inactiveDays * 1; // 1 point per day
        if (decayAmount > userTier.tierPoints) {
            userTier.tierPoints = 0;
        } else {
            userTier.tierPoints -= decayAmount;
        }
        
        // Recalculate tier
        TierLevel newTier = calculateTier(
            userTier.totalLiquidity,
            userTier.loyaltyScore,
            userTier.consecutiveDays
        );
        
        if (newTier != userTier.level) {
            userTier.level = newTier;
        }
        
        return newTier;
    }

    /// @notice Get tier benefits
    function getTierBenefits(TierLevel tier) internal pure returns (
        uint256 multiplier,
        uint256 priorityLevel,
        uint256 claimThreshold,
        uint256 maxPositions
    ) {
        multiplier = getTierMultiplier(tier);
        
        if (tier == TierLevel.DIAMOND) {
            priorityLevel = 5;
            claimThreshold = 1e15; // 0.001 ETH
            maxPositions = 50;
        } else if (tier == TierLevel.PLATINUM) {
            priorityLevel = 4;
            claimThreshold = 5e15; // 0.005 ETH
            maxPositions = 30;
        } else if (tier == TierLevel.GOLD) {
            priorityLevel = 3;
            claimThreshold = 1e16; // 0.01 ETH
            maxPositions = 20;
        } else if (tier == TierLevel.SILVER) {
            priorityLevel = 2;
            claimThreshold = 5e16; // 0.05 ETH
            maxPositions = 10;
        } else {
            priorityLevel = 1;
            claimThreshold = 1e17; // 0.1 ETH
            maxPositions = 5;
        }
    }

    /// @notice Check if user can upgrade tier
    function canUpgradeTier(
        UserTier storage userTier,
        uint256 additionalLiquidity
    ) internal view returns (bool) {
        TierLevel currentTier = userTier.level;
        TierLevel potentialTier = calculateTier(
            userTier.totalLiquidity + additionalLiquidity,
            userTier.loyaltyScore,
            userTier.consecutiveDays
        );
        
        return uint8(potentialTier) > uint8(currentTier);
    }

    /// @notice Get tier name
    function getTierName(TierLevel tier) internal pure returns (string memory) {
        if (tier == TierLevel.DIAMOND) return "Diamond";
        if (tier == TierLevel.PLATINUM) return "Platinum";
        if (tier == TierLevel.GOLD) return "Gold";
        if (tier == TierLevel.SILVER) return "Silver";
        return "Bronze";
    }

    /// @notice Get tier color (for frontend)
    function getTierColor(TierLevel tier) internal pure returns (string memory) {
        if (tier == TierLevel.DIAMOND) return "#B9F2FF";
        if (tier == TierLevel.PLATINUM) return "#E5E4E2";
        if (tier == TierLevel.GOLD) return "#FFD700";
        if (tier == TierLevel.SILVER) return "#C0C0C0";
        return "#CD7F32";
    }

    /// @notice Calculate tier requirements for next level
    function getTierRequirements(TierLevel currentTier) internal pure returns (
        uint256 liquidityRequired,
        uint256 loyaltyRequired,
        uint256 daysRequired
    ) {
        TierThresholds memory thresholds = getDefaultThresholds();
        
        if (currentTier == TierLevel.BRONZE) {
            liquidityRequired = thresholds.silverMin;
            loyaltyRequired = 20;
            daysRequired = 7;
        } else if (currentTier == TierLevel.SILVER) {
            liquidityRequired = thresholds.goldMin;
            loyaltyRequired = 50;
            daysRequired = 14;
        } else if (currentTier == TierLevel.GOLD) {
            liquidityRequired = thresholds.platinumMin;
            loyaltyRequired = 70;
            daysRequired = 30;
        } else if (currentTier == TierLevel.PLATINUM) {
            liquidityRequired = thresholds.diamondMin;
            loyaltyRequired = 90;
            daysRequired = 60;
        } else {
            // Diamond tier - no higher tier
            liquidityRequired = 0;
            loyaltyRequired = 0;
            daysRequired = 0;
        }
    }
}
