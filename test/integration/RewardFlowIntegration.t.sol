// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RewardFlowHook} from "../../src/hooks/RewardFlowHook.sol";
import {RewardFlowHookMEV} from "../../src/hooks/RewardFlowHookMEV.sol";
import {RewardDistributor} from "../../src/distribution/RewardDistributor.sol";
import {CrossChainPositionTracker} from "../../src/tracking/CrossChainPositionTracker.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/types/PoolId.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/types/PoolOperation.sol";
import {SwapParams} from "@uniswap/v4-core/types/PoolOperation.sol";
import {BeforeSwapDelta} from "@uniswap/v4-core/types/BeforeSwapDelta.sol";
import {BaseHook} from "v4-periphery/utils/BaseHook.sol";
import {toBalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {BeforeSwapDeltaLibrary} from "@uniswap/v4-core/types/BeforeSwapDelta.sol";
import {IPositionTracker} from "../../src/hooks/interfaces/IPositionTracker.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";

contract RewardFlowIntegrationTest is Test {
    using PoolIdLibrary for PoolKey;

    RewardFlowHook public hook;
    RewardFlowHookMEV public mevHook;
    RewardDistributor public distributor;
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
        distributor = new RewardDistributor(
            address(0xdef), // reward token
            address(0x123)  // spoke pool
        );
        
        hook = new RewardFlowHook(poolManager, address(distributor));
        mevHook = new RewardFlowHookMEV(poolManager, address(distributor));
        tracker = new CrossChainPositionTracker();
        
        poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
        poolId = poolKey.toId();
    }

    function testCompleteLiquidityFlow() public {
        // User adds liquidity
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1000,
            salt: 0
        });
        
        BalanceDelta delta = toBalanceDelta(int128(1000), int128(2000));
        
        // Test beforeAddLiquidity
        bytes4 selector = hook.beforeAddLiquidity(user1, poolKey, params, "");
        assertEq(selector, BaseHook.beforeAddLiquidity.selector);
        
        // Test afterAddLiquidity
        vm.expectEmit(true, true, false, true);
        emit RewardFlowHook.RewardEarned(user1, 0, RewardFlowHook.RewardType.LIQUIDITY_PROVISION);
        
        (bytes4 afterSelector, BalanceDelta returnDelta) = hook.afterAddLiquidity(
            user1, poolKey, params, delta, toBalanceDelta(0, 0), ""
        );
        assertEq(afterSelector, BaseHook.afterAddLiquidity.selector);
        assertEq(uint256(int256(returnDelta.amount0())), 0);
        assertEq(uint256(int256(returnDelta.amount1())), 0);
        
        // Check position tracking
        IPositionTracker.Position memory position = tracker.getUserPosition(user1, poolId);
        uint256 liquidity = position.liquidity;
        uint256 timestamp = position.timestamp;
        uint256 lastUpdate = position.lastUpdate;
        bool active = position.active;
        
        assertEq(liquidity, 1000);
        assertEq(timestamp, block.timestamp);
        assertEq(lastUpdate, block.timestamp);
        assertTrue(active);
    }

    function testCompleteSwapFlow() public {
        // First add liquidity
        ModifyLiquidityParams memory addParams = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1000,
            salt: 0
        });
        
        hook.beforeAddLiquidity(user1, poolKey, addParams, "");
        hook.afterAddLiquidity(user1, poolKey, addParams, toBalanceDelta(1000, 2000), toBalanceDelta(0, 0), "");
        
        // Then perform swap
        SwapParams memory swapParams = SwapParams({
            zeroForOne: true,
            amountSpecified: 100,
            sqrtPriceLimitX96: 0
        });
        
        BalanceDelta swapDelta = toBalanceDelta(int128(100), int128(-200));
        
        // Test beforeSwap
        (bytes4 beforeSelector, BeforeSwapDelta beforeDelta, uint24 swapFee) = hook.beforeSwap(
            user2, poolKey, swapParams, ""
        );
        assertEq(beforeSelector, BaseHook.beforeSwap.selector);
        assertEq(uint256(int256(BeforeSwapDeltaLibrary.getSpecifiedDelta(beforeDelta))), 0);
        assertEq(uint256(int256(BeforeSwapDeltaLibrary.getUnspecifiedDelta(beforeDelta))), 0);
        assertEq(swapFee, 0);
        
        // Test afterSwap
        vm.expectEmit(true, true, false, true);
        emit RewardFlowHook.SwapRewardsDistributed(poolId, 0, 100);
        
        (bytes4 afterSelector, int128 returnDelta) = hook.afterSwap(
            user2, poolKey, swapParams, swapDelta, ""
        );
        assertEq(afterSelector, BaseHook.afterSwap.selector);
        assertEq(returnDelta, 0);
    }

    function testMEVDetectionFlow() public {
        // Add liquidity first
        ModifyLiquidityParams memory addParams = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1000,
            salt: 0
        });
        
        mevHook.beforeAddLiquidity(user1, poolKey, addParams, "");
        
        // Perform large swap that might trigger MEV detection
        SwapParams memory swapParams = SwapParams({
            zeroForOne: true,
            amountSpecified: 1e18, // Large amount
            sqrtPriceLimitX96: 0
        });
        
        BalanceDelta swapDelta = toBalanceDelta(int128(1e18), int128(-2e18));
        
        // Test MEV detection in beforeSwap
        (bytes4 beforeSelector, BeforeSwapDelta beforeDelta, uint24 fee) = mevHook.beforeSwap(
            user2, poolKey, swapParams, ""
        );
        assertEq(beforeSelector, BaseHook.beforeSwap.selector);
        
        // Test afterSwap with potential MEV distribution
        (bytes4 afterSelector, int128 returnDelta) = mevHook.afterSwap(
            user2, poolKey, swapParams, swapDelta, ""
        );
        assertEq(afterSelector, BaseHook.afterSwap.selector);
        assertEq(returnDelta, 0);
    }

    function testCrossChainDistribution() public {
        // Set user preferences
        distributor.setUserPreferences(1, 1000, 3600, true);
        
        // Execute reward distribution
        uint256 amount = 5000;
        uint256 targetChain = 1;
        
        vm.expectEmit(true, true, false, true);
        emit RewardDistributor.RewardDistributionInitiated(
            keccak256(abi.encode(user1, amount, block.chainid, targetChain, block.timestamp)),
            user1,
            amount,
            targetChain
        );
        
        distributor.executeRewardDistribution(user1, amount, targetChain);
        
        // Verify distribution was recorded
        bytes32 requestId = keccak256(abi.encode(user1, amount, block.chainid, targetChain, block.timestamp));
        RewardDistributor.DistributionRequest memory request = distributor.getDistributionRequest(requestId);
        
        assertEq(request.user, user1);
        assertEq(request.amount, amount);
        assertEq(request.targetChain, targetChain);
        assertTrue(request.executed);
    }

    function testMultipleUsersMultiplePools() public {
        // Create second pool
        PoolKey memory poolKey2 = PoolKey({
            currency0: Currency.wrap(address(0xdef)),
            currency1: Currency.wrap(address(0x123)),
            fee: 500,
            tickSpacing: 10,
            hooks: IHooks(address(hook))
        });
        PoolId poolId2 = poolKey2.toId();
        
        // User1 adds liquidity to both pools
        ModifyLiquidityParams memory params1 = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1000,
            salt: 0
        });
        
        ModifyLiquidityParams memory params2 = ModifyLiquidityParams({
            tickLower: -10,
            tickUpper: 10,
            liquidityDelta: 2000,
            salt: 0
        });
        
        hook.beforeAddLiquidity(user1, poolKey, params1, "");
        hook.afterAddLiquidity(user1, poolKey, params1, toBalanceDelta(1000, 2000), toBalanceDelta(0, 0), "");
        
        hook.beforeAddLiquidity(user1, poolKey2, params2, "");
        hook.afterAddLiquidity(user1, poolKey2, params2, toBalanceDelta(2000, 4000), toBalanceDelta(0, 0), "");
        
        // User2 adds liquidity to first pool
        hook.beforeAddLiquidity(user2, poolKey, params1, "");
        hook.afterAddLiquidity(user2, poolKey, params1, toBalanceDelta(1000, 2000), toBalanceDelta(0, 0), "");
        
        // Check positions
        IPositionTracker.Position memory position1Pool1 = tracker.getUserPosition(user1, poolId);
        IPositionTracker.Position memory position1Pool2 = tracker.getUserPosition(user1, poolId2);
        IPositionTracker.Position memory position2Pool1 = tracker.getUserPosition(user2, poolId);
        
        uint256 liquidity1Pool1 = position1Pool1.liquidity;
        uint256 liquidity1Pool2 = position1Pool2.liquidity;
        uint256 liquidity2Pool1 = position2Pool1.liquidity;
        
        assertEq(liquidity1Pool1, 1000);
        assertEq(liquidity1Pool2, 2000);
        assertEq(liquidity2Pool1, 1000);
        
        // Check pool info
        IPositionTracker.PoolInfo memory poolInfo1 = tracker.getPoolInfo(poolId);
        IPositionTracker.PoolInfo memory poolInfo2 = tracker.getPoolInfo(poolId2);
        
        uint256 totalLiquidity1 = poolInfo1.totalLiquidity;
        uint256 lpCount1 = poolInfo1.lps.length;
        uint256 totalLiquidity2 = poolInfo2.totalLiquidity;
        uint256 lpCount2 = poolInfo2.lps.length;
        
        assertEq(totalLiquidity1, 2000); // 1000 + 1000
        assertEq(lpCount1, 2);
        assertEq(totalLiquidity2, 2000);
        assertEq(lpCount2, 1);
    }

    function testRewardClaimingFlow() public {
        // Add some pending rewards
        // Note: addPendingReward function doesn't exist in current implementation
        // Note: addPendingReward function doesn't exist in current implementation
        
        // Check initial rewards
        assertEq(hook.getPendingRewards(user1), 1000);
        assertEq(hook.getPendingRewards(user2), 2000);
        
        // User1 claims rewards
        vm.prank(user1);
        hook.claimRewards();
        
        assertEq(hook.getPendingRewards(user1), 0);
        assertEq(hook.getPendingRewards(user2), 2000);
        
        // User2 claims rewards
        vm.prank(user2);
        hook.claimRewards();
        
        assertEq(hook.getPendingRewards(user2), 0);
    }

    function testMEVRewardDistribution() public {
        // Add liquidity to MEV hook
        ModifyLiquidityParams memory addParams = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1000,
            salt: 0
        });
        
        mevHook.beforeAddLiquidity(user1, poolKey, addParams, "");
        
        // Add pool rewards
        // Note: addPoolReward function doesn't exist in current implementation
        
        // Claim rewards
        vm.expectEmit(true, true, false, true);
        emit RewardFlowHookMEV.RewardsClaimed(poolId, user1, 1000);
        
        mevHook.claimRewards(poolId);
        
        uint256 userRewards = mevHook.getLPRewards(poolId, user1);
        assertEq(userRewards, 1000);
    }

    function testPauseUnpauseFlow() public {
        // Pause distributor
        distributor.pause();
        assertTrue(distributor.paused());
        
        // Try to execute distribution while paused
        vm.expectRevert(RewardDistributor.Paused.selector);
        distributor.executeRewardDistribution(user1, 1000, 1);
        
        // Unpause
        distributor.unpause();
        assertFalse(distributor.paused());
        
        // Now distribution should work
        distributor.executeRewardDistribution(user1, 1000, 1);
    }

    function testChainSupportManagement() public {
        uint256 newChain = 10;
        
        // Initially not supported
        assertFalse(distributor.isChainSupported(newChain));
        
        // Add support
        distributor.updateChainSupport(newChain, true);
        assertTrue(distributor.isChainSupported(newChain));
        
        // Remove support
        distributor.updateChainSupport(newChain, false);
        assertFalse(distributor.isChainSupported(newChain));
    }

    function testUserPreferencesFlow() public {
        // Set preferences
        distributor.setUserPreferences(1, 1000, 3600, true);
        
        // Get preferences
        (
            uint256 preferredChain,
            uint256 claimThreshold,
            uint256 claimFrequency,
            bool autoClaimEnabled,
            uint256 lastUpdate
        ) = distributor.getUserPreferences(address(this));
        
        assertEq(preferredChain, 1);
        assertEq(claimThreshold, 1000);
        assertEq(claimFrequency, 3600);
        assertTrue(autoClaimEnabled);
        assertEq(lastUpdate, block.timestamp);
        
        // Test instant claim
        distributor.executeInstantClaim(address(this), 2000);
    }

    function testLargeScaleOperations() public {
        // Test with multiple users and large amounts
        address[] memory users = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            users[i] = address(uint160(0x1000 + i));
        }
        
        // Each user adds liquidity
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 10000,
            salt: 0
        });
        
        for (uint256 i = 0; i < users.length; i++) {
            hook.beforeAddLiquidity(users[i], poolKey, params, "");
            hook.afterAddLiquidity(users[i], poolKey, params, BalanceDelta.wrap(10000, 20000), BalanceDelta.wrap(0, 0), "");
        }
        
        // Check total pool liquidity
        (uint256 totalLiquidity, uint256 lpCount,,) = tracker.getPoolInfo(poolId);
        assertEq(totalLiquidity, 50000); // 5 * 10000
        assertEq(lpCount, 5);
        
        // Each user gets rewards
        for (uint256 i = 0; i < users.length; i++) {
            // Note: addPendingReward function doesn't exist in current implementation
            assertEq(hook.getPendingRewards(users[i]), 1000);
        }
    }
}

// Note: Helper contracts removed as they referenced non-existent functions
