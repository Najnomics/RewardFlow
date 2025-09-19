// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {TierCalculations} from "../../src/hooks/libraries/TierCalculations.sol";

contract TierCalculationsTest is Test {
    using TierCalculations for mapping(address => TierCalculations.UserTier);

    mapping(address => TierCalculations.UserTier) public userTiers;
    
    address public user = address(0x123);

    function setUp() public {
        // Initialize user tier
        userTiers[user] = TierCalculations.UserTier({
            level: TierCalculations.TierLevel.BRONZE,
            totalLiquidity: 0,
            loyaltyScore: 0,
            lastUpdate: 0
        });
    }

    function testInitialTier() public {
        TierCalculations.UserTier memory tier = userTiers[user];
        
        assertEq(uint8(tier.level), 0); // BRONZE
        assertEq(tier.totalLiquidity, 0);
        assertEq(tier.loyaltyScore, 0);
        assertEq(tier.lastUpdate, 0);
    }

    function testTierLevels() public {
        TierCalculations.TierLevel bronze = TierCalculations.TierLevel.BRONZE;
        TierCalculations.TierLevel silver = TierCalculations.TierLevel.SILVER;
        TierCalculations.TierLevel gold = TierCalculations.TierLevel.GOLD;
        TierCalculations.TierLevel platinum = TierCalculations.TierLevel.PLATINUM;
        TierCalculations.TierLevel diamond = TierCalculations.TierLevel.DIAMOND;
        
        assertEq(uint8(bronze), 0);
        assertEq(uint8(silver), 1);
        assertEq(uint8(gold), 2);
        assertEq(uint8(platinum), 3);
        assertEq(uint8(diamond), 4);
    }

    function testUpdateTier() public {
        userTiers[user].level = TierCalculations.TierLevel.SILVER;
        userTiers[user].totalLiquidity = 1000;
        userTiers[user].loyaltyScore = 50;
        userTiers[user].lastUpdate = block.timestamp;
        
        TierCalculations.UserTier memory tier = userTiers[user];
        
        assertEq(uint8(tier.level), 1); // SILVER
        assertEq(tier.totalLiquidity, 1000);
        assertEq(tier.loyaltyScore, 50);
        assertEq(tier.lastUpdate, block.timestamp);
    }

    function testCalculateTierFromLiquidity() public {
        // Test different liquidity amounts
        userTiers[user].totalLiquidity = 50e18; // 50 ETH
        TierCalculations.TierLevel tier1 = TierCalculations.calculateTierFromLiquidity(userTiers[user]);
        assertEq(uint8(tier1), 0); // BRONZE
        
        userTiers[user].totalLiquidity = 100e18; // 100 ETH
        TierCalculations.TierLevel tier2 = TierCalculations.calculateTierFromLiquidity(userTiers[user]);
        assertEq(uint8(tier2), 1); // SILVER
        
        userTiers[user].totalLiquidity = 500e18; // 500 ETH
        TierCalculations.TierLevel tier3 = TierCalculations.calculateTierFromLiquidity(userTiers[user]);
        assertEq(uint8(tier3), 2); // GOLD
        
        userTiers[user].totalLiquidity = 1000e18; // 1000 ETH
        TierCalculations.TierLevel tier4 = TierCalculations.calculateTierFromLiquidity(userTiers[user]);
        assertEq(uint8(tier4), 3); // PLATINUM
    }

    function testCalculateTierFromLoyalty() public {
        // Test different loyalty scores
        userTiers[user].loyaltyScore = 30;
        TierCalculations.TierLevel tier1 = TierCalculations.calculateTierFromLoyalty(userTiers[user]);
        assertEq(uint8(tier1), 0); // BRONZE
        
        userTiers[user].loyaltyScore = 50;
        TierCalculations.TierLevel tier2 = TierCalculations.calculateTierFromLoyalty(userTiers[user]);
        assertEq(uint8(tier2), 1); // SILVER
        
        userTiers[user].loyaltyScore = 70;
        TierCalculations.TierLevel tier3 = TierCalculations.calculateTierFromLoyalty(userTiers[user]);
        assertEq(uint8(tier3), 2); // GOLD
        
        userTiers[user].loyaltyScore = 90;
        TierCalculations.TierLevel tier4 = TierCalculations.calculateTierFromLoyalty(userTiers[user]);
        assertEq(uint8(tier4), 3); // PLATINUM
    }

    function testCalculateTierFromCombined() public {
        // Test combined liquidity and loyalty
        userTiers[user].totalLiquidity = 100e18; // 100 ETH
        userTiers[user].loyaltyScore = 50;
        TierCalculations.TierLevel tier1 = TierCalculations.calculateTierFromCombined(userTiers[user]);
        assertEq(uint8(tier1), 1); // SILVER
        
        userTiers[user].totalLiquidity = 500e18; // 500 ETH
        userTiers[user].loyaltyScore = 70;
        TierCalculations.TierLevel tier2 = TierCalculations.calculateTierFromCombined(userTiers[user]);
        assertEq(uint8(tier2), 2); // GOLD
        
        userTiers[user].totalLiquidity = 1000e18; // 1000 ETH
        userTiers[user].loyaltyScore = 90;
        TierCalculations.TierLevel tier3 = TierCalculations.calculateTierFromCombined(userTiers[user]);
        assertEq(uint8(tier3), 3); // PLATINUM
    }

    function testTierMultiplier() public {
        // Test tier multipliers
        uint256 bronzeMultiplier = TierCalculations.getTierMultiplier(TierCalculations.TierLevel.BRONZE);
        uint256 silverMultiplier = TierCalculations.getTierMultiplier(TierCalculations.TierLevel.SILVER);
        uint256 goldMultiplier = TierCalculations.getTierMultiplier(TierCalculations.TierLevel.GOLD);
        uint256 platinumMultiplier = TierCalculations.getTierMultiplier(TierCalculations.TierLevel.PLATINUM);
        uint256 diamondMultiplier = TierCalculations.getTierMultiplier(TierCalculations.TierLevel.DIAMOND);
        
        assertEq(bronzeMultiplier, 1e18); // 1x
        assertEq(silverMultiplier, 12e17); // 1.2x
        assertEq(goldMultiplier, 15e17); // 1.5x
        assertEq(platinumMultiplier, 18e17); // 1.8x
        assertEq(diamondMultiplier, 2e18); // 2x
    }

    function testUpdateTierFromActivity() public {
        userTiers[user].totalLiquidity = 100e18;
        userTiers[user].loyaltyScore = 50;
        userTiers[user].lastUpdate = block.timestamp;
        
        TierCalculations.updateTierFromActivity(userTiers[user]);
        
        TierCalculations.UserTier memory tier = userTiers[user];
        assertEq(uint8(tier.level), 1); // SILVER
        assertEq(tier.totalLiquidity, 100e18);
        assertEq(tier.loyaltyScore, 50);
        assertEq(tier.lastUpdate, block.timestamp);
    }

    function testMultipleUsers() public {
        address user2 = address(0x456);
        
        userTiers[user].level = TierCalculations.TierLevel.SILVER;
        userTiers[user].totalLiquidity = 100e18;
        userTiers[user].loyaltyScore = 50;
        userTiers[user].lastUpdate = block.timestamp;
        
        userTiers[user2].level = TierCalculations.TierLevel.GOLD;
        userTiers[user2].totalLiquidity = 500e18;
        userTiers[user2].loyaltyScore = 70;
        userTiers[user2].lastUpdate = block.timestamp;
        
        TierCalculations.UserTier memory tier1 = userTiers[user];
        TierCalculations.UserTier memory tier2 = userTiers[user2];
        
        assertEq(uint8(tier1.level), 1); // SILVER
        assertEq(uint8(tier2.level), 2); // GOLD
        assertEq(tier1.totalLiquidity, 100e18);
        assertEq(tier2.totalLiquidity, 500e18);
    }

    function testEdgeCaseZeroValues() public {
        userTiers[user].totalLiquidity = 0;
        userTiers[user].loyaltyScore = 0;
        
        TierCalculations.TierLevel tier = TierCalculations.calculateTierFromCombined(userTiers[user]);
        assertEq(uint8(tier), 0); // BRONZE
        
        uint256 multiplier = TierCalculations.getTierMultiplier(tier);
        assertEq(multiplier, 1e18); // 1x
    }

    function testEdgeCaseMaxValues() public {
        userTiers[user].totalLiquidity = type(uint256).max;
        userTiers[user].loyaltyScore = 100;
        
        TierCalculations.TierLevel tier = TierCalculations.calculateTierFromCombined(userTiers[user]);
        assertEq(uint8(tier), 4); // DIAMOND
        
        uint256 multiplier = TierCalculations.getTierMultiplier(tier);
        assertEq(multiplier, 2e18); // 2x
    }

    function testTierProgression() public {
        // Start with bronze
        userTiers[user].level = TierCalculations.TierLevel.BRONZE;
        userTiers[user].totalLiquidity = 0;
        userTiers[user].loyaltyScore = 0;
        
        // Progress to silver
        userTiers[user].totalLiquidity = 100e18;
        userTiers[user].loyaltyScore = 50;
        TierCalculations.updateTierFromActivity(userTiers[user]);
        assertEq(uint8(userTiers[user].level), 1); // SILVER
        
        // Progress to gold
        userTiers[user].totalLiquidity = 500e18;
        userTiers[user].loyaltyScore = 70;
        TierCalculations.updateTierFromActivity(userTiers[user]);
        assertEq(uint8(userTiers[user].level), 2); // GOLD
        
        // Progress to platinum
        userTiers[user].totalLiquidity = 1000e18;
        userTiers[user].loyaltyScore = 90;
        TierCalculations.updateTierFromActivity(userTiers[user]);
        assertEq(uint8(userTiers[user].level), 3); // PLATINUM
    }

    function testTierRegression() public {
        // Start with diamond
        userTiers[user].level = TierCalculations.TierLevel.DIAMOND;
        userTiers[user].totalLiquidity = 2000e18;
        userTiers[user].loyaltyScore = 100;
        
        // Reduce activity
        userTiers[user].totalLiquidity = 50e18;
        userTiers[user].loyaltyScore = 30;
        TierCalculations.updateTierFromActivity(userTiers[user]);
        assertEq(uint8(userTiers[user].level), 0); // BRONZE
    }

    function testConsistentTierCalculation() public {
        userTiers[user].totalLiquidity = 100e18;
        userTiers[user].loyaltyScore = 50;
        
        // Calculate tier multiple times - should be consistent
        TierCalculations.TierLevel tier1 = TierCalculations.calculateTierFromCombined(userTiers[user]);
        TierCalculations.TierLevel tier2 = TierCalculations.calculateTierFromCombined(userTiers[user]);
        
        assertEq(uint8(tier1), uint8(tier2));
    }

    function testTierBoundaryValues() public {
        // Test exact boundary values
        userTiers[user].totalLiquidity = 99e18; // Just below silver threshold
        userTiers[user].loyaltyScore = 49; // Just below silver threshold
        TierCalculations.TierLevel tier1 = TierCalculations.calculateTierFromCombined(userTiers[user]);
        assertEq(uint8(tier1), 0); // BRONZE
        
        userTiers[user].totalLiquidity = 100e18; // Exactly at silver threshold
        userTiers[user].loyaltyScore = 50; // Exactly at silver threshold
        TierCalculations.TierLevel tier2 = TierCalculations.calculateTierFromCombined(userTiers[user]);
        assertEq(uint8(tier2), 1); // SILVER
    }
}
