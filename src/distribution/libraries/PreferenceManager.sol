// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title PreferenceManager
 * @notice Library for managing user preferences
 */
library PreferenceManager {
    /// @notice User preferences structure
    struct UserPreferences {
        uint256 preferredChain;
        uint256 claimThreshold;
        uint256 claimFrequency;
        bool autoClaimEnabled;
        uint256 lastUpdate;
    }

    /// @notice Default preferences
    function getDefaultPreferences() internal pure returns (UserPreferences memory) {
        return UserPreferences({
            preferredChain: 1, // Ethereum
            claimThreshold: 1e16, // 0.01 ETH
            claimFrequency: 1 days,
            autoClaimEnabled: true,
            lastUpdate: 0
        });
    }

    /// @notice Validate user preferences
    function validatePreferences(
        UserPreferences memory prefs
    ) internal pure returns (bool) {
        return prefs.preferredChain > 0 &&
               prefs.claimThreshold > 0 &&
               prefs.claimFrequency > 0;
    }

    /// @notice Get optimal distribution timing
    function getOptimalTiming(
        UserPreferences memory prefs,
        uint256 currentTime
    ) internal pure returns (uint256) {
        if (!prefs.autoClaimEnabled) {
            return 0; // Manual claiming
        }
        
        return currentTime + prefs.claimFrequency;
    }

    /// @notice Check if user should auto-claim
    function shouldAutoClaim(
        UserPreferences memory prefs,
        uint256 pendingAmount
    ) internal view returns (bool) {
        return prefs.autoClaimEnabled &&
               pendingAmount >= prefs.claimThreshold &&
               block.timestamp >= prefs.lastUpdate + prefs.claimFrequency;
    }

    /// @notice Update user preferences
    function updatePreferences(
        UserPreferences storage prefs,
        uint256 preferredChain,
        uint256 claimThreshold,
        uint256 claimFrequency,
        bool autoClaimEnabled
    ) internal {
        prefs.preferredChain = preferredChain;
        prefs.claimThreshold = claimThreshold;
        prefs.claimFrequency = claimFrequency;
        prefs.autoClaimEnabled = autoClaimEnabled;
        prefs.lastUpdate = block.timestamp;
    }

    /// @notice Get preference summary
    function getPreferenceSummary(
        UserPreferences memory prefs
    ) internal pure returns (
        uint256 preferredChain,
        uint256 claimThreshold,
        uint256 claimFrequency,
        bool autoClaimEnabled,
        uint256 lastUpdate
    ) {
        return (
            prefs.preferredChain,
            prefs.claimThreshold,
            prefs.claimFrequency,
            prefs.autoClaimEnabled,
            prefs.lastUpdate
        );
    }
}
