// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Identity} from "src/Identity.sol";

contract IdentityTest is Test {
    Identity internal identity;
    address internal user = address(0xA11CE);

    function setUp() public {
        identity = new Identity();
    }

    function testAddTrustAndTier() public {
        identity.addTrust(user, 10);
        identity.setTier(user, 2);
        (uint256 trust, uint256 tier,,,,bool hasBadge) = identity.users(user);
        assertEq(trust, 10);
        assertEq(tier, 2);
        assertTrue(hasBadge);
    }

    function testReputationPostsJobs() public {
        identity.addReputation(user, 5);
        identity.addPost(user);
        identity.addJobCompleted(user);
        (, , uint256 rep, uint256 posts, uint256 jobs,) = identity.users(user);
        assertEq(rep, 5);
        assertEq(posts, 1);
        assertEq(jobs, 1);
    }
}
