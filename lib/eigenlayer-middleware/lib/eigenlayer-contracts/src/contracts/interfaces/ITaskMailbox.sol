// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ITaskMailbox
 * @notice Interface for task mailbox functionality
 * @dev Placeholder interface for missing EigenLayer contract
 */
interface ITaskMailbox {
    /// @notice Task parameters structure
    struct TaskParams {
        bytes taskData;
        uint96 fee;
        uint8 priority;
        uint32 deadline;
    }
    
    /// @notice Create a new task
    function createTask(TaskParams calldata params) external returns (bytes32 taskHash);
    
    /// @notice Submit task result
    function submitTaskResult(
        bytes32 taskHash,
        bytes calldata result,
        bytes calldata cert
    ) external;
    
    /// @notice Get task status
    function getTaskStatus(bytes32 taskHash) external view returns (uint8 status);
    
    /// @notice Get task data
    function getTaskData(bytes32 taskHash) external view returns (bytes memory);
}

/**
 * @title ITaskMailboxTypes
 * @notice Types interface for task mailbox
 * @dev Placeholder interface for missing EigenLayer contract
 */
interface ITaskMailboxTypes {
    /// @notice Task parameters structure
    struct TaskParams {
        bytes taskData;
        uint96 fee;
        uint8 priority;
        uint32 deadline;
    }
}
