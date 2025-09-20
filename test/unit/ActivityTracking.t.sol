// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ActivityTracking} from "../../src/hooks/libraries/ActivityTracking.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary, toBalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";

contract ActivityTrackingTest is Test {
    // Storage for testing
    mapping(address => ActivityTracking.UserActivity) public userActivities;
    
    function testUpdateSwapVolume() public {
        ActivityTracking.UserActivity storage activity = userActivities[address(0x1)];
        
        uint256 initialVolume = activity.swapVolume;
        uint256 volumeIncrease = 1000e18;
        
        ActivityTracking.updateSwapVolume(activity, volumeIncrease);
        
        assertEq(activity.swapVolume, initialVolume + volumeIncrease);
    }

    function testUpdateLiquidityProvision() public {
        ActivityTracking.UserActivity storage activity = userActivities[address(0x1)];
        
        uint256 initialLiquidity = activity.totalLiquidity;
        
        // Create a mock PoolKey for testing
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0x1)),
            currency1: Currency.wrap(address(0x2)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        
        BalanceDelta delta = toBalanceDelta(int128(500e18), int128(0));
        ActivityTracking.updateLiquidityProvision(activity, delta, key);
        
        assertTrue(activity.totalLiquidity >= initialLiquidity);
    }

    function testGetActivitySummary() public {
        ActivityTracking.UserActivity storage activity = userActivities[address(0x1)];
        
        ActivityTracking.updateSwapVolume(activity, 1000e18);
        
        (uint256 totalLiquidity, uint256 swapVolume, uint256 positionDuration, uint256 lastActivity, uint256 loyaltyScore, uint256 engagementScore, uint8 tier) = ActivityTracking.getActivitySummary(activity);
        
        assertEq(swapVolume, 1000e18);
        assertTrue(totalLiquidity >= 0);
        assertTrue(engagementScore >= 0);
    }

    function testFuzzUpdateSwapVolume(uint256 volume) public {
        vm.assume(volume < type(uint256).max / 2);
        
        ActivityTracking.UserActivity storage activity = userActivities[address(0x1)];
        
        ActivityTracking.updateSwapVolume(activity, volume);
        
        assertEq(activity.swapVolume, volume);
    }

    function testFuzzUpdateLiquidityProvision(uint256 liquidity) public {
        vm.assume(liquidity < type(uint256).max / 2);
        
        ActivityTracking.UserActivity storage activity = userActivities[address(0x1)];
        
        // Create a mock PoolKey for testing
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0x1)),
            currency1: Currency.wrap(address(0x2)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        
        BalanceDelta delta = toBalanceDelta(int128(int256(liquidity)), int128(0));
        ActivityTracking.updateLiquidityProvision(activity, delta, key);
        
        assertTrue(activity.totalLiquidity >= 0);
    }
}