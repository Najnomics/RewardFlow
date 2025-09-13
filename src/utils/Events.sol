// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Events
 * @notice Event definitions for the RewardFlow system
 */
library Events {
    /// @notice Reward events
    event RewardEarned(
        address indexed user,
        uint256 amount,
        uint8 rewardType,
        uint256 timestamp
    );
    
    event RewardProcessed(
        bytes32 indexed entryId,
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );
    
    event RewardDistributed(
        address indexed user,
        uint256 amount,
        uint256 targetChain,
        uint256 timestamp
    );
    
    event RewardClaimed(
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );

    /// @notice Tier events
    event TierUpdated(
        address indexed user,
        uint8 oldTier,
        uint8 newTier,
        uint256 timestamp
    );
    
    event TierBonusApplied(
        address indexed user,
        uint256 bonusAmount,
        uint8 tier,
        uint256 timestamp
    );

    /// @notice Activity events
    event ActivityRecorded(
        address indexed user,
        uint8 activityType,
        uint256 amount,
        uint256 timestamp
    );
    
    event LoyaltyScoreUpdated(
        address indexed user,
        uint256 oldScore,
        uint256 newScore,
        uint256 timestamp
    );

    /// @notice Position events
    event PositionUpdated(
        address indexed user,
        address indexed poolId,
        uint256 liquidity,
        uint256 timestamp
    );
    
    event PositionRemoved(
        address indexed user,
        address indexed poolId,
        uint256 liquidity,
        uint256 timestamp
    );

    /// @notice Pool events
    event PoolLPsUpdated(
        address indexed poolId,
        address[] lps,
        uint256[] shares,
        uint256 timestamp
    );
    
    event SwapRewardsDistributed(
        address indexed poolId,
        uint256 totalReward,
        uint256 swapVolume,
        uint256 timestamp
    );

    /// @notice AVS events
    event RewardRecorded(
        address indexed user,
        uint256 amount,
        uint8 rewardType,
        uint256 timestamp
    );
    
    event RewardsAggregated(
        bytes32 indexed taskId,
        uint256 userCount,
        uint256 totalAmount,
        uint256 timestamp
    );
    
    event AggregationTaskCreated(
        bytes32 indexed taskId,
        address[] users,
        uint256[] amounts,
        uint256[] targetChains,
        uint256 deadline,
        uint256 timestamp
    );
    
    event AggregationTaskCompleted(
        bytes32 indexed taskId,
        uint256 successCount,
        uint256 failureCount,
        uint256 timestamp
    );

    /// @notice Operator events
    event OperatorRegistered(
        address indexed operator,
        uint256 stake,
        uint256 timestamp
    );
    
    event OperatorDeregistered(
        address indexed operator,
        uint256 timestamp
    );
    
    event OperatorSlashed(
        address indexed operator,
        uint256 amount,
        string reason,
        uint256 timestamp
    );

    /// @notice Cross-chain events
    event CrossChainTransferInitiated(
        bytes32 indexed transferId,
        address indexed user,
        uint256 amount,
        uint256 sourceChain,
        uint256 targetChain,
        uint256 timestamp
    );
    
    event CrossChainTransferCompleted(
        bytes32 indexed transferId,
        address indexed user,
        uint256 amount,
        uint256 targetChain,
        uint256 timestamp
    );
    
    event CrossChainTransferFailed(
        bytes32 indexed transferId,
        address indexed user,
        uint256 amount,
        uint256 targetChain,
        string reason,
        uint256 timestamp
    );

    /// @notice Distribution events
    event DistributionInitiated(
        bytes32 indexed requestId,
        address indexed user,
        uint256 amount,
        uint256 targetChain,
        uint256 timestamp
    );
    
    event DistributionExecuted(
        bytes32 indexed requestId,
        uint256 depositId,
        uint256 timestamp
    );
    
    event DistributionFailed(
        bytes32 indexed requestId,
        address indexed user,
        uint256 amount,
        string reason,
        uint256 timestamp
    );

    /// @notice User preference events
    event PreferencesUpdated(
        address indexed user,
        uint256 preferredChain,
        uint256 claimThreshold,
        uint256 claimFrequency,
        uint256 timestamp
    );
    
    event AutoClaimEnabled(
        address indexed user,
        bool enabled,
        uint256 timestamp
    );

    /// @notice System events
    event SystemPaused(
        address indexed admin,
        uint256 timestamp
    );
    
    event SystemUnpaused(
        address indexed admin,
        uint256 timestamp
    );
    
    event EmergencyModeActivated(
        address indexed admin,
        string reason,
        uint256 timestamp
    );
    
    event EmergencyModeDeactivated(
        address indexed admin,
        uint256 timestamp
    );

    /// @notice Governance events
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string description,
        uint256 timestamp
    );
    
    event ProposalExecuted(
        uint256 indexed proposalId,
        address indexed executor,
        uint256 timestamp
    );
    
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 weight,
        uint256 timestamp
    );

    /// @notice Upgrade events
    event UpgradeScheduled(
        address indexed newImplementation,
        uint256 effectiveTime,
        uint256 timestamp
    );
    
    event UpgradeExecuted(
        address indexed oldImplementation,
        address indexed newImplementation,
        uint256 timestamp
    );

    /// @notice Fee events
    event FeeUpdated(
        uint8 feeType,
        uint256 oldFee,
        uint256 newFee,
        uint256 timestamp
    );
    
    event FeeCollected(
        address indexed recipient,
        uint256 amount,
        uint8 feeType,
        uint256 timestamp
    );

    /// @notice Oracle events
    event PriceUpdated(
        address indexed token,
        uint256 price,
        uint256 timestamp
    );
    
    event OracleUpdated(
        address indexed oldOracle,
        address indexed newOracle,
        uint256 timestamp
    );

    /// @notice Challenge events
    event ChallengeRaised(
        bytes32 indexed taskId,
        address indexed challenger,
        string reason,
        uint256 timestamp
    );
    
    event ChallengeResolved(
        bytes32 indexed taskId,
        bool valid,
        address indexed operator,
        uint256 timestamp
    );

    /// @notice Error events
    event ErrorOccurred(
        string error,
        address indexed user,
        uint256 timestamp
    );
    
    event WarningIssued(
        string warning,
        address indexed user,
        uint256 timestamp
    );
}
