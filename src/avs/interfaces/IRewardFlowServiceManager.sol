// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IRewardFlowServiceManager
 * @notice Interface for RewardFlow Service Manager
 */
interface IRewardFlowServiceManager {
    /// @notice Reward aggregation task structure
    struct RewardAggregationTask {
        uint32 taskId;
        address[] users;
        uint256[] amounts;
        uint256[] targetChains;
        uint32 taskCreatedBlock;
        uint256 totalAmount;
        TaskStatus status;
    }

    /// @notice Task status
    enum TaskStatus {
        PENDING,
        IN_PROGRESS,
        COMPLETED,
        FAILED
    }

    /// @notice Events
    event RewardAggregationTaskCreated(uint32 indexed taskId, RewardAggregationTask task);
    event TaskResponded(uint32 indexed taskId, RewardAggregationTask task, address operator);
    event OperatorSlashed(address indexed operator, uint32 taskId, string reason);

    /// @notice Create a new reward aggregation task
    function createRewardAggregationTask(
        address[] calldata users,
        uint256[] calldata amounts,
        uint256[] calldata targetChains
    ) external returns (RewardAggregationTask memory);

    /// @notice Respond to a reward aggregation task
    function respondToRewardAggregationTask(
        RewardAggregationTask calldata task,
        uint32 referenceTaskIndex,
        bytes memory signature
    ) external;

    /// @notice Slash operator for not responding to task
    function slashOperator(
        RewardAggregationTask calldata task,
        uint32 referenceTaskIndex,
        address operator
    ) external;

    /// @notice Get aggregation task
    function getAggregationTask(uint32 taskId) external view returns (RewardAggregationTask memory);

    /// @notice Check if task was responded to
    function isTaskResponded(uint32 taskId) external view returns (bool);
}
