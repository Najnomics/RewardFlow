// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Constants
 * @notice System constants and configuration values
 */
library Constants {
    /// @notice Precision for calculations (18 decimals)
    uint256 public constant PRECISION = 1e18;
    
    /// @notice Maximum uint256 value
    uint256 public constant MAX_UINT256 = type(uint256).max;
    
    /// @notice Maximum uint128 value
    uint128 public constant MAX_UINT128 = type(uint128).max;
    
    /// @notice Maximum uint64 value
    uint64 public constant MAX_UINT64 = type(uint64).max;
    
    /// @notice Maximum uint32 value
    uint32 public constant MAX_UINT32 = type(uint32).max;

    /// @notice Token addresses
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86a33E6441b8c4C8C0e4C8b8c4C8C0e4C8b8c;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    /// @notice Chain IDs
    uint256 public constant ETHEREUM_CHAIN_ID = 1;
    uint256 public constant ARBITRUM_CHAIN_ID = 42161;
    uint256 public constant POLYGON_CHAIN_ID = 137;
    uint256 public constant BASE_CHAIN_ID = 8453;
    uint256 public constant OPTIMISM_CHAIN_ID = 10;

    /// @notice Reward system constants
    uint256 public constant MIN_REWARD_THRESHOLD = 1e15; // 0.001 ETH
    uint256 public constant MAX_REWARD_THRESHOLD = 1000e18; // 1000 ETH
    uint256 public constant DEFAULT_REWARD_THRESHOLD = 1e16; // 0.01 ETH
    
    /// @notice Tier thresholds (in ETH)
    uint256 public constant BRONZE_THRESHOLD = 0;
    uint256 public constant SILVER_THRESHOLD = 10e18;
    uint256 public constant GOLD_THRESHOLD = 100e18;
    uint256 public constant PLATINUM_THRESHOLD = 500e18;
    uint256 public constant DIAMOND_THRESHOLD = 1000e18;

    /// @notice Tier multipliers (in basis points)
    uint256 public constant BRONZE_MULTIPLIER = 10000; // 1x
    uint256 public constant SILVER_MULTIPLIER = 11000; // 1.1x
    uint256 public constant GOLD_MULTIPLIER = 12000; // 1.2x
    uint256 public constant PLATINUM_MULTIPLIER = 15000; // 1.5x
    uint256 public constant DIAMOND_MULTIPLIER = 20000; // 2x

    /// @notice Time constants
    uint256 public constant SECONDS_PER_MINUTE = 60;
    uint256 public constant SECONDS_PER_HOUR = 3600;
    uint256 public constant SECONDS_PER_DAY = 86400;
    uint256 public constant SECONDS_PER_WEEK = 604800;
    uint256 public constant SECONDS_PER_MONTH = 2592000;
    uint256 public constant SECONDS_PER_YEAR = 31536000;

    /// @notice Reward distribution constants
    uint256 public constant LP_FEE_SHARE = 5000; // 50%
    uint256 public constant OPERATOR_FEE_SHARE = 1000; // 10%
    uint256 public constant PROTOCOL_FEE_SHARE = 300; // 3%
    uint256 public constant GAS_COMPENSATION_SHARE = 200; // 2%
    uint256 public constant TOTAL_FEE_SHARE = 10000; // 100%

    /// @notice Aggregation constants
    uint256 public constant AGGREGATION_WINDOW = 1 days;
    uint256 public constant MAX_AGGREGATION_DELAY = 7 days;
    uint256 public constant MIN_AGGREGATION_SIZE = 10;
    uint256 public constant MAX_AGGREGATION_SIZE = 1000;

    /// @notice Cross-chain constants
    uint256 public constant CROSS_CHAIN_DELAY = 30 minutes;
    uint256 public constant MAX_CROSS_CHAIN_RETRIES = 3;
    uint256 public constant CROSS_CHAIN_TIMEOUT = 1 hours;

    /// @notice Gas constants
    uint256 public constant GAS_LIMIT_HOOK = 500000;
    uint256 public constant GAS_LIMIT_AVS = 1000000;
    uint256 public constant GAS_LIMIT_DISTRIBUTION = 200000;

    /// @notice Fee constants
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MAX_FEE_RATE = 1000; // 10%
    uint256 public constant MIN_FEE_RATE = 1; // 0.01%

    /// @notice Slippage constants
    uint256 public constant MAX_SLIPPAGE = 500; // 5%
    uint256 public constant DEFAULT_SLIPPAGE = 100; // 1%

    /// @notice Price oracle constants
    uint256 public constant PRICE_DEVIATION_THRESHOLD = 500; // 5%
    uint256 public constant PRICE_STALENESS_THRESHOLD = 3600; // 1 hour
    uint256 public constant MAX_PRICE_AGE = 86400; // 24 hours

    /// @notice Security constants
    uint256 public constant MAX_OPERATORS = 1000;
    uint256 public constant MIN_OPERATORS = 3;
    uint256 public constant SLASHING_THRESHOLD = 33; // 33%
    uint256 public constant CHALLENGE_PERIOD = 7 days;

    /// @notice Emergency constants
    uint256 public constant EMERGENCY_PAUSE_DELAY = 1 hours;
    uint256 public constant EMERGENCY_WITHDRAWAL_DELAY = 24 hours;
    uint256 public constant MAX_EMERGENCY_WITHDRAWAL = 1000e18; // 1000 ETH

    /// @notice Governance constants
    uint256 public constant VOTING_DELAY = 1 days;
    uint256 public constant VOTING_PERIOD = 3 days;
    uint256 public constant PROPOSAL_THRESHOLD = 1000e18; // 1000 ETH
    uint256 public constant QUORUM_THRESHOLD = 2000e18; // 2000 ETH

    /// @notice Upgrade constants
    uint256 public constant UPGRADE_DELAY = 7 days;
    uint256 public constant UPGRADE_TIMELOCK = 24 hours;

    /// @notice Error messages
    string public constant ERROR_INVALID_AMOUNT = "Invalid amount";
    string public constant ERROR_INVALID_ADDRESS = "Invalid address";
    string public constant ERROR_INVALID_PARAMETER = "Invalid parameter";
    string public constant ERROR_UNAUTHORIZED = "Unauthorized";
    string public constant ERROR_PAUSED = "Contract paused";
    string public constant ERROR_EMERGENCY = "Emergency mode";
    string public constant ERROR_SLIPPAGE_TOO_HIGH = "Slippage too high";
    string public constant ERROR_INSUFFICIENT_BALANCE = "Insufficient balance";
    string public constant ERROR_OVERFLOW = "Arithmetic overflow";
    string public constant ERROR_DIVISION_BY_ZERO = "Division by zero";
    string public constant ERROR_ARRAY_LENGTH_MISMATCH = "Array length mismatch";
    string public constant ERROR_INVALID_TIER = "Invalid tier";
    string public constant ERROR_INSUFFICIENT_THRESHOLD = "Insufficient threshold";
    string public constant ERROR_REWARD_ALREADY_PROCESSED = "Reward already processed";
    string public constant ERROR_INVALID_REWARD_TYPE = "Invalid reward type";
    string public constant ERROR_CROSS_CHAIN_FAILED = "Cross-chain operation failed";
    string public constant ERROR_AGGREGATION_FAILED = "Aggregation failed";
    string public constant ERROR_OPERATOR_NOT_FOUND = "Operator not found";
    string public constant ERROR_INSUFFICIENT_STAKE = "Insufficient stake";
    string public constant ERROR_SLASHING_FAILED = "Slashing failed";
    string public constant ERROR_CHALLENGE_FAILED = "Challenge failed";
    string public constant ERROR_UPGRADE_FAILED = "Upgrade failed";
    string public constant ERROR_GOVERNANCE_FAILED = "Governance failed";
    string public constant ERROR_EMERGENCY_FAILED = "Emergency operation failed";
}
