// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RewardDistributor} from "../../src/distribution/RewardDistributor.sol";

contract RewardDistributorFuzzTest is Test {
    RewardDistributor public distributor;
    address public rewardToken = address(0x123);
    address public spokePool = address(0x456);

    function setUp() public {
        distributor = new RewardDistributor(rewardToken, spokePool);
    }

    function testFuzzSetUserPreferences(
        uint256 preferredChain,
        uint256 claimThreshold,
        uint256 claimFrequency,
        bool autoClaimEnabled
    ) public {
        // Bound inputs to reasonable ranges
        preferredChain = bound(preferredChain, 1, 1000);
        claimThreshold = bound(claimThreshold, 0, type(uint256).max);
        claimFrequency = bound(claimFrequency, 0, type(uint256).max);
        
        // Only test with supported chains
        vm.assume(preferredChain == 1 || preferredChain == 42161 || preferredChain == 137 || preferredChain == 8453);
        
        distributor.setUserPreferences(preferredChain, claimThreshold, claimFrequency, autoClaimEnabled);
        
        (
            uint256 actualPreferredChain,
            uint256 actualClaimThreshold,
            uint256 actualClaimFrequency,
            bool actualAutoClaimEnabled,
            uint256 lastUpdate
        ) = distributor.getUserPreferences(address(this));
        
        assertEq(actualPreferredChain, preferredChain);
        assertEq(actualClaimThreshold, claimThreshold);
        assertEq(actualClaimFrequency, claimFrequency);
        assertEq(actualAutoClaimEnabled, autoClaimEnabled);
        assertEq(lastUpdate, block.timestamp);
    }

    function testFuzzSetUserPreferencesUnsupportedChain(
        uint256 preferredChain,
        uint256 claimThreshold,
        uint256 claimFrequency,
        bool autoClaimEnabled
    ) public {
        // Bound to unsupported chains
        vm.assume(preferredChain != 1 && preferredChain != 42161 && preferredChain != 137 && preferredChain != 8453);
        
        vm.expectRevert(RewardDistributor.UnsupportedChain.selector);
        distributor.setUserPreferences(preferredChain, claimThreshold, claimFrequency, autoClaimEnabled);
    }

    function testFuzzExecuteRewardDistribution(
        address user,
        uint256 amount,
        uint256 targetChain
    ) public {
        // Bound inputs
        vm.assume(user != address(0));
        amount = bound(amount, 1, type(uint256).max);
        targetChain = bound(targetChain, 1, 1000);
        
        // Only test with supported chains
        vm.assume(targetChain == 1 || targetChain == 42161 || targetChain == 137 || targetChain == 8453);
        
        distributor.executeRewardDistribution(user, amount, targetChain);
        
        bytes32 requestId = keccak256(abi.encode(user, amount, block.chainid, targetChain, block.timestamp));
        RewardDistributor.DistributionRequest memory request = distributor.getDistributionRequest(requestId);
        
        assertEq(request.user, user);
        assertEq(request.amount, amount);
        assertEq(request.sourceChain, block.chainid);
        assertEq(request.targetChain, targetChain);
        assertEq(request.rewardToken, rewardToken);
        assertEq(request.timestamp, block.timestamp);
        assertTrue(request.executed);
    }

    function testFuzzExecuteRewardDistributionInvalidAmount(
        address user,
        uint256 amount,
        uint256 targetChain
    ) public {
        vm.assume(user != address(0));
        vm.assume(amount == 0);
        targetChain = bound(targetChain, 1, 1000);
        vm.assume(targetChain == 1 || targetChain == 42161 || targetChain == 137 || targetChain == 8453);
        
        vm.expectRevert(RewardDistributor.InvalidAmount.selector);
        distributor.executeRewardDistribution(user, amount, targetChain);
    }

    function testFuzzExecuteRewardDistributionUnsupportedChain(
        address user,
        uint256 amount,
        uint256 targetChain
    ) public {
        vm.assume(user != address(0));
        amount = bound(amount, 1, type(uint256).max);
        vm.assume(targetChain != 1 && targetChain != 42161 && targetChain != 137 && targetChain != 8453);
        
        vm.expectRevert(RewardDistributor.UnsupportedChain.selector);
        distributor.executeRewardDistribution(user, amount, targetChain);
    }

    function testFuzzExecuteInstantClaim(
        address user,
        uint256 amount,
        uint256 claimThreshold
    ) public {
        vm.assume(user != address(0));
        amount = bound(amount, 0, type(uint256).max);
        claimThreshold = bound(claimThreshold, 0, type(uint256).max);
        
        // Set user preferences
        distributor.setUserPreferences(1, claimThreshold, 3600, true);
        
        if (amount >= claimThreshold) {
            distributor.executeInstantClaim(user, amount);
        } else {
            vm.expectRevert(RewardDistributor.InvalidAmount.selector);
            distributor.executeInstantClaim(user, amount);
        }
    }

    function testFuzzUpdateChainSupport(
        uint256 chainId,
        bool supported
    ) public {
        chainId = bound(chainId, 1, 10000);
        
        distributor.updateChainSupport(chainId, supported);
        assertEq(distributor.isChainSupported(chainId), supported);
    }

    function testFuzzCalculateDistributionFees(
        uint256 amount,
        uint256 targetChain
    ) public {
        amount = bound(amount, 0, type(uint256).max);
        targetChain = bound(targetChain, 1, 1000);
        
        uint256 fees = distributor.calculateDistributionFees(amount, targetChain);
        assertGe(fees, 0);
    }

    function testFuzzGetOptimalDistributionTiming(
        uint256 preferredChain,
        uint256 claimThreshold,
        uint256 claimFrequency,
        bool autoClaimEnabled
    ) public {
        preferredChain = bound(preferredChain, 1, 1000);
        vm.assume(preferredChain == 1 || preferredChain == 42161 || preferredChain == 137 || preferredChain == 8453);
        
        claimThreshold = bound(claimThreshold, 0, type(uint256).max);
        claimFrequency = bound(claimFrequency, 0, type(uint256).max);
        
        distributor.setUserPreferences(preferredChain, claimThreshold, claimFrequency, autoClaimEnabled);
        
        uint256 timing = distributor.getOptimalDistributionTiming(address(this));
        assertGe(timing, 0);
    }

    function testFuzzMultipleDistributions(
        address[] memory users,
        uint256[] memory amounts,
        uint256[] memory targetChains
    ) public {
        vm.assume(users.length > 0 && users.length <= 10);
        vm.assume(users.length == amounts.length);
        vm.assume(users.length == targetChains.length);
        
        for (uint256 i = 0; i < users.length; i++) {
            vm.assume(users[i] != address(0));
            amounts[i] = bound(amounts[i], 1, type(uint256).max);
            targetChains[i] = bound(targetChains[i], 1, 1000);
            vm.assume(targetChains[i] == 1 || targetChains[i] == 42161 || targetChains[i] == 137 || targetChains[i] == 8453);
            
            distributor.executeRewardDistribution(users[i], amounts[i], targetChains[i]);
        }
        
        // Verify all distributions were recorded
        for (uint256 i = 0; i < users.length; i++) {
            bytes32 requestId = keccak256(abi.encode(users[i], amounts[i], block.chainid, targetChains[i], block.timestamp));
            RewardDistributor.DistributionRequest memory request = distributor.getDistributionRequest(requestId);
            assertEq(request.user, users[i]);
            assertEq(request.amount, amounts[i]);
        }
    }

    function testFuzzPauseUnpause() public {
        assertFalse(distributor.paused());
        
        distributor.pause();
        assertTrue(distributor.paused());
        
        distributor.unpause();
        assertFalse(distributor.paused());
    }

    function testFuzzDistributionStats(
        address[] memory users,
        uint256[] memory amounts
    ) public {
        vm.assume(users.length > 0 && users.length <= 5);
        vm.assume(users.length == amounts.length);
        
        uint256 totalExpected = 0;
        
        for (uint256 i = 0; i < users.length; i++) {
            vm.assume(users[i] != address(0));
            amounts[i] = bound(amounts[i], 1, type(uint256).max);
            totalExpected += amounts[i];
            
            distributor.executeRewardDistribution(users[i], amounts[i], 1);
        }
        
        (
            uint256 totalDistributed,
            uint256 totalRequests,
            uint256 successfulDistributions,
            uint256 failedDistributions,
            uint256 totalFees
        ) = distributor.getDistributionStats();
        
        assertEq(totalDistributed, totalExpected);
        assertEq(totalRequests, users.length);
        assertEq(successfulDistributions, users.length);
        assertEq(failedDistributions, 0);
        assertGe(totalFees, 0);
    }
}
