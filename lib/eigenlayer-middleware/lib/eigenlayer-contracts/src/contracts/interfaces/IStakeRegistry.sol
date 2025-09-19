// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IStakeRegistry
 * @notice Interface for stake registry
 * @dev Placeholder interface for missing EigenLayer contract
 */
interface IStakeRegistry {
    /// @notice Get operator stake
    function getOperatorStake(address operator) external view returns (uint256);
    
    /// @notice Check if operator is registered
    function isRegistered(address operator) external view returns (bool);
    
    /// @notice Register operator
    function registerOperator(address operator) external;
    
    /// @notice Deregister operator
    function deregisterOperator(address operator) external;
}
