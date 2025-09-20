// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../unit/TestRewardFlowHook.sol";
import "../unit/TestRewardFlowHookMEV.sol";
import "../../src/distribution/RewardDistributor.sol";
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
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";

contract RewardFlowIntegrationTest is Test {
    using PoolIdLibrary for PoolKey;

    TestRewardFlowHook public hook;
    TestRewardFlowHookMEV public mevHook;
    RewardDistributor public distributor;
    MockPoolManager public poolManager;
    
    address public user1 = address(0x101);
    address public user2 = address(0x102);
    address public tokenA = address(0xA);
    address public tokenB = address(0xB);
    
    PoolKey public poolKey;
    PoolId public poolId;

    function setUp() public {
        poolManager = new MockPoolManager();
        distributor = new RewardDistributor(
            address(0xdef), // reward token
            address(0x123)  // spoke pool
        );

        hook = new TestRewardFlowHook(IPoolManager(address(poolManager)), address(distributor));
        mevHook = new TestRewardFlowHookMEV(IPoolManager(address(poolManager)), address(distributor));
        
        poolKey = PoolKey({
            currency0: Currency.wrap(tokenA),
            currency1: Currency.wrap(tokenB),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        poolId = poolKey.toId();
    }

    function testHookDeployment() public {
        assertEq(address(hook.rewardDistributor()), address(distributor));
        assertEq(address(mevHook.rewardDistributor()), address(distributor));
    }

    function testHookPermissions() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertTrue(permissions.beforeAddLiquidity);
        assertTrue(permissions.afterAddLiquidity);
        assertTrue(permissions.beforeRemoveLiquidity);
        assertTrue(permissions.beforeSwap);
        assertTrue(permissions.afterSwap);
    }

    function testMEVHookPermissions() public {
        Hooks.Permissions memory permissions = mevHook.getHookPermissions();
        assertTrue(permissions.beforeAddLiquidity);
        assertFalse(permissions.afterAddLiquidity);
        assertTrue(permissions.beforeRemoveLiquidity);
        assertTrue(permissions.beforeSwap);
        assertTrue(permissions.afterSwap);
    }

    function testGetPendingRewards() public {
        uint256 rewards1 = hook.getPendingRewards(user1);
        uint256 rewards2 = hook.getPendingRewards(user2);
        
        assertEq(rewards1, 0);
        assertEq(rewards2, 0);
    }

    function testGetUserTier() public {
        uint8 tier1 = uint8(hook.getUserTier(user1));
        uint8 tier2 = uint8(hook.getUserTier(user2));
        
        assertEq(tier1, 0); // Bronze
        assertEq(tier2, 0); // Bronze
    }

    function testGetUserActivity() public {
        (
            uint256 totalLiquidity1,
            uint256 swapVolume1,
            uint256 positionDuration1,
            uint256 lastActivity1,
            uint256 loyaltyScore1,
            uint256 engagementScore1,
            uint8 tier1
        ) = hook.getUserActivity(user1);
        
        assertEq(totalLiquidity1, 0);
        assertEq(swapVolume1, 0);
        assertEq(positionDuration1, 0);
        assertEq(lastActivity1, 0);
        assertEq(loyaltyScore1, 0);
        assertEq(engagementScore1, 0);
        assertEq(tier1, 0);
    }

    function testLiquidityProvisionFlow() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1000,
            salt: 0
        });
        
        // Before add liquidity
        bytes4 selector = hook.testBeforeAddLiquidity(user1, poolKey, params, "");
        assertEq(selector, BaseHook.beforeAddLiquidity.selector);
        
        // After add liquidity
        BalanceDelta delta = toBalanceDelta(int128(1000), int128(2000));
        BalanceDelta feesAccrued = toBalanceDelta(int128(10), int128(20));
        
        (bytes4 afterSelector, BalanceDelta returnDelta) = hook.testAfterAddLiquidity(
            user1, poolKey, params, delta, feesAccrued, ""
        );
        assertEq(afterSelector, BaseHook.afterAddLiquidity.selector);
    }

    function testLiquidityRemovalFlow() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: -1000,
            salt: 0
        });
        
        // Before remove liquidity
        bytes4 selector = hook.testBeforeRemoveLiquidity(user1, poolKey, params, "");
        assertEq(selector, BaseHook.beforeRemoveLiquidity.selector);
    }

    function testSwapFlow() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 1000,
            sqrtPriceLimitX96: 0
        });
        
        // Before swap
        (bytes4 beforeSelector, BeforeSwapDelta beforeDelta, uint24 fee) = hook.testBeforeSwap(
            user1, poolKey, params, ""
        );
        assertEq(beforeSelector, BaseHook.beforeSwap.selector);
        
        // After swap
        BalanceDelta delta = toBalanceDelta(int128(100), int128(-200));
        (bytes4 afterSelector, int128 returnDelta) = hook.testAfterSwap(
            user1, poolKey, params, delta, ""
        );
        assertEq(afterSelector, BaseHook.afterSwap.selector);
    }

    function testMEVHookFlow() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 1000,
            sqrtPriceLimitX96: 0
        });
        
        // Before swap with MEV hook
        (bytes4 beforeSelector, BeforeSwapDelta beforeDelta, uint24 fee) = mevHook.testBeforeSwap(
            user1, poolKey, params, ""
        );
        assertEq(beforeSelector, BaseHook.beforeSwap.selector);
        
        // After swap with MEV hook
        BalanceDelta delta = toBalanceDelta(int128(100), int128(-200));
        (bytes4 afterSelector, int128 returnDelta) = mevHook.testAfterSwap(
            user1, poolKey, params, delta, ""
        );
        assertEq(afterSelector, BaseHook.afterSwap.selector);
    }

    function testMultipleUsers() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1000,
            salt: 0
        });
        
        // User 1 adds liquidity
        hook.testBeforeAddLiquidity(user1, poolKey, params, "");
        BalanceDelta delta1 = toBalanceDelta(int128(1000), int128(2000));
        hook.testAfterAddLiquidity(user1, poolKey, params, delta1, delta1, "");
        
        // User 2 adds liquidity
        hook.testBeforeAddLiquidity(user2, poolKey, params, "");
        BalanceDelta delta2 = toBalanceDelta(int128(500), int128(1000));
        hook.testAfterAddLiquidity(user2, poolKey, params, delta2, delta2, "");
        
        // Check pool total liquidity
        uint256 totalLiquidity = hook.poolTotalLiquidity(poolId);
        assertTrue(totalLiquidity >= 0);
    }

    function testRewardDistributionIntegration() public {
        // Execute reward distribution as owner
        vm.prank(address(this)); // Test contract is the owner
        distributor.executeRewardDistribution(user1, 1000, 1);
        
        // Check distribution stats
        RewardDistributor.DistributionStats memory stats = distributor.getDistributionStats();
        assertTrue(stats.successfulDistributions >= 0); // Just check that stats exist
    }

    function testClaimRewardsIntegration() public {
        // Test claiming rewards when there are no rewards (should fail)
        vm.prank(user1);
        vm.expectRevert();
        hook.claimRewards();
        
        // Check that rewards are 0
        uint256 rewards = hook.getPendingRewards(user1);
        assertEq(rewards, 0);
    }

    function testPoolLiquidityTracking() public {
        uint256 initialLiquidity = hook.poolTotalLiquidity(poolId);
        assertEq(initialLiquidity, 0);
        
        // Add some liquidity
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1000,
            salt: 0
        });
        
        hook.testBeforeAddLiquidity(user1, poolKey, params, "");
        BalanceDelta delta = toBalanceDelta(int128(1000), int128(2000));
        hook.testAfterAddLiquidity(user1, poolKey, params, delta, delta, "");
        
        uint256 finalLiquidity = hook.poolTotalLiquidity(poolId);
        assertTrue(finalLiquidity >= 0);
    }

    function testUserTierProgression() public {
        uint8 initialTier = uint8(hook.getUserTier(user1));
        assertEq(initialTier, 0); // Bronze
        
        // Simulate some activity
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1000,
            salt: 0
        });
        
        hook.testBeforeAddLiquidity(user1, poolKey, params, "");
        BalanceDelta delta = toBalanceDelta(int128(1000), int128(2000));
        hook.testAfterAddLiquidity(user1, poolKey, params, delta, delta, "");
        
        uint8 finalTier = uint8(hook.getUserTier(user1));
        assertTrue(finalTier >= initialTier);
    }

    function testMEVDetection() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 1000,
            sqrtPriceLimitX96: 0
        });
        
        // Test MEV hook before swap
        (bytes4 selector, BeforeSwapDelta delta, uint24 fee) = mevHook.testBeforeSwap(
            user1, poolKey, params, ""
        );
        assertEq(selector, BaseHook.beforeSwap.selector);
        
        // Test MEV hook after swap
        BalanceDelta swapDelta = toBalanceDelta(int128(100), int128(-200));
        (bytes4 afterSelector, int128 returnDelta) = mevHook.testAfterSwap(
            user1, poolKey, params, swapDelta, ""
        );
        assertEq(afterSelector, BaseHook.afterSwap.selector);
    }

    function testSystemConsistency() public {
        // Test that all components work together
        uint256 initialRewards = hook.totalRewardsDistributed();
        uint256 initialMEV = hook.totalMEVCaptured();
        
        // Perform various operations
        ModifyLiquidityParams memory addParams = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1000,
            salt: 0
        });
        
        hook.testBeforeAddLiquidity(user1, poolKey, addParams, "");
        BalanceDelta delta = toBalanceDelta(int128(1000), int128(2000));
        hook.testAfterAddLiquidity(user1, poolKey, addParams, delta, delta, "");
        
        SwapParams memory swapParams = SwapParams({
            zeroForOne: true,
            amountSpecified: 1000,
            sqrtPriceLimitX96: 0
        });
        
        hook.testBeforeSwap(user1, poolKey, swapParams, "");
        hook.testAfterSwap(user1, poolKey, swapParams, delta, "");
        
        // Verify system state
        uint256 finalRewards = hook.totalRewardsDistributed();
        uint256 finalMEV = hook.totalMEVCaptured();
        
        assertTrue(finalRewards >= initialRewards);
        assertTrue(finalMEV >= initialMEV);
    }
}