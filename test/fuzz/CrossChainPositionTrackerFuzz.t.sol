// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {CrossChainPositionTracker} from "../../src/tracking/CrossChainPositionTracker.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/types/PoolId.sol";

contract CrossChainPositionTrackerFuzzTest is Test {
    using PoolIdLibrary for PoolKey;

    CrossChainPositionTracker public tracker;
    
    function setUp() public {
        tracker = new CrossChainPositionTracker();
    }

    function testFuzzUpdatePosition(
        address user,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing,
        int128 amount0,
        int128 amount1
    ) public {
        vm.assume(user != address(0));
        vm.assume(token0 != address(0));
        vm.assume(token1 != address(0));
        vm.assume(token0 != token1);
        vm.assume(fee > 0 && fee <= 1000000);
        vm.assume(tickSpacing > 0 && tickSpacing <= 1000);
        
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: address(0)
        });
        PoolId poolId = poolKey.toId();
        
        BalanceDelta delta = BalanceDelta.wrap(amount0, amount1);
        
        tracker.updatePosition(user, poolKey, delta);
        
        (
            uint256 liquidity,
            uint256 timestamp,
            uint256 lastUpdate,
            bool active
        ) = tracker.getUserPosition(user, poolId);
        
        // Calculate expected liquidity (simplified)
        uint256 expectedLiquidity = amount0 > 0 ? uint256(int256(amount0)) : 0;
        if (amount1 > amount0) {
            expectedLiquidity = uint256(int256(amount1));
        }
        
        assertEq(liquidity, expectedLiquidity);
        assertEq(timestamp, block.timestamp);
        assertEq(lastUpdate, block.timestamp);
        assertEq(active, expectedLiquidity > 0);
    }

    function testFuzzMultipleUsersSamePool(
        address[] memory users,
        int128[] memory amounts0,
        int128[] memory amounts1
    ) public {
        vm.assume(users.length > 0 && users.length <= 10);
        vm.assume(users.length == amounts0.length);
        vm.assume(users.length == amounts1.length);
        
        address token0 = address(0x123);
        address token1 = address(0x456);
        
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: address(0)
        });
        PoolId poolId = poolKey.toId();
        
        uint256 expectedTotalLiquidity = 0;
        uint256 expectedLpCount = 0;
        
        for (uint256 i = 0; i < users.length; i++) {
            vm.assume(users[i] != address(0));
            
            BalanceDelta delta = BalanceDelta.wrap(amounts0[i], amounts1[i]);
            tracker.updatePosition(users[i], poolKey, delta);
            
            uint256 liquidity = amounts0[i] > 0 ? uint256(int256(amounts0[i])) : 0;
            if (amounts1[i] > amounts0[i]) {
                liquidity = uint256(int256(amounts1[i]));
            }
            
            if (liquidity > 0) {
                expectedTotalLiquidity += liquidity;
                expectedLpCount++;
            }
        }
        
        (
            uint256 totalLiquidity,
            uint256 lpCount,
            uint256 lastUpdate,
            bool active
        ) = tracker.getPoolInfo(poolId);
        
        assertEq(totalLiquidity, expectedTotalLiquidity);
        assertEq(lpCount, expectedLpCount);
        assertEq(lastUpdate, block.timestamp);
        assertEq(active, expectedLpCount > 0);
    }

    function testFuzzMultiplePoolsSameUser(
        address user,
        address[] memory tokens0,
        address[] memory tokens1,
        int128[] memory amounts0,
        int128[] memory amounts1
    ) public {
        vm.assume(user != address(0));
        vm.assume(tokens0.length > 0 && tokens0.length <= 5);
        vm.assume(tokens0.length == tokens1.length);
        vm.assume(tokens0.length == amounts0.length);
        vm.assume(tokens0.length == amounts1.length);
        
        for (uint256 i = 0; i < tokens0.length; i++) {
            vm.assume(tokens0[i] != address(0));
            vm.assume(tokens1[i] != address(0));
            vm.assume(tokens0[i] != tokens1[i]);
            
            PoolKey memory poolKey = PoolKey({
                currency0: Currency.wrap(tokens0[i]),
                currency1: Currency.wrap(tokens1[i]),
                fee: uint24(3000 + i * 1000),
                tickSpacing: int24(60 + i * 10),
                hooks: address(0)
            });
            PoolId poolId = poolKey.toId();
            
            BalanceDelta delta = BalanceDelta.wrap(amounts0[i], amounts1[i]);
            tracker.updatePosition(user, poolKey, delta);
            
            (
                uint256 liquidity,
                uint256 timestamp,
                uint256 lastUpdate,
                bool active
            ) = tracker.getUserPosition(user, poolId);
            
            uint256 expectedLiquidity = amounts0[i] > 0 ? uint256(int256(amounts0[i])) : 0;
            if (amounts1[i] > amounts0[i]) {
                expectedLiquidity = uint256(int256(amounts1[i]));
            }
            
            assertEq(liquidity, expectedLiquidity);
            assertEq(timestamp, block.timestamp);
            assertEq(lastUpdate, block.timestamp);
            assertEq(active, expectedLiquidity > 0);
        }
        
        PoolId[] memory positions = tracker.getUserActivePositions(user);
        assertLe(positions.length, tokens0.length);
    }

    function testFuzzAddRemoveLiquidity(
        address user,
        address token0,
        address token1,
        int128 addAmount0,
        int128 addAmount1,
        int128 removeAmount0,
        int128 removeAmount1
    ) public {
        vm.assume(user != address(0));
        vm.assume(token0 != address(0));
        vm.assume(token1 != address(0));
        vm.assume(token0 != token1);
        vm.assume(addAmount0 > 0);
        vm.assume(addAmount1 > 0);
        vm.assume(removeAmount0 <= 0);
        vm.assume(removeAmount1 <= 0);
        
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: address(0)
        });
        PoolId poolId = poolKey.toId();
        
        // Add liquidity
        BalanceDelta addDelta = BalanceDelta.wrap(addAmount0, addAmount1);
        tracker.updatePosition(user, poolKey, addDelta);
        
        uint256 expectedLiquidity = uint256(int256(addAmount0));
        if (addAmount1 > addAmount0) {
            expectedLiquidity = uint256(int256(addAmount1));
        }
        
        (uint256 liquidity,,, bool active) = tracker.getUserPosition(user, poolId);
        assertEq(liquidity, expectedLiquidity);
        assertTrue(active);
        
        // Remove liquidity
        BalanceDelta removeDelta = BalanceDelta.wrap(removeAmount0, removeAmount1);
        tracker.updatePosition(user, poolKey, removeDelta);
        
        uint256 removeLiquidity = uint256(int256(-removeAmount0));
        if (-removeAmount1 > -removeAmount0) {
            removeLiquidity = uint256(int256(-removeAmount1));
        }
        
        uint256 finalExpectedLiquidity = expectedLiquidity > removeLiquidity ? expectedLiquidity - removeLiquidity : 0;
        
        (liquidity,,, active) = tracker.getUserPosition(user, poolId);
        assertEq(liquidity, finalExpectedLiquidity);
        assertEq(active, finalExpectedLiquidity > 0);
    }

    function testFuzzCrossChainPositionUpdate(
        address user,
        address token0,
        address token1,
        int128 amount0,
        int128 amount1,
        uint256 sourceChain
    ) public {
        vm.assume(user != address(0));
        vm.assume(token0 != address(0));
        vm.assume(token1 != address(0));
        vm.assume(token0 != token1);
        vm.assume(sourceChain > 0);
        
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: address(0)
        });
        PoolId poolId = poolKey.toId();
        
        BalanceDelta delta = BalanceDelta.wrap(amount0, amount1);
        
        tracker.updateCrossChainPosition(user, poolKey, delta, sourceChain);
        
        (
            uint256 liquidity,
            uint256 timestamp,
            uint256 lastUpdate,
            bool active
        ) = tracker.getUserPosition(user, poolId);
        
        uint256 expectedLiquidity = amount0 > 0 ? uint256(int256(amount0)) : 0;
        if (amount1 > amount0) {
            expectedLiquidity = uint256(int256(amount1));
        }
        
        assertEq(liquidity, expectedLiquidity);
        assertEq(timestamp, block.timestamp);
        assertEq(lastUpdate, block.timestamp);
        assertEq(active, expectedLiquidity > 0);
    }

    function testFuzzIsUserLP(
        address user,
        address token0,
        address token1,
        int128 amount0,
        int128 amount1
    ) public {
        vm.assume(user != address(0));
        vm.assume(token0 != address(0));
        vm.assume(token1 != address(0));
        vm.assume(token0 != token1);
        
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: address(0)
        });
        PoolId poolId = poolKey.toId();
        
        // Initially not an LP
        assertFalse(tracker.isUserLP(user, poolId));
        
        // Add position
        BalanceDelta delta = BalanceDelta.wrap(amount0, amount1);
        tracker.updatePosition(user, poolKey, delta);
        
        uint256 expectedLiquidity = amount0 > 0 ? uint256(int256(amount0)) : 0;
        if (amount1 > amount0) {
            expectedLiquidity = uint256(int256(amount1));
        }
        
        assertEq(tracker.isUserLP(user, poolId), expectedLiquidity > 0);
    }

    function testFuzzGetPoolLPs(
        address[] memory users,
        int128[] memory amounts0,
        int128[] memory amounts1
    ) public {
        vm.assume(users.length > 0 && users.length <= 10);
        vm.assume(users.length == amounts0.length);
        vm.assume(users.length == amounts1.length);
        
        address token0 = address(0x123);
        address token1 = address(0x456);
        
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: address(0)
        });
        PoolId poolId = poolKey.toId();
        
        uint256 expectedLpCount = 0;
        
        for (uint256 i = 0; i < users.length; i++) {
            vm.assume(users[i] != address(0));
            
            BalanceDelta delta = BalanceDelta.wrap(amounts0[i], amounts1[i]);
            tracker.updatePosition(users[i], poolKey, delta);
            
            uint256 liquidity = amounts0[i] > 0 ? uint256(int256(amounts0[i])) : 0;
            if (amounts1[i] > amounts0[i]) {
                liquidity = uint256(int256(amounts1[i]));
            }
            
            if (liquidity > 0) {
                expectedLpCount++;
            }
        }
        
        address[] memory lps = tracker.getPoolLPs(poolId);
        assertEq(lps.length, expectedLpCount);
    }

    function testFuzzGetPoolShares(
        address[] memory users,
        int128[] memory amounts0,
        int128[] memory amounts1
    ) public {
        vm.assume(users.length > 0 && users.length <= 10);
        vm.assume(users.length == amounts0.length);
        vm.assume(users.length == amounts1.length);
        
        address token0 = address(0x123);
        address token1 = address(0x456);
        
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: address(0)
        });
        PoolId poolId = poolKey.toId();
        
        uint256 expectedLpCount = 0;
        
        for (uint256 i = 0; i < users.length; i++) {
            vm.assume(users[i] != address(0));
            
            BalanceDelta delta = BalanceDelta.wrap(amounts0[i], amounts1[i]);
            tracker.updatePosition(users[i], poolKey, delta);
            
            uint256 liquidity = amounts0[i] > 0 ? uint256(int256(amounts0[i])) : 0;
            if (amounts1[i] > amounts0[i]) {
                liquidity = uint256(int256(amounts1[i]));
            }
            
            if (liquidity > 0) {
                expectedLpCount++;
            }
        }
        
        uint256[] memory shares = tracker.getPoolShares(poolId);
        assertEq(shares.length, expectedLpCount);
    }

    function testFuzzZeroAmounts(
        address user,
        address token0,
        address token1
    ) public {
        vm.assume(user != address(0));
        vm.assume(token0 != address(0));
        vm.assume(token1 != address(0));
        vm.assume(token0 != token1);
        
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: address(0)
        });
        PoolId poolId = poolKey.toId();
        
        BalanceDelta delta = BalanceDelta.wrap(0, 0);
        tracker.updatePosition(user, poolKey, delta);
        
        (uint256 liquidity,,, bool active) = tracker.getUserPosition(user, poolId);
        assertEq(liquidity, 0);
        assertFalse(active);
    }
}
