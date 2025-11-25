// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Identity} from "./Identity.sol";
import {DustToken} from "./DustToken.sol";
import {SharedTypes} from "./SharedTypes.sol";
import {Errors} from "./Errors.sol";

/// @notice Simplified content/post minting that burns DUST and updates identity stats.
contract Content {
    Identity public identity;
    DustToken public dust;
    uint256 public constant POST_FEE = 10e18; // 10 DUST (18 decimals)

    constructor(Identity identity_, DustToken dust_) {
        identity = identity_;
        dust = dust_;
    }

    function mintPost(string calldata /*uri*/ ) external {
        dust.burn(msg.sender, POST_FEE);
        identity.addPost(msg.sender);
    }
}
