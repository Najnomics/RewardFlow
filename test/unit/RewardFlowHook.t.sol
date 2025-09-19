// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RewardFlowHook} from "../../src/hooks/RewardFlowHook.sol";
import {RewardDistributor} from "../../src/distribution/RewardDistributor.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/types/PoolId.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/types/PoolOperation.sol";
import {SwapParams} from "@uniswap/v4-core/types/PoolOperation.sol";
import {BeforeSwapDelta} from "@uniswap/v4-core/types/BeforeSwapDelta.sol";
import {BaseHook} from "v4-periphery/utils/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/libraries/Hooks.sol";
import {TierCalculations} from "../../src/hooks/libraries/TierCalculations.sol";

contract RewardFlowHookTest is Test {
    using PoolIdLibrary for PoolKey;

    RewardFlowHook public hook;
    RewardDistributor public distributor;
    IPoolManager public poolManager;
    
    address public user = address(0x123);
    address public token0 = address(0x456);
    address public token1 = address(0x789);
    
    PoolKey public poolKey;
    PoolId public poolId;

    function setUp() public {
        poolManager = IPoolManager(address(0x999));
        distributor = new RewardDistributor(
            address(0xabc), // reward token
            address(0xdef)  // spoke pool
        );
        
        hook = new RewardFlowHook(poolManager, address(distributor));
        
        poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: address(hook)
        });
        poolId = poolKey.toId();
    }

    function testConstructor() public {
        assertEq(address(hook.poolManager()), address(poolManager));
        assertEq(hook.rewardDistributor(), address(distributor));
        assertEq(hook.owner(), address(this));
    }

    function testGetHookPermissions() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        
        assertFalse(permissions.beforeInitialize);
        assertFalse(permissions.afterInitialize);
        assertTrue(permissions.beforeAddLiquidity);
        assertTrue(permissions.afterAddLiquidity);
        assertTrue(permissions.beforeRemoveLiquidity);
        assertFalse(permissions.afterRemoveLiquidity);
        assertTrue(permissions.beforeSwap);
        assertTrue(permissions.afterSwap);
        assertFalse(permissions.beforeDonate);
        assertFalse(permissions.afterDonate);
    }

    function testBeforeAddLiquidity() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1000,
            salt: 0
        });
        
        bytes4 selector = hook.beforeAddLiquidity(user, poolKey, params, "");
        assertEq(selector, BaseHook.beforeAddLiquidity.selector);
    }

    function testBeforeRemoveLiquidity() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: -1000,
            salt: 0
        });
        
        bytes4 selector = hook.beforeRemoveLiquidity(user, poolKey, params, "");
        assertEq(selector, BaseHook.beforeRemoveLiquidity.selector);
    }

    function testBeforeSwap() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 1000,
            sqrtPriceLimitX96: 0
        });
        
        (bytes4 selector, BeforeSwapDelta delta, uint24 fee) = hook.beforeSwap(
            user, poolKey, params, ""
        );
        
        assertEq(selector, BaseHook.beforeSwap.selector);
        assertEq(uint256(int256(delta.amount0())), 0);
        assertEq(uint256(int256(delta.amount1())), 0);
        assertEq(fee, 0);
    }

    function testAfterSwap() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 1000,
            sqrtPriceLimitX96: 0
        });
        
        BalanceDelta delta = BalanceDelta.wrap(int128(100), int128(-200));
        
        (bytes4 selector, int128 returnDelta) = hook.afterSwap(
            user, poolKey, params, delta, ""
        );
        
        assertEq(selector, BaseHook.afterSwap.selector);
        assertEq(returnDelta, 0);
    }

    function testAfterAddLiquidity() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1000,
            salt: 0
        });
        
        BalanceDelta delta = BalanceDelta.wrap(int128(1000), int128(2000));
        BalanceDelta feesAccrued = BalanceDelta.wrap(int128(10), int128(20));
        
        vm.expectEmit(true, true, false, true);
        emit RewardFlowHook.RewardEarned(user, 0, RewardFlowHook.RewardType.LIQUIDITY_PROVISION);
        
        (bytes4 selector, BalanceDelta returnDelta) = hook.afterAddLiquidity(
            user, poolKey, params, delta, feesAccrued, ""
        );
        
        assertEq(selector, BaseHook.afterAddLiquidity.selector);
        assertEq(uint256(int256(returnDelta.amount0())), 0);
        assertEq(uint256(int256(returnDelta.amount1())), 0);
    }

    function testGetPendingRewards() public {
        uint256 rewards = hook.getPendingRewards(user);
        assertEq(rewards, 0);
    }

    function testGetUserTier() public {
        TierCalculations.TierLevel tier = hook.getUserTier(user);
        assertEq(uint8(tier), 0); // Bronze tier by default
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
        // First add some pending rewards
        hook.addPendingReward(user, 1000);
        
        uint256 initialRewards = hook.getPendingRewards(user);
        assertEq(initialRewards, 1000);
        
        // Claim rewards
        hook.claimRewards();
        
        uint256 finalRewards = hook.getPendingRewards(user);
        assertEq(finalRewards, 0);
    }

    function testClaimRewardsInsufficientThreshold() public {
        // Add small amount below threshold
        hook.addPendingReward(user, 1);
        
        vm.expectRevert(RewardFlowHook.InsufficientRewardThreshold.selector);
        hook.claimRewards();
    }

    function testAddPendingReward() public {
        uint256 amount = 1000;
        
        vm.expectEmit(true, true, false, true);
        emit RewardFlowHook.RewardEarned(user, amount, RewardFlowHook.RewardType.LIQUIDITY_PROVISION);
        
        hook.addPendingReward(user, amount);
        
        assertEq(hook.getPendingRewards(user), amount);
    }

    function testOnlyOwnerFunctions() public {
        address nonOwner = address(0x999);
        
        vm.prank(nonOwner);
        vm.expectRevert();
        hook.addPendingReward(user, 1000);
    }

    function testRewardTypes() public {
        // Test different reward types
        RewardFlowHook.RewardType liquidityType = RewardFlowHook.RewardType.LIQUIDITY_PROVISION;
        RewardFlowHook.RewardType swapType = RewardFlowHook.RewardType.SWAP_VOLUME;
        RewardFlowHook.RewardType loyaltyType = RewardFlowHook.RewardType.LOYALTY_BONUS;
        RewardFlowHook.RewardType tierType = RewardFlowHook.RewardType.TIER_MULTIPLIER;
        RewardFlowHook.RewardType mevType = RewardFlowHook.RewardType.MEV_CAPTURE;
        
        assertEq(uint8(liquidityType), 0);
        assertEq(uint8(swapType), 1);
        assertEq(uint8(loyaltyType), 2);
        assertEq(uint8(tierType), 3);
        assertEq(uint8(mevType), 4);
    }

    function testConstants() public {
        assertEq(hook.LP_REWARD_PERCENTAGE(), 7500);
        assertEq(hook.AVS_REWARD_PERCENTAGE(), 1500);
        assertEq(hook.PROTOCOL_FEE_PERCENTAGE(), 1000);
        assertEq(hook.BASIS_POINTS(), 10000);
        assertEq(hook.MEV_THRESHOLD(), 100);
        assertEq(hook.LP_FEE_SHARE(), 5000);
        assertEq(hook.MIN_REWARD_THRESHOLD(), 1e15);
    }

    function testMultipleUsers() public {
        address user2 = address(0x456);
        
        // Add rewards for both users
        hook.addPendingReward(user, 1000);
        hook.addPendingReward(user2, 2000);
        
        assertEq(hook.getPendingRewards(user), 1000);
        assertEq(hook.getPendingRewards(user2), 2000);
        
        // Claim for one user
        vm.prank(user);
        hook.claimRewards();
        
        assertEq(hook.getPendingRewards(user), 0);
        assertEq(hook.getPendingRewards(user2), 2000);
    }

    function testLargeRewardAmounts() public {
        uint256 largeAmount = 1e18;
        hook.addPendingReward(user, largeAmount);
        
        assertEq(hook.getPendingRewards(user), largeAmount);
    }

    function testZeroRewardAmount() public {
        hook.addPendingReward(user, 0);
        assertEq(hook.getPendingRewards(user), 0);
    }
}

// Helper contract to expose internal functions for testing
contract RewardFlowHookTestHelper is RewardFlowHook {
    constructor(IPoolManager _poolManager, address _rewardDistributor) 
        RewardFlowHook(_poolManager, _rewardDistributor) {}
    
    function addPendingReward(address user, uint256 amount) external {
        pendingRewards[user] += amount;
        emit RewardEarned(user, amount, RewardType.LIQUIDITY_PROVISION);
    }
}
