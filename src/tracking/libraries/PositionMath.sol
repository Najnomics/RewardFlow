// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";

/**
 * @title PositionMath
 * @notice Library for position calculation utilities
 */
library PositionMath {
    /// @notice Position information
    struct Position {
        address user;
        address poolId;
        uint256 liquidity;
        uint256 timestamp;
        uint256 lastUpdate;
        bool active;
    }

    /// @notice Calculate liquidity change from delta
    function calculateLiquidityChange(BalanceDelta delta) internal pure returns (int256) {
        uint256 delta0 = uint256(int256(delta.amount0()));
        uint256 delta1 = uint256(int256(delta.amount1()));
        
        // Use the larger delta as liquidity change
        return delta0 > delta1 ? int256(delta0) : int256(delta1);
    }

    /// @notice Calculate position value
    function calculatePositionValue(
        Position memory position,
        uint256 price0,
        uint256 price1
    ) internal pure returns (uint256) {
        // Simplified calculation - in practice would use proper price oracles
        return position.liquidity * (price0 + price1) / 2;
    }

    /// @notice Check if position is active
    function isPositionActive(Position memory position) internal view returns (bool) {
        return position.active && position.liquidity > 0;
    }

    /// @notice Calculate position age
    function calculatePositionAge(Position memory position) internal view returns (uint256) {
        return block.timestamp - position.timestamp;
    }

    /// @notice Update position with delta
    function updatePosition(
        Position storage position,
        BalanceDelta delta
    ) internal {
        int256 liquidityChange = calculateLiquidityChange(delta);
        
        if (liquidityChange > 0) {
            position.liquidity += uint256(liquidityChange);
            position.active = true;
        } else if (position.liquidity > uint256(-liquidityChange)) {
            position.liquidity -= uint256(-liquidityChange);
        } else {
            position.liquidity = 0;
            position.active = false;
        }
        
        position.timestamp = block.timestamp;
        position.lastUpdate = block.timestamp;
    }
}
