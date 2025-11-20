// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {
    JobMarketplace,
    ITrustCoreJobs,
    IReputation1155Jobs
} from "../src/jobs/JobMarketplace.sol";
import {EscrowVault} from "../src/jobs/EscrowVault.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MOCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

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

    function mint(address to, uint256 id, uint256 amount) external {
        minted[to][id] += amount;
    }
}

contract JobMarketplaceTest is Test {
    JobMarketplace internal marketplace;
    EscrowVault internal vault;
    MockERC20 internal token;
    MockTrustCore internal core;
    MockReputation1155Jobs internal rep;

    address internal owner = address(0xA11CE);
    address internal poster = address(0xB0B);
    address internal worker = address(0xC0DE);
    address internal bonus = address(0xD00D);

    function setUp() public {
        token = new MockERC20();
        core = new MockTrustCore();
        rep = new MockReputation1155Jobs();

        vm.prank(owner);
        vault = new EscrowVault(owner, bonus);
        vm.prank(owner);
        vault.setMarketplace(address(this)); // temp to allow marketplace constructor to pass checks

        vm.prank(owner);
        marketplace = new JobMarketplace(
            owner,
            address(core),
            address(vault),
            address(rep)
        );

        vm.prank(owner);
        vault.setMarketplace(address(marketplace));
    }

    function testJobLifecycleFundsReleaseAndReward() public {
        uint256 rewardAmount = 1_000 ether;
        token.mint(poster, rewardAmount);

        vm.prank(poster);
        token.approve(address(vault), rewardAmount);

        vm.prank(poster);
        uint256 jobId = marketplace.createJob(
            address(token),
            rewardAmount,
            100
        );

        // funds locked in escrow
        assertEq(token.balanceOf(address(vault)), rewardAmount);

        vm.prank(worker);
        marketplace.applyToJob(jobId);

        vm.prank(poster);
        marketplace.assignWorker(jobId, worker);

        vm.prank(worker);
        marketplace.submitWork(jobId);

        vm.prank(poster);
        marketplace.approveJob(jobId, 5); // rating 5 → scoreDelta 200

        assertEq(token.balanceOf(worker), (rewardAmount * 80) / 100);
        assertEq(token.balanceOf(bonus), rewardAmount - (rewardAmount * 80) / 100);
        assertEq(core.lastUser(), worker);
        assertEq(core.lastScoreDelta(), 200);
        assertEq(
            rep.minted(worker, marketplace.JOB_COMPLETION_ACHIEVEMENT_ID()),
            1
        );
    }
}
