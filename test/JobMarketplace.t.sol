// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {
    JobMarketplace,
    ITrustCoreJobs,
    IReputation1155Jobs
} from "../src/jobs/JobMarketplace.sol";
import {DustToken} from "../src/token/DustToken.sol";

contract MockTrustCore is ITrustCoreJobs {
    bool public allow = true;
    address public lastUser;
    uint256 public lastScoreDelta;

    function setAllowed(bool allowed) external {
        allow = allowed;
    }

    function hasMinTrustScore(
        address,
        uint256
    ) external view returns (bool) {
        return allow;
    }

    function rewardJobCompletion(address user, uint256 scoreDelta) external {
        lastUser = user;
        lastScoreDelta = scoreDelta;
    }
}

contract MockReputation1155Jobs is IReputation1155Jobs {
    mapping(address => mapping(uint256 => uint256)) public minted;
    mapping(address => bool) public authorized;

    function mint(address to, uint256 id, uint256 amount) external {
        minted[to][id] += amount;
    }

    function setAuthorized(address module, bool allowed) external {
        authorized[module] = allowed;
    }
}

contract JobMarketplaceTest is Test {
    JobMarketplace internal marketplace;
    MockTrustCore internal core;
    MockReputation1155Jobs internal rep;
    DustToken internal dust;

    address internal owner = address(0xA11CE);
    address internal poster = address(0xB0B);
    address internal worker = address(0xC0DE);

    function setUp() public {
        dust = new DustToken("Dust", "DUST", owner);
        core = new MockTrustCore();
        rep = new MockReputation1155Jobs();
        marketplace = new JobMarketplace(
            owner,
            address(dust),
            address(core),
            address(rep)
        );
        vm.prank(owner);
        dust.setMinter(address(marketplace), true);
        vm.prank(owner);
        rep.setAuthorized(address(marketplace), true);
        vm.prank(owner);
        dust.ownerMint(poster, 20 ether); // untuk bayar fee burn
    }

    function testJobLifecycleBurnFeeAndRewardReputation() public {
        uint256 minScore = 100;

        vm.prank(poster);
        uint256 jobId = marketplace.createJob(minScore);

        // fee burn 10 DUST
        assertEq(dust.balanceOf(poster), 10 ether);

        vm.prank(worker);
        marketplace.applyToJob(jobId);

        vm.prank(poster);
        marketplace.assignWorker(jobId, worker);

        vm.prank(worker);
        marketplace.submitWork(jobId);

        vm.prank(poster);
        marketplace.approveJob(jobId, 5);

        assertEq(core.lastUser(), worker);
        assertEq(core.lastScoreDelta(), 200);
        assertEq(
            rep.minted(worker, marketplace.JOB_COMPLETION_ACHIEVEMENT_ID()),
            1
        );
    }
}
