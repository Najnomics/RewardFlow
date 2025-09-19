// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RewardMath} from "../../src/hooks/libraries/RewardMath.sol";

contract RewardMathTest is Test {
    using RewardMath for uint256;

    function testMulDiv() public {
        uint256 a = 1000;
        uint256 b = 2000;
        uint256 denominator = 10000;
        
        uint256 result = a.mulDiv(b, denominator);
        assertEq(result, 200); // (1000 * 2000) / 10000 = 200
    }

    function testMulDivWithZero() public {
        uint256 a = 0;
        uint256 b = 2000;
        uint256 denominator = 10000;
        
        uint256 result = a.mulDiv(b, denominator);
        assertEq(result, 0);
    }

    function testMulDivWithDenominatorZero() public {
        uint256 a = 1000;
        uint256 b = 2000;
        uint256 denominator = 0;
        
        vm.expectRevert();
        a.mulDiv(b, denominator);
    }

    function testMulDivLargeNumbers() public {
        uint256 a = 1e18;
        uint256 b = 2e18;
        uint256 denominator = 1e18;
        
        uint256 result = a.mulDiv(b, denominator);
        assertEq(result, 2e18);
    }

    function testMulDivPrecision() public {
        uint256 a = 1;
        uint256 b = 3;
        uint256 denominator = 2;
        
        uint256 result = a.mulDiv(b, denominator);
        assertEq(result, 1); // 3/2 = 1.5, truncated to 1
    }

    function testMulDivRounding() public {
        uint256 a = 1;
        uint256 b = 1;
        uint256 denominator = 3;
        
        uint256 result = a.mulDiv(b, denominator);
        assertEq(result, 0); // 1/3 = 0.333..., truncated to 0
    }

    function testMulDivEdgeCases() public {
        // Test with maximum values
        uint256 max = type(uint256).max;
        uint256 result = max.mulDiv(1, max);
        assertEq(result, 1);
        
        result = max.mulDiv(max, max);
        assertEq(result, max);
    }

    function testMulDivConsistency() public {
        uint256 a = 1000;
        uint256 b = 2000;
        uint256 denominator = 10000;
        
        // Calculate multiple times - should be consistent
        uint256 result1 = a.mulDiv(b, denominator);
        uint256 result2 = a.mulDiv(b, denominator);
        
        assertEq(result1, result2);
    }

    function testMulDivWithOne() public {
        uint256 a = 1000;
        uint256 b = 1;
        uint256 denominator = 1;
        
        uint256 result = a.mulDiv(b, denominator);
        assertEq(result, 1000);
    }

    function testMulDivWithSameValues() public {
        uint256 a = 1000;
        uint256 b = 1000;
        uint256 denominator = 1000;
        
        uint256 result = a.mulDiv(b, denominator);
        assertEq(result, 1000);
    }

    function testMulDivWithSmallDenominator() public {
        uint256 a = 1000;
        uint256 b = 2000;
        uint256 denominator = 1;
        
        uint256 result = a.mulDiv(b, denominator);
        assertEq(result, 2000000); // 1000 * 2000 / 1
    }

    function testMulDivWithLargeDenominator() public {
        uint256 a = 1000;
        uint256 b = 2000;
        uint256 denominator = 1000000;
        
        uint256 result = a.mulDiv(b, denominator);
        assertEq(result, 2); // 2000000 / 1000000 = 2
    }

    function testMulDivOverflow() public {
        uint256 a = type(uint256).max;
        uint256 b = 2;
        uint256 denominator = 1;
        
        vm.expectRevert();
        a.mulDiv(b, denominator);
    }

    function testMulDivUnderflow() public {
        uint256 a = 1;
        uint256 b = 0;
        uint256 denominator = 1;
        
        uint256 result = a.mulDiv(b, denominator);
        assertEq(result, 0);
    }

    function testMulDivFractionalResult() public {
        uint256 a = 1;
        uint256 b = 1;
        uint256 denominator = 2;
        
        uint256 result = a.mulDiv(b, denominator);
        assertEq(result, 0); // 1/2 = 0.5, truncated to 0
    }

    function testMulDivExactDivision() public {
        uint256 a = 1000;
        uint256 b = 2000;
        uint256 denominator = 500;
        
        uint256 result = a.mulDiv(b, denominator);
        assertEq(result, 4000); // (1000 * 2000) / 500 = 4000
    }

    function testMulDivWithBasisPoints() public {
        uint256 amount = 1000;
        uint256 basisPoints = 2500; // 25%
        uint256 denominator = 10000; // 100%
        
        uint256 result = amount.mulDiv(basisPoints, denominator);
        assertEq(result, 250); // 1000 * 25% = 250
    }

    function testMulDivWithPercentage() public {
        uint256 amount = 1000;
        uint256 percentage = 50; // 50%
        uint256 denominator = 100; // 100%
        
        uint256 result = amount.mulDiv(percentage, denominator);
        assertEq(result, 500); // 1000 * 50% = 500
    }

    function testMulDivWithDecimals() public {
        uint256 amount = 1000;
        uint256 multiplier = 15e17; // 1.5
        uint256 denominator = 1e18; // 1.0
        
        uint256 result = amount.mulDiv(multiplier, denominator);
        assertEq(result, 1500); // 1000 * 1.5 = 1500
    }

    function testMulDivWithVerySmallNumbers() public {
        uint256 a = 1;
        uint256 b = 1;
        uint256 denominator = 1000000;
        
        uint256 result = a.mulDiv(b, denominator);
        assertEq(result, 0); // 1/1000000 = 0.000001, truncated to 0
    }

    function testMulDivWithVeryLargeDenominator() public {
        uint256 a = 1000;
        uint256 b = 1;
        uint256 denominator = type(uint256).max;
        
        uint256 result = a.mulDiv(b, denominator);
        assertEq(result, 0); // Very small result, truncated to 0
    }

    function testMulDivGasUsage() public {
        uint256 a = 1000;
        uint256 b = 2000;
        uint256 denominator = 10000;
        
        uint256 gasStart = gasleft();
        uint256 result = a.mulDiv(b, denominator);
        uint256 gasUsed = gasStart - gasleft();
        
        assertEq(result, 200);
        assertLt(gasUsed, 1000); // Should use reasonable amount of gas
    }

    function testMulDivMultipleOperations() public {
        uint256 a = 1000;
        uint256 b = 2000;
        uint256 c = 3000;
        uint256 denominator = 10000;
        
        uint256 result1 = a.mulDiv(b, denominator);
        uint256 result2 = b.mulDiv(c, denominator);
        uint256 result3 = a.mulDiv(c, denominator);
        
        assertEq(result1, 200);
        assertEq(result2, 600);
        assertEq(result3, 300);
    }

    function testMulDivWithZeroNumerator() public {
        uint256 a = 0;
        uint256 b = 2000;
        uint256 denominator = 10000;
        
        uint256 result = a.mulDiv(b, denominator);
        assertEq(result, 0);
    }

    function testMulDivWithZeroMultiplier() public {
        uint256 a = 1000;
        uint256 b = 0;
        uint256 denominator = 10000;
        
        uint256 result = a.mulDiv(b, denominator);
        assertEq(result, 0);
    }
}
