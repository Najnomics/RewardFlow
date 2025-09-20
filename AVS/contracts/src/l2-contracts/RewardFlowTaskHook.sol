// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IAVSTaskHook} from "@eigenlayer-contracts/src/contracts/interfaces/IAVSTaskHook.sol";
import {ITaskMailboxTypes} from "@eigenlayer-contracts/src/contracts/interfaces/ITaskMailbox.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title RewardFlowTaskHook
 * @dev Task hook for RewardFlow AVS - validates and processes reward distribution tasks
 * @notice This contract handles task validation and processing for the RewardFlow system
 * which manages Uniswap V4 hook rewards and cross-chain distribution via EigenLayer AVS
 */
contract RewardFlowTaskHook is IAVSTaskHook, Ownable {
    
    // Events
    event RewardTaskCreated(bytes32 indexed taskHash, address indexed user, uint256 amount);
    event RewardTaskProcessed(bytes32 indexed taskHash, bool success);
    event TaskFeeUpdated(uint96 newFee);
    
    // State variables
    uint96 public constant MIN_REWARD_AMOUNT = 0.001 ether; // 0.001 ETH minimum reward
    uint96 public constant MAX_REWARD_AMOUNT = 100 ether;   // 100 ETH maximum reward
    uint96 public taskFee = 0.0001 ether; // 0.0001 ETH task fee
    uint256 public totalTasksProcessed;
    uint256 public totalRewardsDistributed;
    
    // Task tracking
    mapping(bytes32 => bool) public processedTasks;
    mapping(address => uint256) public userTaskCount;
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Validates reward distribution task creation
     * @param caller The address creating the task
     * @param taskParams The task parameters containing reward details
     */
    function validatePreTaskCreation(
        address caller,
        ITaskMailboxTypes.TaskParams memory taskParams
    ) external view override {
        require(caller != address(0), "Invalid caller");
        require(taskParams.data.length > 0, "Empty task data");
        
        // Decode task data to validate reward parameters
        (address user, uint256 amount, uint256 chainId) = abi.decode(taskParams.data, (address, uint256, uint256));
        
        require(user != address(0), "Invalid user address");
        require(amount >= MIN_REWARD_AMOUNT, "Reward too small");
        require(amount <= MAX_REWARD_AMOUNT, "Reward too large");
        require(chainId > 0, "Invalid chain ID");
    }

    /**
     * @dev Handles post task creation logic
     * @param taskHash The hash of the created task
     */
    function handlePostTaskCreation(
        bytes32 taskHash
    ) external override {
        require(taskHash != bytes32(0), "Invalid task hash");
        
        totalTasksProcessed++;
        emit RewardTaskCreated(taskHash, msg.sender, 0); // Amount will be set during processing
    }

    /**
     * @dev Validates task result submission
     * @param caller The address submitting the result
     * @param taskHash The hash of the task
     * @param cert The certificate data
     * @param result The task result data
     */
    function validatePreTaskResultSubmission(
        address caller,
        bytes32 taskHash,
        bytes memory cert,
        bytes memory result
    ) external view override {
        require(caller != address(0), "Invalid caller");
        require(taskHash != bytes32(0), "Invalid task hash");
        require(cert.length > 0, "Empty certificate");
        require(result.length > 0, "Empty result");
        require(!processedTasks[taskHash], "Task already processed");
    }

    /**
     * @dev Handles post task result submission
     * @param taskHash The hash of the processed task
     */
    function handlePostTaskResultSubmission(
        bytes32 taskHash
    ) external override {
        require(taskHash != bytes32(0), "Invalid task hash");
        require(!processedTasks[taskHash], "Task already processed");
        
        processedTasks[taskHash] = true;
        userTaskCount[msg.sender]++;
        
        emit RewardTaskProcessed(taskHash, true);
    }

    /**
     * @dev Calculates the fee for a task
     * @param taskParams The task parameters
     * @return The calculated task fee
     */
    function calculateTaskFee(
        ITaskMailboxTypes.TaskParams memory taskParams
    ) external view override returns (uint96) {
        // Base fee for all reward distribution tasks
        return taskFee;
    }
    
    /**
     * @dev Updates the task fee (owner only)
     * @param newFee The new task fee
     */
    function setTaskFee(uint96 newFee) external onlyOwner {
        require(newFee > 0, "Fee must be positive");
        taskFee = newFee;
        emit TaskFeeUpdated(newFee);
    }
    
    /**
     * @dev Gets task processing statistics
     * @return tasksProcessed Total number of tasks processed
     * @return rewardsDistributed Total rewards distributed
     * @return currentFee Current task fee
     */
    function getStats() external view returns (uint256 tasksProcessed, uint256 rewardsDistributed, uint96 currentFee) {
        return (totalTasksProcessed, totalRewardsDistributed, taskFee);
    }
    
    /**
     * @dev Checks if a task has been processed
     * @param taskHash The task hash to check
     * @return Whether the task has been processed
     */
    function isTaskProcessed(bytes32 taskHash) external view returns (bool) {
        return processedTasks[taskHash];
    }
}