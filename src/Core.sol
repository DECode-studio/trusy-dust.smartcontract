// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Identity} from "./Identity.sol";
import {DustToken} from "./DustToken.sol";
import {SharedTypes} from "./SharedTypes.sol";

/// @notice Core reward/tier logic with simplified access (no role functions).
contract Core {
    Identity public identity;
    DustToken public dust;

    // Rewards denominated in DUST (18 decimals)
    uint256 public likeReward = 1e18;
    uint256 public commentReward = 3e18;
    uint256 public repostReward = 1e18;

    constructor(Identity identity_, DustToken dust_) {
        identity = identity_;
        dust = dust_;
    }

    function rewardSocial(address user, uint8 actionType) external {
        SharedTypes.SocialAction action = SharedTypes.SocialAction(actionType);
        uint256 delta = action == SharedTypes.SocialAction.LIKE
            ? likeReward
            : action == SharedTypes.SocialAction.COMMENT
                ? commentReward
                : repostReward;

        identity.addTrust(user, delta);
        dust.mint(user, delta);
    }

    function rewardJob(address user, uint8 rating) external {
        require(rating >= 1 && rating <= 5, "invalid rating");
        uint256 delta = rating == 5
            ? 200e18
            : rating == 4
                ? 150e18
                : rating == 3
                    ? 100e18
                    : rating == 2
                        ? 50e18
                        : 20e18;
        identity.addTrust(user, delta);
        identity.addJobCompleted(user);
        dust.mint(user, delta);
    }
}
