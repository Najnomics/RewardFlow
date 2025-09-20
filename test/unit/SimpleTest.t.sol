// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RewardDistributor} from "../../src/distribution/RewardDistributor.sol";

contract SimpleTest is Test {
    RewardDistributor public distributor;
    address public rewardToken = address(0x123);
    address public spokePool = address(0x456);

    function setUp() public {
        distributor = new RewardDistributor(rewardToken, spokePool);
    }

    function testDeployment() public {
        assertEq(address(distributor.rewardToken()), rewardToken);
        assertEq(address(distributor.spokePool()), spokePool);
        assertEq(address(distributor.owner()), address(this));
    }

    function testSetUserPreferences() public {
        address user = address(0x789);
        uint256 preferredChain = 1;
        uint256 claimThreshold = 100;
        uint256 claimFrequency = 7 days;
        bool autoClaimEnabled = true;

        vm.prank(user);
        distributor.setUserPreferences(preferredChain, claimThreshold, claimFrequency, autoClaimEnabled);

        RewardDistributor.UserPreferences memory prefs = distributor.getUserPreferences(user);
        assertEq(prefs.preferredChain, preferredChain);
        assertEq(prefs.claimThreshold, claimThreshold);
        assertEq(prefs.claimFrequency, claimFrequency);
        assertEq(prefs.autoClaimEnabled, autoClaimEnabled);
    }
}
