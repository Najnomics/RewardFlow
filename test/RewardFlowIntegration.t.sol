// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/hooks/RewardFlowHook.sol";
import "../src/hooks/RewardFlowHookMEV.sol";
import "../src/distribution/RewardDistributor.sol";
import {IPoolManager} from "@uniswap/v4-core/interfaces/IPoolManager.sol";

contract RewardFlowIntegrationTest is Test {
    RewardFlowHook public hook;
    RewardFlowHookMEV public mevHook;
    RewardDistributor public distributor;
    IPoolManager public poolManager;
    
    function setUp() public {
        // Deploy mock dependencies
        poolManager = IPoolManager(address(0x123));
        distributor = new RewardDistributor(
            address(0x456), // Reward token
            address(0x789)  // Spoke pool
        );
        
        // Deploy hooks
        hook = new RewardFlowHook(
            poolManager,
            address(distributor)
        );
        
        mevHook = new RewardFlowHookMEV(
            poolManager,
            address(distributor)
        );
    }
    
    function testHookDeployment() public {
        assertEq(address(hook.rewardDistributor()), address(distributor));
        assertEq(address(mevHook.rewardDistributor()), address(distributor));
    }
    
    function testHookPermissions() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        
        // Check hook permissions
        assertFalse(permissions.beforeInitialize);
        assertFalse(permissions.afterInitialize);
        assertTrue(permissions.beforeAddLiquidity);
        assertTrue(permissions.afterAddLiquidity);
        assertTrue(permissions.beforeRemoveLiquidity);
        assertFalse(permissions.afterRemoveLiquidity);
        assertTrue(permissions.beforeSwap);
        assertTrue(permissions.afterSwap);
        assertFalse(permissions.beforeDonate);
        assertFalse(permissions.afterDonate);
    }
    
    function testMEVHookPermissions() public {
        Hooks.Permissions memory permissions = mevHook.getHookPermissions();
        
        // Check MEV hook permissions
        assertFalse(permissions.beforeInitialize);
        assertFalse(permissions.afterInitialize);
        assertTrue(permissions.beforeAddLiquidity);
        assertFalse(permissions.afterAddLiquidity);
        assertTrue(permissions.beforeRemoveLiquidity);
        assertFalse(permissions.afterRemoveLiquidity);
        assertTrue(permissions.beforeSwap);
        assertTrue(permissions.afterSwap);
        assertFalse(permissions.beforeDonate);
        assertFalse(permissions.afterDonate);
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
    
    function testGetUserActivity() public {
        address user = address(0x789);
        (
            uint256 totalLiquidity,
            uint256 swapVolume,
            uint256 positionDuration,
            uint256 lastActivity,
            uint256 loyaltyScore,
            uint256 engagementScore,
            uint8 tier
        ) = hook.getUserActivity(user);
        assertEq(totalLiquidity, 0);
        assertEq(swapVolume, 0);
        assertEq(tier, 0);
    }
}


