// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ITaskAVSRegistrarBase
 * @notice Interface for task-based AVS registrar
 * @dev Placeholder interface for missing EigenLayer contract
 */
interface ITaskAVSRegistrarBase {
    /// @notice AVS configuration
    struct AvsConfig {
        uint256 minStake;
        uint256 maxOperators;
        bool isActive;
    }
    
    /// @notice Register operator for AVS
    function registerOperator(address avs) external;
    
    /// @notice Deregister operator from AVS
    function deregisterOperator(address avs) external;
    
    /// @notice Configure AVS settings
    function configureAVS(address avs, AvsConfig calldata config) external;
    
    /// @notice Check if operator is registered
    function registeredOperators(address operator) external view returns (bool);
    
    /// @notice Get AVS configuration
    function avsConfigs(address avs) external view returns (AvsConfig memory);
}

/**
 * @title ITaskAVSRegistrarBaseTypes
 * @notice Types interface for task-based AVS registrar
 * @dev Placeholder interface for missing EigenLayer contract
 */
interface ITaskAVSRegistrarBaseTypes {
    /// @notice AVS configuration
    struct AvsConfig {
        uint256 minStake;
        uint256 maxOperators;
        bool isActive;
    }
}
