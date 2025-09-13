// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ServiceManagerBase} from "@eigenlayer-middleware/src/ServiceManagerBase.sol";
import {IRewardAggregatorAVS} from "./interfaces/IRewardAggregatorAVS.sol";
import {IPositionValidation} from "./interfaces/IPositionValidation.sol";
import {CrossChainAggregation} from "./libraries/CrossChainAggregation.sol";
import {TierManagement} from "./libraries/TierManagement.sol";
import {RewardScheduling} from "./libraries/RewardScheduling.sol";
import {Constants} from "../utils/Constants.sol";
import {Events} from "../utils/Events.sol";
import {Errors} from "../utils/Errors.sol";

/**
 * @title RewardAggregatorAVS
 * @notice EigenLayer AVS Service Manager for cross-chain reward aggregation
 * @dev Manages reward aggregation, tier calculations, and cross-chain distribution
 */
contract RewardAggregatorAVS is ServiceManagerBase, IRewardAggregatorAVS {
    using CrossChainAggregation for mapping(address => CrossChainAggregation.UserRewards);
    using TierManagement for mapping(address => TierManagement.UserTier);
    using RewardScheduling for mapping(bytes32 => RewardScheduling.AggregationTask);

    /// @notice Global reward state
    GlobalRewardState public globalState;
    
    /// @notice Aggregation tasks
    mapping(bytes32 => RewardScheduling.AggregationTask) public aggregationTasks;
    
    /// @notice User reward data
    mapping(address => CrossChainAggregation.UserRewards) public userRewards;
    
    /// @notice User tier data
    mapping(address => TierManagement.UserTier) public userTiers;
    
    /// @notice Chain reward data
    mapping(uint256 => ChainRewards) public chainRewards;
    
    /// @notice Operator data
    mapping(address => OperatorData) public operators;
    
    /// @notice Authorized reward flow hooks
    mapping(address => bool) public authorizedHooks;

    /// @notice Constants
    uint256 public constant AGGREGATION_DEADLINE = 1 hours;
    uint256 public constant CLAIM_INTERVAL = 1 days;
    uint256 public constant DIAMOND_THRESHOLD = 1000e18;
    uint256 public constant PLATINUM_THRESHOLD = 500e18;
    uint256 public constant GOLD_THRESHOLD = 100e18;

    /// @notice Events
    event RewardRecorded(address indexed user, uint256 amount, uint8 rewardType);
    event RewardsAggregated(bytes32 indexed taskId, uint256 userCount, uint256 totalAmount);
    event TierUpdated(address indexed user, uint8 newTier);
    event OperatorRegistered(address indexed operator, uint256 stake);
    event OperatorDeregistered(address indexed operator);
    event OperatorSlashed(address indexed operator, uint256 amount, string reason);

    /// @notice Errors
    error InvalidRewardAmount();
    error InvalidUser();
    error UnauthorizedHook();
    error TaskNotFound();
    error TaskExpired();
    error InsufficientOperators();
    error InvalidTaskResponse();

    /// @notice Modifiers
    modifier onlyRewardFlowHook() {
        if (!authorizedHooks[msg.sender]) revert UnauthorizedHook();
        _;
    }

    modifier onlyOperator() {
        if (!operators[msg.sender].isActive) revert Unauthorized();
        _;
    }

    constructor(
        address _avsDirectory,
        address _delegationManager
    ) ServiceManagerBase(_avsDirectory, _delegationManager) {}

    /// @notice Record a reward entry
    function recordReward(
        RewardEntry calldata entry
    ) external override onlyRewardFlowHook {
        if (entry.amount == 0) revert InvalidRewardAmount();
        if (entry.user == address(0)) revert InvalidUser();
        
        // Update user rewards
        userRewards[entry.user].totalEarned += entry.amount;
        userRewards[entry.user].pendingClaim += entry.amount;
        
        // Update tier if necessary
        _updateUserTier(entry.user);
        
        // Check if aggregation should be triggered
        if (_shouldTriggerAggregation(entry.user)) {
            _scheduleRewardAggregation(entry.user);
        }
        
        emit RewardRecorded(entry.user, entry.amount, uint8(entry.rewardType));
    }

    /// @notice Aggregate user rewards
    function aggregateUserRewards(
        address[] calldata users,
        uint256[] calldata amounts,
        uint256[] calldata targetChains
    ) external override onlyOperator {
        if (users.length != amounts.length || amounts.length != targetChains.length) {
            revert Errors.ArrayLengthMismatch();
        }
        
        // Create aggregation task
        bytes32 taskId = keccak256(abi.encode(
            users, amounts, targetChains, block.timestamp
        ));
        
        aggregationTasks[taskId] = RewardScheduling.AggregationTask({
            taskId: uint256(taskId),
            users: users,
            amounts: amounts,
            targetChains: targetChains,
            deadline: block.timestamp + AGGREGATION_DEADLINE,
            status: RewardScheduling.TaskStatus.PENDING,
            createdAt: block.timestamp
        });
        
        // Execute distribution via cross-chain
        for (uint256 i = 0; i < users.length; i++) {
            if (amounts[i] >= userRewards[users[i]].claimThreshold) {
                _executeRewardDistribution(users[i], amounts[i], targetChains[i]);
            }
        }
        
        aggregationTasks[taskId].status = RewardScheduling.TaskStatus.COMPLETED;
        globalState.lastAggregationBlock = block.number;
        
        emit RewardsAggregated(taskId, users.length, _sum(amounts));
    }

    /// @notice Trigger reward distribution for a user
    function triggerRewardDistribution(
        address user,
        uint256 amount
    ) external override onlyRewardFlowHook {
        if (amount < userRewards[user].claimThreshold) {
            revert InsufficientRewardThreshold();
        }
        
        userRewards[user].pendingClaim -= amount;
        userRewards[user].totalClaimed += amount;
        userRewards[user].lastClaimTime = block.timestamp;
        
        // Trigger cross-chain distribution
        _executeRewardDistribution(user, amount, userRewards[user].preferredChain);
    }

    /// @notice Set user preferences
    function setUserPreferences(
        uint256 preferredChain,
        uint256 claimThreshold,
        uint256 claimFrequency
    ) external override {
        userRewards[msg.sender].preferredChain = preferredChain;
        userRewards[msg.sender].claimThreshold = claimThreshold;
        userRewards[msg.sender].claimFrequency = claimFrequency;
        userRewards[msg.sender].lastUpdate = block.timestamp;
    }

    /// @notice Register operator
    function registerOperator(
        address operator,
        uint256 stake
    ) external override onlyOwner {
        operators[operator] = OperatorData({
            operator: operator,
            stake: stake,
            isActive: true,
            registeredAt: block.timestamp,
            lastActivity: block.timestamp
        });
        
        emit OperatorRegistered(operator, stake);
    }

    /// @notice Deregister operator
    function deregisterOperator(address operator) external override onlyOwner {
        operators[operator].isActive = false;
        emit OperatorDeregistered(operator);
    }

    /// @notice Slash operator
    function slashOperator(
        address operator,
        uint256 amount,
        string calldata reason
    ) external override onlyOwner {
        if (amount > operators[operator].stake) {
            amount = operators[operator].stake;
        }
        
        operators[operator].stake -= amount;
        operators[operator].isActive = false;
        
        emit OperatorSlashed(operator, amount, reason);
    }

    /// @notice Authorize reward flow hook
    function authorizeHook(address hook) external onlyOwner {
        authorizedHooks[hook] = true;
    }

    /// @notice Revoke hook authorization
    function revokeHook(address hook) external onlyOwner {
        authorizedHooks[hook] = false;
    }

    /// @notice Check if aggregation should be triggered
    function _shouldTriggerAggregation(address user) internal view returns (bool) {
        CrossChainAggregation.UserRewards memory userReward = userRewards[user];
        
        return userReward.pendingClaim >= userReward.claimThreshold ||
               block.timestamp - userReward.lastClaimTime >= CLAIM_INTERVAL;
    }

    /// @notice Schedule reward aggregation
    function _scheduleRewardAggregation(address user) internal {
        // Implementation for scheduling aggregation
        // This would typically involve creating a task for operators
    }

    /// @notice Update user tier
    function _updateUserTier(address user) internal {
        CrossChainAggregation.UserRewards storage userReward = userRewards[user];
        uint256 totalEarned = userReward.totalEarned;
        
        uint8 newTier;
        if (totalEarned >= DIAMOND_THRESHOLD) {
            newTier = 4; // Diamond
        } else if (totalEarned >= PLATINUM_THRESHOLD) {
            newTier = 3; // Platinum
        } else if (totalEarned >= GOLD_THRESHOLD) {
            newTier = 2; // Gold
        } else {
            newTier = 1; // Base
        }
        
        if (userReward.currentTier != newTier) {
            userReward.currentTier = newTier;
            emit TierUpdated(user, newTier);
        }
    }

    /// @notice Execute reward distribution
    function _executeRewardDistribution(
        address user,
        uint256 amount,
        uint256 targetChain
    ) internal {
        // Implementation for cross-chain distribution
        // This would typically involve calling a cross-chain bridge
    }

    /// @notice Sum array of amounts
    function _sum(uint256[] memory amounts) internal pure returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
        return total;
    }

    /// @notice Get user reward data
    function getUserRewards(address user) external view returns (CrossChainAggregation.UserRewards memory) {
        return userRewards[user];
    }

    /// @notice Get user tier data
    function getUserTier(address user) external view returns (TierManagement.UserTier memory) {
        return userTiers[user];
    }

    /// @notice Get aggregation task
    function getAggregationTask(bytes32 taskId) external view returns (RewardScheduling.AggregationTask memory) {
        return aggregationTasks[taskId];
    }

    /// @notice Get operator data
    function getOperator(address operator) external view returns (OperatorData memory) {
        return operators[operator];
    }

    /// @notice Get global state
    function getGlobalState() external view returns (GlobalRewardState memory) {
        return globalState;
    }
}
