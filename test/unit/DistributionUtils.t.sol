// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DistributionUtils} from "../../src/distribution/libraries/DistributionUtils.sol";

contract DistributionUtilsTest is Test {
    function testCalculateDistributionFees() public {
        uint256 amount = 1000;
        
        uint256 fee = DistributionUtils.calculateFees(amount, 1); // Using chain 1 (Ethereum)
        assertEq(fee, 1e15); // Fixed base fee of 0.001 ETH
    }

    function testCalculateDistributionFeesZeroAmount() public {
        uint256 amount = 0;
        
        uint256 fee = DistributionUtils.calculateFees(amount, 1); // Using chain 1 (Ethereum)
        assertEq(fee, 1e15); // Fixed base fee regardless of amount
    }

    function testCalculateDistributionFeesZeroFeeRate() public {
        uint256 amount = 1000;
        
        uint256 fee = DistributionUtils.calculateFees(amount, 1); // Using chain 1 (Ethereum)
        assertEq(fee, 1e15); // Fixed base fee
    }

    function testCalculateDistributionFeesHighFeeRate() public {
        uint256 amount = 1000;
        
        uint256 fee = DistributionUtils.calculateFees(amount, 1); // Using chain 1 (Ethereum)
        assertEq(fee, 1e15); // Fixed base fee
    }

    function testCalculateDistributionFeesLargeAmount() public {
        uint256 amount = 1e18;
        
        uint256 fee = DistributionUtils.calculateFees(amount, 1); // Using chain 1 (Ethereum)
        assertEq(fee, 1e15); // Fixed base fee
    }

    function testCalculateDistributionFeesPrecision() public {
        uint256 amount = 333;
        
        uint256 fee = DistributionUtils.calculateFees(amount, 1); // Using chain 1 (Ethereum)
        assertEq(fee, 1e15); // Fixed base fee
    }

    function testCalculateDistributionFeesMaximumValues() public {
        uint256 amount = type(uint256).max;
        
        uint256 fee = DistributionUtils.calculateFees(amount, 1); // Using chain 1 (Ethereum)
        assertEq(fee, 1e15); // Fixed base fee
    }

    function testCalculateDistributionFeesSmallValues() public {
        uint256 amount = 1;
        
        uint256 fee = DistributionUtils.calculateFees(amount, 1); // Using chain 1 (Ethereum)
        assertEq(fee, 1e15); // Fixed base fee
    }

    function testCalculateDistributionFeesDifferentRates() public {
        uint256 amount = 1000;
        
        // Test different chains with different fee rates
        assertEq(DistributionUtils.calculateFees(amount, 1), 1e15);      // Ethereum: 0.001 ETH
        assertEq(DistributionUtils.calculateFees(amount, 42161), 1e14);  // Arbitrum: 0.0001 ETH
        assertEq(DistributionUtils.calculateFees(amount, 137), 5e13);    // Polygon: 0.00005 ETH
        assertEq(DistributionUtils.calculateFees(amount, 8453), 66666666666666); // Base: ~0.000067 ETH
    }

    function testCalculateDistributionFeesRounding() public {
        uint256 amount = 7;
        
        uint256 fee = DistributionUtils.calculateFees(amount, 1); // Using chain 1 (Ethereum)
        assertEq(fee, 1e15); // Fixed base fee
    }
}
