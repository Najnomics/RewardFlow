// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {IAllocationManager} from "@eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {IKeyRegistrar} from "@eigenlayer-contracts/src/contracts/interfaces/IKeyRegistrar.sol";

import {RewardFlowAVSRegistrar} from "@project/l1-contracts/RewardFlowAVSRegistrar.sol";
import {HelloWorldL1} from "@project/l1-contracts/HelloWorldL1.sol"; // Keep example contract for reference

/**
 * @title DeployRewardFlowL1Contracts
 * @dev Deployment script for RewardFlow L1 contracts
 * @notice Deploys the RewardFlowAVSRegistrar and any other L1-specific contracts
 */
contract DeployRewardFlowL1Contracts is Script {
    using stdJson for string;

    struct Context {
        address avs;
        uint256 avsPrivateKey;
        uint256 deployerPrivateKey;
        IAllocationManager allocationManager;
        IKeyRegistrar keyRegistrar;
        RewardFlowAVSRegistrar rewardFlowAVSRegistrar;
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

        // Deploy RewardFlowAVSRegistrar
        RewardFlowAVSRegistrar rewardFlowRegistrar = new RewardFlowAVSRegistrar(
            context.allocationManager,
            context.keyRegistrar,
            IPermissionController(address(0)) // Will be set during initialization
        );
        console.log("RewardFlowAVSRegistrar deployed to:", address(rewardFlowRegistrar));

        // Deploy HelloWorldL1 (example contract - can be removed in production)
        HelloWorldL1 helloWorldL1 = new HelloWorldL1();
        console.log("HelloWorldL1 deployed to:", address(helloWorldL1));

        vm.stopBroadcast();

        vm.startBroadcast(context.avsPrivateKey);
        console.log("AVS address:", context.avs);

        // Initialize the RewardFlowAVSRegistrar
        // Note: In a real deployment, you would set proper initial configuration
        console.log("Initializing RewardFlowAVSRegistrar...");
        
        // Example initialization (adjust parameters as needed)
        // rewardFlowRegistrar.initialize(
        //     context.avs,
        //     vm.addr(context.avsPrivateKey), // owner
        //     AvsConfig({
        //         // Initial AVS configuration parameters
        //     })
        // );

        vm.stopBroadcast();

        // Write deployment outputs
        Output[] memory outputs = new Output[](2);
        outputs[0] = Output({name: "RewardFlowAVSRegistrar", contractAddress: address(rewardFlowRegistrar)});
        outputs[1] = Output({name: "HelloWorldL1", contractAddress: address(helloWorldL1)});
        _writeOutputToJson(environment, outputs);
        
        console.log("RewardFlow L1 contracts deployed successfully!");
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
        context.allocationManager = IAllocationManager(stdJson.readAddress(_context, ".context.eigenlayer.l1.allocation_manager"));
        context.keyRegistrar = IKeyRegistrar(stdJson.readAddress(_context, ".context.eigenlayer.l1.key_registrar"));
        
        // Try to read existing RewardFlowAVSRegistrar address if it exists
        try this._readRewardFlowL1ConfigAddress(environment, "rewardFlowAVSRegistrar") returns (address addr) {
            context.rewardFlowAVSRegistrar = RewardFlowAVSRegistrar(addr);
        } catch {
            // If it doesn't exist yet, we'll deploy a new one
            context.rewardFlowAVSRegistrar = RewardFlowAVSRegistrar(address(0));
        }

        return context;
    }

    function _readRewardFlowL1ConfigAddress(string memory environment, string memory key) external view returns (address) {
        // Load the RewardFlow L1 config file
        string memory rewardFlowL1ConfigFile = string.concat("script/", environment, "/output/deploy_rewardflow_l1_output.json");
        string memory rewardFlowL1Config = vm.readFile(rewardFlowL1ConfigFile);

        // Parse and return the address
        return stdJson.readAddress(rewardFlowL1Config, string.concat(".addresses.", key));
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
            metadata = vm.serializeString(metadata, "deploymentType", "RewardFlowL1");
            metadata = vm.serializeString(metadata, "timestamp", vm.toString(block.timestamp));
            metadata = vm.serializeString(metadata, "blockNumber", vm.toString(block.number));

            // Finalize the JSON
            string memory finalJson = "final";
            vm.serializeString(finalJson, "addresses", addresses);
            vm.serializeString(finalJson, "chainInfo", chainInfo);
            vm.serializeString(finalJson, "metadata", metadata);

            // Write to output file
            string memory outputFile = string.concat("script/", environment, "/output/deploy_rewardflow_l1_output.json");
            vm.writeJson(finalJson, outputFile);
            
            console.log("Deployment output written to:", outputFile);
        }
    }
}