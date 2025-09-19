// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IAVSTaskHook
 * @notice Interface for AVS task hook functionality
 * @dev Placeholder interface for missing EigenLayer contract
 */
interface IAVSTaskHook {
    /// @notice Validate task before creation
    function validatePreTaskCreation(
        address caller,
        bytes calldata taskParams
    ) external view;
    
    /// @notice Handle post task creation
    function handlePostTaskCreation(bytes32 taskHash) external;
    
    /// @notice Validate task result before submission
    function validatePreTaskResultSubmission(
        address caller,
        bytes32 taskHash,
        bytes calldata cert,
        bytes calldata result
    ) external view;
    
    /// @notice Handle post task result submission
    function handlePostTaskResultSubmission(
        address caller,
        bytes32 taskHash
    ) external;
    
    /// @notice Calculate task fee
    function calculateTaskFee(bytes calldata taskParams) external view returns (uint96 fee);
}
