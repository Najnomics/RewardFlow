// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RewardDistributor} from "../../src/distribution/RewardDistributor.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract RewardDistributorTest is Test {
    RewardDistributor distributor;
    MockERC20 rewardToken;
    address owner = address(0x1);
    address user1 = address(0x2);

    function setUp() public {
        vm.startPrank(owner);
        rewardToken = new MockERC20("Reward Token", "RWT");
        distributor = new RewardDistributor(address(rewardToken), address(0x123)); // Mock spoke pool
        vm.stopPrank();
    }

    function testDeployment() public {
        assertEq(distributor.owner(), owner);
        assertEq(address(distributor.rewardToken()), address(rewardToken));
    }

    function testExecuteRewardDistribution() public {
        uint256 amount = 1000e18;
        
        vm.startPrank(owner);
        rewardToken.mint(address(distributor), amount);
        distributor.executeRewardDistribution(user1, amount, 1); // Using chain 1 (Ethereum)
        vm.stopPrank();

        // Check that the function was called successfully (no revert)
        assertTrue(true);
    }

    function testIsChainSupported() public {
        assertTrue(distributor.isChainSupported(1)); // Ethereum
        assertTrue(distributor.isChainSupported(42161)); // Arbitrum
        assertTrue(distributor.isChainSupported(137)); // Polygon
        assertTrue(distributor.isChainSupported(8453)); // Base
        assertFalse(distributor.isChainSupported(999)); // Unsupported chain
    }

    function testGetDistributionStats() public {
        RewardDistributor.DistributionStats memory stats = distributor.getDistributionStats();
        assertEq(stats.successfulDistributions, 0);
        assertEq(stats.failedDistributions, 0);
        assertEq(stats.totalDistributed, 0);
    }

    function testFuzzExecuteRewardDistribution(uint256 amount) public {
        vm.assume(amount > 0 && amount < 1000000e18); // Max 1M tokens
        
        vm.startPrank(owner);
        rewardToken.mint(address(distributor), amount);
        distributor.executeRewardDistribution(user1, amount, 1); // Using chain 1 (Ethereum)
        vm.stopPrank();

        // Check that the function was called successfully (no revert)
        assertTrue(true);
    }

    function testFuzzIsChainSupported(uint256 chainId) public {
        bool isSupported = distributor.isChainSupported(chainId);
        // Only specific chains should be supported
        assertTrue(isSupported == (chainId == 1 || chainId == 42161 || chainId == 137 || chainId == 8453));
    }
}