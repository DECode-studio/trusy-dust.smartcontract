// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {DustToken} from "../src/token/DustToken.sol";
import {TokenErrors} from "../src/token/TokenErrors.sol";

contract DustTokenTest is Test {
    DustToken internal token;
    address internal owner = address(0xAAA);
    address internal minter = address(0xBEEF);
    address internal user = address(0xCAFE);

    function setUp() public {
        vm.prank(owner);
        token = new DustToken("Dust", "DUST", owner);
    }

    function testOwnerCanSetMinterAndMintBurn() public {
        vm.prank(owner);
        token.setMinter(minter, true);

        vm.prank(minter);
        token.mint(user, 100);
        assertEq(token.balanceOf(user), 100);

        vm.prank(minter);
        token.burn(user, 40);
        assertEq(token.balanceOf(user), 60);
    }

    function testNonMinterCannotMint() public {
        vm.expectRevert(TokenErrors.NotMinter.selector);
        token.mint(user, 1);
    }

    function testOwnerMintZeroAddressReverts() public {
        vm.prank(owner);
        vm.expectRevert(TokenErrors.ZeroAddress.selector);
        token.ownerMint(address(0), 1);
    }
}
