// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RewardFlowHook} from "../../src/hooks/RewardFlowHook.sol";
import {BaseHook} from "v4-periphery/utils/BaseHook.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/types/PoolOperation.sol";
import {SwapParams} from "@uniswap/v4-core/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "@uniswap/v4-core/types/BeforeSwapDelta.sol";

contract TestRewardFlowHook is RewardFlowHook {
    constructor(IPoolManager _manager, address _rewardDistributor) 
        RewardFlowHook(_manager, _rewardDistributor) 
    {
        // Skip hook address validation for testing
    }
    
    function validateHookAddress(BaseHook _this) internal pure override {
        // Skip validation for testing
    }
    
    // Test functions that bypass onlyPoolManager modifier
    function testBeforeAddLiquidity(address sender, PoolKey calldata key, ModifyLiquidityParams calldata params, bytes calldata hookData) external returns (bytes4) {
        return _beforeAddLiquidity(sender, key, params, hookData);
    }
    
    function testAfterAddLiquidity(address sender, PoolKey calldata key, ModifyLiquidityParams calldata params, BalanceDelta delta, BalanceDelta feesAccrued, bytes calldata hookData) external returns (bytes4, BalanceDelta) {
        return _afterAddLiquidity(sender, key, params, delta, feesAccrued, hookData);
    }
    
    function testBeforeRemoveLiquidity(address sender, PoolKey calldata key, ModifyLiquidityParams calldata params, bytes calldata hookData) external returns (bytes4) {
        return _beforeRemoveLiquidity(sender, key, params, hookData);
    }
    
    function testBeforeSwap(address sender, PoolKey calldata key, SwapParams calldata params, bytes calldata hookData) external returns (bytes4, BeforeSwapDelta, uint24) {
        return _beforeSwap(sender, key, params, hookData);
    }
    
    function testAfterSwap(address sender, PoolKey calldata key, SwapParams calldata params, BalanceDelta delta, bytes calldata hookData) external returns (bytes4, int128) {
        return _afterSwap(sender, key, params, delta, hookData);
    }
}
