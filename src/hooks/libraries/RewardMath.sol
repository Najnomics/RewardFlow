// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title RewardMath
 * @notice Library for reward calculation mathematics
 */
library RewardMath {
    /// @notice Precision for calculations (18 decimals)
    uint256 public constant PRECISION = 1e18;
    
    /// @notice Maximum multiplier (10x)
    uint256 public constant MAX_MULTIPLIER = 10e18;
    
    /// @notice Minimum multiplier (0.1x)
    uint256 public constant MIN_MULTIPLIER = 1e17;

    /// @notice Safe multiplication with precision
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256) {
        if (denominator == 0) {
            revert("Division by zero");
        }
        
        uint256 z = x * y;
        require(z / x == y, "Multiplication overflow");
        
        return z / denominator;
    }

    /// @notice Calculate compound interest
    function compound(
        uint256 principal,
        uint256 rate,
        uint256 time
    ) internal pure returns (uint256) {
        if (time == 0) return principal;
        
        // Simple compound interest: A = P(1 + r)^t
        // Using approximation for gas efficiency
        uint256 result = principal;
        for (uint256 i = 0; i < time; i++) {
            result = mulDiv(result, PRECISION + rate, PRECISION);
        }
        
        return result;
    }

    /// @notice Calculate exponential decay
    function exponentialDecay(
        uint256 value,
        uint256 decayRate,
        uint256 time
    ) internal pure returns (uint256) {
        if (time == 0) return value;
        
        // Exponential decay: A = A0 * e^(-rt)
        // Using approximation: A = A0 * (1 - r)^t
        uint256 decayFactor = PRECISION - decayRate;
        uint256 result = value;
        
        for (uint256 i = 0; i < time; i++) {
            result = mulDiv(result, decayFactor, PRECISION);
        }
        
        return result;
    }

    /// @notice Calculate tier multiplier based on activity
    function calculateTierMultiplier(
        uint256 totalLiquidity,
        uint256 loyaltyScore,
        uint256 timeActive
    ) internal pure returns (uint256) {
        // Base multiplier
        uint256 baseMultiplier = PRECISION;
        
        // Liquidity bonus (up to 2x for high liquidity)
        uint256 liquidityBonus = 1e18 + (totalLiquidity * 1e15) / 1e18; // 1% per 1 ETH
        if (liquidityBonus > 2e18) liquidityBonus = 2e18;
        
        // Loyalty bonus (up to 1.5x for high loyalty)
        uint256 loyaltyBonus = 1e18 + (loyaltyScore * 5e15) / 100; // 5% per loyalty point
        if (loyaltyBonus > 15e17) loyaltyBonus = 15e17;
        
        // Time bonus (up to 1.2x for long-term users)
        uint256 timeBonus = 1e18 + (timeActive * 1e15) / 1e18; // 1% per day
        if (timeBonus > 12e17) timeBonus = 12e17;
        
        // Calculate final multiplier
        uint256 multiplier = mulDiv(
            mulDiv(baseMultiplier, liquidityBonus, PRECISION),
            mulDiv(loyaltyBonus, timeBonus, PRECISION),
            PRECISION
        );
        
        // Ensure within bounds
        if (multiplier > MAX_MULTIPLIER) multiplier = MAX_MULTIPLIER;
        if (multiplier < MIN_MULTIPLIER) multiplier = MIN_MULTIPLIER;
        
        return multiplier;
    }

    /// @notice Calculate time-weighted average
    function timeWeightedAverage(
        uint256[] memory values,
        uint256[] memory weights
    ) internal pure returns (uint256) {
        require(values.length == weights.length, "Array length mismatch");
        
        uint256 totalWeight = 0;
        uint256 weightedSum = 0;
        
        for (uint256 i = 0; i < values.length; i++) {
            totalWeight += weights[i];
            weightedSum += values[i] * weights[i];
        }
        
        if (totalWeight == 0) return 0;
        
        return weightedSum / totalWeight;
    }

    /// @notice Calculate geometric mean
    function geometricMean(
        uint256[] memory values
    ) internal pure returns (uint256) {
        if (values.length == 0) return 0;
        
        uint256 product = 1;
        for (uint256 i = 0; i < values.length; i++) {
            product = mulDiv(product, values[i], PRECISION);
        }
        
        // Calculate nth root using approximation
        uint256 n = values.length;
        uint256 root = product;
        
        for (uint256 i = 0; i < 10; i++) { // 10 iterations for approximation
            uint256 prev = root;
            root = mulDiv(
                mulDiv(root, (n - 1) * PRECISION, n * PRECISION) + 
                mulDiv(product, PRECISION, n * PRECISION),
                PRECISION,
                prev
            );
        }
        
        return root;
    }

    /// @notice Calculate reward distribution
    function calculateRewardDistribution(
        uint256 totalReward,
        uint256[] memory shares
    ) internal pure returns (uint256[] memory) {
        uint256[] memory rewards = new uint256[](shares.length);
        uint256 totalShares = 0;
        
        // Calculate total shares
        for (uint256 i = 0; i < shares.length; i++) {
            totalShares += shares[i];
        }
        
        if (totalShares == 0) return rewards;
        
        // Distribute rewards proportionally
        for (uint256 i = 0; i < shares.length; i++) {
            rewards[i] = mulDiv(totalReward, shares[i], totalShares);
        }
        
        return rewards;
    }

    /// @notice Calculate slippage protection
    function calculateSlippageProtection(
        uint256 expectedAmount,
        uint256 actualAmount,
        uint256 maxSlippage
    ) internal pure returns (uint256) {
        if (actualAmount >= expectedAmount) return actualAmount;
        
        uint256 slippage = mulDiv(expectedAmount - actualAmount, PRECISION, expectedAmount);
        
        if (slippage > maxSlippage) {
            revert("Slippage too high");
        }
        
        return actualAmount;
    }

    /// @notice Calculate fee
    function calculateFee(
        uint256 amount,
        uint256 feeRate
    ) internal pure returns (uint256) {
        return mulDiv(amount, feeRate, PRECISION);
    }

    /// @notice Calculate net amount after fee
    function calculateNetAmount(
        uint256 amount,
        uint256 feeRate
    ) internal pure returns (uint256) {
        uint256 fee = calculateFee(amount, feeRate);
        return amount - fee;
    }
}
