// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {PostContentNFT} from "../src/identity/PostContentNFT.sol";
import {DustToken} from "../src/token/DustToken.sol";
import {TrustReputation1155} from "../src/identity/TrustReputation1155.sol";

contract PostContentNFTTest is Test {
    DustToken internal dust;
    TrustReputation1155 internal rep;
    PostContentNFT internal post;
    address owner = address(this);
    address user = address(0xBEEF);

    function setUp() public {
        dust = new DustToken("Dust", "DUST", owner);
        rep = new TrustReputation1155("ipfs://rep/", owner);
        post = new PostContentNFT(
            "Post",
            "POST",
            owner,
            address(dust),
            address(rep),
            4001
        );
        dust.setMinter(address(post), true);
        rep.setAuthorized(address(post), true);
        dust.ownerMint(user, 20 ether); // untuk bayar fee
    }

    function testMintPostBurnsDustAndMintsNFT() public {
        vm.prank(user);
        uint256 tokenId = post.mintPost("ipfs://post/1");

        assertEq(tokenId, 1);
        assertEq(post.ownerOf(tokenId), user);
        assertEq(dust.balanceOf(user), 10 ether); // 20 - 10 burn
        assertEq(rep.balanceOf(user, 4001), 1);
        assertEq(post.tokenURI(tokenId), "ipfs://post/1");
    }

    function testMintPostWithoutURIReverts() public {
        vm.prank(user);
        vm.expectRevert(bytes("PostNFT: empty uri"));
        post.mintPost("");
    }
}
