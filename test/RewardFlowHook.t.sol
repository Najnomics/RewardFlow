// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/hooks/RewardFlowHook.sol";
import "../src/avs/interfaces/IRewardFlowServiceManager.sol";

contract RewardFlowHookTest is Test {
    RewardFlowHook public hook;
    IRewardFlowServiceManager public serviceManager;
    
    function setUp() public {
        // Mock service manager for testing
        serviceManager = IRewardFlowServiceManager(address(0x123));
        
        // Deploy hook with mock dependencies
        hook = new RewardFlowHook(
            IPoolManager(address(0x456)),
            serviceManager
        );
    }
    
    function testHookDeployment() public {
        assertEq(address(hook.serviceManager()), address(serviceManager));
    }
    
    function testGetPendingRewards() public {
        address user = address(0x789);
        uint256 rewards = hook.getPendingRewards(user);
        assertEq(rewards, 0);
    }
    
    function testGetUserTier() public {
        address user = address(0x789);
        uint8 tier = hook.getUserTier(user);
        assertEq(tier, 0); // Should be Bronze tier by default
    }
}
