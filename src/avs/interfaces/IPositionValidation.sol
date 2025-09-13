// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IPositionValidation
 * @notice Interface for position validation middleware
 */
interface IPositionValidation {
    /// @notice Position validation result
    struct ValidationResult {
        bool isValid;
        string reason;
        uint256 confidence;
        uint256 timestamp;
    }

    /// @notice Position data
    struct PositionData {
        address user;
        address poolId;
        uint256 liquidity;
        uint256 timestamp;
        uint256 blockNumber;
        bytes32 positionHash;
    }

    /// @notice Events
    event PositionValidated(
        address indexed user,
        address indexed poolId,
        bool isValid,
        string reason
    );
    
    event ValidationRuleUpdated(
        uint8 ruleId,
        bool enabled,
        uint256 threshold
    );

    /// @notice Validate a position
    function validatePosition(
        PositionData calldata position
    ) external view returns (ValidationResult memory);

    /// @notice Batch validate positions
    function validatePositions(
        PositionData[] calldata positions
    ) external view returns (ValidationResult[] memory);

    /// @notice Check if position is valid
    function isPositionValid(
        address user,
        address poolId,
        uint256 liquidity
    ) external view returns (bool);

    /// @notice Get validation rules
    function getValidationRules() external view returns (uint8[] memory);

    /// @notice Update validation rule
    function updateValidationRule(
        uint8 ruleId,
        bool enabled,
        uint256 threshold
    ) external;

    /// @notice Get validation statistics
    function getValidationStats() external view returns (
        uint256 totalValidations,
        uint256 validPositions,
        uint256 invalidPositions,
        uint256 averageConfidence
    );
}
