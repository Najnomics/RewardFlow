// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/hooks/RewardFlowHook.sol";
import "../src/distribution/RewardDistributor.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";

contract RewardFlowHookTest is Test {
    RewardFlowHook public hook;
    RewardDistributor public distributor;
    IPoolManager public poolManager;
    
    function setUp() public {
        // Deploy mock dependencies
        poolManager = IPoolManager(address(0x123));
        distributor = new RewardDistributor(
            address(0x456), // Reward token
            address(0x789)  // Spoke pool
        );
        
        // Deploy hook with mock dependencies
        hook = new RewardFlowHook(
            poolManager,
            address(distributor)
        );
    }
    
    function testHookDeployment() public {
        assertEq(address(hook.rewardDistributor()), address(distributor));
    }
    
    function testGetPendingRewards() public {
        address user = address(0x789);
        uint256 rewards = hook.getPendingRewards(user);
        assertEq(rewards, 0);
    }
    
    function testGetUserTier() public {
        address user = address(0x789);
        TierCalculations.TierLevel tier = hook.getUserTier(user);
        assertEq(uint8(tier), 0); // Should be Bronze tier by default
    }
}
