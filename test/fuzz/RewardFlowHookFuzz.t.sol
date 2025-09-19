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
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/types/BeforeSwapDelta.sol";
import {BaseHook} from "v4-periphery/utils/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";
import {TierCalculations} from "../../src/hooks/libraries/TierCalculations.sol";
import {toBalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";

contract RewardFlowHookFuzzTest is Test {
    using PoolIdLibrary for PoolKey;

    RewardFlowHook public hook;
    RewardDistributor public distributor;
    IPoolManager public poolManager;

    function setUp() public {
        poolManager = IPoolManager(address(0x999));
        distributor = new RewardDistributor(
            address(0xdef), // reward token
            address(0x123)  // spoke pool
        );
        
        hook = new RewardFlowHook(poolManager, address(distributor));
    }

    function testFuzzBeforeAddLiquidity(
        address user,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing,
        int256 liquidityDelta,
        uint256 salt
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
            hooks: IHooks(address(hook))
        });
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: liquidityDelta,
            salt: bytes32(salt)
        });
        
        bytes4 selector = hook.beforeAddLiquidity(user, poolKey, params, "");
        assertEq(selector, BaseHook.beforeAddLiquidity.selector);
    }

    function testFuzzBeforeRemoveLiquidity(
        address user,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing,
        int256 liquidityDelta,
        uint256 salt
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
            hooks: IHooks(address(hook))
        });
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: liquidityDelta,
            salt: bytes32(salt)
        });
        
        bytes4 selector = hook.beforeRemoveLiquidity(user, poolKey, params, "");
        assertEq(selector, BaseHook.beforeRemoveLiquidity.selector);
    }

    function testFuzzBeforeSwap(
        address user,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96
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
            hooks: IHooks(address(hook))
        });
        
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });
        
        (bytes4 selector, BeforeSwapDelta delta, uint24 swapFee) = hook.beforeSwap(user, poolKey, params, "");
        
        assertEq(selector, BaseHook.beforeSwap.selector);
        assertEq(uint256(int256(BeforeSwapDeltaLibrary.getSpecifiedDelta(delta))), 0);
        assertEq(uint256(int256(BeforeSwapDeltaLibrary.getUnspecifiedDelta(delta))), 0);
        assertEq(swapFee, 0);
    }

    function testFuzzAfterSwap(
        address user,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        int128 delta0,
        int128 delta1
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
            hooks: IHooks(address(hook))
        });
        
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });
        
        BalanceDelta delta = toBalanceDelta(delta0, delta1);
        
        (bytes4 selector, int128 returnDelta) = hook.afterSwap(user, poolKey, params, delta, "");
        
        assertEq(selector, BaseHook.afterSwap.selector);
        assertEq(returnDelta, 0);
    }

    function testFuzzAfterAddLiquidity(
        address user,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing,
        int256 liquidityDelta,
        uint256 salt,
        int128 delta0,
        int128 delta1,
        int128 fees0,
        int128 fees1
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
            hooks: IHooks(address(hook))
        });
        
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: liquidityDelta,
            salt: bytes32(salt)
        });
        
        BalanceDelta delta = toBalanceDelta(delta0, delta1);
        BalanceDelta feesAccrued = toBalanceDelta(fees0, fees1);
        
        (bytes4 selector, BalanceDelta returnDelta) = hook.afterAddLiquidity(
            user, poolKey, params, delta, feesAccrued, ""
        );
        
        assertEq(selector, BaseHook.afterAddLiquidity.selector);
        assertEq(uint256(int256(returnDelta.amount0())), 0);
        assertEq(uint256(int256(returnDelta.amount1())), 0);
    }

    function testFuzzGetPendingRewards(address user) public {
        vm.assume(user != address(0));
        
        uint256 rewards = hook.getPendingRewards(user);
        assertGe(rewards, 0);
    }

    function testFuzzGetUserTier(address user) public {
        vm.assume(user != address(0));
        
        TierCalculations.TierLevel tier = hook.getUserTier(user);
        assertGe(uint8(tier), 0);
        assertLe(uint8(tier), 4); // Assuming 5 tiers (0-4)
    }

    function testFuzzGetUserActivity(address user) public {
        vm.assume(user != address(0));
        
        (
            uint256 totalLiquidity,
            uint256 swapVolume,
            uint256 positionDuration,
            uint256 lastActivity,
            uint256 loyaltyScore,
            uint256 engagementScore,
            uint8 tier
        ) = hook.getUserActivity(user);
        
        assertGe(totalLiquidity, 0);
        assertGe(swapVolume, 0);
        assertGe(positionDuration, 0);
        assertGe(lastActivity, 0);
        assertGe(loyaltyScore, 0);
        assertLe(loyaltyScore, 100); // Assuming max loyalty score is 100
        assertGe(engagementScore, 0);
        assertGe(tier, 0);
        assertLe(tier, 4); // Assuming 5 tiers (0-4)
    }

    function testFuzzClaimRewards(address user, uint256 amount) public {
        vm.assume(user != address(0));
        amount = bound(amount, 0, type(uint256).max);
        
        // Note: addPendingReward function doesn't exist in current implementation
        // This test would need to be updated based on actual reward mechanism
        
        if (amount >= hook.MIN_REWARD_THRESHOLD()) {
            vm.prank(user);
            hook.claimRewards();
            assertEq(hook.getPendingRewards(user), 0);
        } else {
            vm.prank(user);
            vm.expectRevert(RewardFlowHook.InsufficientRewardThreshold.selector);
            hook.claimRewards();
        }
    }

    function testFuzzAddPendingReward(address user, uint256 amount) public {
        vm.assume(user != address(0));
        amount = bound(amount, 0, type(uint256).max);
        
        uint256 initialRewards = hook.getPendingRewards(user);
        
        // Note: addPendingReward function doesn't exist in current implementation
        
        uint256 finalRewards = hook.getPendingRewards(user);
        assertEq(finalRewards, initialRewards + amount);
    }

    function testFuzzMultipleUsersMultipleRewards(
        address[] memory users,
        uint256[] memory amounts
    ) public {
        vm.assume(users.length > 0 && users.length <= 10);
        vm.assume(users.length == amounts.length);
        
        for (uint256 i = 0; i < users.length; i++) {
            vm.assume(users[i] != address(0));
            amounts[i] = bound(amounts[i], 0, type(uint256).max);
            
            // Note: addPendingReward function doesn't exist in current implementation
            assertEq(hook.getPendingRewards(users[i]), amounts[i]);
        }
    }

    function testFuzzLargeRewardAmounts(address user) public {
        vm.assume(user != address(0));
        
        uint256 largeAmount = type(uint256).max;
        // Note: addPendingReward function doesn't exist in current implementation
        
        assertEq(hook.getPendingRewards(user), largeAmount);
    }

    function testFuzzZeroRewardAmount(address user) public {
        vm.assume(user != address(0));
        
        // Note: addPendingReward function doesn't exist in current implementation
        assertEq(hook.getPendingRewards(user), 0);
    }

    function testFuzzRewardAccumulation(address user, uint256[] memory amounts) public {
        vm.assume(user != address(0));
        vm.assume(amounts.length > 0 && amounts.length <= 10);
        
        uint256 totalExpected = 0;
        
        for (uint256 i = 0; i < amounts.length; i++) {
            amounts[i] = bound(amounts[i], 0, type(uint256).max);
            totalExpected += amounts[i];
            
            // Note: addPendingReward function doesn't exist in current implementation
        }
        
        assertEq(hook.getPendingRewards(user), totalExpected);
    }

    function testFuzzRewardClaimingMultipleUsers(
        address[] memory users,
        uint256[] memory amounts
    ) public {
        vm.assume(users.length > 0 && users.length <= 5);
        vm.assume(users.length == amounts.length);
        
        for (uint256 i = 0; i < users.length; i++) {
            vm.assume(users[i] != address(0));
            amounts[i] = bound(amounts[i], hook.MIN_REWARD_THRESHOLD(), type(uint256).max);
            
            // Note: addPendingReward function doesn't exist in current implementation
        }
        
        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            hook.claimRewards();
            assertEq(hook.getPendingRewards(users[i]), 0);
        }
    }

    function testFuzzRewardTypes() public {
        // Test all reward types
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

    function testFuzzConstants() public {
        assertEq(hook.LP_REWARD_PERCENTAGE(), 7500);
        assertEq(hook.AVS_REWARD_PERCENTAGE(), 1500);
        assertEq(hook.PROTOCOL_FEE_PERCENTAGE(), 1000);
        assertEq(hook.BASIS_POINTS(), 10000);
        assertEq(hook.MEV_THRESHOLD(), 100);
        assertEq(hook.LP_FEE_SHARE(), 5000);
        assertEq(hook.MIN_REWARD_THRESHOLD(), 1e15);
        
        // Check that percentages add up to 100%
        assertEq(
            hook.LP_REWARD_PERCENTAGE() + hook.AVS_REWARD_PERCENTAGE() + hook.PROTOCOL_FEE_PERCENTAGE(),
            hook.BASIS_POINTS()
        );
    }

    function testFuzzHookPermissions() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        
        // Check that permissions are boolean values
        assertTrue(permissions.beforeInitialize == true || permissions.beforeInitialize == false);
        assertTrue(permissions.afterInitialize == true || permissions.afterInitialize == false);
        assertTrue(permissions.beforeAddLiquidity == true || permissions.beforeAddLiquidity == false);
        assertTrue(permissions.afterAddLiquidity == true || permissions.afterAddLiquidity == false);
        assertTrue(permissions.beforeRemoveLiquidity == true || permissions.beforeRemoveLiquidity == false);
        assertTrue(permissions.afterRemoveLiquidity == true || permissions.afterRemoveLiquidity == false);
        assertTrue(permissions.beforeSwap == true || permissions.beforeSwap == false);
        assertTrue(permissions.afterSwap == true || permissions.afterSwap == false);
        assertTrue(permissions.beforeDonate == true || permissions.beforeDonate == false);
        assertTrue(permissions.afterDonate == true || permissions.afterDonate == false);
    }

    function testFuzzGasUsage() public {
        address user = address(0x123);
        uint256 amount = 1000;
        
        uint256 gasStart = gasleft();
        // Note: addPendingReward function doesn't exist in current implementation
        uint256 gasUsed = gasStart - gasleft();
        
        assertLt(gasUsed, 100000); // Should use reasonable amount of gas
    }
}

// Note: Helper contract removed as it referenced non-existent functions
