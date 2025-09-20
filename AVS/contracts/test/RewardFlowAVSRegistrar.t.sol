// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {RewardFlowAVSRegistrar} from "../src/l1-contracts/RewardFlowAVSRegistrar.sol";
import {IAllocationManager} from "@eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {IKeyRegistrar} from "@eigenlayer-contracts/src/contracts/interfaces/IKeyRegistrar.sol";
import {IPermissionController} from "@eigenlayer-contracts/src/contracts/interfaces/IPermissionController.sol";

/**
 * @title RewardFlowAVSRegistrarTest
 * @dev Test suite for RewardFlowAVSRegistrar contract
 * @notice Tests operator registration and AVS configuration management
 */
contract RewardFlowAVSRegistrarTest is Test {
    RewardFlowAVSRegistrar public rewardFlowRegistrar;
    IAllocationManager public mockAllocationManager;
    IKeyRegistrar public mockKeyRegistrar;
    IPermissionController public mockPermissionController;
    
    address public owner;
    address public operator1;
    address public operator2;
    address public operator3;

    event RewardFlowOperatorRegistered(address indexed operator, uint256 stake);
    event RewardFlowOperatorDeregistered(address indexed operator);
    event RewardFlowConfigUpdated(bytes32 indexed configKey, bytes configValue);

    function setUp() public {
        owner = makeAddr("owner");
        operator1 = makeAddr("operator1");
        operator2 = makeAddr("operator2");
        operator3 = makeAddr("operator3");

        // Deploy mock contracts
        mockAllocationManager = IAllocationManager(makeAddr("allocationManager"));
        mockKeyRegistrar = IKeyRegistrar(makeAddr("keyRegistrar"));
        mockPermissionController = IPermissionController(makeAddr("permissionController"));

        vm.prank(owner);
        rewardFlowRegistrar = new RewardFlowAVSRegistrar(
            mockAllocationManager,
            mockKeyRegistrar,
            mockPermissionController
        );
    }

    function testConstructor() public {
        assertEq(rewardFlowRegistrar.owner(), owner);
        assertEq(rewardFlowRegistrar.MIN_STAKE_AMOUNT(), 1 ether);
        assertEq(rewardFlowRegistrar.MAX_OPERATORS(), 1000);
        assertEq(rewardFlowRegistrar.totalOperators(), 0);
        assertEq(rewardFlowRegistrar.totalStake(), 0);
    }

    function testRegisterRewardFlowOperator() public {
        uint256 stake = 5 ether;
        uint256 initialOperators = rewardFlowRegistrar.totalOperators();
        uint256 initialStake = rewardFlowRegistrar.totalStake();

        vm.expectEmit(true, true, false, true);
        emit RewardFlowOperatorRegistered(operator1, stake);

        vm.prank(owner);
        rewardFlowRegistrar.registerRewardFlowOperator(operator1, stake);

        assertTrue(rewardFlowRegistrar.isRewardFlowOperator(operator1));
        assertEq(rewardFlowRegistrar.operatorStake(operator1), stake);
        assertEq(rewardFlowRegistrar.totalOperators(), initialOperators + 1);
        assertEq(rewardFlowRegistrar.totalStake(), initialStake + stake);
    }

    function testRegisterRewardFlowOperatorInvalidOperator() public {
        vm.prank(owner);
        vm.expectRevert("Invalid operator");
        rewardFlowRegistrar.registerRewardFlowOperator(address(0), 5 ether);
    }

    function testRegisterRewardFlowOperatorInsufficientStake() public {
        vm.prank(owner);
        vm.expectRevert("Insufficient stake");
        rewardFlowRegistrar.registerRewardFlowOperator(operator1, 0.5 ether);
    }

    function testRegisterRewardFlowOperatorMaxOperators() public {
        // Register maximum number of operators
        vm.startPrank(owner);
        for (uint256 i = 0; i < 1000; i++) {
            address operator = address(uint160(1000 + i));
            rewardFlowRegistrar.registerRewardFlowOperator(operator, 1 ether);
        }
        vm.stopPrank();

        // Try to register one more operator
        vm.prank(owner);
        vm.expectRevert("Max operators reached");
        rewardFlowRegistrar.registerRewardFlowOperator(operator1, 5 ether);
    }

    function testRegisterRewardFlowOperatorAlreadyRegistered() public {
        vm.prank(owner);
        rewardFlowRegistrar.registerRewardFlowOperator(operator1, 5 ether);

        vm.prank(owner);
        vm.expectRevert("Already registered");
        rewardFlowRegistrar.registerRewardFlowOperator(operator1, 3 ether);
    }

    function testRegisterRewardFlowOperatorNotOwner() public {
        vm.prank(operator1);
        vm.expectRevert();
        rewardFlowRegistrar.registerRewardFlowOperator(operator2, 5 ether);
    }

    function testDeregisterRewardFlowOperator() public {
        uint256 stake = 5 ether;
        
        // Register operator first
        vm.prank(owner);
        rewardFlowRegistrar.registerRewardFlowOperator(operator1, stake);

        uint256 initialOperators = rewardFlowRegistrar.totalOperators();
        uint256 initialStake = rewardFlowRegistrar.totalStake();

        vm.expectEmit(true, true, false, true);
        emit RewardFlowOperatorDeregistered(operator1);

        vm.prank(owner);
        rewardFlowRegistrar.deregisterRewardFlowOperator(operator1);

        assertFalse(rewardFlowRegistrar.isRewardFlowOperator(operator1));
        assertEq(rewardFlowRegistrar.operatorStake(operator1), 0);
        assertEq(rewardFlowRegistrar.totalOperators(), initialOperators - 1);
        assertEq(rewardFlowRegistrar.totalStake(), initialStake - stake);
    }

    function testDeregisterRewardFlowOperatorInvalidOperator() public {
        vm.prank(owner);
        vm.expectRevert("Invalid operator");
        rewardFlowRegistrar.deregisterRewardFlowOperator(address(0));
    }

    function testDeregisterRewardFlowOperatorNotRegistered() public {
        vm.prank(owner);
        vm.expectRevert("Not registered");
        rewardFlowRegistrar.deregisterRewardFlowOperator(operator1);
    }

    function testDeregisterRewardFlowOperatorNotOwner() public {
        vm.prank(owner);
        rewardFlowRegistrar.registerRewardFlowOperator(operator1, 5 ether);

        vm.prank(operator1);
        vm.expectRevert();
        rewardFlowRegistrar.deregisterRewardFlowOperator(operator1);
    }

    function testUpdateRewardFlowConfig() public {
        bytes32 configKey = keccak256("test_config");
        bytes memory configValue = abi.encode("test_value");

        vm.expectEmit(true, true, false, true);
        emit RewardFlowConfigUpdated(configKey, configValue);

        vm.prank(owner);
        rewardFlowRegistrar.updateRewardFlowConfig(configKey, configValue);

        bytes memory retrievedValue = rewardFlowRegistrar.getRewardFlowConfig(configKey);
        assertEq(retrievedValue, configValue);
    }

    function testUpdateRewardFlowConfigEmptyValue() public {
        bytes32 configKey = keccak256("test_config");
        bytes memory configValue = "";

        vm.prank(owner);
        vm.expectRevert("Empty config value");
        rewardFlowRegistrar.updateRewardFlowConfig(configKey, configValue);
    }

    function testUpdateRewardFlowConfigNotOwner() public {
        bytes32 configKey = keccak256("test_config");
        bytes memory configValue = abi.encode("test_value");

        vm.prank(operator1);
        vm.expectRevert();
        rewardFlowRegistrar.updateRewardFlowConfig(configKey, configValue);
    }

    function testGetRewardFlowStats() public {
        // Register some operators
        vm.startPrank(owner);
        rewardFlowRegistrar.registerRewardFlowOperator(operator1, 5 ether);
        rewardFlowRegistrar.registerRewardFlowOperator(operator2, 3 ether);
        rewardFlowRegistrar.registerRewardFlowOperator(operator3, 2 ether);
        vm.stopPrank();

        (uint256 operators, uint256 stake, uint256 avgStake) = rewardFlowRegistrar.getRewardFlowStats();

        assertEq(operators, 3);
        assertEq(stake, 10 ether);
        assertEq(avgStake, 10 ether / 3); // 3.333... ether
    }

    function testGetRewardFlowStatsZeroOperators() public {
        (uint256 operators, uint256 stake, uint256 avgStake) = rewardFlowRegistrar.getRewardFlowStats();

        assertEq(operators, 0);
        assertEq(stake, 0);
        assertEq(avgStake, 0);
    }

    function testIsOperatorRegistered() public {
        assertFalse(rewardFlowRegistrar.isOperatorRegistered(operator1));

        vm.prank(owner);
        rewardFlowRegistrar.registerRewardFlowOperator(operator1, 5 ether);

        assertTrue(rewardFlowRegistrar.isOperatorRegistered(operator1));
    }

    function testGetOperatorStake() public {
        uint256 stake = 7 ether;

        assertEq(rewardFlowRegistrar.getOperatorStake(operator1), 0);

        vm.prank(owner);
        rewardFlowRegistrar.registerRewardFlowOperator(operator1, stake);

        assertEq(rewardFlowRegistrar.getOperatorStake(operator1), stake);
    }

    function testMultipleOperators() public {
        vm.startPrank(owner);
        rewardFlowRegistrar.registerRewardFlowOperator(operator1, 5 ether);
        rewardFlowRegistrar.registerRewardFlowOperator(operator2, 3 ether);
        rewardFlowRegistrar.registerRewardFlowOperator(operator3, 2 ether);
        vm.stopPrank();

        assertTrue(rewardFlowRegistrar.isRewardFlowOperator(operator1));
        assertTrue(rewardFlowRegistrar.isRewardFlowOperator(operator2));
        assertTrue(rewardFlowRegistrar.isRewardFlowOperator(operator3));

        assertEq(rewardFlowRegistrar.operatorStake(operator1), 5 ether);
        assertEq(rewardFlowRegistrar.operatorStake(operator2), 3 ether);
        assertEq(rewardFlowRegistrar.operatorStake(operator3), 2 ether);

        assertEq(rewardFlowRegistrar.totalOperators(), 3);
        assertEq(rewardFlowRegistrar.totalStake(), 10 ether);
    }

    function testRegisterDeregisterCycle() public {
        uint256 stake = 5 ether;

        // Register
        vm.prank(owner);
        rewardFlowRegistrar.registerRewardFlowOperator(operator1, stake);

        assertTrue(rewardFlowRegistrar.isRewardFlowOperator(operator1));
        assertEq(rewardFlowRegistrar.totalOperators(), 1);
        assertEq(rewardFlowRegistrar.totalStake(), stake);

        // Deregister
        vm.prank(owner);
        rewardFlowRegistrar.deregisterRewardFlowOperator(operator1);

        assertFalse(rewardFlowRegistrar.isRewardFlowOperator(operator1));
        assertEq(rewardFlowRegistrar.totalOperators(), 0);
        assertEq(rewardFlowRegistrar.totalStake(), 0);

        // Register again
        vm.prank(owner);
        rewardFlowRegistrar.registerRewardFlowOperator(operator1, stake * 2);

        assertTrue(rewardFlowRegistrar.isRewardFlowOperator(operator1));
        assertEq(rewardFlowRegistrar.operatorStake(operator1), stake * 2);
        assertEq(rewardFlowRegistrar.totalOperators(), 1);
        assertEq(rewardFlowRegistrar.totalStake(), stake * 2);
    }

    function testFuzzRegisterOperator(address operator, uint256 stake) public {
        vm.assume(operator != address(0));
        vm.assume(stake >= 1 ether);

        vm.prank(owner);
        rewardFlowRegistrar.registerRewardFlowOperator(operator, stake);

        assertTrue(rewardFlowRegistrar.isRewardFlowOperator(operator));
        assertEq(rewardFlowRegistrar.operatorStake(operator), stake);
    }

    function testFuzzUpdateConfig(bytes32 configKey, bytes memory configValue) public {
        vm.assume(configValue.length > 0);

        vm.prank(owner);
        rewardFlowRegistrar.updateRewardFlowConfig(configKey, configValue);

        bytes memory retrievedValue = rewardFlowRegistrar.getRewardFlowConfig(configKey);
        assertEq(retrievedValue, configValue);
    }

    function testFuzzMultipleOperators(
        address operator1,
        address operator2,
        uint256 stake1,
        uint256 stake2
    ) public {
        vm.assume(operator1 != address(0));
        vm.assume(operator2 != address(0));
        vm.assume(operator1 != operator2);
        vm.assume(stake1 >= 1 ether);
        vm.assume(stake2 >= 1 ether);

        vm.startPrank(owner);
        rewardFlowRegistrar.registerRewardFlowOperator(operator1, stake1);
        rewardFlowRegistrar.registerRewardFlowOperator(operator2, stake2);
        vm.stopPrank();

        assertTrue(rewardFlowRegistrar.isRewardFlowOperator(operator1));
        assertTrue(rewardFlowRegistrar.isRewardFlowOperator(operator2));
        assertEq(rewardFlowRegistrar.totalOperators(), 2);
        assertEq(rewardFlowRegistrar.totalStake(), stake1 + stake2);
    }
}
