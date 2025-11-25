// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {DustToken} from "src/DustToken.sol";
import {Errors} from "src/Errors.sol";

contract DustTokenTest is Test {
    DustToken internal dust;
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    function setUp() public {
        dust = new DustToken("Dust", "DUST", address(this));
        dust.mint(alice, 100e18);
    }

    function testTransfer() public {
        vm.prank(alice);
        vm.expectRevert(bytes("DUST: NON TRANSFERABLE"));
        dust.transfer(bob, 10e18);
    }

    function testTransferRevertZero() public {
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0))
        );
        vm.prank(alice);
        dust.transfer(address(0), 1);
        assertEq(dust.balanceOf(alice), 100e18);
    }

    function testBurn() public {
        dust.burn(alice, 50e18);
        assertEq(dust.balanceOf(alice), 50e18);
    }

    function testBurnRevertInsufficient() public {
        vm.expectRevert();
        dust.burn(alice, 200e18);
    }
}
