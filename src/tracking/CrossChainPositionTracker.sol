// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPositionTracker} from "../hooks/interfaces/IPositionTracker.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {PoolId} from "@uniswap/v4-core/types/PoolId.sol";
import {PositionMath} from "./libraries/PositionMath.sol";
import {EngagementMetrics} from "./libraries/EngagementMetrics.sol";
import {Constants} from "../utils/Constants.sol";
import {Events} from "../utils/Events.sol";
import {Errors} from "../utils/Errors.sol";

/**
 * @title CrossChainPositionTracker
 * @notice Multi-chain LP position management and tracking
 */
contract CrossChainPositionTracker is IPositionTracker {
    using PositionMath for Position;
    using EngagementMetrics for mapping(address => EngagementMetrics.UserEngagement);

    /// @notice Position storage
    mapping(address => mapping(PoolId => Position)) public positions;
    mapping(PoolId => PoolInfo) public poolInfo;
    mapping(address => PoolId[]) public userPools;
    mapping(address => mapping(PoolId => bool)) public userPoolMembership;

    /// @notice User engagement tracking
    mapping(address => EngagementMetrics.UserEngagement) public userEngagement;

    /// @notice Cross-chain position data
    mapping(address => mapping(uint256 => Position)) public crossChainPositions;
    mapping(address => uint256[]) public userChains;

    /// @notice Events
    event CrossChainPositionUpdated(address indexed user, uint256 chainId, uint256 liquidity);
    event EngagementUpdated(address indexed user, uint256 score, uint256 tier);

    /// @notice Errors
    error PositionNotFound();
    error InvalidPool();
    error InsufficientLiquidity();
    error CrossChainNotSupported();

    /// @notice Update user position
    function updatePosition(
        address user,
        PoolKey calldata key,
        BalanceDelta delta
    ) external override {
        PoolId poolId = key.toId();
        
        // Update local position
        _updateLocalPosition(user, poolId, delta);
        
        // Update pool information
        _updatePoolInfo(poolId, user, delta);
        
        // Update user engagement
        _updateUserEngagement(user, delta);
        
        // Update cross-chain position if supported
        _updateCrossChainPosition(user, poolId, delta);
        
        emit PositionUpdated(user, poolId, positions[user][poolId].liquidity);
    }

    /// @notice Get all LPs for a pool
    function getPoolLPs(PoolId poolId) external view override returns (address[] memory) {
        return poolInfo[poolId].lps;
    }

    /// @notice Get LP shares for a pool
    function getPoolShares(PoolId poolId) external view override returns (uint256[] memory) {
        return poolInfo[poolId].shares;
    }

    /// @notice Get user's position in a pool
    function getUserPosition(address user, PoolId poolId) external view override returns (Position memory) {
        return positions[user][poolId];
    }

    /// @notice Get user's total liquidity across all pools
    function getUserTotalLiquidity(address user) external view override returns (uint256) {
        uint256 total = 0;
        PoolId[] memory pools = userPools[user];
        
        for (uint256 i = 0; i < pools.length; i++) {
            total += positions[user][pools[i]].liquidity;
        }
        
        return total;
    }

    /// @notice Get pool information
    function getPoolInfo(PoolId poolId) external view override returns (PoolInfo memory) {
        return poolInfo[poolId];
    }

    /// @notice Check if user is LP in pool
    function isUserLP(address user, PoolId poolId) external view override returns (bool) {
        return userPoolMembership[user][poolId];
    }

    /// @notice Get user's active positions
    function getUserActivePositions(address user) external view override returns (Position[] memory) {
        PoolId[] memory pools = userPools[user];
        Position[] memory activePositions = new Position[](pools.length);
        uint256 activeCount = 0;
        
        for (uint256 i = 0; i < pools.length; i++) {
            if (positions[user][pools[i]].active) {
                activePositions[activeCount] = positions[user][pools[i]];
                activeCount++;
            }
        }
        
        // Resize array to actual active positions
        Position[] memory result = new Position[](activeCount);
        for (uint256 i = 0; i < activeCount; i++) {
            result[i] = activePositions[i];
        }
        
        return result;
    }

    /// @notice Get cross-chain position
    function getCrossChainPosition(
        address user,
        uint256 chainId
    ) external view returns (Position memory) {
        return crossChainPositions[user][chainId];
    }

    /// @notice Get user's chains
    function getUserChains(address user) external view returns (uint256[] memory) {
        return userChains[user];
    }

    /// @notice Get user engagement score
    function getUserEngagementScore(address user) external view returns (uint256) {
        return EngagementMetrics.getEngagementScore(userEngagement[user]);
    }

    /// @notice Update local position
    function _updateLocalPosition(
        address user,
        PoolId poolId,
        BalanceDelta delta
    ) internal {
        Position storage position = positions[user][poolId];
        
        // Calculate liquidity change
        int256 liquidityChange = _calculateLiquidityChange(delta);
        
        // Update position
        if (liquidityChange > 0) {
            position.liquidity += uint256(liquidityChange);
            position.active = true;
        } else if (position.liquidity > uint256(-liquidityChange)) {
            position.liquidity -= uint256(-liquidityChange);
        } else {
            position.liquidity = 0;
            position.active = false;
        }
        
        position.timestamp = block.timestamp;
        position.lastUpdate = block.timestamp;
        
        // Update user pool membership
        if (position.liquidity > 0 && !userPoolMembership[user][poolId]) {
            userPools[user].push(poolId);
            userPoolMembership[user][poolId] = true;
        } else if (position.liquidity == 0 && userPoolMembership[user][poolId]) {
            _removeUserFromPool(user, poolId);
        }
    }

    /// @notice Update pool information
    function _updatePoolInfo(
        PoolId poolId,
        address user,
        BalanceDelta delta
    ) internal {
        PoolInfo storage pool = poolInfo[poolId];
        
        // Update total liquidity
        int256 liquidityChange = _calculateLiquidityChange(delta);
        if (liquidityChange > 0) {
            pool.totalLiquidity += uint256(liquidityChange);
        } else if (pool.totalLiquidity > uint256(-liquidityChange)) {
            pool.totalLiquidity -= uint256(-liquidityChange);
        } else {
            pool.totalLiquidity = 0;
        }
        
        // Update LP list and shares
        _updatePoolLPs(poolId, user, liquidityChange);
        
        pool.lastUpdate = block.timestamp;
    }

    /// @notice Update pool LPs
    function _updatePoolLPs(
        PoolId poolId,
        address user,
        int256 liquidityChange
    ) internal {
        PoolInfo storage pool = poolInfo[poolId];
        
        // Find user in LP list
        uint256 userIndex = _findUserInPool(poolId, user);
        
        if (liquidityChange > 0) {
            if (userIndex == type(uint256).max) {
                // Add new LP
                pool.lps.push(user);
                pool.shares.push(uint256(liquidityChange));
            } else {
                // Update existing LP
                pool.shares[userIndex] += uint256(liquidityChange);
            }
        } else if (userIndex != type(uint256).max) {
            // Remove or update LP
            uint256 change = uint256(-liquidityChange);
            if (pool.shares[userIndex] <= change) {
                // Remove LP
                _removeLPFromPool(poolId, userIndex);
            } else {
                // Update LP share
                pool.shares[userIndex] -= change;
            }
        }
        
        emit PoolLPsUpdated(poolId, pool.lps, pool.shares);
    }

    /// @notice Update user engagement
    function _updateUserEngagement(
        address user,
        BalanceDelta delta
    ) internal {
        EngagementMetrics.UserEngagement storage engagement = userEngagement[user];
        
        int256 liquidityChange = _calculateLiquidityChange(delta);
        EngagementMetrics.updateLiquidityActivity(engagement, uint256(liquidityChange));
        
        uint256 newScore = EngagementMetrics.getEngagementScore(engagement);
        uint256 newTier = EngagementMetrics.getTier(engagement);
        
        emit EngagementUpdated(user, newScore, newTier);
    }

    /// @notice Update cross-chain position
    function _updateCrossChainPosition(
        address user,
        PoolId poolId,
        BalanceDelta delta
    ) internal {
        // This would integrate with cross-chain bridges in practice
        // For now, just update local cross-chain tracking
        uint256 chainId = block.chainid;
        int256 liquidityChange = _calculateLiquidityChange(delta);
        
        if (liquidityChange > 0) {
            crossChainPositions[user][chainId].liquidity += uint256(liquidityChange);
            crossChainPositions[user][chainId].active = true;
        } else if (crossChainPositions[user][chainId].liquidity > uint256(-liquidityChange)) {
            crossChainPositions[user][chainId].liquidity -= uint256(-liquidityChange);
        } else {
            crossChainPositions[user][chainId].liquidity = 0;
            crossChainPositions[user][chainId].active = false;
        }
        
        crossChainPositions[user][chainId].timestamp = block.timestamp;
        crossChainPositions[user][chainId].lastUpdate = block.timestamp;
        
        // Add chain to user's chains if not already present
        if (liquidityChange > 0 && !_isUserOnChain(user, chainId)) {
            userChains[user].push(chainId);
        }
        
        emit CrossChainPositionUpdated(user, chainId, crossChainPositions[user][chainId].liquidity);
    }

    /// @notice Calculate liquidity change from delta
    function _calculateLiquidityChange(BalanceDelta delta) internal pure returns (int256) {
        uint256 delta0 = uint256(int256(delta.amount0()));
        uint256 delta1 = uint256(int256(delta.amount1()));
        
        // Use the larger delta as liquidity change
        return delta0 > delta1 ? int256(delta0) : int256(delta1);
    }

    /// @notice Find user in pool LP list
    function _findUserInPool(PoolId poolId, address user) internal view returns (uint256) {
        address[] memory lps = poolInfo[poolId].lps;
        
        for (uint256 i = 0; i < lps.length; i++) {
            if (lps[i] == user) {
                return i;
            }
        }
        
        return type(uint256).max;
    }

    /// @notice Remove user from pool
    function _removeUserFromPool(address user, PoolId poolId) internal {
        PoolId[] storage userPoolsList = userPools[user];
        
        for (uint256 i = 0; i < userPoolsList.length; i++) {
            if (PoolId.unwrap(userPoolsList[i]) == PoolId.unwrap(poolId)) {
                userPoolsList[i] = userPoolsList[userPoolsList.length - 1];
                userPoolsList.pop();
                break;
            }
        }
        
        userPoolMembership[user][poolId] = false;
    }

    /// @notice Remove LP from pool
    function _removeLPFromPool(PoolId poolId, uint256 index) internal {
        PoolInfo storage pool = poolInfo[poolId];
        
        pool.lps[index] = pool.lps[pool.lps.length - 1];
        pool.shares[index] = pool.shares[pool.shares.length - 1];
        
        pool.lps.pop();
        pool.shares.pop();
    }

    /// @notice Check if user is on chain
    function _isUserOnChain(address user, uint256 chainId) internal view returns (bool) {
        uint256[] memory chains = userChains[user];
        
        for (uint256 i = 0; i < chains.length; i++) {
            if (chains[i] == chainId) {
                return true;
            }
        }
        
        return false;
    }
}
