// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RewardMath} from "../../src/hooks/libraries/RewardMath.sol";

contract RewardMathTest is Test {
    using RewardMath for uint256;

    function testMulDiv() public {
        uint256 a = 100;
        uint256 b = 200;
        uint256 denominator = 1000;
        assertEq(a.mulDiv(b, denominator), 20);
    }

    // function testMulDivZeroDenominator() public {
    //     uint256 a = 100;
    //     uint256 b = 200;
    //     uint256 denominator = 0;
    //     vm.expectRevert();
    //     a.mulDiv(b, denominator);
    // }

    function testMulDivLargeNumbers() public {
        uint256 a = 1e18;
        uint256 b = 2e18;
        uint256 denominator = 1e18;
        assertEq(a.mulDiv(b, denominator), 2e18);
    }

    function testMulDivWithRemainder() public {
        uint256 a = 7;
        uint256 b = 3;
        uint256 denominator = 2;
        assertEq(a.mulDiv(b, denominator), 10); // 7 * 3 / 2 = 21 / 2 = 10
    }

    // function testMulDivZeroNumerator() public {
    //     uint256 a = 0;
    //     uint256 b = 100;
    //     uint256 denominator = 50;
    //     vm.expectRevert();
    //     a.mulDiv(b, denominator);
    // }

    function testMulDivZeroMultiplier() public {
        uint256 a = 100;
        uint256 b = 0;
        uint256 denominator = 50;
        assertEq(a.mulDiv(b, denominator), 0);
    }

    function testMulDivOneDenominator() public {
        uint256 a = 100;
        uint256 b = 200;
        uint256 denominator = 1;
        assertEq(a.mulDiv(b, denominator), 20000);
    }

    function testMulDivEqualValues() public {
        uint256 a = 100;
        uint256 b = 100;
        uint256 denominator = 100;
        assertEq(a.mulDiv(b, denominator), 100);
    }

    function testMulDivMaxValues() public {
        uint256 a = type(uint256).max;
        uint256 b = 1;
        uint256 denominator = type(uint256).max;
        assertEq(a.mulDiv(b, denominator), 1);
    }

    function testMulDivPrecision() public {
        uint256 a = 1;
        uint256 b = 1;
        uint256 denominator = 3;
        assertEq(a.mulDiv(b, denominator), 0); // 1 * 1 / 3 = 0 (integer division)
    }

    function testMulDivRounding() public {
        uint256 a = 1;
        uint256 b = 2;
        uint256 denominator = 3;
        assertEq(a.mulDiv(b, denominator), 0); // 1 * 2 / 3 = 0 (integer division)
    }
}