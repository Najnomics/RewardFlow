// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {CrossChainPositionTracker} from "../../src/tracking/CrossChainPositionTracker.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/types/PoolId.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";
import {IPositionTracker} from "../../src/hooks/interfaces/IPositionTracker.sol";
import {toBalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";

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
            hooks: IHooks(address(0))
        });
        PoolId poolId = poolKey.toId();
        
        BalanceDelta delta = toBalanceDelta(amount0, amount1);
        
        tracker.updatePosition(user, poolKey, delta);
        
        IPositionTracker.Position memory position = tracker.getUserPosition(user, poolId);
        uint256 liquidity = position.liquidity;
        uint256 timestamp = position.timestamp;
        uint256 lastUpdate = position.lastUpdate;
        bool active = position.active;
        
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
            hooks: IHooks(address(0))
        });
        PoolId poolId = poolKey.toId();
        
        uint256 expectedTotalLiquidity = 0;
        uint256 expectedLpCount = 0;
        
        for (uint256 i = 0; i < users.length; i++) {
            vm.assume(users[i] != address(0));
            
            BalanceDelta delta = toBalanceDelta(amounts0[i], amounts1[i]);
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
        
        IPositionTracker.PoolInfo memory pool = tracker.getPoolInfo(poolId);
        uint256 totalLiquidity = pool.totalLiquidity;
        uint256 lpCount = pool.lps.length;
        uint256 lastUpdate = pool.lastUpdate;
        bool active = pool.totalLiquidity > 0;
        
        assertEq(totalLiquidity, expectedTotalLiquidity);
        assertEq(lpCount, expectedLpCount);
        assertEq(lastUpdate, block.timestamp);
        assertEq(active, expectedLpCount > 0);
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
            hooks: IHooks(address(0))
        });
        PoolId poolId = poolKey.toId();
        
        // Initially not an LP
        assertFalse(tracker.isUserLP(user, poolId));
        
        // Add position
        BalanceDelta delta = toBalanceDelta(amount0, amount1);
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
            hooks: IHooks(address(0))
        });
        PoolId poolId = poolKey.toId();
        
        uint256 expectedLpCount = 0;
        
        for (uint256 i = 0; i < users.length; i++) {
            vm.assume(users[i] != address(0));
            
            BalanceDelta delta = toBalanceDelta(amounts0[i], amounts1[i]);
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
            hooks: IHooks(address(0))
        });
        PoolId poolId = poolKey.toId();
        
        uint256 expectedLpCount = 0;
        
        for (uint256 i = 0; i < users.length; i++) {
            vm.assume(users[i] != address(0));
            
            BalanceDelta delta = toBalanceDelta(amounts0[i], amounts1[i]);
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
            hooks: IHooks(address(0))
        });
        PoolId poolId = poolKey.toId();
        
        BalanceDelta delta = toBalanceDelta(0, 0);
        tracker.updatePosition(user, poolKey, delta);
        
        IPositionTracker.Position memory position = tracker.getUserPosition(user, poolId);
        uint256 liquidity = position.liquidity;
        bool active = position.active;
        assertEq(liquidity, 0);
        assertFalse(active);
    }

    function testFuzzLargeAmounts(
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
            hooks: IHooks(address(0))
        });
        PoolId poolId = poolKey.toId();
        
        int128 largeAmount = int128(int256(1e18));
        BalanceDelta delta = toBalanceDelta(int128(largeAmount), int128(largeAmount));
        
        tracker.updatePosition(user, poolKey, delta);
        
        IPositionTracker.Position memory position = tracker.getUserPosition(user, poolId);
        uint256 liquidity = position.liquidity;
        bool active = position.active;
        assertEq(liquidity, 1e18);
        assertTrue(active);
    }

    function testFuzzEdgeCaseMaxValues(
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
            hooks: IHooks(address(0))
        });
        PoolId poolId = poolKey.toId();
        
        int128 maxAmount = type(int128).max;
        BalanceDelta delta = toBalanceDelta(int128(maxAmount), int128(maxAmount));
        
        tracker.updatePosition(user, poolKey, delta);
        
        IPositionTracker.Position memory position = tracker.getUserPosition(user, poolId);
        uint256 liquidity = position.liquidity;
        bool active = position.active;
        assertEq(liquidity, uint256(int256(maxAmount)));
        assertTrue(active);
    }

    function testFuzzConsistentState(
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
            hooks: IHooks(address(0))
        });
        PoolId poolId = poolKey.toId();
        
        BalanceDelta delta = toBalanceDelta(amount0, amount1);
        tracker.updatePosition(user, poolKey, delta);
        
        // Get position multiple times - should be consistent
        IPositionTracker.Position memory position1 = tracker.getUserPosition(user, poolId);
        uint256 liquidity1 = position1.liquidity;
        uint256 timestamp1 = position1.timestamp;
        uint256 lastUpdate1 = position1.lastUpdate;
        bool active1 = position1.active;
        
        IPositionTracker.Position memory position2 = tracker.getUserPosition(user, poolId);
        uint256 liquidity2 = position2.liquidity;
        uint256 timestamp2 = position2.timestamp;
        uint256 lastUpdate2 = position2.lastUpdate;
        bool active2 = position2.active;
        
        assertEq(liquidity1, liquidity2);
        assertEq(timestamp1, timestamp2);
        assertEq(lastUpdate1, lastUpdate2);
        assertEq(active1, active2);
    }
}