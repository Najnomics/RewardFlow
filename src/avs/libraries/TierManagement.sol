// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RewardMath} from "../../hooks/libraries/RewardMath.sol";

/**
 * @title TierManagement
 * @notice Library for tier management in AVS
 */
library TierManagement {
    using RewardMath for uint256;

    /// @notice User tier structure
    struct UserTier {
        uint8 level;
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
    uint256 public constant MAX_TIER_POINTS = 10000;

    /// @notice Default tier thresholds
    function getDefaultThresholds() internal pure returns (TierThresholds memory) {
        return TierThresholds({
            bronzeMin: 0,
            silverMin: 10e18,    // 10 ETH
            goldMin: 100e18,     // 100 ETH
            platinumMin: 500e18, // 500 ETH
            diamondMin: 1000e18  // 1000 ETH
        });
    }

    /// @notice Default tier multipliers
    function getDefaultMultipliers() internal pure returns (TierMultipliers memory) {
        return TierMultipliers({
            bronze: 1e18,        // 1x
            silver: 11e17,       // 1.1x
            gold: 12e17,         // 1.2x
            platinum: 15e17,     // 1.5x
            diamond: 2e18        // 2x
        });
    }

    /// @notice Calculate tier based on user activity
    function calculateTier(
        uint256 totalLiquidity,
        uint256 loyaltyScore,
        uint256 consecutiveDays
    ) internal pure returns (uint8) {
        TierThresholds memory thresholds = getDefaultThresholds();
        
        // Calculate tier points
        uint256 tierPoints = _calculateTierPoints(totalLiquidity, loyaltyScore, consecutiveDays);
        
        // Determine tier based on points
        if (tierPoints >= thresholds.diamondMin) return 4; // Diamond
        if (tierPoints >= thresholds.platinumMin) return 3; // Platinum
        if (tierPoints >= thresholds.goldMin) return 2; // Gold
        if (tierPoints >= thresholds.silverMin) return 1; // Silver
        return 0; // Bronze
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
    function getTierMultiplier(uint8 tier) internal pure returns (uint256) {
        TierMultipliers memory multipliers = getDefaultMultipliers();
        
        if (tier == 4) return multipliers.diamond; // Diamond
        if (tier == 3) return multipliers.platinum; // Platinum
        if (tier == 2) return multipliers.gold; // Gold
        if (tier == 1) return multipliers.silver; // Silver
        return multipliers.bronze; // Bronze
    }

    /// @notice Calculate tier progression
    function calculateTierProgression(
        UserTier storage userTier,
        uint256 newLiquidity,
        uint256 newLoyaltyScore
    ) internal returns (uint8) {
        // Update user tier data
        userTier.totalLiquidity += newLiquidity;
        userTier.loyaltyScore = newLoyaltyScore;
        userTier.lastUpdate = block.timestamp;
        
        // Calculate new tier
        uint8 newTier = calculateTier(
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
        uint8 tier
    ) internal pure returns (uint256) {
        uint256 multiplier = getTierMultiplier(tier);
        return baseReward.mulDiv(multiplier, 1e18);
    }

    /// @notice Calculate tier decay
    function calculateTierDecay(
        UserTier storage userTier,
        uint256 inactiveDays
    ) internal returns (uint8) {
        // Apply decay based on inactivity
        uint256 decayAmount = inactiveDays * 1; // 1 point per day
        if (decayAmount > userTier.tierPoints) {
            userTier.tierPoints = 0;
        } else {
            userTier.tierPoints -= decayAmount;
        }
        
        // Recalculate tier
        uint8 newTier = calculateTier(
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
    function getTierBenefits(uint8 tier) internal pure returns (
        uint256 multiplier,
        uint256 priorityLevel,
        uint256 claimThreshold,
        uint256 maxPositions
    ) {
        multiplier = getTierMultiplier(tier);
        
        if (tier == 4) { // Diamond
            priorityLevel = 5;
            claimThreshold = 1e15; // 0.001 ETH
            maxPositions = 50;
        } else if (tier == 3) { // Platinum
            priorityLevel = 4;
            claimThreshold = 5e15; // 0.005 ETH
            maxPositions = 30;
        } else if (tier == 2) { // Gold
            priorityLevel = 3;
            claimThreshold = 1e16; // 0.01 ETH
            maxPositions = 20;
        } else if (tier == 1) { // Silver
            priorityLevel = 2;
            claimThreshold = 5e16; // 0.05 ETH
            maxPositions = 10;
        } else { // Bronze
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
        uint8 currentTier = userTier.level;
        uint8 potentialTier = calculateTier(
            userTier.totalLiquidity + additionalLiquidity,
            userTier.loyaltyScore,
            userTier.consecutiveDays
        );
        
        return potentialTier > currentTier;
    }

    /// @notice Get tier name
    function getTierName(uint8 tier) internal pure returns (string memory) {
        if (tier == 4) return "Diamond";
        if (tier == 3) return "Platinum";
        if (tier == 2) return "Gold";
        if (tier == 1) return "Silver";
        return "Bronze";
    }

    /// @notice Get tier color (for frontend)
    function getTierColor(uint8 tier) internal pure returns (string memory) {
        if (tier == 4) return "#B9F2FF";
        if (tier == 3) return "#E5E4E2";
        if (tier == 2) return "#FFD700";
        if (tier == 1) return "#C0C0C0";
        return "#CD7F32";
    }

    /// @notice Calculate tier requirements for next level
    function getTierRequirements(uint8 currentTier) internal pure returns (
        uint256 liquidityRequired,
        uint256 loyaltyRequired,
        uint256 daysRequired
    ) {
        TierThresholds memory thresholds = getDefaultThresholds();
        
        if (currentTier == 0) { // Bronze to Silver
            liquidityRequired = thresholds.silverMin;
            loyaltyRequired = 20;
            daysRequired = 7;
        } else if (currentTier == 1) { // Silver to Gold
            liquidityRequired = thresholds.goldMin;
            loyaltyRequired = 50;
            daysRequired = 14;
        } else if (currentTier == 2) { // Gold to Platinum
            liquidityRequired = thresholds.platinumMin;
            loyaltyRequired = 70;
            daysRequired = 30;
        } else if (currentTier == 3) { // Platinum to Diamond
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
