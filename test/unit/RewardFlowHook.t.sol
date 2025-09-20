// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {TestRewardFlowHook} from "./TestRewardFlowHook.sol";
import {RewardDistributor} from "../../src/distribution/RewardDistributor.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {MockPoolManager} from "../mocks/MockPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/types/PoolId.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/types/PoolOperation.sol";
import {SwapParams} from "@uniswap/v4-core/types/PoolOperation.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/types/BeforeSwapDelta.sol";
import {toBalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {BaseHook} from "v4-periphery/utils/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/libraries/Hooks.sol";
import {TierCalculations} from "../../src/hooks/libraries/TierCalculations.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";
import {Errors} from "../../src/utils/Errors.sol";

contract RewardFlowHookTest is Test {
    using PoolIdLibrary for PoolKey;

    TestRewardFlowHook public hook;
    RewardDistributor public distributor;
    MockPoolManager public poolManager;
    
    address public user = address(0x123);
    address public token0 = address(0x456);
    address public token1 = address(0x789);
    
    PoolKey public poolKey;
    PoolId public poolId;

    function setUp() public {
        poolManager = new MockPoolManager();
        distributor = new RewardDistributor(
            address(0xabc), // reward token
            address(0xdef)  // spoke pool
        );
        
        hook = new TestRewardFlowHook(IPoolManager(address(poolManager)), address(distributor));
        
        poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        poolId = poolKey.toId();
    }

    function testConstructor() public {
        assertEq(address(hook.rewardDistributor()), address(distributor));
        assertEq(address(hook.poolManager()), address(poolManager));
    }

    function testGetPendingRewards() public {
        uint256 rewards = hook.getPendingRewards(user);
        assertEq(rewards, 0);
    }

    function testGetUserTier() public {
        uint8 tier = uint8(hook.getUserTier(user));
        assertEq(tier, uint8(TierCalculations.TierLevel.BRONZE));
    }

    function testBeforeAddLiquidity() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1000,
            salt: 0
        });
        
        bytes4 selector = hook.testBeforeAddLiquidity(user, poolKey, params, "");
        assertEq(selector, BaseHook.beforeAddLiquidity.selector);
    }

    function testAfterAddLiquidity() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1000,
            salt: 0
        });
        
        BalanceDelta delta = toBalanceDelta(int128(1000), int128(2000));
        BalanceDelta feesAccrued = toBalanceDelta(int128(10), int128(20));
        
        (bytes4 selector, BalanceDelta returnDelta) = hook.testAfterAddLiquidity(
            user, poolKey, params, delta, feesAccrued, ""
        );
        
        assertEq(selector, BaseHook.afterAddLiquidity.selector);
    }

    function testBeforeRemoveLiquidity() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: -1000,
            salt: 0
        });
        
        bytes4 selector = hook.testBeforeRemoveLiquidity(user, poolKey, params, "");
        assertEq(selector, BaseHook.beforeRemoveLiquidity.selector);
    }

    function testBeforeSwap() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 1000,
            sqrtPriceLimitX96: 0
        });
        
        (bytes4 selector, BeforeSwapDelta delta, uint24 fee) = hook.testBeforeSwap(
            user, poolKey, params, ""
        );
        
        assertEq(selector, BaseHook.beforeSwap.selector);
        assertEq(uint256(int256(BeforeSwapDeltaLibrary.getSpecifiedDelta(delta))), 0);
        assertEq(uint256(int256(BeforeSwapDeltaLibrary.getUnspecifiedDelta(delta))), 0);
        assertEq(fee, 0);
    }

    function testAfterSwap() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 1000,
            sqrtPriceLimitX96: 0
        });
        
        BalanceDelta delta = toBalanceDelta(int128(100), int128(-200));
        
        (bytes4 selector, int128 returnDelta) = hook.testAfterSwap(
            user, poolKey, params, delta, ""
        );
        
        assertEq(selector, BaseHook.afterSwap.selector);
    }

    function testGetUserActivity() public {
        (
            uint256 totalLiquidity,
            uint256 swapVolume,
            uint256 positionDuration,
            uint256 lastActivity,
            uint256 loyaltyScore,
            uint256 engagementScore,
            uint8 tier
        ) = hook.getUserActivity(user);
        
        assertEq(totalLiquidity, 0);
        assertEq(swapVolume, 0);
        assertEq(positionDuration, 0);
        assertEq(lastActivity, 0);
        assertEq(loyaltyScore, 0);
        assertEq(engagementScore, 0);
        assertEq(tier, 0);
    }

    function testClaimRewards() public {
        // Test that rewards start at 0
        uint256 initialRewards = hook.getPendingRewards(user);
        assertEq(initialRewards, 0);
        
        // Test claiming rewards with insufficient amount (should revert)
        vm.expectRevert(Errors.InsufficientRewardThreshold.selector);
        hook.claimRewards();
        
        // Test that rewards are still 0 after failed claim
        uint256 finalRewards = hook.getPendingRewards(user);
        assertEq(finalRewards, 0);
    }

    function testGetHookPermissions() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertTrue(permissions.beforeAddLiquidity);
        assertTrue(permissions.afterAddLiquidity);
        assertTrue(permissions.beforeRemoveLiquidity);
        assertTrue(permissions.beforeSwap);
        assertTrue(permissions.afterSwap);
    }

    function testPoolTotalLiquidity() public {
        uint256 totalLiquidity = hook.poolTotalLiquidity(poolId);
        assertEq(totalLiquidity, 0);
    }

    function testLPLiquidityPositions() public {
        uint256 liquidity = hook.lpLiquidityPositions(poolId, user);
        assertEq(liquidity, 0);
    }

    function testTotalRewardsDistributed() public {
        uint256 totalRewards = hook.totalRewardsDistributed();
        assertEq(totalRewards, 0);
    }

    function testTotalMEVCaptured() public {
        uint256 totalMEV = hook.totalMEVCaptured();
        assertEq(totalMEV, 0);
    }
}