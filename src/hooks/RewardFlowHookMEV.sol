// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/utils/BaseHook.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/types/PoolId.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/types/BeforeSwapDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/types/PoolOperation.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// Removed AVS dependency - using direct reward distribution

/**
 * @title RewardFlowHookMEV  
 * @notice Enhanced Uniswap V4 Hook combining MEV detection from LVR Auction Hook with AVS reward distribution
 * @dev Integrates LVR-style MEV capture with EigenLayer AVS for cross-chain reward aggregation
 */
contract RewardFlowHookMEV is BaseHook, ReentrancyGuard, Ownable {
    using PoolIdLibrary for PoolKey;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice LP reward percentage from MEV capture (85%)
    uint256 public constant LP_REWARD_PERCENTAGE = 8500;
    
    /// @notice AVS operator reward percentage (10%)
    uint256 public constant AVS_REWARD_PERCENTAGE = 1000;
    
    /// @notice Protocol fee percentage (5%)
    uint256 public constant PROTOCOL_FEE_PERCENTAGE = 500;
    
    /// @notice Basis points denominator
    uint256 public constant BASIS_POINTS = 10000;
    
    /// @notice MEV threshold for triggering redistribution (1%)
    uint256 public constant MEV_THRESHOLD = 100;
    
    /// @notice Minimum swap size to consider for MEV (1 ETH equivalent)
    uint256 public constant MIN_SWAP_SIZE = 1e18;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Reward distributor for cross-chain distribution
    address public immutable rewardDistributor;
    
    /// @notice Pool to MEV tracking
    mapping(PoolId => MEVTracker) public mevTrackers;
    
    /// @notice Pool to LP positions
    mapping(PoolId => mapping(address => uint256)) public lpPositions;
    
    /// @notice Pool to total liquidity
    mapping(PoolId => uint256) public totalLiquidity;
    
    /// @notice Pool to accumulated rewards  
    mapping(PoolId => uint256) public poolRewards;
    
    /// @notice LP to claimable rewards per pool
    mapping(PoolId => mapping(address => uint256)) public lpRewards;
    
    /// @notice Total MEV captured across all pools
    uint256 public totalMEVCaptured;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS  
    //////////////////////////////////////////////////////////////*/

    struct MEVTracker {
        uint256 lastPrice;
        uint256 lastBlock;
        uint256 capturedMEV;
        bool mevDetected;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    
    event MEVDetected(PoolId indexed poolId, uint256 deviation, uint256 amount);
    event MEVDistributed(PoolId indexed poolId, uint256 lpAmount, uint256 avsAmount, uint256 protocolAmount);
    event RewardsClaimed(PoolId indexed poolId, address indexed lp, uint256 amount);
    event AVSTaskTriggered(PoolId indexed poolId, uint256 amount, uint256 targetChain);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        IPoolManager _poolManager,
        address _rewardDistributor
    ) BaseHook(_poolManager) Ownable(msg.sender) {
        rewardDistributor = _rewardDistributor;
    }

    /*//////////////////////////////////////////////////////////////
                           HOOK PERMISSIONS
    //////////////////////////////////////////////////////////////*/

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true, 
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /*//////////////////////////////////////////////////////////////
                            LIQUIDITY HOOKS
    //////////////////////////////////////////////////////////////*/

    function _beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata
    ) internal override returns (bytes4) {
        PoolId poolId = key.toId();
        
        if (params.liquidityDelta > 0) {
            lpPositions[poolId][sender] += uint256(int256(params.liquidityDelta));
            totalLiquidity[poolId] += uint256(int256(params.liquidityDelta));
        }
        
        return BaseHook.beforeAddLiquidity.selector;
    }

    function _beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata
    ) internal override returns (bytes4) {
        PoolId poolId = key.toId();
        
        if (params.liquidityDelta < 0) {
            uint256 liquidityRemoved = uint256(-int256(params.liquidityDelta));
            lpPositions[poolId][sender] -= liquidityRemoved;
            totalLiquidity[poolId] -= liquidityRemoved;
        }
        
        return BaseHook.beforeRemoveLiquidity.selector;
    }

    /*//////////////////////////////////////////////////////////////
                              SWAP HOOKS
    //////////////////////////////////////////////////////////////*/

    function _beforeSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        PoolId poolId = key.toId();
        
        // Track price and detect MEV
        uint256 currentPrice = _getPoolPrice(key);
        bool shouldCaptureMEV = _detectMEV(poolId, currentPrice, params);
        
        if (shouldCaptureMEV) {
            uint256 mevAmount = _calculateMEVAmount(params);
            mevTrackers[poolId].capturedMEV += mevAmount;
            mevTrackers[poolId].mevDetected = true;
            
            emit MEVDetected(poolId, MEV_THRESHOLD, mevAmount);
        }
        
        mevTrackers[poolId].lastPrice = currentPrice;
        mevTrackers[poolId].lastBlock = block.number;
        
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function _afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, int128) {
        PoolId poolId = key.toId();
        
        // Process MEV distribution if detected
        if (mevTrackers[poolId].mevDetected && mevTrackers[poolId].capturedMEV > 0) {
            _distributeMEV(poolId);
        }
        
        return (BaseHook.afterSwap.selector, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            MEV FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _detectMEV(
        PoolId poolId, 
        uint256 currentPrice, 
        SwapParams calldata params
    ) internal view returns (bool) {
        MEVTracker memory tracker = mevTrackers[poolId];
        
        if (tracker.lastPrice == 0) return false;
        
        // Check swap size threshold
        uint256 swapSize = params.amountSpecified > 0 ? 
            uint256(params.amountSpecified) : uint256(-params.amountSpecified);
        if (swapSize < MIN_SWAP_SIZE) return false;
        
        // Calculate price deviation
        uint256 deviation;
        if (currentPrice > tracker.lastPrice) {
            deviation = ((currentPrice - tracker.lastPrice) * BASIS_POINTS) / tracker.lastPrice;
        } else {
            deviation = ((tracker.lastPrice - currentPrice) * BASIS_POINTS) / currentPrice;
        }
        
        return deviation >= MEV_THRESHOLD;
    }

    function _calculateMEVAmount(SwapParams calldata params) internal pure returns (uint256) {
        uint256 swapSize = params.amountSpecified > 0 ? 
            uint256(params.amountSpecified) : uint256(-params.amountSpecified);
        
        // Simple MEV calculation: 0.1% of swap size
        return (swapSize * 10) / BASIS_POINTS;
    }

    function _distributeMEV(PoolId poolId) internal {
        uint256 totalMEV = mevTrackers[poolId].capturedMEV;
        if (totalMEV == 0) return;
        
        // Calculate distribution amounts
        uint256 lpAmount = (totalMEV * LP_REWARD_PERCENTAGE) / BASIS_POINTS;
        uint256 avsAmount = (totalMEV * AVS_REWARD_PERCENTAGE) / BASIS_POINTS;
        uint256 protocolAmount = (totalMEV * PROTOCOL_FEE_PERCENTAGE) / BASIS_POINTS;
        
        // Distribute to LPs proportionally
        poolRewards[poolId] += lpAmount;
        
        // Trigger AVS task for cross-chain distribution
        if (avsAmount > 0) {
            _triggerAVSTask(poolId, avsAmount);
        }
        
        // Reset tracker
        mevTrackers[poolId].capturedMEV = 0;
        mevTrackers[poolId].mevDetected = false;
        
        totalMEVCaptured += totalMEV;
        
        emit MEVDistributed(poolId, lpAmount, avsAmount, protocolAmount);
    }

    function _triggerAVSTask(PoolId poolId, uint256 amount) internal {
        // In full implementation, this would create an AVS task through serviceManager
        // For now, just emit event
        emit AVSTaskTriggered(poolId, amount, 1); // Default to chain 1
    }

    function _getPoolPrice(PoolKey calldata /* key */) internal pure returns (uint256) {
        // Simplified price getter - in production would get actual pool price
        return 1e18; // Placeholder
    }

    /*//////////////////////////////////////////////////////////////
                            CLAIM FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function claimRewards(PoolId poolId) external nonReentrant {
        uint256 userLiquidity = lpPositions[poolId][msg.sender];
        require(userLiquidity > 0, "No liquidity provided");
        
        uint256 totalPool = totalLiquidity[poolId];
        uint256 poolRewardBalance = poolRewards[poolId];
        
        // Calculate user's share
        uint256 userReward = (poolRewardBalance * userLiquidity) / totalPool;
        
        if (userReward > 0) {
            lpRewards[poolId][msg.sender] += userReward;
            poolRewards[poolId] -= userReward;
            
            // In production, transfer actual tokens
            emit RewardsClaimed(poolId, msg.sender, userReward);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getMEVTracker(PoolId poolId) external view returns (MEVTracker memory) {
        return mevTrackers[poolId];
    }

    function getLPPosition(PoolId poolId, address lp) external view returns (uint256) {
        return lpPositions[poolId][lp];
    }

    function getPoolRewards(PoolId poolId) external view returns (uint256) {
        return poolRewards[poolId];
    }

    function getLPRewards(PoolId poolId, address lp) external view returns (uint256) {
        return lpRewards[poolId][lp];
    }
}