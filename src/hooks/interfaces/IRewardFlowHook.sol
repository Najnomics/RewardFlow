// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";

/**
 * @title IRewardFlowHook
 * @notice Interface for the RewardFlow Hook contract
 */
interface IRewardFlowHook {
    /// @notice Reward types
    enum RewardType {
        LIQUIDITY_PROVISION,
        SWAP_VOLUME,
        LOYALTY_BONUS,
        TIER_MULTIPLIER
    }

    /// @notice Reward entry structure
    struct RewardEntry {
        address user;
        address token0;
        address token1;
        uint256 amount;
        uint256 timestamp;
        uint256 blockNumber;
        RewardType rewardType;
        bool processed;
    }

    /// @notice Events
    event RewardEarned(address indexed user, uint256 amount, RewardType rewardType);
    event SwapRewardsDistributed(address indexed poolId, uint256 totalReward, uint256 swapVolume);
    event UserTierUpdated(address indexed user, uint8 newTier);
    event RewardProcessed(bytes32 indexed entryId, address indexed user, uint256 amount);

    /// @notice Get user's pending rewards
    function getPendingRewards(address user) external view returns (uint256);

    /// @notice Get user's tier information
    function getUserTier(address user) external view returns (uint8);

    /// @notice Get user's activity summary
    function getUserActivity(address user) external view returns (
        uint256 totalLiquidity,
        uint256 swapVolume,
        uint256 positionDuration,
        uint256 lastActivity,
        uint256 loyaltyScore
    );

    /// @notice Claim rewards for a user
    function claimRewards() external;

    /// @notice Get total rewards distributed
    function totalRewardsDistributed() external view returns (uint256);
}
