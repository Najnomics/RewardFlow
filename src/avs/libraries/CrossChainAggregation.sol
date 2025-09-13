// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RewardMath} from "../../hooks/libraries/RewardMath.sol";

/**
 * @title CrossChainAggregation
 * @notice Library for cross-chain reward aggregation
 */
library CrossChainAggregation {
    using RewardMath for uint256;

    /// @notice User rewards structure
    struct UserRewards {
        uint256 totalEarned;
        uint256 totalClaimed;
        uint256 pendingClaim;
        uint256 preferredChain;
        uint256 claimThreshold;
        uint256 lastClaimTime;
        uint8 currentTier;
        uint256 lastUpdate;
        mapping(uint256 => uint256) chainRewards;
    }

    /// @notice Chain aggregation data
    struct ChainAggregation {
        uint256 totalRewards;
        uint256 totalUsers;
        uint256 lastUpdate;
        uint256 pendingDistribution;
        bool isActive;
    }

    /// @notice Aggregation task
    struct AggregationTask {
        bytes32 taskId;
        address[] users;
        uint256[] amounts;
        uint256[] targetChains;
        uint256 deadline;
        TaskStatus status;
        uint256 createdAt;
    }

    /// @notice Task status
    enum TaskStatus {
        PENDING,
        IN_PROGRESS,
        COMPLETED,
        FAILED,
        CANCELLED
    }

    /// @notice Constants
    uint256 public constant AGGREGATION_WINDOW = 1 days;
    uint256 public constant MAX_AGGREGATION_SIZE = 1000;
    uint256 public constant MIN_AGGREGATION_SIZE = 10;

    /// @notice Update user rewards
    function updateUserRewards(
        UserRewards storage userRewards,
        uint256 amount,
        uint256 chainId
    ) internal {
        userRewards.totalEarned += amount;
        userRewards.pendingClaim += amount;
        userRewards.chainRewards[chainId] += amount;
        userRewards.lastUpdate = block.timestamp;
    }

    /// @notice Process reward claim
    function processRewardClaim(
        UserRewards storage userRewards,
        uint256 amount
    ) internal returns (uint256) {
        if (amount > userRewards.pendingClaim) {
            amount = userRewards.pendingClaim;
        }
        
        userRewards.pendingClaim -= amount;
        userRewards.totalClaimed += amount;
        userRewards.lastClaimTime = block.timestamp;
        
        return amount;
    }

    /// @notice Calculate aggregation efficiency
    function calculateAggregationEfficiency(
        uint256 totalRewards,
        uint256 totalUsers,
        uint256 gasCost
    ) internal pure returns (uint256) {
        if (totalUsers == 0) return 0;
        
        uint256 averageReward = totalRewards / totalUsers;
        uint256 efficiency = averageReward.mulDiv(1e18, gasCost);
        
        return efficiency;
    }

    /// @notice Check if aggregation is profitable
    function isAggregationProfitable(
        uint256 totalRewards,
        uint256 gasCost,
        uint256 minEfficiency
    ) internal pure returns (bool) {
        uint256 efficiency = totalRewards.mulDiv(1e18, gasCost);
        return efficiency >= minEfficiency;
    }

    /// @notice Calculate optimal aggregation size
    function calculateOptimalAggregationSize(
        uint256 totalUsers,
        uint256 gasLimit
    ) internal pure returns (uint256) {
        uint256 optimalSize = gasLimit / 100000; // Approximate gas per user
        
        if (optimalSize > totalUsers) {
            optimalSize = totalUsers;
        }
        
        if (optimalSize < MIN_AGGREGATION_SIZE) {
            optimalSize = MIN_AGGREGATION_SIZE;
        }
        
        if (optimalSize > MAX_AGGREGATION_SIZE) {
            optimalSize = MAX_AGGREGATION_SIZE;
        }
        
        return optimalSize;
    }

    /// @notice Calculate cross-chain fees
    function calculateCrossChainFees(
        uint256 amount,
        uint256 targetChain
    ) internal pure returns (uint256) {
        // Simplified fee calculation based on target chain
        uint256 baseFee = 1e15; // 0.001 ETH base fee
        
        if (targetChain == 1) { // Ethereum
            return baseFee;
        } else if (targetChain == 42161) { // Arbitrum
            return baseFee / 10;
        } else if (targetChain == 137) { // Polygon
            return baseFee / 20;
        } else if (targetChain == 8453) { // Base
            return baseFee / 15;
        } else {
            return baseFee;
        }
    }

    /// @notice Calculate net reward after fees
    function calculateNetReward(
        uint256 grossReward,
        uint256 targetChain
    ) internal pure returns (uint256) {
        uint256 fees = calculateCrossChainFees(grossReward, targetChain);
        return grossReward - fees;
    }

    /// @notice Check if user is eligible for aggregation
    function isUserEligibleForAggregation(
        UserRewards storage userRewards,
        uint256 minThreshold
    ) internal view returns (bool) {
        return userRewards.pendingClaim >= minThreshold &&
               block.timestamp - userRewards.lastClaimTime >= 1 days;
    }

    /// @notice Get user's total rewards across all chains
    function getTotalRewardsAcrossChains(
        UserRewards storage userRewards
    ) internal view returns (uint256) {
        uint256 total = 0;
        
        // Sum rewards from all chains (simplified - in practice, iterate through known chains)
        for (uint256 i = 1; i <= 10; i++) {
            total += userRewards.chainRewards[i];
        }
        
        return total;
    }

    /// @notice Calculate tier-based aggregation priority
    function calculateAggregationPriority(
        UserRewards storage userRewards
    ) internal pure returns (uint256) {
        // Higher tier users get higher priority
        uint256 basePriority = 100;
        uint256 tierMultiplier = userRewards.currentTier + 1;
        
        return basePriority * tierMultiplier;
    }

    /// @notice Check if aggregation task is valid
    function isValidAggregationTask(
        AggregationTask storage task
    ) internal view returns (bool) {
        return task.status == TaskStatus.PENDING &&
               block.timestamp <= task.deadline &&
               task.users.length > 0 &&
               task.users.length == task.amounts.length &&
               task.amounts.length == task.targetChains.length;
    }

    /// @notice Calculate task completion percentage
    function calculateTaskCompletion(
        AggregationTask storage task
    ) internal view returns (uint256) {
        if (task.status == TaskStatus.COMPLETED) return 100;
        if (task.status == TaskStatus.FAILED) return 0;
        
        uint256 timeElapsed = block.timestamp - task.createdAt;
        uint256 totalTime = task.deadline - task.createdAt;
        
        if (totalTime == 0) return 0;
        
        return timeElapsed.mulDiv(100, totalTime);
    }

    /// @notice Get aggregation statistics
    function getAggregationStats(
        mapping(bytes32 => AggregationTask) storage tasks
    ) internal view returns (
        uint256 totalTasks,
        uint256 completedTasks,
        uint256 failedTasks,
        uint256 pendingTasks
    ) {
        // This would iterate through all tasks in practice
        // For now, return placeholder values
        return (0, 0, 0, 0);
    }
}
