// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {PreferenceManager} from "../../src/distribution/libraries/PreferenceManager.sol";

contract PreferenceManagerTest is Test {
    using PreferenceManager for PreferenceManager.UserPreferences;

    PreferenceManager.UserPreferences public preferences;

    function setUp() public {
        // Initialize empty preferences
    }

    function testSetPreferences() public {
        preferences.updatePreferences(1, 1000, 500, true);
        
        assertEq(preferences.preferredChain, 1);
        assertEq(preferences.claimThreshold, 1000);
        assertEq(preferences.claimFrequency, 500);
        assertTrue(preferences.autoClaimEnabled);
    }

    function testUpdatePreferredChain() public {
        preferences.updatePreferences(1, 1000, 500, true);
        preferences.updatePreferences(2, 1000, 500, true);
        
        assertEq(preferences.preferredChain, 2);
    }

    function testUpdateMinRewardThreshold() public {
        preferences.updatePreferences(1, 1000, 500, true);
        preferences.updatePreferences(1, 2000, 500, true);
        
        assertEq(preferences.claimThreshold, 2000);
    }

    function testUpdateClaimFrequency() public {
        preferences.updatePreferences(1, 1000, 500, true);
        preferences.updatePreferences(1, 1000, 1000, true);
        
        assertEq(preferences.claimFrequency, 1000);
    }

    function testToggleAutoClaim() public {
        preferences.updatePreferences(1, 1000, 500, true);
        assertTrue(preferences.autoClaimEnabled);
        
        preferences.updatePreferences(1, 1000, 500, false);
        assertFalse(preferences.autoClaimEnabled);
        
        preferences.updatePreferences(1, 1000, 500, true);
        assertTrue(preferences.autoClaimEnabled);
    }

    function testGetOptimalTiming() public {
        preferences.updatePreferences(1, 1000, 500, true);
        
        uint256 optimalTiming = preferences.getOptimalTiming(block.timestamp);
        assertTrue(optimalTiming > 0);
    }

    function testIsValidPreferences() public {
        // Valid preferences
        preferences.updatePreferences(1, 1000, 500, true);
        assertTrue(PreferenceManager.validatePreferences(preferences));
        
        // Invalid chain
        preferences.updatePreferences(0, 1000, 500, true);
        assertFalse(PreferenceManager.validatePreferences(preferences));
        
        // Invalid threshold
        preferences.updatePreferences(1, 0, 500, true);
        assertFalse(PreferenceManager.validatePreferences(preferences));
        
        // Invalid frequency
        preferences.updatePreferences(1, 1000, 0, true);
        assertFalse(PreferenceManager.validatePreferences(preferences));
    }

    function testReupdatePreferences() public {
        preferences.updatePreferences(1, 1000, 500, true);
        preferences.updatePreferences(1, 1000, 500, true);
        
        // Values should remain the same after re-updating with same values
        assertEq(preferences.preferredChain, 1);
        assertEq(preferences.claimThreshold, 1000);
        assertEq(preferences.claimFrequency, 500);
        assertTrue(preferences.autoClaimEnabled);
    }

    function testMultipleUpdates() public {
        preferences.updatePreferences(1, 1000, 500, true);
        preferences.updatePreferences(2, 1000, 500, true);
        preferences.updatePreferences(1, 2000, 500, true);
        preferences.updatePreferences(1, 1000, 1000, true);
        preferences.updatePreferences(1, 1000, 500, false);
        
        // Final values should be from the last call
        assertEq(preferences.preferredChain, 1);
        assertEq(preferences.claimThreshold, 1000);
        assertEq(preferences.claimFrequency, 500);
        assertFalse(preferences.autoClaimEnabled);
    }

    function testEdgeCaseValues() public {
        // Test with maximum values
        preferences.updatePreferences(type(uint256).max, type(uint256).max, type(uint256).max, true);
        assertTrue(PreferenceManager.validatePreferences(preferences));
        
        // Test with minimum valid values
        preferences.updatePreferences(1, 1, 1, false);
        assertTrue(PreferenceManager.validatePreferences(preferences));
    }
}
