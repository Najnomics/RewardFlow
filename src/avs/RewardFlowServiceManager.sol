// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ECDSAServiceManagerBase} from "@eigenlayer-middleware/src/unaudited/ECDSAServiceManagerBase.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {IServiceManager} from "@eigenlayer-middleware/src/interfaces/IServiceManager.sol";
import {ECDSAUpgradeable} from "@openzeppelin-upgrades/contracts/utils/cryptography/ECDSAUpgradeable.sol";
import {IERC1271Upgradeable} from "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";
import {IRewardFlowServiceManager} from "./interfaces/IRewardFlowServiceManager.sol";

/**
 * @title RewardFlowServiceManager
 * @notice AVS Service Manager for RewardFlow cross-chain reward aggregation
 * @dev Handles reward aggregation tasks and operator responses
 */
contract RewardFlowServiceManager is ECDSAServiceManagerBase, IRewardFlowServiceManager {
    using ECDSAUpgradeable for bytes32;

    /// @notice Latest task number
    uint32 public latestTaskNum;

    /// @notice Mapping of task indices to task hashes
    mapping(uint32 => bytes32) public allTaskHashes;

    /// @notice Mapping of task indices to task responses
    mapping(address => mapping(uint32 => bytes)) public allTaskResponses;

    /// @notice Mapping of task indices to task status
    mapping(uint32 => bool) public taskWasResponded;

    /// @notice Max interval in blocks for responding to a task
    uint32 public immutable MAX_RESPONSE_INTERVAL_BLOCKS;

    /// @notice Reward aggregation tasks
    mapping(uint32 => RewardAggregationTask) public aggregationTasks;

    /// @notice Modifier to ensure only operators can call
    modifier onlyOperator() {
        require(
            ECDSAStakeRegistry(stakeRegistry).operatorRegistered(msg.sender),
            "Operator must be the caller"
        );
        _;
    }

    constructor(
        address _avsDirectory,
        address _stakeRegistry,
        address _rewardsCoordinator,
        address _delegationManager,
        address _allocationManager,
        uint32 _maxResponseIntervalBlocks
    )
        ECDSAServiceManagerBase(
            _avsDirectory,
            _stakeRegistry,
            _rewardsCoordinator,
            _delegationManager,
            _allocationManager
        )
    {
        MAX_RESPONSE_INTERVAL_BLOCKS = _maxResponseIntervalBlocks;
    }

    function initialize(address initialOwner, address _rewardsInitiator) external initializer {
        __ServiceManagerBase_init(initialOwner, _rewardsInitiator);
    }

    /// @notice Create a new reward aggregation task
    function createRewardAggregationTask(
        address[] calldata users,
        uint256[] calldata amounts,
        uint256[] calldata targetChains
    ) external returns (RewardAggregationTask memory) {
        require(users.length == amounts.length, "Array length mismatch");
        require(amounts.length == targetChains.length, "Array length mismatch");

        RewardAggregationTask memory newTask = RewardAggregationTask({
            taskId: latestTaskNum,
            users: users,
            amounts: amounts,
            targetChains: targetChains,
            taskCreatedBlock: uint32(block.number),
            totalAmount: _sum(amounts),
            status: TaskStatus.PENDING
        });

        // Store task hash
        allTaskHashes[latestTaskNum] = keccak256(abi.encode(newTask));
        
        // Store aggregation task
        aggregationTasks[latestTaskNum] = newTask;

        emit RewardAggregationTaskCreated(latestTaskNum, newTask);
        latestTaskNum = latestTaskNum + 1;

        return newTask;
    }

    /// @notice Respond to a reward aggregation task
    function respondToRewardAggregationTask(
        RewardAggregationTask calldata task,
        uint32 referenceTaskIndex,
        bytes memory signature
    ) external {
        // Check that the task is valid and hasn't been responded to yet
        require(
            keccak256(abi.encode(task)) == allTaskHashes[referenceTaskIndex],
            "Supplied task does not match the one recorded in the contract"
        );
        require(
            block.number <= task.taskCreatedBlock + MAX_RESPONSE_INTERVAL_BLOCKS,
            "Task response time has already expired"
        );

        // The message that was signed (aggregated reward data)
        bytes32 messageHash = keccak256(abi.encode(
            task.users,
            task.amounts,
            task.targetChains,
            task.totalAmount
        ));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        bytes4 magicValue = IERC1271Upgradeable.isValidSignature.selector;

        // Decode the signature data to get operators and their signatures
        (address[] memory operators, bytes[] memory signatures, uint32 referenceBlock) =
            abi.decode(signature, (address[], bytes[], uint32));

        // Check that referenceBlock matches task creation block
        require(
            referenceBlock == task.taskCreatedBlock,
            "Reference block must match task creation block"
        );

        // Store each operator's signature
        for (uint256 i = 0; i < operators.length; i++) {
            // Check that this operator hasn't already responded
            require(
                allTaskResponses[operators[i]][referenceTaskIndex].length == 0,
                "Operator has already responded to the task"
            );

            // Store the operator's signature
            allTaskResponses[operators[i]][referenceTaskIndex] = signatures[i];

            // Emit event for this operator
            emit TaskResponded(referenceTaskIndex, task, operators[i]);
        }

        taskWasResponded[referenceTaskIndex] = true;
        aggregationTasks[referenceTaskIndex].status = TaskStatus.COMPLETED;

        // Verify all signatures at once
        bytes4 isValidSignatureResult =
            ECDSAStakeRegistry(stakeRegistry).isValidSignature(ethSignedMessageHash, signature);

        require(magicValue == isValidSignatureResult, "Invalid signature");
    }

    /// @notice Slash operator for not responding to task
    function slashOperator(
        RewardAggregationTask calldata task,
        uint32 referenceTaskIndex,
        address operator
    ) external {
        // Check that the task is valid and hasn't been responded to yet
        require(
            keccak256(abi.encode(task)) == allTaskHashes[referenceTaskIndex],
            "Supplied task does not match the one recorded in the contract"
        );
        require(!taskWasResponded[referenceTaskIndex], "Task has already been responded to");
        require(
            allTaskResponses[operator][referenceTaskIndex].length == 0,
            "Operator has already responded to the task"
        );
        require(
            block.number > task.taskCreatedBlock + MAX_RESPONSE_INTERVAL_BLOCKS,
            "Task response time has not expired yet"
        );

        // Check operator was registered when task was created
        uint256 operatorWeight = ECDSAStakeRegistry(stakeRegistry).getOperatorWeightAtBlock(
            operator, task.taskCreatedBlock
        );
        require(operatorWeight > 0, "Operator was not registered when task was created");

        // Mark operator as slashed
        allTaskResponses[operator][referenceTaskIndex] = "slashed";

        // TODO: Implement actual slashing logic
        emit OperatorSlashed(operator, referenceTaskIndex, "Failed to respond to task");
    }

    /// @notice Get aggregation task
    function getAggregationTask(uint32 taskId) external view returns (RewardAggregationTask memory) {
        return aggregationTasks[taskId];
    }

    /// @notice Check if task was responded to
    function isTaskResponded(uint32 taskId) external view returns (bool) {
        return taskWasResponded[taskId];
    }

    /// @notice Sum array of amounts
    function _sum(uint256[] memory amounts) internal pure returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
        return total;
    }

    // Required by IServiceManager interface
    function addPendingAdmin(address admin) external onlyOwner {}
    function removePendingAdmin(address pendingAdmin) external onlyOwner {}
    function removeAdmin(address admin) external onlyOwner {}
    function setAppointee(address appointee, address target, bytes4 selector) external onlyOwner {}
    function removeAppointee(address appointee, address target, bytes4 selector) external onlyOwner {}
    function deregisterOperatorFromOperatorSets(address operator, uint32[] memory operatorSetIds) external {}
}
