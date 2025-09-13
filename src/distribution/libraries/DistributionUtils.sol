// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RewardMath} from "../../hooks/libraries/RewardMath.sol";

/**
 * @title DistributionUtils
 * @notice Library for distribution utilities
 */
library DistributionUtils {
    using RewardMath for uint256;

    /// @notice Distribution request structure
    struct DistributionRequest {
        address user;
        uint256 amount;
        uint256 sourceChain;
        uint256 targetChain;
        address rewardToken;
        uint256 timestamp;
        bool executed;
        bytes32 requestId;
    }

    /// @notice Calculate distribution fees
    function calculateFees(
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

    /// @notice Calculate net amount after fees
    function calculateNetAmount(
        uint256 amount,
        uint256 targetChain
    ) internal pure returns (uint256) {
        uint256 fees = calculateFees(amount, targetChain);
        return amount - fees;
    }

    /// @notice Check if distribution is profitable
    function isDistributionProfitable(
        uint256 amount,
        uint256 targetChain,
        uint256 minProfitThreshold
    ) internal pure returns (bool) {
        uint256 netAmount = calculateNetAmount(amount, targetChain);
        return netAmount >= minProfitThreshold;
    }

    /// @notice Calculate distribution priority
    function calculateDistributionPriority(
        uint256 amount,
        uint256 userTier,
        uint256 timeSinceLastDistribution
    ) internal pure returns (uint256) {
        // Higher amount = higher priority
        uint256 amountPriority = amount / 1e18; // 1 point per ETH
        
        // Higher tier = higher priority
        uint256 tierPriority = userTier * 10;
        
        // Longer time since last distribution = higher priority
        uint256 timePriority = timeSinceLastDistribution / 1 days;
        
        return amountPriority + tierPriority + timePriority;
    }

    /// @notice Validate distribution request
    function validateDistributionRequest(
        DistributionRequest memory request
    ) internal pure returns (bool) {
        return request.user != address(0) &&
               request.amount > 0 &&
               request.targetChain > 0 &&
               request.rewardToken != address(0) &&
               request.timestamp > 0;
    }

    /// @notice Calculate optimal distribution timing
    function calculateOptimalTiming(
        uint256 currentTime,
        uint256 userPreference,
        uint256 gasPrice
    ) internal pure returns (uint256) {
        // Consider gas price and user preference
        uint256 gasFactor = gasPrice > 20 gwei ? 1 hours : 30 minutes;
        uint256 userFactor = userPreference > 0 ? userPreference : 1 hours;
        
        return currentTime + (gasFactor + userFactor) / 2;
    }

    /// @notice Get distribution status
    function getDistributionStatus(
        DistributionRequest storage request
    ) internal view returns (string memory) {
        if (request.executed) return "COMPLETED";
        if (block.timestamp > request.timestamp + 1 hours) return "EXPIRED";
        return "PENDING";
    }

    /// @notice Calculate distribution efficiency
    function calculateDistributionEfficiency(
        uint256 totalAmount,
        uint256 totalFees,
        uint256 executionTime
    ) internal pure returns (uint256) {
        if (executionTime == 0) return 0;
        
        uint256 netAmount = totalAmount - totalFees;
        return netAmount.mulDiv(1e18, executionTime);
    }
}
