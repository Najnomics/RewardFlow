// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Errors
 * @notice Custom error definitions for the RewardFlow system
 */
library Errors {
    /// @notice General errors
    error InvalidAmount();
    error InvalidAddress();
    error InvalidParameter();
    error Unauthorized();
    error Paused();
    error EmergencyMode();
    
    /// @notice Reward errors
    error InsufficientRewardThreshold();
    error RewardAlreadyProcessed();
    error InvalidRewardType();
    error RewardNotFound();
    error RewardExpired();
    
    /// @notice Tier errors
    error InvalidTier();
    error TierNotUpgradeable();
    error InsufficientTierRequirements();
    
    /// @notice Position errors
    error PositionNotFound();
    error InsufficientLiquidity();
    error InvalidPool();
    error PositionExpired();
    
    /// @notice AVS errors
    error OperatorNotFound();
    error InsufficientStake();
    error InvalidTask();
    error TaskExpired();
    error AggregationFailed();
    
    /// @notice Cross-chain errors
    error CrossChainFailed();
    error InvalidTargetChain();
    error TransferTimeout();
    error InsufficientGas();
    
    /// @notice Distribution errors
    error DistributionFailed();
    error InvalidDistribution();
    error DistributionExpired();
    
    /// @notice System errors
    error SystemPaused();
    error EmergencyMode();
    error UpgradeFailed();
    error GovernanceFailed();
    
    /// @notice Math errors
    error Overflow();
    error Underflow();
    error DivisionByZero();
    error SlippageTooHigh();
    
    /// @notice Array errors
    error ArrayLengthMismatch();
    error EmptyArray();
    error IndexOutOfBounds();
}
