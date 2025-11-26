// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Identity} from "src/Identity.sol";
import {DustToken} from "src/DustToken.sol";
import {Core} from "src/Core.sol";
import {Jobs} from "src/Jobs.sol";
import {SharedTypes} from "src/SharedTypes.sol";
import {Errors} from "src/Errors.sol";

contract JobsTest is Test {
    Identity internal identity;
    DustToken internal dust;
    Core internal core;
    Jobs internal jobs;

    address internal poster = address(0xA11CE);
    address internal worker = address(0xB0B);

    function setUp() public {
        identity = new Identity();
        dust = new DustToken("Dust", "DUST", address(this));
        core = new Core(identity, dust);
        jobs = new Jobs(identity, dust, core);
        // grant operator roles to contracts that mint/burn
        dust.setRole(address(core), DustToken.Role.OPERATOR);
        dust.setRole(address(jobs), DustToken.Role.OPERATOR);
        dust.setRole(address(this), DustToken.Role.OPERATOR);
        dust.mint(poster, 100e18);
        dust.mint(worker, 100e18);
    }

    function testCreateJobBurnsFee() public {
        vm.prank(poster);
        uint256 jobId = jobs.createJob(10e18);
        assertEq(jobId, 1);
        assertEq(dust.balanceOf(poster), 90e18);
    }

    function testApproveJobUpdatesStatusAndRewards() public {
        vm.prank(poster);
        uint256 jobId = jobs.createJob(10e18);
        vm.prank(poster);
        jobs.assignWorker(jobId, worker);
        vm.prank(poster);
        jobs.approveJob(jobId, 5);
        (, , , , uint256 jobsCompleted, ) = identity.users(worker);
        assertEq(jobsCompleted, 1);
        assertEq(dust.balanceOf(worker), 300e18); // initial 100e18 + reward 200e18
    }

    function testApproveJobWrongPosterReverts() public {
        vm.prank(poster);
        uint256 jobId = jobs.createJob(10e18);
        vm.expectRevert(Errors.Unauthorized.selector);
        vm.prank(worker);
        jobs.approveJob(jobId, 3);
    }

    function testCancelJob() public {
        vm.prank(poster);
        uint256 jobId = jobs.createJob(10e18);
        vm.prank(poster);
        jobs.cancelJob(jobId);
        (, , , , , SharedTypes.JobStatus status) = jobs.jobs(jobId);
        assertEq(uint8(status), uint8(SharedTypes.JobStatus.CANCELLED));
    }
}
