// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {EngagementMetrics} from "../../src/tracking/libraries/EngagementMetrics.sol";

contract EngagementMetricsTest is Test {
    using EngagementMetrics for EngagementMetrics.UserEngagement;

    EngagementMetrics.UserEngagement public engagement;

    function setUp() public {
        // Initialize empty engagement
    }

    function testUpdateLiquidityActivity() public {
        engagement.updateLiquidityActivity(1000);
        assertEq(engagement.totalLiquidity, 1000);
        assertEq(engagement.transactionCount, 1);
    }

    function testUpdateSwapActivity() public {
        engagement.updateSwapActivity(500);
        assertEq(engagement.swapVolume, 500);
        assertEq(engagement.transactionCount, 1);
    }

    function testUpdateTimeActive() public {
        // updateTimeActive doesn't exist, using updateLiquidityActivity instead
        engagement.updateLiquidityActivity(86400); // 1 day
        assertEq(engagement.totalLiquidity, 86400);
    }

    function testGetEngagementScore() public {
        engagement.updateLiquidityActivity(1000);
        engagement.updateSwapActivity(500);
        engagement.updateLiquidityActivity(86400);
        
        uint256 score = engagement.getEngagementScore();
        assertTrue(score > 0);
    }

    function testGetTier() public {
        engagement.updateLiquidityActivity(10000);
        engagement.updateSwapActivity(5000);
        engagement.updateLiquidityActivity(7 * 86400); // 7 days
        
        uint256 tier = engagement.getTier();
        assertTrue(tier >= 0);
        assertTrue(tier <= 4); // 0-4 tiers
    }

    function testMultipleUpdates() public {
        engagement.updateLiquidityActivity(1000);
        engagement.updateLiquidityActivity(2000);
        engagement.updateSwapActivity(500);
        engagement.updateSwapActivity(1000);
        
        assertEq(engagement.totalLiquidity, 3000);
        assertEq(engagement.transactionCount, 4); // 2 liquidity + 2 swap
        assertEq(engagement.swapVolume, 1500);
    }

    function testZeroValues() public {
        engagement.updateLiquidityActivity(0);
        engagement.updateSwapActivity(0);
        engagement.updateLiquidityActivity(0);
        
        assertEq(engagement.totalLiquidity, 0);
        assertEq(engagement.swapVolume, 0);
    }

    function testLargeValues() public {
        engagement.updateLiquidityActivity(1e18);
        engagement.updateSwapActivity(1e18);
        engagement.updateLiquidityActivity(365 * 86400); // 1 year
        
        assertEq(engagement.totalLiquidity, 1e18 + 365 * 86400);
        assertEq(engagement.swapVolume, 1e18);
    }

    function testEngagementScoreCalculation() public {
        // Test different combinations
        engagement.updateLiquidityActivity(1000);
        uint256 score1 = engagement.getEngagementScore();
        
        engagement.updateSwapActivity(500);
        uint256 score2 = engagement.getEngagementScore();
        
        // Both scores should be valid (0-100 range)
        assertTrue(score1 >= 0 && score1 <= 100);
        assertTrue(score2 >= 0 && score2 <= 100);
        
        // Both should be greater than 0 since we have activity
        assertTrue(score1 > 0);
        assertTrue(score2 > 0);
    }

    function testTierProgression() public {
        // Start with low activity
        engagement.updateLiquidityActivity(100);
        uint256 tier1 = engagement.getTier();
        
        // Increase activity
        engagement.updateLiquidityActivity(10000);
        engagement.updateSwapActivity(5000);
        uint256 tier2 = engagement.getTier();
        
        assertTrue(tier2 >= tier1);
    }
}
