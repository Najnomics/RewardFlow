// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {TierCalculations} from "../../src/hooks/libraries/TierCalculations.sol";

contract TierCalculationsTest is Test {
    function testCalculateTier() public {
        uint256 totalLiquidity = 1000e18;
        uint256 loyaltyScore = 100;
        uint256 consecutiveDays = 30;
        TierCalculations.TierLevel tier = TierCalculations.calculateTier(totalLiquidity, loyaltyScore, consecutiveDays);
        assertTrue(uint8(tier) >= 0 && uint8(tier) <= 4);
    }

    function testCalculateTierZero() public {
        uint256 totalLiquidity = 0;
        uint256 loyaltyScore = 0;
        uint256 consecutiveDays = 0;
        TierCalculations.TierLevel tier = TierCalculations.calculateTier(totalLiquidity, loyaltyScore, consecutiveDays);
        assertEq(uint8(tier), 0);
    }

    function testCalculateTierMax() public {
        uint256 totalLiquidity = 1000000e18; // 1M ETH
        uint256 loyaltyScore = 1000;
        uint256 consecutiveDays = 365;
        TierCalculations.TierLevel tier = TierCalculations.calculateTier(totalLiquidity, loyaltyScore, consecutiveDays);
        assertTrue(uint8(tier) >= 0 && uint8(tier) <= 4);
    }

    function testGetTierMultiplier() public {
        assertEq(TierCalculations.getTierMultiplier(TierCalculations.TierLevel.BRONZE), 100);
        assertEq(TierCalculations.getTierMultiplier(TierCalculations.TierLevel.SILVER), 110);
        assertEq(TierCalculations.getTierMultiplier(TierCalculations.TierLevel.GOLD), 125);
        assertEq(TierCalculations.getTierMultiplier(TierCalculations.TierLevel.PLATINUM), 150);
        assertEq(TierCalculations.getTierMultiplier(TierCalculations.TierLevel.DIAMOND), 200);
    }

    function testCalculateTierBonus() public {
        uint256 baseReward = 1000e18;
        uint256 bronzeBonus = TierCalculations.calculateTierBonus(baseReward, TierCalculations.TierLevel.BRONZE);
        uint256 goldBonus = TierCalculations.calculateTierBonus(baseReward, TierCalculations.TierLevel.GOLD);
        uint256 diamondBonus = TierCalculations.calculateTierBonus(baseReward, TierCalculations.TierLevel.DIAMOND);
        
        assertEq(bronzeBonus, baseReward);
        assertEq(goldBonus, baseReward * 125 / 100);
        assertEq(diamondBonus, baseReward * 200 / 100);
    }

    function testGetDefaultThresholds() public {
        TierCalculations.TierThresholds memory thresholds = TierCalculations.getDefaultThresholds();
        assertTrue(thresholds.bronzeMin >= 0);
        assertTrue(thresholds.silverMin > thresholds.bronzeMin);
        assertTrue(thresholds.goldMin > thresholds.silverMin);
        assertTrue(thresholds.platinumMin > thresholds.goldMin);
        assertTrue(thresholds.diamondMin > thresholds.platinumMin);
    }

    function testGetDefaultMultipliers() public {
        TierCalculations.TierMultipliers memory multipliers = TierCalculations.getDefaultMultipliers();
        assertEq(multipliers.bronze, 100);
        assertEq(multipliers.silver, 110);
        assertEq(multipliers.gold, 125);
        assertEq(multipliers.platinum, 150);
        assertEq(multipliers.diamond, 200);
    }

    function testFuzzCalculateTier(uint256 totalLiquidity, uint256 loyaltyScore, uint256 consecutiveDays) public {
        vm.assume(totalLiquidity < type(uint256).max / 3);
        vm.assume(loyaltyScore < type(uint256).max / 3);
        vm.assume(consecutiveDays < type(uint256).max / 3);
        
        TierCalculations.TierLevel tier = TierCalculations.calculateTier(totalLiquidity, loyaltyScore, consecutiveDays);
        assertTrue(uint8(tier) >= 0 && uint8(tier) <= 4);
    }

    function testFuzzGetTierMultiplier(uint8 tierLevel) public {
        vm.assume(tierLevel <= 4);
        TierCalculations.TierLevel tier = TierCalculations.TierLevel(tierLevel);
        uint256 multiplier = TierCalculations.getTierMultiplier(tier);
        assertTrue(multiplier >= 100);
    }

    function testFuzzCalculateTierBonus(uint256 baseReward, uint8 tierLevel) public {
        vm.assume(tierLevel <= 4);
        vm.assume(baseReward < type(uint256).max / 200); // Prevent overflow
        
        TierCalculations.TierLevel tier = TierCalculations.TierLevel(tierLevel);
        uint256 bonus = TierCalculations.calculateTierBonus(baseReward, tier);
        assertTrue(bonus >= baseReward);
    }
}