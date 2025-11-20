// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title IDustToken
/// @notice Interface standar untuk DUST token (ERC20) di ekosistem TrustyDust.
interface IDustToken is IERC20, IERC20Metadata {
    /// @notice Mint DUST ke user (dipanggil modul authorized: TrustCore / RewardEngine / dll).
    function mint(address to, uint256 amount) external;

    /// @notice Burn DUST dari user (dipanggil modul authorized, misal untuk penalti).
    function burn(address from, uint256 amount) external;
}
