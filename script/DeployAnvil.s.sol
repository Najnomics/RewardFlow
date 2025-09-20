// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {RewardDistributor} from "../src/distribution/RewardDistributor.sol";
import {RewardFlowHook} from "../src/hooks/RewardFlowHook.sol";
import {RewardFlowHookMEV} from "../src/hooks/RewardFlowHookMEV.sol";
import {CrossChainPositionTracker} from "../src/tracking/CrossChainPositionTracker.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";

contract DeployAnvil is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying to Anvil...");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy mock reward token
        MockERC20 rewardToken = new MockERC20("RewardFlow Token", "RFT");
        console.log("RewardToken deployed at:", address(rewardToken));
        
        // Deploy mock spoke pool (using deployer address as placeholder)
        address spokePool = deployer; // In real deployment, this would be the actual spoke pool
        
        // Deploy RewardDistributor
        RewardDistributor distributor = new RewardDistributor(
            address(rewardToken),
            spokePool
        );
        console.log("RewardDistributor deployed at:", address(distributor));
        
        // Deploy CrossChainPositionTracker
        CrossChainPositionTracker tracker = new CrossChainPositionTracker();
        console.log("CrossChainPositionTracker deployed at:", address(tracker));
        
        // Deploy RewardFlowHook
        RewardFlowHook hook = new RewardFlowHook(
            IPoolManager(address(0x999)), // Mock pool manager address
            address(distributor)
        );
        console.log("RewardFlowHook deployed at:", address(hook));
        
        // Deploy RewardFlowHookMEV
        RewardFlowHookMEV mevHook = new RewardFlowHookMEV(
            IPoolManager(address(0x999)), // Mock pool manager address
            address(distributor)
        );
        console.log("RewardFlowHookMEV deployed at:", address(mevHook));
        
        vm.stopBroadcast();
        
        console.log("\n=== Deployment Summary ===");
        console.log("Network: Anvil (Local)");
        console.log("RewardToken:", address(rewardToken));
        console.log("RewardDistributor:", address(distributor));
        console.log("CrossChainPositionTracker:", address(tracker));
        console.log("RewardFlowHook:", address(hook));
        console.log("RewardFlowHookMEV:", address(mevHook));
        console.log("\nDeployment completed successfully!");
    }
}
