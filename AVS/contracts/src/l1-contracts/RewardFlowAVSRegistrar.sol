// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {IAllocationManager} from "@eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {IKeyRegistrar} from "@eigenlayer-contracts/src/contracts/interfaces/IKeyRegistrar.sol";
import {IPermissionController} from "@eigenlayer-contracts/src/contracts/interfaces/IPermissionController.sol";
import {TaskAVSRegistrarBase} from "@eigenlayer-middleware/src/avs/task/TaskAVSRegistrarBase.sol";

/**
 * @title RewardFlowAVSRegistrar
 * @dev AVS Registrar for RewardFlow - manages operator registration and configuration
 * @notice This contract handles operator registration for the RewardFlow AVS system
 * which processes Uniswap V4 hook rewards and cross-chain distribution
 */
contract RewardFlowAVSRegistrar is TaskAVSRegistrarBase {
    
    // Events
    event RewardFlowOperatorRegistered(address indexed operator, uint256 stake);
    event RewardFlowOperatorDeregistered(address indexed operator);
    event RewardFlowConfigUpdated(bytes32 indexed configKey, bytes configValue);
    
    // State variables
    uint256 public constant MIN_STAKE_AMOUNT = 1 ether; // Minimum 1 ETH stake
    uint256 public constant MAX_OPERATORS = 1000;       // Maximum number of operators
    
    uint256 public totalOperators;
    uint256 public totalStake;
    
    mapping(address => bool) public isRewardFlowOperator;
    mapping(address => uint256) public operatorStake;
    mapping(bytes32 => bytes) public rewardFlowConfig;
    
    /**
     * @dev Constructor that passes parameters to parent TaskAVSRegistrarBase
     * @param _allocationManager The AllocationManager contract address
     * @param _keyRegistrar The KeyRegistrar contract address
     * @param _permissionController The PermissionController contract address
     */
    constructor(
        IAllocationManager _allocationManager,
        IKeyRegistrar _keyRegistrar,
        IPermissionController _permissionController
    ) TaskAVSRegistrarBase(_allocationManager, _keyRegistrar, _permissionController) {}

    /**
     * @dev Initializer that calls parent initializer
     * @param _avs The address of the AVS
     * @param _owner The owner of the contract
     * @param _initialConfig The initial AVS configuration
     */
    function initialize(address _avs, address _owner, AvsConfig memory _initialConfig) external initializer {
        __TaskAVSRegistrarBase_init(_avs, _owner, _initialConfig);
        
        // Initialize RewardFlow specific configuration
        _setRewardFlowConfig("min_reward_amount", abi.encode(0.001 ether));
        _setRewardFlowConfig("max_reward_amount", abi.encode(100 ether));
        _setRewardFlowConfig("task_fee", abi.encode(0.0001 ether));
    }
    
    /**
     * @dev Registers an operator for RewardFlow AVS with custom validation
     * @param operator The operator address to register
     * @param stake The stake amount
     */
    function registerRewardFlowOperator(address operator, uint256 stake) external onlyOwner {
        require(operator != address(0), "Invalid operator");
        require(stake >= MIN_STAKE_AMOUNT, "Insufficient stake");
        require(totalOperators < MAX_OPERATORS, "Max operators reached");
        require(!isRewardFlowOperator[operator], "Already registered");
        
        isRewardFlowOperator[operator] = true;
        operatorStake[operator] = stake;
        totalOperators++;
        totalStake += stake;
        
        emit RewardFlowOperatorRegistered(operator, stake);
    }
    
    /**
     * @dev Deregisters an operator from RewardFlow AVS
     * @param operator The operator address to deregister
     */
    function deregisterRewardFlowOperator(address operator) external onlyOwner {
        require(operator != address(0), "Invalid operator");
        require(isRewardFlowOperator[operator], "Not registered");
        
        uint256 stake = operatorStake[operator];
        isRewardFlowOperator[operator] = false;
        operatorStake[operator] = 0;
        totalOperators--;
        totalStake -= stake;
        
        emit RewardFlowOperatorDeregistered(operator);
    }
    
    /**
     * @dev Updates RewardFlow configuration
     * @param configKey The configuration key
     * @param configValue The configuration value
     */
    function updateRewardFlowConfig(bytes32 configKey, bytes memory configValue) external onlyOwner {
        require(configValue.length > 0, "Empty config value");
        
        _setRewardFlowConfig(configKey, configValue);
        emit RewardFlowConfigUpdated(configKey, configValue);
    }
    
    /**
     * @dev Internal function to set RewardFlow configuration
     * @param configKey The configuration key
     * @param configValue The configuration value
     */
    function _setRewardFlowConfig(bytes32 configKey, bytes memory configValue) internal {
        rewardFlowConfig[configKey] = configValue;
    }
    
    /**
     * @dev Gets RewardFlow configuration
     * @param configKey The configuration key
     * @return The configuration value
     */
    function getRewardFlowConfig(bytes32 configKey) external view returns (bytes memory) {
        return rewardFlowConfig[configKey];
    }
    
    /**
     * @dev Gets RewardFlow statistics
     * @return operators Total number of operators
     * @return stake Total stake amount
     * @return avgStake Average stake per operator
     */
    function getRewardFlowStats() external view returns (uint256 operators, uint256 stake, uint256 avgStake) {
        operators = totalOperators;
        stake = totalStake;
        avgStake = totalOperators > 0 ? totalStake / totalOperators : 0;
    }
    
    /**
     * @dev Checks if an operator is registered for RewardFlow
     * @param operator The operator address to check
     * @return Whether the operator is registered
     */
    function isOperatorRegistered(address operator) external view returns (bool) {
        return isRewardFlowOperator[operator];
    }
    
    /**
     * @dev Gets the stake amount for an operator
     * @param operator The operator address
     * @return The stake amount
     */
    function getOperatorStake(address operator) external view returns (uint256) {
        return operatorStake[operator];
    }
}