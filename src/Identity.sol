// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {SharedTypes} from "./SharedTypes.sol";

/// @notice Identity registry holding user state (trustScore, tier, reputation, posts, jobs). No role setter functions.
contract Identity {
    mapping(address => SharedTypes.User) public users;

    function addTrust(address user, uint256 delta) external {
        users[user].trustScore += delta;
    }

    function setTier(address user, uint256 tier) external {
        users[user].tier = tier;
        users[user].hasBadge = true;
    }

    function addReputation(address user, uint256 delta) external {
        users[user].reputation += delta;
    }

    function addPost(address user) external {
        users[user].posts += 1;
    }

    function addJobCompleted(address user) external {
        users[user].jobsCompleted += 1;
    }
}
