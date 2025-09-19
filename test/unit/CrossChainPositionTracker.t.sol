// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {CrossChainPositionTracker} from "../../src/tracking/CrossChainPositionTracker.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";

contract CrossChainPositionTrackerTest is Test {
    using PoolIdLibrary for PoolKey;

    CrossChainPositionTracker public tracker;
    IPoolManager public poolManager;
    
    address public user1 = address(0x123);
    address public user2 = address(0x456);
    address public token0 = address(0x789);
    address public token1 = address(0xabc);
    
    PoolKey public poolKey;
    PoolId public poolId;

    function setUp() public {
        poolManager = IPoolManager(address(0x999));
        tracker = new CrossChainPositionTracker();
        
        poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: address(0)
        });
        poolId = poolKey.toId();
    }

    function testUpdatePosition() public {
        BalanceDelta delta = BalanceDelta.wrap(int128(1000), int128(2000));
        
        vm.expectEmit(true, true, false, true);
        emit CrossChainPositionTracker.PositionUpdated(
            user1,
            poolId,
            1000,
            2000,
            block.timestamp
        );

        tracker.updatePosition(user1, poolKey, delta);
        
        (
            uint256 liquidity,
            uint256 timestamp,
            uint256 lastUpdate,
            bool active
        ) = tracker.getUserPosition(user1, poolId);
        
        assertEq(liquidity, 1000);
        assertEq(timestamp, block.timestamp);
        assertEq(lastUpdate, block.timestamp);
        assertTrue(active);
    }

    function testUpdatePositionNegativeDelta() public {
        // First add liquidity
        BalanceDelta delta1 = BalanceDelta.wrap(int128(1000), int128(2000));
        tracker.updatePosition(user1, poolKey, delta1);
        
        // Then remove some
        BalanceDelta delta2 = BalanceDelta.wrap(int128(-500), int128(-1000));
        tracker.updatePosition(user1, poolKey, delta2);
        
        (
            uint256 liquidity,
            uint256 timestamp,
            uint256 lastUpdate,
            bool active
        ) = tracker.getUserPosition(user1, poolId);
        
        assertEq(liquidity, 500);
        assertTrue(active);
    }

    function testUpdatePositionRemoveAll() public {
        // First add liquidity
        BalanceDelta delta1 = BalanceDelta.wrap(int128(1000), int128(2000));
        tracker.updatePosition(user1, poolKey, delta1);
        
        // Then remove all
        BalanceDelta delta2 = BalanceDelta.wrap(int128(-1000), int128(-2000));
        tracker.updatePosition(user1, poolKey, delta2);
        
        (
            uint256 liquidity,
            uint256 timestamp,
            uint256 lastUpdate,
            bool active
        ) = tracker.getUserPosition(user1, poolId);
        
        assertEq(liquidity, 0);
        assertFalse(active);
    }

    function testGetPoolLPs() public {
        // Add positions for two users
        BalanceDelta delta1 = BalanceDelta.wrap(int128(1000), int128(2000));
        tracker.updatePosition(user1, poolKey, delta1);
        
        BalanceDelta delta2 = BalanceDelta.wrap(int128(500), int128(1000));
        tracker.updatePosition(user2, poolKey, delta2);
        
        address[] memory lps = tracker.getPoolLPs(poolId);
        assertEq(lps.length, 2);
        assertTrue(lps[0] == user1 || lps[0] == user2);
        assertTrue(lps[1] == user1 || lps[1] == user2);
        assertTrue(lps[0] != lps[1]);
    }

    function testGetPoolShares() public {
        // Add positions for two users
        BalanceDelta delta1 = BalanceDelta.wrap(int128(1000), int128(2000));
        tracker.updatePosition(user1, poolKey, delta1);
        
        BalanceDelta delta2 = BalanceDelta.wrap(int128(500), int128(1000));
        tracker.updatePosition(user2, poolKey, delta2);
        
        uint256[] memory shares = tracker.getPoolShares(poolId);
        assertEq(shares.length, 2);
        assertTrue(shares[0] == 1000 || shares[0] == 500);
        assertTrue(shares[1] == 1000 || shares[1] == 500);
    }

    function testGetPoolInfo() public {
        BalanceDelta delta = BalanceDelta.wrap(int128(1000), int128(2000));
        tracker.updatePosition(user1, poolKey, delta);
        
        (
            uint256 totalLiquidity,
            uint256 lpCount,
            uint256 lastUpdate,
            bool active
        ) = tracker.getPoolInfo(poolId);
        
        assertEq(totalLiquidity, 1000);
        assertEq(lpCount, 1);
        assertEq(lastUpdate, block.timestamp);
        assertTrue(active);
    }

    function testIsUserLP() public {
        assertFalse(tracker.isUserLP(user1, poolId));
        
        BalanceDelta delta = BalanceDelta.wrap(int128(1000), int128(2000));
        tracker.updatePosition(user1, poolKey, delta);
        
        assertTrue(tracker.isUserLP(user1, poolId));
    }

    function testGetUserActivePositions() public {
        // Create multiple pools
        PoolKey memory poolKey2 = PoolKey({
            currency0: Currency.wrap(address(0xdef)),
            currency1: Currency.wrap(address(0x123)),
            fee: 500,
            tickSpacing: 10,
            hooks: address(0)
        });
        PoolId poolId2 = poolKey2.toId();
        
        // Add positions to both pools
        BalanceDelta delta1 = BalanceDelta.wrap(int128(1000), int128(2000));
        tracker.updatePosition(user1, poolKey, delta1);
        tracker.updatePosition(user1, poolKey2, delta1);
        
        PoolId[] memory positions = tracker.getUserActivePositions(user1);
        assertEq(positions.length, 2);
    }

    function testCrossChainPositionUpdate() public {
        BalanceDelta delta = BalanceDelta.wrap(int128(1000), int128(2000));
        
        vm.expectEmit(true, true, false, true);
        emit CrossChainPositionTracker.CrossChainPositionUpdated(
            user1,
            poolId,
            1000,
            2000,
            1, // sourceChain
            block.timestamp
        );
        
        tracker.updateCrossChainPosition(user1, poolKey, delta, 1);
    }

    function testPoolLPsUpdatedEvent() public {
        BalanceDelta delta = BalanceDelta.wrap(int128(1000), int128(2000));
        
        vm.expectEmit(true, false, false, true);
        emit CrossChainPositionTracker.PoolLPsUpdated(
            poolId,
            1, // lpCount
            block.timestamp
        );
        
        tracker.updatePosition(user1, poolKey, delta);
    }

    function testMultipleUsersSamePool() public {
        BalanceDelta delta1 = BalanceDelta.wrap(int128(1000), int128(2000));
        BalanceDelta delta2 = BalanceDelta.wrap(int128(500), int128(1000));
        
        tracker.updatePosition(user1, poolKey, delta1);
        tracker.updatePosition(user2, poolKey, delta2);
        
        // Check pool info
        (
            uint256 totalLiquidity,
            uint256 lpCount,
            uint256 lastUpdate,
            bool active
        ) = tracker.getPoolInfo(poolId);
        
        assertEq(totalLiquidity, 1500);
        assertEq(lpCount, 2);
        assertTrue(active);
        
        // Check individual positions
        (uint256 liquidity1,,,) = tracker.getUserPosition(user1, poolId);
        (uint256 liquidity2,,,) = tracker.getUserPosition(user2, poolId);
        
        assertEq(liquidity1, 1000);
        assertEq(liquidity2, 500);
    }

    function testUserRemovedFromPool() public {
        // Add position
        BalanceDelta delta1 = BalanceDelta.wrap(int128(1000), int128(2000));
        tracker.updatePosition(user1, poolKey, delta1);
        assertTrue(tracker.isUserLP(user1, poolId));
        
        // Remove all liquidity
        BalanceDelta delta2 = BalanceDelta.wrap(int128(-1000), int128(-2000));
        tracker.updatePosition(user1, poolKey, delta2);
        assertFalse(tracker.isUserLP(user1, poolId));
        
        // Check pool info
        (,, uint256 lpCount,) = tracker.getPoolInfo(poolId);
        assertEq(lpCount, 0);
    }

    function testZeroLiquidityDelta() public {
        BalanceDelta delta = BalanceDelta.wrap(int128(0), int128(0));
        tracker.updatePosition(user1, poolKey, delta);
        
        (uint256 liquidity,,, bool active) = tracker.getUserPosition(user1, poolId);
        assertEq(liquidity, 0);
        assertFalse(active);
    }

    function testLargeLiquidityAmounts() public {
        uint256 largeAmount = 1e18;
        BalanceDelta delta = BalanceDelta.wrap(int128(int256(largeAmount)), int128(int256(largeAmount)));
        
        tracker.updatePosition(user1, poolKey, delta);
        
        (uint256 liquidity,,, bool active) = tracker.getUserPosition(user1, poolId);
        assertEq(liquidity, largeAmount);
        assertTrue(active);
    }
}
