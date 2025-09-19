// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ActivityTracking} from "../../src/hooks/libraries/ActivityTracking.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/types/PoolId.sol";

contract ActivityTrackingTest is Test {
    using PoolIdLibrary for PoolKey;
    using ActivityTracking for mapping(address => ActivityTracking.UserActivity);

    mapping(address => ActivityTracking.UserActivity) public userActivity;
    
    address public user = address(0x123);
    address public token0 = address(0x456);
    address public token1 = address(0x789);
    
    PoolKey public poolKey;
    PoolId public poolId;

    function setUp() public {
        poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: address(0)
        });
        poolId = poolKey.toId();
    }

    function testUpdateLiquidityProvision() public {
        BalanceDelta delta = BalanceDelta.wrap(int128(1000), int128(2000));
        
        ActivityTracking.updateLiquidityProvision(userActivity[user], delta, poolKey);
        
        (
            uint256 totalLiquidity,
            uint256 swapVolume,
            uint256 positionDuration,
            uint256 lastActivity,
            uint256 loyaltyScore,
            uint256 engagementScore,
            uint8 tier
        ) = ActivityTracking.getActivitySummary(userActivity[user]);
        
        assertEq(totalLiquidity, 1000);
        assertEq(swapVolume, 0);
        assertEq(positionDuration, 0);
        assertEq(lastActivity, block.timestamp);
        assertEq(loyaltyScore, 0);
        assertEq(engagementScore, 0);
        assertEq(tier, 0);
    }

    function testUpdateSwapVolume() public {
        uint256 swapVolume = 5000;
        
        ActivityTracking.updateSwapVolume(userActivity[user], swapVolume);
        
        (
            uint256 totalLiquidity,
            uint256 actualSwapVolume,
            uint256 positionDuration,
            uint256 lastActivity,
            uint256 loyaltyScore,
            uint256 engagementScore,
            uint8 tier
        ) = ActivityTracking.getActivitySummary(userActivity[user]);
        
        assertEq(totalLiquidity, 0);
        assertEq(actualSwapVolume, swapVolume);
        assertEq(positionDuration, 0);
        assertEq(lastActivity, block.timestamp);
        assertEq(loyaltyScore, 0);
        assertEq(engagementScore, 0);
        assertEq(tier, 0);
    }

    function testMultipleUpdates() public {
        BalanceDelta delta1 = BalanceDelta.wrap(int128(1000), int128(2000));
        ActivityTracking.updateLiquidityProvision(userActivity[user], delta1, poolKey);
        
        uint256 swapVolume1 = 3000;
        ActivityTracking.updateSwapVolume(userActivity[user], swapVolume1);
        
        BalanceDelta delta2 = BalanceDelta.wrap(int128(500), int128(1000));
        ActivityTracking.updateLiquidityProvision(userActivity[user], delta2, poolKey);
        
        uint256 swapVolume2 = 2000;
        ActivityTracking.updateSwapVolume(userActivity[user], swapVolume2);
        
        (
            uint256 totalLiquidity,
            uint256 totalSwapVolume,
            uint256 positionDuration,
            uint256 lastActivity,
            uint256 loyaltyScore,
            uint256 engagementScore,
            uint8 tier
        ) = ActivityTracking.getActivitySummary(userActivity[user]);
        
        assertEq(totalLiquidity, 1500); // 1000 + 500
        assertEq(totalSwapVolume, 5000); // 3000 + 2000
        assertEq(positionDuration, 0);
        assertEq(lastActivity, block.timestamp);
        assertEq(loyaltyScore, 0);
        assertEq(engagementScore, 0);
        assertEq(tier, 0);
    }

    function testZeroAmounts() public {
        BalanceDelta delta = BalanceDelta.wrap(0, 0);
        ActivityTracking.updateLiquidityProvision(userActivity[user], delta, poolKey);
        
        ActivityTracking.updateSwapVolume(userActivity[user], 0);
        
        (
            uint256 totalLiquidity,
            uint256 swapVolume,
            uint256 positionDuration,
            uint256 lastActivity,
            uint256 loyaltyScore,
            uint256 engagementScore,
            uint8 tier
        ) = ActivityTracking.getActivitySummary(userActivity[user]);
        
        assertEq(totalLiquidity, 0);
        assertEq(swapVolume, 0);
        assertEq(positionDuration, 0);
        assertEq(lastActivity, block.timestamp);
        assertEq(loyaltyScore, 0);
        assertEq(engagementScore, 0);
        assertEq(tier, 0);
    }

    function testLargeAmounts() public {
        uint256 largeAmount = 1e18;
        BalanceDelta delta = BalanceDelta.wrap(int128(int256(largeAmount)), int128(int256(largeAmount)));
        
        ActivityTracking.updateLiquidityProvision(userActivity[user], delta, poolKey);
        
        ActivityTracking.updateSwapVolume(userActivity[user], largeAmount);
        
        (
            uint256 totalLiquidity,
            uint256 swapVolume,
            uint256 positionDuration,
            uint256 lastActivity,
            uint256 loyaltyScore,
            uint256 engagementScore,
            uint8 tier
        ) = ActivityTracking.getActivitySummary(userActivity[user]);
        
        assertEq(totalLiquidity, largeAmount);
        assertEq(swapVolume, largeAmount);
        assertEq(positionDuration, 0);
        assertEq(lastActivity, block.timestamp);
        assertEq(loyaltyScore, 0);
        assertEq(engagementScore, 0);
        assertEq(tier, 0);
    }

    function testNegativeDelta() public {
        BalanceDelta delta = BalanceDelta.wrap(int128(-1000), int128(-2000));
        
        ActivityTracking.updateLiquidityProvision(userActivity[user], delta, poolKey);
        
        (
            uint256 totalLiquidity,
            uint256 swapVolume,
            uint256 positionDuration,
            uint256 lastActivity,
            uint256 loyaltyScore,
            uint256 engagementScore,
            uint8 tier
        ) = ActivityTracking.getActivitySummary(userActivity[user]);
        
        assertEq(totalLiquidity, 0); // Should not go negative
        assertEq(swapVolume, 0);
        assertEq(positionDuration, 0);
        assertEq(lastActivity, block.timestamp);
        assertEq(loyaltyScore, 0);
        assertEq(engagementScore, 0);
        assertEq(tier, 0);
    }

    function testMultipleUsers() public {
        address user2 = address(0x456);
        
        BalanceDelta delta1 = BalanceDelta.wrap(int128(1000), int128(2000));
        ActivityTracking.updateLiquidityProvision(userActivity[user], delta1, poolKey);
        
        BalanceDelta delta2 = BalanceDelta.wrap(int128(500), int128(1000));
        ActivityTracking.updateLiquidityProvision(userActivity[user2], delta2, poolKey);
        
        (
            uint256 liquidity1,
            uint256 swapVolume1,
            uint256 positionDuration1,
            uint256 lastActivity1,
            uint256 loyaltyScore1,
            uint256 engagementScore1,
            uint8 tier1
        ) = ActivityTracking.getActivitySummary(userActivity[user]);
        
        (
            uint256 liquidity2,
            uint256 swapVolume2,
            uint256 positionDuration2,
            uint256 lastActivity2,
            uint256 loyaltyScore2,
            uint256 engagementScore2,
            uint8 tier2
        ) = ActivityTracking.getActivitySummary(userActivity[user2]);
        
        assertEq(liquidity1, 1000);
        assertEq(liquidity2, 500);
        assertEq(swapVolume1, 0);
        assertEq(swapVolume2, 0);
        assertEq(tier1, 0);
        assertEq(tier2, 0);
    }

    function testMultiplePools() public {
        PoolKey memory poolKey2 = PoolKey({
            currency0: Currency.wrap(address(0xdef)),
            currency1: Currency.wrap(address(0x123)),
            fee: 500,
            tickSpacing: 10,
            hooks: address(0)
        });
        PoolId poolId2 = poolKey2.toId();
        
        BalanceDelta delta1 = BalanceDelta.wrap(int128(1000), int128(2000));
        ActivityTracking.updateLiquidityProvision(userActivity[user], delta1, poolKey);
        
        BalanceDelta delta2 = BalanceDelta.wrap(int128(500), int128(1000));
        ActivityTracking.updateLiquidityProvision(userActivity[user], delta2, poolKey2);
        
        (
            uint256 totalLiquidity,
            uint256 swapVolume,
            uint256 positionDuration,
            uint256 lastActivity,
            uint256 loyaltyScore,
            uint256 engagementScore,
            uint8 tier
        ) = ActivityTracking.getActivitySummary(userActivity[user]);
        
        assertEq(totalLiquidity, 1500); // 1000 + 500
        assertEq(swapVolume, 0);
        assertEq(positionDuration, 0);
        assertEq(lastActivity, block.timestamp);
        assertEq(loyaltyScore, 0);
        assertEq(engagementScore, 0);
        assertEq(tier, 0);
    }

    function testTimeProgression() public {
        BalanceDelta delta = BalanceDelta.wrap(int128(1000), int128(2000));
        ActivityTracking.updateLiquidityProvision(userActivity[user], delta, poolKey);
        
        uint256 firstTimestamp = block.timestamp;
        
        // Advance time
        vm.warp(block.timestamp + 3600); // 1 hour
        
        uint256 swapVolume = 3000;
        ActivityTracking.updateSwapVolume(userActivity[user], swapVolume);
        
        (
            uint256 totalLiquidity,
            uint256 actualSwapVolume,
            uint256 positionDuration,
            uint256 lastActivity,
            uint256 loyaltyScore,
            uint256 engagementScore,
            uint8 tier
        ) = ActivityTracking.getActivitySummary(userActivity[user]);
        
        assertEq(totalLiquidity, 1000);
        assertEq(actualSwapVolume, swapVolume);
        assertEq(positionDuration, 0);
        assertEq(lastActivity, firstTimestamp + 3600);
        assertEq(loyaltyScore, 0);
        assertEq(engagementScore, 0);
        assertEq(tier, 0);
    }

    function testEdgeCaseMaxValues() public {
        uint256 maxAmount = type(uint256).max;
        BalanceDelta delta = BalanceDelta.wrap(int128(int256(maxAmount)), int128(int256(maxAmount)));
        
        ActivityTracking.updateLiquidityProvision(userActivity[user], delta, poolKey);
        
        ActivityTracking.updateSwapVolume(userActivity[user], maxAmount);
        
        (
            uint256 totalLiquidity,
            uint256 swapVolume,
            uint256 positionDuration,
            uint256 lastActivity,
            uint256 loyaltyScore,
            uint256 engagementScore,
            uint8 tier
        ) = ActivityTracking.getActivitySummary(userActivity[user]);
        
        assertEq(totalLiquidity, maxAmount);
        assertEq(swapVolume, maxAmount);
        assertEq(positionDuration, 0);
        assertEq(lastActivity, block.timestamp);
        assertEq(loyaltyScore, 0);
        assertEq(engagementScore, 0);
        assertEq(tier, 0);
    }

    function testEmptyUserActivity() public {
        (
            uint256 totalLiquidity,
            uint256 swapVolume,
            uint256 positionDuration,
            uint256 lastActivity,
            uint256 loyaltyScore,
            uint256 engagementScore,
            uint8 tier
        ) = ActivityTracking.getActivitySummary(userActivity[user]);
        
        assertEq(totalLiquidity, 0);
        assertEq(swapVolume, 0);
        assertEq(positionDuration, 0);
        assertEq(lastActivity, 0);
        assertEq(loyaltyScore, 0);
        assertEq(engagementScore, 0);
        assertEq(tier, 0);
    }

    function testConsistentState() public {
        BalanceDelta delta = BalanceDelta.wrap(int128(1000), int128(2000));
        ActivityTracking.updateLiquidityProvision(userActivity[user], delta, poolKey);
        
        uint256 swapVolume = 3000;
        ActivityTracking.updateSwapVolume(userActivity[user], swapVolume);
        
        // Get summary multiple times - should be consistent
        (
            uint256 totalLiquidity1,
            uint256 swapVolume1,
            uint256 positionDuration1,
            uint256 lastActivity1,
            uint256 loyaltyScore1,
            uint256 engagementScore1,
            uint8 tier1
        ) = ActivityTracking.getActivitySummary(userActivity[user]);
        
        (
            uint256 totalLiquidity2,
            uint256 swapVolume2,
            uint256 positionDuration2,
            uint256 lastActivity2,
            uint256 loyaltyScore2,
            uint256 engagementScore2,
            uint8 tier2
        ) = ActivityTracking.getActivitySummary(userActivity[user]);
        
        assertEq(totalLiquidity1, totalLiquidity2);
        assertEq(swapVolume1, swapVolume2);
        assertEq(positionDuration1, positionDuration2);
        assertEq(lastActivity1, lastActivity2);
        assertEq(loyaltyScore1, loyaltyScore2);
        assertEq(engagementScore1, engagementScore2);
        assertEq(tier1, tier2);
    }
}
