// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";

/**
 * @title IRewardCalculator
 * @notice Interface for reward calculation logic
 */
interface IRewardCalculator {
    /// @notice Calculate base reward for liquidity provision
    function calculateLiquidityReward(
        BalanceDelta delta,
        PoolKey calldata key,
        address user
    ) external view returns (uint256);

    /// @notice Calculate reward for swap volume
    function calculateSwapReward(
        uint256 swapVolume,
        address poolId,
        address user
    ) external view returns (uint256);

    /// @notice Calculate tier multiplier for a user
    function calculateTierMultiplier(address user) external view returns (uint256);

    /// @notice Calculate time-based multiplier
    function calculateTimeMultiplier() external view returns (uint256);

    /// @notice Calculate token pair multiplier
    function calculateTokenMultiplier(
        address token0,
        address token1
    ) external view returns (uint256);

    /// @notice Calculate loyalty bonus
    function calculateLoyaltyBonus(address user) external view returns (uint256);
}
