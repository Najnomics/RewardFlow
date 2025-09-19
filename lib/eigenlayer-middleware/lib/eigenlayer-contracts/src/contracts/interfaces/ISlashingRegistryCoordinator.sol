// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ISlashingRegistryCoordinator
 * @notice Interface for slashing registry coordinator
 * @dev Placeholder interface for missing EigenLayer contract
 */
interface ISlashingRegistryCoordinator {
    /// @notice Slash operator
    function slashOperator(address operator, uint256 amount) external;
    
    /// @notice Check if operator is slashed
    function isSlashed(address operator) external view returns (bool);
    
    /// @notice Get slashing amount
    function getSlashingAmount(address operator) external view returns (uint256);
}
