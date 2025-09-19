// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RewardFlowHookMEV} from "../../src/hooks/RewardFlowHookMEV.sol";
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

contract RewardFlowHookMEVTest is Test {
    using PoolIdLibrary for PoolKey;

    RewardFlowHookMEV public mevHook;
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
        
        mevHook = new RewardFlowHookMEV(poolManager, address(distributor));
        
        poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: address(mevHook)
        });
        poolId = poolKey.toId();
    }

    function testConstructor() public {
        assertEq(address(mevHook.poolManager()), address(poolManager));
        assertEq(mevHook.rewardDistributor(), address(distributor));
        assertEq(mevHook.owner(), address(this));
    }

    function testGetHookPermissions() public {
        Hooks.Permissions memory permissions = mevHook.getHookPermissions();
        
        assertFalse(permissions.beforeInitialize);
        assertFalse(permissions.afterInitialize);
        assertTrue(permissions.beforeAddLiquidity);
        assertFalse(permissions.afterAddLiquidity);
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
        
        bytes4 selector = mevHook.beforeAddLiquidity(user, poolKey, params, "");
        assertEq(selector, BaseHook.beforeAddLiquidity.selector);
    }

    function testBeforeRemoveLiquidity() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: -1000,
            salt: 0
        });
        
        bytes4 selector = mevHook.beforeRemoveLiquidity(user, poolKey, params, "");
        assertEq(selector, BaseHook.beforeRemoveLiquidity.selector);
    }

    function testBeforeSwap() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 1000,
            sqrtPriceLimitX96: 0
        });
        
        (bytes4 selector, BeforeSwapDelta delta, uint24 fee) = mevHook.beforeSwap(
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
        
        (bytes4 selector, int128 returnDelta) = mevHook.afterSwap(
            user, poolKey, params, delta, ""
        );
        
        assertEq(selector, BaseHook.afterSwap.selector);
        assertEq(returnDelta, 0);
    }

    function testGetMEVTracker() public {
        RewardFlowHookMEV.MEVTracker memory tracker = mevHook.getMEVTracker(poolId);
        
        assertEq(tracker.lastPrice, 0);
        assertEq(tracker.lastBlock, 0);
        assertEq(tracker.capturedMEV, 0);
        assertFalse(tracker.mevDetected);
    }

    function testGetLPPosition() public {
        uint256 position = mevHook.getLPPosition(poolId, user);
        assertEq(position, 0);
    }

    function testGetPoolRewards() public {
        uint256 rewards = mevHook.getPoolRewards(poolId);
        assertEq(rewards, 0);
    }

    function testGetLPRewards() public {
        uint256 rewards = mevHook.getLPRewards(poolId, user);
        assertEq(rewards, 0);
    }

    function testClaimRewards() public {
        // First add some liquidity
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1000,
            salt: 0
        });
        
        mevHook.beforeAddLiquidity(user, poolKey, params, "");
        
        // Add some pool rewards
        mevHook.addPoolReward(poolId, 1000);
        
        // Claim rewards
        vm.expectEmit(true, true, false, true);
        emit RewardFlowHookMEV.RewardsClaimed(poolId, user, 1000);
        
        mevHook.claimRewards(poolId);
        
        uint256 userRewards = mevHook.getLPRewards(poolId, user);
        assertEq(userRewards, 1000);
    }

    function testClaimRewardsNoLiquidity() public {
        vm.expectRevert("No liquidity provided");
        mevHook.claimRewards(poolId);
    }

    function testClaimRewardsZeroReward() public {
        // Add liquidity but no rewards
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1000,
            salt: 0
        });
        
        mevHook.beforeAddLiquidity(user, poolKey, params, "");
        
        // Should not emit event for zero reward
        mevHook.claimRewards(poolId);
        
        uint256 userRewards = mevHook.getLPRewards(poolId, user);
        assertEq(userRewards, 0);
    }

    function testConstants() public {
        assertEq(mevHook.LP_REWARD_PERCENTAGE(), 8500);
        assertEq(mevHook.AVS_REWARD_PERCENTAGE(), 1000);
        assertEq(mevHook.PROTOCOL_FEE_PERCENTAGE(), 500);
        assertEq(mevHook.BASIS_POINTS(), 10000);
        assertEq(mevHook.MEV_THRESHOLD(), 100);
        assertEq(mevHook.MIN_SWAP_SIZE(), 1e18);
    }

    function testMultipleUsersClaimRewards() public {
        address user2 = address(0x456);
        
        // Add liquidity for both users
        ModifyLiquidityParams memory params1 = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1000,
            salt: 0
        });
        
        ModifyLiquidityParams memory params2 = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 2000,
            salt: 0
        });
        
        mevHook.beforeAddLiquidity(user, poolKey, params1, "");
        mevHook.beforeAddLiquidity(user2, poolKey, params2, "");
        
        // Add pool rewards
        mevHook.addPoolReward(poolId, 3000);
        
        // Claim for both users
        mevHook.claimRewards(poolId);
        vm.prank(user2);
        mevHook.claimRewards(poolId);
        
        uint256 user1Rewards = mevHook.getLPRewards(poolId, user);
        uint256 user2Rewards = mevHook.getLPRewards(poolId, user2);
        
        // User1 should get 1/3 of rewards (1000/3000), User2 should get 2/3 (2000/3000)
        assertEq(user1Rewards, 1000);
        assertEq(user2Rewards, 2000);
    }

    function testLargeLiquidityAmounts() public {
        uint256 largeAmount = 1e18;
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: int256(largeAmount),
            salt: 0
        });
        
        mevHook.beforeAddLiquidity(user, poolKey, params, "");
        
        uint256 position = mevHook.getLPPosition(poolId, user);
        assertEq(position, largeAmount);
    }

    function testRemoveLiquidity() public {
        // First add liquidity
        ModifyLiquidityParams memory addParams = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1000,
            salt: 0
        });
        
        mevHook.beforeAddLiquidity(user, poolKey, addParams, "");
        
        // Then remove some
        ModifyLiquidityParams memory removeParams = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: -500,
            salt: 0
        });
        
        mevHook.beforeRemoveLiquidity(user, poolKey, removeParams, "");
        
        uint256 position = mevHook.getLPPosition(poolId, user);
        assertEq(position, 500);
    }

    function testRemoveAllLiquidity() public {
        // First add liquidity
        ModifyLiquidityParams memory addParams = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1000,
            salt: 0
        });
        
        mevHook.beforeAddLiquidity(user, poolKey, addParams, "");
        
        // Then remove all
        ModifyLiquidityParams memory removeParams = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: -1000,
            salt: 0
        });
        
        mevHook.beforeRemoveLiquidity(user, poolKey, removeParams, "");
        
        uint256 position = mevHook.getLPPosition(poolId, user);
        assertEq(position, 0);
    }

    function testZeroLiquidityDelta() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 0,
            salt: 0
        });
        
        mevHook.beforeAddLiquidity(user, poolKey, params, "");
        
        uint256 position = mevHook.getLPPosition(poolId, user);
        assertEq(position, 0);
    }
}

// Helper contract to expose internal functions for testing
contract RewardFlowHookMEVTestHelper is RewardFlowHookMEV {
    constructor(IPoolManager _poolManager, address _rewardDistributor) 
        RewardFlowHookMEV(_poolManager, _rewardDistributor) {}
    
    function addPoolReward(PoolId poolId, uint256 amount) external {
        poolRewards[poolId] += amount;
    }
}
