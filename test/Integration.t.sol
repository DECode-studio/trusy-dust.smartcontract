// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {BaseTest} from "./Base.t.sol";
import {SharedTypes} from "src/SharedTypes.sol";
import {Errors} from "src/Errors.sol";
import {IExternalVerifier} from "src/Verifier.sol";

contract MockExternalVerifier is IExternalVerifier, Test {
    bool public result = true;

    function setResult(bool r) external {
        result = r;
    }

    function verify(
        bytes calldata,
        bytes32[] calldata
    ) external view returns (bool) {
        return result;
    }
}

contract IntegrationTest is BaseTest {
    MockExternalVerifier internal extTier;
    address internal poster;
    address internal worker;
    address internal user;

    function setUp() public override {
        super.setUp();
        poster = user1;
        worker = user2;
        user = user1;
        extTier = new MockExternalVerifier();
        verifier.setVerifiers(address(extTier), address(extTier));
    }

    function testFullJobFlowAndRewards() public {
        vm.prank(poster);
        uint256 jobId = jobs.createJob(50e18);
        assertEq(dust.balanceOf(poster), 990e18);

        vm.prank(poster);
        jobs.assignWorker(jobId, worker);

        vm.prank(poster);
        jobs.approveJob(jobId, 4);

        (uint256 trust, , , , uint256 jobsCompleted, ) = identity.users(worker);
        assertEq(trust, 150e18);
        assertEq(jobsCompleted, 1);
        assertEq(dust.balanceOf(worker), 1_150e18);

        (, , , , , SharedTypes.JobStatus status) = jobs.jobs(jobId);
        assertEq(uint8(status), uint8(SharedTypes.JobStatus.COMPLETED));
    }

    function testSocialRewardsStacking() public {
        core.rewardSocial(user, uint8(SharedTypes.SocialAction.LIKE));
        core.rewardSocial(user, uint8(SharedTypes.SocialAction.COMMENT));
        core.rewardSocial(user, uint8(SharedTypes.SocialAction.REPOST));

        (uint256 trust, , , , , ) = identity.users(user);
        assertEq(trust, 5e18);
        assertEq(dust.balanceOf(user), 1_005e18);
    }

    function testContentAndRewardComposition() public {
        dust.mint(user, 20e18);
        vm.prank(user);
        content.mintPost("ipfs://1");
        vm.prank(user);
        content.mintPost("ipfs://2");

        core.rewardJob(user, 5); // +200e18
        (, , , uint256 posts, , ) = identity.users(user);
        assertEq(posts, 2);
        assertEq(dust.balanceOf(user), 1_200e18);
    }

    function testCancelJobUnauthorizedReverts() public {
        vm.prank(poster);
        uint256 jobId = jobs.createJob(10e18);
        vm.prank(worker);
        vm.expectRevert(Errors.Unauthorized.selector);
        jobs.cancelJob(jobId);
    }

    function testVerifierTierUpdate() public {
        bool ok = verifier.verifyTier(hex"01", 3, 500);
        assertTrue(ok);
        (, uint256 tier, , , , bool hasBadge) = identity.users(address(this));
        assertEq(tier, 3);
        assertTrue(hasBadge);
    }

    function testVerifierFails() public {
        extTier.setResult(false);
        bool ok = verifier.verifyTier(hex"01", 1, 100);
        assertFalse(ok);
    }
}
