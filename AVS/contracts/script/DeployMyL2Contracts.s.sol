// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {IBN254CertificateVerifier} from
    "@eigenlayer-contracts/src/contracts/interfaces/IBN254CertificateVerifier.sol";
import {IECDSACertificateVerifier} from "@eigenlayer-contracts/src/contracts/interfaces/IECDSACertificateVerifier.sol";
import {ITaskMailbox} from "@eigenlayer-contracts/src/contracts/interfaces/ITaskMailbox.sol";

import {RewardFlowTaskHook} from "@project/l2-contracts/RewardFlowTaskHook.sol";
import {HelloWorldL2} from "@project/l2-contracts/HelloWorldL2.sol"; // Keep example contract for reference

/**
 * @title DeployRewardFlowL2Contracts
 * @dev Deployment script for RewardFlow L2 contracts
 * @notice Deploys the RewardFlowTaskHook and any other L2-specific contracts
 */
contract DeployRewardFlowL2Contracts is Script {
    using stdJson for string;

    struct Context {
        address avs;
        uint256 avsPrivateKey;
        uint256 deployerPrivateKey;
        IBN254CertificateVerifier certificateVerifier;
        IECDSACertificateVerifier ecdsaCertificateVerifier;
        ITaskMailbox taskMailbox;
        RewardFlowTaskHook rewardFlowTaskHook;
    }

    struct Output {
        string name;
        address contractAddress;
    }

    function run(string memory environment, string memory _context) public {
        // Read the context
        Context memory context = _readContext(environment, _context);

        vm.startBroadcast(context.deployerPrivateKey);
        console.log("Deployer address:", vm.addr(context.deployerPrivateKey));

        // Deploy RewardFlowTaskHook
        RewardFlowTaskHook rewardFlowTaskHook = new RewardFlowTaskHook();
        console.log("RewardFlowTaskHook deployed to:", address(rewardFlowTaskHook));

        // Deploy HelloWorldL2 (example contract - can be removed in production)
        HelloWorldL2 helloWorldL2 = new HelloWorldL2();
        console.log("HelloWorldL2 deployed to:", address(helloWorldL2));

        vm.stopBroadcast();

        vm.startBroadcast(context.avsPrivateKey);
        console.log("AVS address:", context.avs);

        // Configure RewardFlowTaskHook
        console.log("Configuring RewardFlowTaskHook...");
        
        // Set initial task fee (0.0001 ETH)
        rewardFlowTaskHook.setTaskFee(0.0001 ether);
        console.log("Task fee set to 0.0001 ETH");

        // Verify configuration
        (uint256 tasksProcessed, uint256 rewardsDistributed, uint96 currentFee) = rewardFlowTaskHook.getStats();
        console.log("RewardFlowTaskHook stats - Tasks:", tasksProcessed, "Rewards:", rewardsDistributed, "Fee:", currentFee);

        vm.stopBroadcast();

        // Write deployment outputs
        Output[] memory outputs = new Output[](2);
        outputs[0] = Output({name: "RewardFlowTaskHook", contractAddress: address(rewardFlowTaskHook)});
        outputs[1] = Output({name: "HelloWorldL2", contractAddress: address(helloWorldL2)});
        _writeOutputToJson(environment, outputs);
        
        console.log("RewardFlow L2 contracts deployed successfully!");
        console.log("RewardFlowTaskHook address:", address(rewardFlowTaskHook));
        console.log("Task fee:", rewardFlowTaskHook.taskFee());
        console.log("Min reward amount:", rewardFlowTaskHook.MIN_REWARD_AMOUNT());
        console.log("Max reward amount:", rewardFlowTaskHook.MAX_REWARD_AMOUNT());
    }

    function _readContext(
        string memory environment,
        string memory _context
    ) internal view returns (Context memory) {
        // Parse the context
        Context memory context;
        context.avs = stdJson.readAddress(_context, ".context.avs.address");
        context.avsPrivateKey = uint256(stdJson.readBytes32(_context, ".context.avs.avs_private_key"));
        context.deployerPrivateKey = uint256(stdJson.readBytes32(_context, ".context.deployer_private_key"));
        context.certificateVerifier = IBN254CertificateVerifier(stdJson.readAddress(_context, ".context.eigenlayer.l2.bn254_certificate_verifier"));
        context.ecdsaCertificateVerifier = IECDSACertificateVerifier(stdJson.readAddress(_context, ".context.eigenlayer.l2.ecdsa_certificate_verifier"));
        context.taskMailbox = ITaskMailbox(_readHourglassConfigAddress(environment, "taskMailbox"));
        
        // Try to read existing RewardFlowTaskHook address if it exists
        try this._readRewardFlowL2ConfigAddress(environment, "rewardFlowTaskHook") returns (address addr) {
            context.rewardFlowTaskHook = RewardFlowTaskHook(addr);
        } catch {
            // If it doesn't exist yet, we'll deploy a new one
            context.rewardFlowTaskHook = RewardFlowTaskHook(address(0));
        }

        return context;
    }

    function _readHourglassConfigAddress(
        string memory environment,
        string memory key
    ) internal view returns (address) {
        // Load the Hourglass config file
        string memory hourglassConfigFile =
                            string.concat("script/", environment, "/output/deploy_hourglass_core_output.json");
        string memory hourglassConfig = vm.readFile(hourglassConfigFile);

        // Parse and return the address
        return stdJson.readAddress(hourglassConfig, string.concat(".addresses.", key));
    }

    function _readRewardFlowL2ConfigAddress(string memory environment, string memory key) external view returns (address) {
        // Load the RewardFlow L2 config file
        string memory rewardFlowL2ConfigFile = string.concat("script/", environment, "/output/deploy_rewardflow_l2_output.json");
        string memory rewardFlowL2Config = vm.readFile(rewardFlowL2ConfigFile);

        // Parse and return the address
        return stdJson.readAddress(rewardFlowL2Config, string.concat(".addresses.", key));
    }

    function _writeOutputToJson(
        string memory environment,
        Output[] memory outputs
    ) internal {
        uint256 length = outputs.length;

        if (length > 0) {
            // Add the addresses object
            string memory addresses = "addresses";

            for (uint256 i = 0; i < outputs.length - 1; i++) {
                vm.serializeAddress(addresses, outputs[i].name, outputs[i].contractAddress);
            }
            addresses = vm.serializeAddress(addresses, outputs[length - 1].name, outputs[length - 1].contractAddress);

            // Add the chainInfo object
            string memory chainInfo = "chainInfo";
            chainInfo = vm.serializeUint(chainInfo, "chainId", block.chainid);

            // Add deployment metadata
            string memory metadata = "metadata";
            metadata = vm.serializeString(metadata, "deploymentType", "RewardFlowL2");
            metadata = vm.serializeString(metadata, "timestamp", vm.toString(block.timestamp));
            metadata = vm.serializeString(metadata, "blockNumber", vm.toString(block.number));
            metadata = vm.serializeString(metadata, "avsName", "RewardFlow");
            metadata = vm.serializeString(metadata, "description", "Uniswap V4 Hook Reward Distribution AVS");

            // Finalize the JSON
            string memory finalJson = "final";
            vm.serializeString(finalJson, "addresses", addresses);
            vm.serializeString(finalJson, "chainInfo", chainInfo);
            vm.serializeString(finalJson, "metadata", metadata);

            // Write to output file
            string memory outputFile = string.concat("script/", environment, "/output/deploy_rewardflow_l2_output.json");
            vm.writeJson(finalJson, outputFile);
            
            console.log("Deployment output written to:", outputFile);
        }
    }
}