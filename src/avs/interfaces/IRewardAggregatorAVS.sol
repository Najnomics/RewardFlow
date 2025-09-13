// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IRewardAggregatorAVS
 * @notice Interface for the Reward Aggregator AVS
 */
interface IRewardAggregatorAVS {
    /// @notice Reward entry structure
    struct RewardEntry {
        address user;
        address token0;
        address token1;
        uint256 amount;
        uint256 timestamp;
        uint256 blockNumber;
        RewardType rewardType;
    }

    /// @notice Reward types
    enum RewardType {
        LIQUIDITY_PROVISION,
        SWAP_VOLUME,
        LOYALTY_BONUS,
        TIER_MULTIPLIER
    }

    /// @notice Global reward state
    struct GlobalRewardState {
        uint256 totalRewardsDistributed;
        uint256 lastAggregationBlock;
        uint256 totalUsers;
        uint256 totalOperators;
    }

    /// @notice Chain rewards
    struct ChainRewards {
        uint256 totalRewards;
        uint256 totalUsers;
        uint256 lastUpdate;
    }

    /// @notice Operator data
    struct OperatorData {
        address operator;
        uint256 stake;
        bool isActive;
        uint256 registeredAt;
        uint256 lastActivity;
    }

    /// @notice Events
    event RewardRecorded(address indexed user, uint256 amount, uint8 rewardType);
    event RewardsAggregated(bytes32 indexed taskId, uint256 userCount, uint256 totalAmount);
    event TierUpdated(address indexed user, uint8 newTier);
    event OperatorRegistered(address indexed operator, uint256 stake);
    event OperatorDeregistered(address indexed operator);
    event OperatorSlashed(address indexed operator, uint256 amount, string reason);

    /// @notice Record a reward entry
    function recordReward(RewardEntry calldata entry) external;

    /// @notice Aggregate user rewards
    function aggregateUserRewards(
        address[] calldata users,
        uint256[] calldata amounts,
        uint256[] calldata targetChains
    ) external;

    /// @notice Trigger reward distribution for a user
    function triggerRewardDistribution(address user, uint256 amount) external;

    /// @notice Set user preferences
    function setUserPreferences(
        uint256 preferredChain,
        uint256 claimThreshold,
        uint256 claimFrequency
    ) external;

    /// @notice Register operator
    function registerOperator(address operator, uint256 stake) external;

    /// @notice Deregister operator
    function deregisterOperator(address operator) external;

    /// @notice Slash operator
    function slashOperator(address operator, uint256 amount, string calldata reason) external;
}
