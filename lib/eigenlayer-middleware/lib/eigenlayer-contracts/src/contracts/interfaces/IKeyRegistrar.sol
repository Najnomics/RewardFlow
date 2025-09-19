// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IKeyRegistrar
 * @notice Interface for key registrar functionality
 * @dev Placeholder interface for missing EigenLayer contract
 */
interface IKeyRegistrar {
    /// @notice Register a public key
    function registerPublicKey(bytes calldata publicKey) external;
    
    /// @notice Get public key for an operator
    function getPublicKey(address operator) external view returns (bytes memory);
    
    /// @notice Check if operator is registered
    function isRegistered(address operator) external view returns (bool);
}
