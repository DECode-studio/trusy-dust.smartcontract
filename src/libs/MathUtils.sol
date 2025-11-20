// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title MathUtils
/// @notice Fungsi matematika umum untuk TrustyDust.
library MathUtils {
    /// @notice Ceiling division: (a + b - 1) / b
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "DIV_BY_ZERO");
        if (a == 0) return 0;
        return (a + b - 1) / b;
    }

    /// @notice Linear mapping antara dua range:
    ///         map(x, 0–1000 score → 0–3 tier)
    function mapRange(
        uint256 x,
        uint256 inMin,
        uint256 inMax,
        uint256 outMin,
        uint256 outMax
    ) internal pure returns (uint256) {
        require(inMax > inMin, "INVALID_RANGE");
        if (x <= inMin) return outMin;
        if (x >= inMax) return outMax;
        return ((x - inMin) * (outMax - outMin)) / (inMax - inMin) + outMin;
    }

    /// @notice Hitung percentage secara aman.
    function percent(
        uint256 value,
        uint256 bps
    ) internal pure returns (uint256) {
        // bps = basis points (10000 = 100%)
        return (value * bps) / 10000;
    }

    /// @notice Trust score multiplier jika staking DUST (misal +10%).
    function applyMultiplier(
        uint256 base,
        uint256 multiplierBps
    ) internal pure returns (uint256) {
        return base + percent(base, multiplierBps);
    }

    /// @notice Clamp nilai ke rentang tertentu (0–1000 untuk Trust Score).
    function clamp(
        uint256 x,
        uint256 minVal,
        uint256 maxVal
    ) internal pure returns (uint256) {
        if (x < minVal) return minVal;
        if (x > maxVal) return maxVal;
        return x;
    }
}
