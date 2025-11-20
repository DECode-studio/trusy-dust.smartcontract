// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IDustToken} from "../interfaces/IDustToken.sol";
import {TokenErrors} from "./TokenErrors.sol";

/// @title DustToken
/// @notice ERC20 untuk TrustScore / reputasi on-chain di ekosistem TrustyDust.
///         Mint hanya bisa dilakukan oleh minter (TrustCoreImpl, RewardEngine, dll).
contract DustToken is ERC20, Ownable, IDustToken {
    using TokenErrors for *;

    /// @dev mapping modul => boleh mint/burn atau tidak
    mapping(address => bool) public isMinter;

    event MinterUpdated(address indexed minter, bool allowed);

    constructor(
        string memory name_,
        string memory symbol_,
        address owner_
    ) ERC20(name_, symbol_) Ownable(owner_) {
        require(owner_ != address(0), "DustToken: zero owner");
    }

    // ========= MODIFIER =========

    modifier onlyMinter() {
        if (!isMinter[msg.sender]) revert TokenErrors.NotMinter();
        _;
    }

    // ========= ADMIN / OWNER =========

    /// @notice Set / revoke minter (TrustCoreImpl, RewardEngine, dsb).
    function setMinter(address minter, bool allowed) external onlyOwner {
        if (minter == address(0)) revert TokenErrors.ZeroAddress();
        isMinter[minter] = allowed;
        emit MinterUpdated(minter, allowed);
    }

    /// @notice Owner optional bisa mint initial supply (bootstrap, liquidity, dll).
    function ownerMint(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert TokenErrors.ZeroAddress();
        _mint(to, amount);
    }

    // ========= IDustToken IMPLEMENTATION =========

    /// @notice Mint DUST ke user (dipanggil modul yang sudah di-set sebagai minter).
    function mint(address to, uint256 amount) external override onlyMinter {
        if (to == address(0)) revert TokenErrors.ZeroAddress();
        _mint(to, amount);
    }

    /// @notice Burn DUST dari user (dipanggil modul minter, misal penalti).
    function burn(address from, uint256 amount) external override onlyMinter {
        if (from == address(0)) revert TokenErrors.ZeroAddress();
        uint256 bal = balanceOf(from);
        if (bal < amount) revert TokenErrors.InsufficientBalance();
        _burn(from, amount);
    }

    /// @notice Override decimals kalau mau beda (default 18).
    function decimals()
        public
        pure
        override(ERC20, IERC20Metadata)
        returns (uint8)
    {
        return 18;
    }
}
