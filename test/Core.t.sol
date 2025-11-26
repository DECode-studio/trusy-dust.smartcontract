// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Identity} from "src/Identity.sol";
import {DustToken} from "src/DustToken.sol";
import {Core} from "src/Core.sol";

contract CoreTest is Test {
    Identity internal identity;
    DustToken internal dust;
    Core internal core;
    address internal user = address(0xA11CE);

    function setUp() public {
        identity = new Identity();
        dust = new DustToken("Dust", "DUST", address(this));
        core = new Core(identity, dust);
        dust.setRole(address(core), DustToken.Role.OPERATOR);
        dust.setRole(address(this), DustToken.Role.OPERATOR);
    }

    function testRewardSocialLike() public {
        core.rewardSocial(user, 0); // LIKE
        (uint256 trust, , , , , ) = identity.users(user);
        assertEq(trust, 1e18);
        assertEq(dust.balanceOf(user), 1e18);
    }

    function testRewardJobRating5() public {
        core.rewardJob(user, 5);
        (uint256 trust, , , , , ) = identity.users(user);
        assertEq(trust, 200e18);
        assertEq(dust.balanceOf(user), 200e18);
    }

    function testRewardJobInvalidRatingReverts() public {
        vm.expectRevert();
        core.rewardJob(user, 0);
    }
}
