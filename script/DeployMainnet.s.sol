// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {RewardDistributor} from "../src/distribution/RewardDistributor.sol";
import {RewardFlowHook} from "../src/hooks/RewardFlowHook.sol";
import {RewardFlowHookMEV} from "../src/hooks/RewardFlowHookMEV.sol";
import {CrossChainPositionTracker} from "../src/tracking/CrossChainPositionTracker.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";

contract DeployMainnet is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Get network configuration
        string memory network = vm.envString("NETWORK");
        string memory rpcUrl = vm.envString("RPC_URL");
        
        console.log("Deploying to mainnet:", network);
        console.log("RPC URL:", rpcUrl);
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        // Get contract addresses from environment
        address rewardToken = vm.envAddress("REWARD_TOKEN_ADDRESS");
        address spokePool = vm.envAddress("SPOKE_POOL_ADDRESS");
        address poolManager = vm.envAddress("UNISWAP_V4_POOL_MANAGER");
        
        // Verify addresses are set
        require(rewardToken != address(0), "REWARD_TOKEN_ADDRESS not set");
        require(spokePool != address(0), "SPOKE_POOL_ADDRESS not set");
        require(poolManager != address(0), "UNISWAP_V4_POOL_MANAGER not set");
        
        console.log("RewardToken:", rewardToken);
        console.log("SpokePool:", spokePool);
        console.log("PoolManager:", poolManager);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy RewardDistributor
        RewardDistributor distributor = new RewardDistributor(
            rewardToken,
            spokePool
        );
        console.log("RewardDistributor deployed at:", address(distributor));
        
        // Deploy CrossChainPositionTracker
        CrossChainPositionTracker tracker = new CrossChainPositionTracker();
        console.log("CrossChainPositionTracker deployed at:", address(tracker));
        
        // Deploy RewardFlowHook
        RewardFlowHook hook = new RewardFlowHook(
            IPoolManager(poolManager),
            address(distributor)
        );
        console.log("RewardFlowHook deployed at:", address(hook));
        
        // Deploy RewardFlowHookMEV
        RewardFlowHookMEV mevHook = new RewardFlowHookMEV(
            IPoolManager(poolManager),
            address(distributor)
        );
        console.log("RewardFlowHookMEV deployed at:", address(mevHook));
        
        vm.stopBroadcast();
        
        console.log("\n=== Deployment Summary ===");
        console.log("Network:", network);
        console.log("RewardToken:", rewardToken);
        console.log("SpokePool:", spokePool);
        console.log("PoolManager:", poolManager);
        console.log("RewardDistributor:", address(distributor));
        console.log("CrossChainPositionTracker:", address(tracker));
        console.log("RewardFlowHook:", address(hook));
        console.log("RewardFlowHookMEV:", address(mevHook));
        console.log("\nDeployment completed successfully!");
        
        // Save deployment addresses for verification
        _saveDeploymentAddresses(network, address(distributor), address(tracker), address(hook), address(mevHook));
        
        // Generate verification commands
        _generateVerificationCommands(network, address(distributor), address(tracker), address(hook), address(mevHook));
    }
    
    function _saveDeploymentAddresses(
        string memory network,
        address distributor,
        address tracker,
        address hook,
        address mevHook
    ) internal {
        string memory deploymentFile = string.concat("deployments/", network, ".json");
        
        string memory json = string.concat(
            '{\n',
            '  "network": "', network, '",\n',
            '  "deploymentTime": ', vm.toString(block.timestamp), ',\n',
            '  "deployer": "', vm.toString(msg.sender), '",\n',
            '  "contracts": {\n',
            '    "RewardDistributor": "', vm.toString(distributor), '",\n',
            '    "CrossChainPositionTracker": "', vm.toString(tracker), '",\n',
            '    "RewardFlowHook": "', vm.toString(hook), '",\n',
            '    "RewardFlowHookMEV": "', vm.toString(mevHook), '"\n',
            '  }\n',
            '}'
        );
        
        vm.writeFile(deploymentFile, json);
        console.log("Deployment addresses saved to:", deploymentFile);
    }
    
    function _generateVerificationCommands(
        string memory network,
        address distributor,
        address tracker,
        address hook,
        address mevHook
    ) internal {
        string memory verificationFile = string.concat("deployments/", network, "-verification.sh");
        
        string memory commands = string.concat(
            '#!/bin/bash\n',
            '# Verification commands for ', network, ' deployment\n\n',
            '# Verify RewardDistributor\n',
            'forge verify-contract ', vm.toString(distributor), ' src/distribution/RewardDistributor.sol:RewardDistributor --chain-id ', network, '\n\n',
            '# Verify CrossChainPositionTracker\n',
            'forge verify-contract ', vm.toString(tracker), ' src/tracking/CrossChainPositionTracker.sol:CrossChainPositionTracker --chain-id ', network, '\n\n',
            '# Verify RewardFlowHook\n',
            'forge verify-contract ', vm.toString(hook), ' src/hooks/RewardFlowHook.sol:RewardFlowHook --chain-id ', network, '\n\n',
            '# Verify RewardFlowHookMEV\n',
            'forge verify-contract ', vm.toString(mevHook), ' src/hooks/RewardFlowHookMEV.sol:RewardFlowHookMEV --chain-id ', network, '\n'
        );
        
        vm.writeFile(verificationFile, commands);
        console.log("Verification commands saved to:", verificationFile);
    }
}
