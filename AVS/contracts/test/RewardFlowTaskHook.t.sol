// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {RewardFlowTaskHook} from "../src/l2-contracts/RewardFlowTaskHook.sol";
import {ITaskMailboxTypes} from "@eigenlayer-contracts/src/contracts/interfaces/ITaskMailbox.sol";

/**
 * @title RewardFlowTaskHookTest
 * @dev Test suite for RewardFlowTaskHook contract
 * @notice Tests reward distribution task validation and processing
 */
contract RewardFlowTaskHookTest is Test {
    RewardFlowTaskHook public rewardFlowTaskHook;
    address public owner;
    address public user1;
    address public user2;

    event RewardTaskCreated(bytes32 indexed taskHash, address indexed user, uint256 amount);
    event RewardTaskProcessed(bytes32 indexed taskHash, bool success);
    event TaskFeeUpdated(uint96 newFee);

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.prank(owner);
        rewardFlowTaskHook = new RewardFlowTaskHook();
    }

    function testConstructor() public {
        assertEq(rewardFlowTaskHook.owner(), owner);
        assertEq(rewardFlowTaskHook.taskFee(), 0.0001 ether);
        assertEq(rewardFlowTaskHook.MIN_REWARD_AMOUNT(), 0.001 ether);
        assertEq(rewardFlowTaskHook.MAX_REWARD_AMOUNT(), 100 ether);
        assertEq(rewardFlowTaskHook.totalTasksProcessed(), 0);
        assertEq(rewardFlowTaskHook.totalRewardsDistributed(), 0);
    }

    function testValidatePreTaskCreation() public {
        ITaskMailboxTypes.TaskParams memory taskParams = ITaskMailboxTypes.TaskParams({
            taskType: 1,
            data: abi.encode(user1, 1 ether, 1) // user, amount, chainId
        });

        // Should not revert with valid parameters
        rewardFlowTaskHook.validatePreTaskCreation(user1, taskParams);
    }

    function testValidatePreTaskCreationInvalidCaller() public {
        ITaskMailboxTypes.TaskParams memory taskParams = ITaskMailboxTypes.TaskParams({
            taskType: 1,
            data: abi.encode(user1, 1 ether, 1)
        });

        vm.expectRevert("Invalid caller");
        rewardFlowTaskHook.validatePreTaskCreation(address(0), taskParams);
    }

    function testValidatePreTaskCreationEmptyData() public {
        ITaskMailboxTypes.TaskParams memory taskParams = ITaskMailboxTypes.TaskParams({
            taskType: 1,
            data: ""
        });

        vm.expectRevert("Empty task data");
        rewardFlowTaskHook.validatePreTaskCreation(user1, taskParams);
    }

    function testValidatePreTaskCreationInvalidUser() public {
        ITaskMailboxTypes.TaskParams memory taskParams = ITaskMailboxTypes.TaskParams({
            taskType: 1,
            data: abi.encode(address(0), 1 ether, 1)
        });

        vm.expectRevert("Invalid user address");
        rewardFlowTaskHook.validatePreTaskCreation(user1, taskParams);
    }

    function testValidatePreTaskCreationRewardTooSmall() public {
        ITaskMailboxTypes.TaskParams memory taskParams = ITaskMailboxTypes.TaskParams({
            taskType: 1,
            data: abi.encode(user1, 0.0001 ether, 1) // Below minimum
        });

        vm.expectRevert("Reward too small");
        rewardFlowTaskHook.validatePreTaskCreation(user1, taskParams);
    }

    function testValidatePreTaskCreationRewardTooLarge() public {
        ITaskMailboxTypes.TaskParams memory taskParams = ITaskMailboxTypes.TaskParams({
            taskType: 1,
            data: abi.encode(user1, 101 ether, 1) // Above maximum
        });

        vm.expectRevert("Reward too large");
        rewardFlowTaskHook.validatePreTaskCreation(user1, taskParams);
    }

    function testValidatePreTaskCreationInvalidChainId() public {
        ITaskMailboxTypes.TaskParams memory taskParams = ITaskMailboxTypes.TaskParams({
            taskType: 1,
            data: abi.encode(user1, 1 ether, 0)
        });

        vm.expectRevert("Invalid chain ID");
        rewardFlowTaskHook.validatePreTaskCreation(user1, taskParams);
    }

    function testHandlePostTaskCreation() public {
        bytes32 taskHash = keccak256("test-task");
        uint256 initialTasks = rewardFlowTaskHook.totalTasksProcessed();

        vm.expectEmit(true, true, false, true);
        emit RewardTaskCreated(taskHash, user1, 0);

        rewardFlowTaskHook.handlePostTaskCreation(taskHash);

        assertEq(rewardFlowTaskHook.totalTasksProcessed(), initialTasks + 1);
    }

    function testHandlePostTaskCreationInvalidHash() public {
        vm.expectRevert("Invalid task hash");
        rewardFlowTaskHook.handlePostTaskCreation(bytes32(0));
    }

    function testValidatePreTaskResultSubmission() public {
        bytes32 taskHash = keccak256("test-task");
        bytes memory cert = "certificate";
        bytes memory result = "result";

        // Should not revert with valid parameters
        rewardFlowTaskHook.validatePreTaskResultSubmission(user1, taskHash, cert, result);
    }

    function testValidatePreTaskResultSubmissionInvalidCaller() public {
        bytes32 taskHash = keccak256("test-task");
        bytes memory cert = "certificate";
        bytes memory result = "result";

        vm.expectRevert("Invalid caller");
        rewardFlowTaskHook.validatePreTaskResultSubmission(address(0), taskHash, cert, result);
    }

    function testValidatePreTaskResultSubmissionInvalidHash() public {
        bytes memory cert = "certificate";
        bytes memory result = "result";

        vm.expectRevert("Invalid task hash");
        rewardFlowTaskHook.validatePreTaskResultSubmission(user1, bytes32(0), cert, result);
    }

    function testValidatePreTaskResultSubmissionEmptyCert() public {
        bytes32 taskHash = keccak256("test-task");
        bytes memory result = "result";

        vm.expectRevert("Empty certificate");
        rewardFlowTaskHook.validatePreTaskResultSubmission(user1, taskHash, "", result);
    }

    function testValidatePreTaskResultSubmissionEmptyResult() public {
        bytes32 taskHash = keccak256("test-task");
        bytes memory cert = "certificate";

        vm.expectRevert("Empty result");
        rewardFlowTaskHook.validatePreTaskResultSubmission(user1, taskHash, cert, "");
    }

    function testValidatePreTaskResultSubmissionAlreadyProcessed() public {
        bytes32 taskHash = keccak256("test-task");
        bytes memory cert = "certificate";
        bytes memory result = "result";

        // Process the task first
        rewardFlowTaskHook.handlePostTaskResultSubmission(taskHash);

        vm.expectRevert("Task already processed");
        rewardFlowTaskHook.validatePreTaskResultSubmission(user1, taskHash, cert, result);
    }

    function testHandlePostTaskResultSubmission() public {
        bytes32 taskHash = keccak256("test-task");
        uint256 initialUserTasks = rewardFlowTaskHook.userTaskCount(user1);

        vm.expectEmit(true, true, false, true);
        emit RewardTaskProcessed(taskHash, true);

        vm.prank(user1);
        rewardFlowTaskHook.handlePostTaskResultSubmission(taskHash);

        assertTrue(rewardFlowTaskHook.processedTasks(taskHash));
        assertEq(rewardFlowTaskHook.userTaskCount(user1), initialUserTasks + 1);
    }

    function testHandlePostTaskResultSubmissionInvalidHash() public {
        vm.expectRevert("Invalid task hash");
        rewardFlowTaskHook.handlePostTaskResultSubmission(bytes32(0));
    }

    function testHandlePostTaskResultSubmissionAlreadyProcessed() public {
        bytes32 taskHash = keccak256("test-task");

        // Process the task first
        rewardFlowTaskHook.handlePostTaskResultSubmission(taskHash);

        vm.expectRevert("Task already processed");
        rewardFlowTaskHook.handlePostTaskResultSubmission(taskHash);
    }

    function testCalculateTaskFee() public {
        ITaskMailboxTypes.TaskParams memory taskParams = ITaskMailboxTypes.TaskParams({
            taskType: 1,
            data: abi.encode(user1, 1 ether, 1)
        });

        uint96 fee = rewardFlowTaskHook.calculateTaskFee(taskParams);
        assertEq(fee, 0.0001 ether);
    }

    function testSetTaskFee() public {
        uint96 newFee = 0.0002 ether;

        vm.expectEmit(true, false, false, true);
        emit TaskFeeUpdated(newFee);

        vm.prank(owner);
        rewardFlowTaskHook.setTaskFee(newFee);

        assertEq(rewardFlowTaskHook.taskFee(), newFee);
    }

    function testSetTaskFeeZero() public {
        vm.prank(owner);
        vm.expectRevert("Fee must be positive");
        rewardFlowTaskHook.setTaskFee(0);
    }

    function testSetTaskFeeNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        rewardFlowTaskHook.setTaskFee(0.0002 ether);
    }

    function testGetStats() public {
        (uint256 tasksProcessed, uint256 rewardsDistributed, uint96 currentFee) = rewardFlowTaskHook.getStats();
        
        assertEq(tasksProcessed, 0);
        assertEq(rewardsDistributed, 0);
        assertEq(currentFee, 0.0001 ether);
    }

    function testIsTaskProcessed() public {
        bytes32 taskHash = keccak256("test-task");

        assertFalse(rewardFlowTaskHook.isTaskProcessed(taskHash));

        rewardFlowTaskHook.handlePostTaskResultSubmission(taskHash);

        assertTrue(rewardFlowTaskHook.isTaskProcessed(taskHash));
    }

    function testMultipleTasks() public {
        bytes32 taskHash1 = keccak256("task-1");
        bytes32 taskHash2 = keccak256("task-2");
        bytes32 taskHash3 = keccak256("task-3");

        // Process multiple tasks
        rewardFlowTaskHook.handlePostTaskCreation(taskHash1);
        rewardFlowTaskHook.handlePostTaskCreation(taskHash2);
        rewardFlowTaskHook.handlePostTaskCreation(taskHash3);

        assertEq(rewardFlowTaskHook.totalTasksProcessed(), 3);

        // Process results
        vm.prank(user1);
        rewardFlowTaskHook.handlePostTaskResultSubmission(taskHash1);

        vm.prank(user2);
        rewardFlowTaskHook.handlePostTaskResultSubmission(taskHash2);

        vm.prank(user1);
        rewardFlowTaskHook.handlePostTaskResultSubmission(taskHash3);

        assertEq(rewardFlowTaskHook.userTaskCount(user1), 2);
        assertEq(rewardFlowTaskHook.userTaskCount(user2), 1);

        assertTrue(rewardFlowTaskHook.isTaskProcessed(taskHash1));
        assertTrue(rewardFlowTaskHook.isTaskProcessed(taskHash2));
        assertTrue(rewardFlowTaskHook.isTaskProcessed(taskHash3));
    }

    function testFuzzValidatePreTaskCreation(
        address caller,
        address user,
        uint256 amount,
        uint256 chainId
    ) public {
        vm.assume(caller != address(0));
        vm.assume(user != address(0));
        vm.assume(amount >= 0.001 ether && amount <= 100 ether);
        vm.assume(chainId > 0);

        ITaskMailboxTypes.TaskParams memory taskParams = ITaskMailboxTypes.TaskParams({
            taskType: 1,
            data: abi.encode(user, amount, chainId)
        });

        // Should not revert with valid fuzzed parameters
        rewardFlowTaskHook.validatePreTaskCreation(caller, taskParams);
    }

    function testFuzzCalculateTaskFee(
        address user,
        uint256 amount,
        uint256 chainId
    ) public {
        vm.assume(amount > 0);

        ITaskMailboxTypes.TaskParams memory taskParams = ITaskMailboxTypes.TaskParams({
            taskType: 1,
            data: abi.encode(user, amount, chainId)
        });

        uint96 fee = rewardFlowTaskHook.calculateTaskFee(taskParams);
        assertEq(fee, 0.0001 ether); // Should always be the same fee
    }

    function testFuzzSetTaskFee(uint96 fee) public {
        vm.assume(fee > 0);

        vm.prank(owner);
        rewardFlowTaskHook.setTaskFee(fee);

        assertEq(rewardFlowTaskHook.taskFee(), fee);
    }
}
