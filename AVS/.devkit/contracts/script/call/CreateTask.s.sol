// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {OperatorSet} from "@eigenlayer-contracts/src/contracts/libraries/OperatorSetLib.sol";
import {ITaskMailbox, ITaskMailboxTypes} from "@eigenlayer-contracts/src/contracts/interfaces/ITaskMailbox.sol";

/**
 * @title CreateRewardFlowTask
 * @dev Script to create RewardFlow reward distribution tasks
 * @notice Creates tasks for distributing rewards from Uniswap V4 hooks across chains
 */
contract CreateRewardFlowTask is Script {
    using stdJson for string;

    function run(
        string memory environment,
        address taskMailbox,
        address avs,
        uint32 executorOperatorSetId,
        bytes memory payload
    ) public {
        // TaskMailbox address from args
        console.log("RewardFlow Task Mailbox:", taskMailbox);

        // Load the private key from the environment variable
        uint256 appPrivateKey = vm.envUint("PRIVATE_KEY_APP");
        address app = vm.addr(appPrivateKey);

        vm.startBroadcast(appPrivateKey);
        console.log("RewardFlow App address:", app);

        // Call createTask for RewardFlow reward distribution
        OperatorSet memory executorOperatorSet = OperatorSet({avs: avs, id: executorOperatorSetId});
        ITaskMailboxTypes.TaskParams memory taskParams = ITaskMailboxTypes.TaskParams({
            refundCollector: address(0),
            executorOperatorSet: executorOperatorSet,
            payload: payload
        });
        
        bytes32 taskHash = ITaskMailbox(taskMailbox).createTask(taskParams);
        console.log("Created RewardFlow task with hash:");
        console.logBytes32(taskHash);
        
        ITaskMailboxTypes.Task memory task = ITaskMailbox(taskMailbox).getTaskInfo(taskHash);
        console.log("RewardFlow Task status:", uint8(task.status));
        console.log("RewardFlow Task payload:");
        console.logBytes(task.payload);

        vm.stopBroadcast();
    }

    /**
     * @dev Helper function to create a RewardFlow reward distribution task
     * @param user The user address receiving the reward
     * @param amount The reward amount in wei
     * @param chainId The source chain ID
     * @param rewardType The type of reward (liquidity, swap, mev)
     * @param poolId The pool ID for tracking
     * @param hookAddress The hook contract address
     * @param txHash The transaction hash
     */
    function createRewardDistributionTask(
        string memory environment,
        address taskMailbox,
        address avs,
        uint32 executorOperatorSetId,
        address user,
        uint256 amount,
        uint256 chainId,
        string memory rewardType,
        bytes32 poolId,
        address hookAddress,
        bytes32 txHash
    ) public {
        // Encode the reward distribution task data
        bytes memory payload = abi.encode(
            user,           // User address
            amount,         // Reward amount
            chainId,        // Source chain ID
            poolId,         // Pool ID
            rewardType,     // Reward type
            block.timestamp, // Timestamp
            hookAddress,    // Hook address
            txHash          // Transaction hash
        );

        // Create the task
        run(environment, taskMailbox, avs, executorOperatorSetId, payload);
    }

    /**
     * @dev Helper function to create a liquidity reward task
     */
    function createLiquidityRewardTask(
        string memory environment,
        address taskMailbox,
        address avs,
        uint32 executorOperatorSetId,
        address user,
        uint256 amount,
        uint256 chainId,
        bytes32 poolId,
        address hookAddress,
        bytes32 txHash
    ) public {
        createRewardDistributionTask(
            environment,
            taskMailbox,
            avs,
            executorOperatorSetId,
            user,
            amount,
            chainId,
            "liquidity",
            poolId,
            hookAddress,
            txHash
        );
    }

    /**
     * @dev Helper function to create a swap reward task
     */
    function createSwapRewardTask(
        string memory environment,
        address taskMailbox,
        address avs,
        uint32 executorOperatorSetId,
        address user,
        uint256 amount,
        uint256 chainId,
        bytes32 poolId,
        address hookAddress,
        bytes32 txHash
    ) public {
        createRewardDistributionTask(
            environment,
            taskMailbox,
            avs,
            executorOperatorSetId,
            user,
            amount,
            chainId,
            "swap",
            poolId,
            hookAddress,
            txHash
        );
    }

    /**
     * @dev Helper function to create an MEV reward task
     */
    function createMEVRewardTask(
        string memory environment,
        address taskMailbox,
        address avs,
        uint32 executorOperatorSetId,
        address user,
        uint256 amount,
        uint256 chainId,
        bytes32 poolId,
        address hookAddress,
        bytes32 txHash
    ) public {
        createRewardDistributionTask(
            environment,
            taskMailbox,
            avs,
            executorOperatorSetId,
            user,
            amount,
            chainId,
            "mev",
            poolId,
            hookAddress,
            txHash
        );
    }
}