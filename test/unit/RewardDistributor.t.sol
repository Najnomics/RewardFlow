// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RewardDistributor} from "../../src/distribution/RewardDistributor.sol";

contract RewardDistributorTest is Test {
    RewardDistributor public distributor;
    address public rewardToken = address(0x123);
    address public spokePool = address(0x456);
    address public owner = address(this);
    address public user = address(0x789);

    function setUp() public {
        distributor = new RewardDistributor(rewardToken, spokePool);
    }

    function testConstructor() public {
        assertEq(distributor.rewardToken(), rewardToken);
        assertEq(distributor.spokePool(), spokePool);
        assertEq(distributor.owner(), owner);
        assertFalse(distributor.paused());
    }

    function testSupportedChains() public {
        assertTrue(distributor.isChainSupported(1)); // Ethereum
        assertTrue(distributor.isChainSupported(42161)); // Arbitrum
        assertTrue(distributor.isChainSupported(137)); // Polygon
        assertTrue(distributor.isChainSupported(8453)); // Base
        assertFalse(distributor.isChainSupported(999)); // Unsupported
    }

    function testSetUserPreferences() public {
        vm.prank(user);
        distributor.setUserPreferences(
            1, // preferredChain
            1000, // claimThreshold
            3600, // claimFrequency
            true // autoClaimEnabled
        );

        (
            uint256 preferredChain,
            uint256 claimThreshold,
            uint256 claimFrequency,
            bool autoClaimEnabled,
            uint256 lastUpdate
        ) = distributor.getUserPreferences(user);

        assertEq(preferredChain, 1);
        assertEq(claimThreshold, 1000);
        assertEq(claimFrequency, 3600);
        assertTrue(autoClaimEnabled);
        assertEq(lastUpdate, block.timestamp);
    }

    function testSetUserPreferencesUnsupportedChain() public {
        vm.prank(user);
        vm.expectRevert(RewardDistributor.UnsupportedChain.selector);
        distributor.setUserPreferences(
            999, // unsupported chain
            1000,
            3600,
            true
        );
    }

    function testExecuteRewardDistribution() public {
        uint256 amount = 1000;
        uint256 targetChain = 1;

        vm.expectEmit(true, true, false, true);
        emit RewardDistributor.RewardDistributionInitiated(
            keccak256(abi.encode(user, amount, block.chainid, targetChain, block.timestamp)),
            user,
            amount,
            targetChain
        );

        distributor.executeRewardDistribution(user, amount, targetChain);
    }

    function testExecuteRewardDistributionInvalidAmount() public {
        vm.expectRevert(RewardDistributor.InvalidAmount.selector);
        distributor.executeRewardDistribution(user, 0, 1);
    }

    function testExecuteRewardDistributionUnsupportedChain() public {
        vm.expectRevert(RewardDistributor.UnsupportedChain.selector);
        distributor.executeRewardDistribution(user, 1000, 999);
    }

    function testExecuteInstantClaim() public {
        // Set user preferences first
        vm.prank(user);
        distributor.setUserPreferences(1, 500, 3600, true);

        uint256 amount = 1000;
        vm.expectEmit(true, true, false, true);
        emit RewardDistributor.RewardDistributionInitiated(
            keccak256(abi.encode(user, amount, block.chainid, 1, block.timestamp)),
            user,
            amount,
            1
        );

        distributor.executeInstantClaim(user, amount);
    }

    function testExecuteInstantClaimInsufficientAmount() public {
        // Set user preferences with high threshold
        vm.prank(user);
        distributor.setUserPreferences(1, 2000, 3600, true);

        vm.expectRevert(RewardDistributor.InvalidAmount.selector);
        distributor.executeInstantClaim(user, 1000);
    }

    function testUpdateChainSupport() public {
        uint256 newChain = 10;
        assertFalse(distributor.isChainSupported(newChain));

        distributor.updateChainSupport(newChain, true);
        assertTrue(distributor.isChainSupported(newChain));

        distributor.updateChainSupport(newChain, false);
        assertFalse(distributor.isChainSupported(newChain));
    }

    function testPauseUnpause() public {
        assertFalse(distributor.paused());

        distributor.pause();
        assertTrue(distributor.paused());

        distributor.unpause();
        assertFalse(distributor.paused());
    }

    function testExecuteRewardDistributionWhenPaused() public {
        distributor.pause();
        vm.expectRevert(RewardDistributor.Paused.selector);
        distributor.executeRewardDistribution(user, 1000, 1);
    }

    function testExecuteInstantClaimWhenPaused() public {
        distributor.pause();
        vm.expectRevert(RewardDistributor.Paused.selector);
        distributor.executeInstantClaim(user, 1000);
    }

    function testGetDistributionStats() public {
        (
            uint256 totalDistributed,
            uint256 totalRequests,
            uint256 successfulDistributions,
            uint256 failedDistributions,
            uint256 totalFees
        ) = distributor.getDistributionStats();

        assertEq(totalDistributed, 0);
        assertEq(totalRequests, 0);
        assertEq(successfulDistributions, 0);
        assertEq(failedDistributions, 0);
        assertEq(totalFees, 0);
    }

    function testCalculateDistributionFees() public {
        uint256 amount = 1000;
        uint256 targetChain = 1;
        uint256 fees = distributor.calculateDistributionFees(amount, targetChain);
        assertGt(fees, 0);
    }

    function testGetOptimalDistributionTiming() public {
        // Set user preferences
        vm.prank(user);
        distributor.setUserPreferences(1, 1000, 3600, true);

        uint256 timing = distributor.getOptimalDistributionTiming(user);
        assertGt(timing, 0);
    }

    function testOnlyOwnerFunctions() public {
        address nonOwner = address(0x999);
        
        vm.prank(nonOwner);
        vm.expectRevert(RewardDistributor.Unauthorized.selector);
        distributor.updateChainSupport(10, true);

        vm.prank(nonOwner);
        vm.expectRevert(RewardDistributor.Unauthorized.selector);
        distributor.pause();

        vm.prank(nonOwner);
        vm.expectRevert(RewardDistributor.Unauthorized.selector);
        distributor.unpause();
    }

    function testGetDistributionRequest() public {
        uint256 amount = 1000;
        uint256 targetChain = 1;

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
        assertEq(request.requestId, requestId);
    }
}
