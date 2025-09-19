// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {PoolId} from "@uniswap/v4-core/types/PoolId.sol";

/**
 * @title IPositionTracker
 * @notice Interface for position tracking across chains
 */
interface IPositionTracker {
    /// @notice Position information
    struct Position {
        address user;
        PoolId poolId;
        uint256 liquidity;
        uint256 timestamp;
        uint256 lastUpdate;
        bool active;
    }

    /// @notice Pool information
    struct PoolInfo {
        PoolId poolId;
        address[] lps;
        uint256[] shares;
        uint256 totalLiquidity;
        uint256 lastUpdate;
    }

    /// @notice Events
    event PositionUpdated(address indexed user, PoolId indexed poolId, uint256 liquidity);
    event PoolLPsUpdated(PoolId indexed poolId, address[] lps, uint256[] shares);

    /// @notice Update user position
    function updatePosition(
        address user,
        PoolKey calldata key,
        BalanceDelta delta
    ) external;

    /// @notice Get all LPs for a pool
    function getPoolLPs(PoolId poolId) external view returns (address[] memory);

    /// @notice Get LP shares for a pool
    function getPoolShares(PoolId poolId) external view returns (uint256[] memory);

    /// @notice Get user's position in a pool
    function getUserPosition(address user, PoolId poolId) external view returns (Position memory);

    /// @notice Get user's total liquidity across all pools
    function getUserTotalLiquidity(address user) external view returns (uint256);

    /// @notice Get pool information
    function getPoolInfo(PoolId poolId) external view returns (PoolInfo memory);

    /// @notice Check if user is LP in pool
    function isUserLP(address user, PoolId poolId) external view returns (bool);

    /// @notice Get user's active positions
    function getUserActivePositions(address user) external view returns (Position[] memory);
}
