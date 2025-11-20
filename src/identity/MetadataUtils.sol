// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MetadataUtils
/// @notice Helper untuk build metadata URI sederhana (opsional).
library MetadataUtils {
    function badgeTierPath(uint256 tier) internal pure returns (string memory) {
        if (tier == 0) return "dust.json";
        if (tier == 1) return "spark.json";
        if (tier == 2) return "flare.json";
        if (tier == 3) return "nova.json";
        return "unknown.json";
    }
}
