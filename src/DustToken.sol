// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Errors} from "./Errors.sol";

contract DustToken is ERC20 {
    enum Role {
        NONE,
        OWNER,
        OPERATOR,
        SYSTEM
    }

    mapping(address => Role) public roles;

    constructor(
        string memory name_,
        string memory symbol_,
        address owner_
    ) ERC20(name_, symbol_) {
        if (owner_ == address(0)) revert Errors.ZeroAddress();
        roles[owner_] = Role.OWNER;
    }

    modifier onlyRole(Role requiredRole) {
        _onlyRole(requiredRole);
        _;
    }

    function _onlyRole(Role requiredRole) internal view {
        Role r = roles[msg.sender];
        if (r != requiredRole && r != Role.OWNER) {
            revert Errors.Unauthorized();
        }
    }

    function setRole(address user, Role role) external onlyRole(Role.OWNER) {
        if (user == address(0)) revert Errors.ZeroAddress();
        roles[user] = role;
    }

    function mint(address to, uint256 amount) external onlyRole(Role.OPERATOR) {
        if (to == address(0)) revert Errors.ZeroAddress();
        if (amount == 0) revert Errors.ZeroAmount();

        _mint(to, amount);
    }

    function burn(
        address from,
        uint256 amount
    ) external onlyRole(Role.OPERATOR) {
        if (from == address(0)) revert Errors.ZeroAddress();
        if (amount == 0) revert Errors.ZeroAmount();

        _burn(from, amount);
    }

    /**
     * @dev OVERRIDE _update to BLOCK all transfers
     * Only allow:
     * - MINT  : from == address(0)
     * - BURN  : to   == address(0)
     *
     * Disallow:
     * - normal transfer: from != 0 && to != 0
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (from != address(0) && to != address(0)) {
            revert("DUST: NON TRANSFERABLE");
        }

        super._update(from, to, amount);
    }
}
