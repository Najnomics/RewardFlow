// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {SwapParams} from "@uniswap/v4-core/types/PoolOperation.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/types/PoolOperation.sol";
import {toBalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";

contract MockPoolManager is IPoolManager {
    using PoolIdLibrary for PoolKey;

    mapping(PoolId => PoolKey) public pools;

    function initialize(PoolKey memory key, uint160 sqrtPriceX96, bytes calldata hookData) external returns (int24 tick) {
        PoolId poolId = key.toId();
        pools[poolId] = key;
        return 0;
    }

    function lock(bytes calldata data) external returns (bytes memory) {
        return data;
    }

    function unlock(bytes calldata data) external returns (bytes memory) {
        return data;
    }

    function settle(Currency currency) external returns (uint128 amount0, uint128 amount1) {
        return (0, 0);
    }

    function take(Currency currency, address to, uint128 amount) external returns (uint128 amount0, uint128 amount1) {
        return (0, 0);
    }

    function mint(Currency currency, address to, uint128 amount) external returns (uint128 amount0, uint128 amount1) {
        return (0, 0);
    }

    function swap(PoolKey memory key, SwapParams memory params, bytes calldata hookData) external returns (BalanceDelta delta) {
        return toBalanceDelta(0, 0);
    }

    function modifyLiquidity(PoolKey memory key, ModifyLiquidityParams memory params, bytes calldata hookData) external returns (BalanceDelta callerDelta, BalanceDelta feesAccrued) {
        return (toBalanceDelta(0, 0), toBalanceDelta(0, 0));
    }

    function donate(PoolKey memory key, uint128 amount0, uint128 amount1, bytes calldata hookData) external returns (BalanceDelta delta) {
        return toBalanceDelta(0, 0);
    }

    function getSlot0(PoolId id) external view returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) {
        return (0, 0, 0, 0);
    }

    function getLiquidity(PoolId id) external view returns (uint128 liquidity) {
        return 0;
    }

    function getFee(PoolId id) external view returns (uint24 fee) {
        return 0;
    }

    function getProtocolFee(PoolId id) external view returns (uint24 protocolFee) {
        return 0;
    }

    function getLpFee(PoolId id) external view returns (uint24 lpFee) {
        return 0;
    }

    function getTickSpacing(PoolId id) external view returns (int24 tickSpacing) {
        return 0;
    }

    function getHooks(PoolId id) external view returns (address hooks) {
        return address(0);
    }

    function getKey(PoolId id) external view returns (PoolKey memory key) {
        return pools[id];
    }

    function getBalance(address account, Currency currency) external view returns (uint256 balance) {
        return 0;
    }

    function getPoolBalance(PoolId id, Currency currency) external view returns (uint256 balance) {
        return 0;
    }

    function getPoolBalances(PoolId id) external view returns (uint256 balance0, uint256 balance1) {
        return (0, 0);
    }

    function getPoolBalances(PoolId id, Currency currency) external view returns (uint256 balance) {
        return 0;
    }

    function getPoolBalances(PoolId id, Currency currency0, Currency currency1) external view returns (uint256 balance0, uint256 balance1) {
        return (0, 0);
    }

    function getPoolBalances(PoolId id, Currency currency0, Currency currency1, Currency currency2) external view returns (uint256 balance0, uint256 balance1, uint256 balance2) {
        return (0, 0, 0);
    }

    function getPoolBalances(PoolId id, Currency currency0, Currency currency1, Currency currency2, Currency currency3) external view returns (uint256 balance0, uint256 balance1, uint256 balance2, uint256 balance3) {
        return (0, 0, 0, 0);
    }

    function getPoolBalances(PoolId id, Currency currency0, Currency currency1, Currency currency2, Currency currency3, Currency currency4) external view returns (uint256 balance0, uint256 balance1, uint256 balance2, uint256 balance3, uint256 balance4) {
        return (0, 0, 0, 0, 0);
    }

    function getPoolBalances(PoolId id, Currency currency0, Currency currency1, Currency currency2, Currency currency3, Currency currency4, Currency currency5) external view returns (uint256 balance0, uint256 balance1, uint256 balance2, uint256 balance3, uint256 balance4, uint256 balance5) {
        return (0, 0, 0, 0, 0, 0);
    }

    function getPoolBalances(PoolId id, Currency currency0, Currency currency1, Currency currency2, Currency currency3, Currency currency4, Currency currency5, Currency currency6) external view returns (uint256 balance0, uint256 balance1, uint256 balance2, uint256 balance3, uint256 balance4, uint256 balance5, uint256 balance6) {
        return (0, 0, 0, 0, 0, 0, 0);
    }

    function getPoolBalances(PoolId id, Currency currency0, Currency currency1, Currency currency2, Currency currency3, Currency currency4, Currency currency5, Currency currency6, Currency currency7) external view returns (uint256 balance0, uint256 balance1, uint256 balance2, uint256 balance3, uint256 balance4, uint256 balance5, uint256 balance6, uint256 balance7) {
        return (0, 0, 0, 0, 0, 0, 0, 0);
    }

    function getPoolBalances(PoolId id, Currency currency0, Currency currency1, Currency currency2, Currency currency3, Currency currency4, Currency currency5, Currency currency6, Currency currency7, Currency currency8) external view returns (uint256 balance0, uint256 balance1, uint256 balance2, uint256 balance3, uint256 balance4, uint256 balance5, uint256 balance6, uint256 balance7, uint256 balance8) {
        return (0, 0, 0, 0, 0, 0, 0, 0, 0);
    }

    function getPoolBalances(PoolId id, Currency currency0, Currency currency1, Currency currency2, Currency currency3, Currency currency4, Currency currency5, Currency currency6, Currency currency7, Currency currency8, Currency currency9) external view returns (uint256 balance0, uint256 balance1, uint256 balance2, uint256 balance3, uint256 balance4, uint256 balance5, uint256 balance6, uint256 balance7, uint256 balance8, uint256 balance9) {
        return (0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
    }

    // Stub implementations for missing functions
    function initialize(PoolKey memory key, uint160 sqrtPriceX96) external returns (int24 tick) {
        PoolId poolId = key.toId();
        pools[poolId] = key;
        return 0;
    }

    function clear(Currency currency, uint256 amount) external {}

    function burn(address from, uint256 id, uint256 amount) external {}

    function mint(address to, uint256 id, uint256 amount) external {}

    function donate(PoolKey memory key, uint256 amount0, uint256 amount1, bytes calldata hookData) external returns (BalanceDelta delta) {
        return toBalanceDelta(0, 0);
    }

    function settle() external payable returns (uint256 paid) {
        return 0;
    }

    function settleFor(address recipient) external payable returns (uint256 paid) {
        return 0;
    }

    function sync(Currency currency) external {}

    function take(Currency currency, address to, uint256 amount) external {}

    function updateDynamicLPFee(PoolKey memory key, uint24 newDynamicLPFee) external {}

    // ERC6909 stubs
    function balanceOf(address owner, uint256 id) external view returns (uint256 amount) {
        return 0;
    }

    function allowance(address owner, address spender, uint256 id) external view returns (uint256 amount) {
        return 0;
    }

    function isOperator(address owner, address spender) external view returns (bool approved) {
        return false;
    }

    function approve(address spender, uint256 id, uint256 amount) external returns (bool) {
        return true;
    }

    function setOperator(address operator, bool approved) external returns (bool) {
        return true;
    }

    function transfer(address receiver, uint256 id, uint256 amount) external returns (bool) {
        return true;
    }

    function transferFrom(address sender, address receiver, uint256 id, uint256 amount) external returns (bool) {
        return true;
    }

    // Protocol fees stubs
    function protocolFeesAccrued(Currency currency) external view returns (uint256 amount) {
        return 0;
    }

    function setProtocolFee(PoolKey memory key, uint24 newProtocolFee) external {}

    function setProtocolFeeController(address controller) external {}

    function collectProtocolFees(address recipient, Currency currency, uint256 amount) external returns (uint256 amountCollected) {
        return 0;
    }

    function protocolFeeController() external view returns (address) {
        return address(0);
    }

    // Extsload stubs
    function extsload(bytes32 slot) external view returns (bytes32 value) {
        return bytes32(0);
    }

    function extsload(bytes32 startSlot, uint256 nSlots) external view returns (bytes32[] memory values) {
        return new bytes32[](nSlots);
    }

    function extsload(bytes32[] calldata slots) external view returns (bytes32[] memory values) {
        return new bytes32[](slots.length);
    }

    // Exttload stubs
    function exttload(bytes32 slot) external view returns (bytes32 value) {
        return bytes32(0);
    }

    function exttload(bytes32[] calldata slots) external view returns (bytes32[] memory values) {
        return new bytes32[](slots.length);
    }
}