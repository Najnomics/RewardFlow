// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/hooks/RewardFlowHook.sol";
import "../src/hooks/RewardFlowHookMEV.sol";
import "../src/distribution/RewardDistributor.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployer);
        
        // Deploy RewardDistributor
        RewardDistributor distributor = new RewardDistributor(
            address(0x123), // Reward token (placeholder)
            address(0x456)  // Spoke pool (placeholder)
        );
        
        // Deploy RewardFlowHook
        RewardFlowHook hook = new RewardFlowHook(
            IPoolManager(address(0x789)), // Pool Manager
            address(distributor)
        );
        
        // Deploy RewardFlowHookMEV
        RewardFlowHookMEV mevHook = new RewardFlowHookMEV(
            IPoolManager(address(0x789)), // Pool Manager
            address(distributor)
        );
        
        vm.stopBroadcast();
        
        console.log("RewardDistributor deployed at:", address(distributor));
        console.log("RewardFlowHook deployed at:", address(hook));
        console.log("RewardFlowHookMEV deployed at:", address(mevHook));
    }
}


