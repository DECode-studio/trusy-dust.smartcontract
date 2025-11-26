// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Identity} from "src/Identity.sol";
import {DustToken} from "src/DustToken.sol";
import {Content} from "src/Content.sol";

contract ContentTest is Test {
    Identity internal identity;
    DustToken internal dust;
    Content internal content;
    address internal user = address(0xA11CE);

    function setUp() public {
        identity = new Identity();
        dust = new DustToken("Dust", "DUST", address(this));
        content = new Content(identity, dust);
        dust.setRole(address(content), DustToken.Role.OPERATOR);
        dust.setRole(address(this), DustToken.Role.OPERATOR);
    }

    function testMintPostBurnsFee() public {
        dust.mint(user, 20e18);
        vm.prank(user);
        content.mintPost("ipfs://uri");
        (, , , uint256 posts, , ) = identity.users(user);
        assertEq(posts, 1);
        assertEq(dust.balanceOf(user), 10e18);
    }

    function testMintPostRevertInsufficient() public {
        dust.mint(user, 5e18);
        vm.prank(user);
        vm.expectRevert();
        content.mintPost("ipfs://uri");
    }
}
