// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {TestRewardFlowHookMEV} from "./TestRewardFlowHookMEV.sol";
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
import {IHooks} from "@uniswap/v4-core/interfaces/IHooks.sol";

contract RewardFlowHookMEVTest is Test {
    using PoolIdLibrary for PoolKey;

    TestRewardFlowHookMEV public mevHook;
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
        
        mevHook = new TestRewardFlowHookMEV(IPoolManager(address(poolManager)), address(distributor));
        
        poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(mevHook))
        });
        poolId = poolKey.toId();
    }

    function testConstructor() public {
        assertEq(address(mevHook.rewardDistributor()), address(distributor));
        assertEq(address(mevHook.poolManager()), address(poolManager));
    }

    function testBeforeAddLiquidity() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1000,
            salt: 0
        });
        
        bytes4 selector = mevHook.testBeforeAddLiquidity(user, poolKey, params, "");
        assertEq(selector, BaseHook.beforeAddLiquidity.selector);
    }

    function testBeforeRemoveLiquidity() public {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: -1000,
            salt: 0
        });
        
        bytes4 selector = mevHook.testBeforeRemoveLiquidity(user, poolKey, params, "");
        assertEq(selector, BaseHook.beforeRemoveLiquidity.selector);
    }

    function testBeforeSwap() public {
        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: 1000,
            sqrtPriceLimitX96: 0
        });
        
        (bytes4 selector, BeforeSwapDelta delta, uint24 fee) = mevHook.testBeforeSwap(
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
        
        (bytes4 selector, int128 returnDelta) = mevHook.testAfterSwap(
            user, poolKey, params, delta, ""
        );
        
        assertEq(selector, BaseHook.afterSwap.selector);
    }

    function testGetHookPermissions() public {
        Hooks.Permissions memory permissions = mevHook.getHookPermissions();
        assertTrue(permissions.beforeAddLiquidity);
        assertFalse(permissions.afterAddLiquidity);
        assertTrue(permissions.beforeRemoveLiquidity);
        assertTrue(permissions.beforeSwap);
        assertTrue(permissions.afterSwap);
    }

    function testGetMEVTracker() public {
        TestRewardFlowHookMEV.MEVTracker memory tracker = mevHook.getMEVTracker(poolId);
        assertEq(tracker.capturedMEV, 0);
    }

    function testGetLPPosition() public {
        uint256 position = mevHook.getLPPosition(poolId, user);
        assertEq(position, 0);
    }

    function testGetLPRewards() public {
        uint256 rewards = mevHook.getLPRewards(poolId, user);
        assertEq(rewards, 0);
    }

    function testTotalMEVCaptured() public {
        uint256 totalMEV = mevHook.totalMEVCaptured();
        assertEq(totalMEV, 0);
    }
}