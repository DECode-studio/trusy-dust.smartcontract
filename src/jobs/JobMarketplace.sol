// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {JobEvents} from "./JobEvents.sol";
import {IDustToken} from "../interfaces/IDustToken.sol";

/// @notice Interface ke TrustCoreImpl khusus fitur jobs
interface ITrustCoreJobs {
    function hasMinTrustScore(
        address user,
        uint256 minScore
    ) external view returns (bool);

    function rewardJobCompletion(address user, uint256 scoreDelta) external;
}

/// @notice Interface minimal ke ERC1155 reputasi (dipakai untuk achievement job)
interface IReputation1155Jobs {
    function mint(address to, uint256 id, uint256 amount) external;
}

/// @title JobMarketplace
/// @notice Job board trust-gated tanpa escrow gaji; poster membayar fee burn 10 DUST saat membuat job.
contract JobMarketplace is Ownable, JobEvents {
    /// @dev data utama job yang disimpan on-chain
    struct Job {
        uint256 id;
        address poster;
        uint256 minScore; // minimum trustScore (dalam "score unit", bukan wei)
        address worker; // worker yang dipilih poster
        JobStatus status;
        uint64 createdAt;
    }

    mapping(uint256 => Job) public jobs;
    uint256 public nextJobId = 1;

    ITrustCoreJobs public trustCore;
    IReputation1155Jobs public reputation1155;
    IDustToken public dust;

    uint256 public constant JOB_COMPLETION_ACHIEVEMENT_ID = 2001;
    uint256 public constant JOB_CREATION_FEE = 10 ether; // 10 DUST (18 desimal)

    event Reputation1155Updated(
        address indexed previous,
        address indexed current
    );
    event TrustCoreUpdated(address indexed previous, address indexed current);
    event DustUpdated(address indexed previous, address indexed current);

    constructor(
        address owner_,
        address dustToken_,
        address trustCore_,
        address reputation1155_
    ) Ownable(owner_) {
        require(owner_ != address(0), "JobMarket: zero owner");
        require(dustToken_ != address(0), "JobMarket: zero dust");
        require(trustCore_ != address(0), "JobMarket: zero trustCore");
        require(reputation1155_ != address(0), "JobMarket: zero rep1155");

        dust = IDustToken(dustToken_);
        trustCore = ITrustCoreJobs(trustCore_);
        reputation1155 = IReputation1155Jobs(reputation1155_);
    }

    // ==================== ADMIN CONFIG ====================

    function setTrustCore(address core) external onlyOwner {
        require(core != address(0), "JobMarket: zero core");
        emit TrustCoreUpdated(address(trustCore), core);
        trustCore = ITrustCoreJobs(core);
    }

    function setReputation1155(address rep) external onlyOwner {
        require(rep != address(0), "JobMarket: zero rep");
        emit Reputation1155Updated(address(reputation1155), rep);
        reputation1155 = IReputation1155Jobs(rep);
    }

    function setDust(address dustToken) external onlyOwner {
        require(dustToken != address(0), "JobMarket: zero dust");
        emit DustUpdated(address(dust), dustToken);
        dust = IDustToken(dustToken);
    }

    // ==================== CORE JOB LOGIC ====================

    /// @notice Poster membuat job baru; membayar fee burn 10 DUST.
    function createJob(uint256 minScore) external returns (uint256) {
        require(minScore > 0, "JobMarket: zero minScore");

        // burn fee (kontrak harus diset sebagai minter di DustToken)
        dust.burn(msg.sender, JOB_CREATION_FEE);

        uint256 jobId = nextJobId++;
        jobs[jobId] = Job({
            id: jobId,
            poster: msg.sender,
            minScore: minScore,
            worker: address(0),
            status: JobStatus.OPEN,
            createdAt: uint64(block.timestamp)
        });

        emit JobCreated(jobId, msg.sender, minScore);
        return jobId;
    }

    function applyToJob(uint256 jobId) external {
        Job storage j = jobs[jobId];
        require(j.id != 0, "JobMarket: job not exist");
        require(j.status == JobStatus.OPEN, "JobMarket: not OPEN");

        bool ok = trustCore.hasMinTrustScore(msg.sender, j.minScore);
        require(ok, "JobMarket: trustScore too low");

        emit JobApplied(jobId, msg.sender);
    }

    function assignWorker(uint256 jobId, address worker) external {
        Job storage j = jobs[jobId];
        require(j.id != 0, "JobMarket: job not exist");
        require(j.poster == msg.sender, "JobMarket: not poster");
        require(j.status == JobStatus.OPEN, "JobMarket: not OPEN");
        require(worker != address(0), "JobMarket: zero worker");

        bool ok = trustCore.hasMinTrustScore(worker, j.minScore);
        require(ok, "JobMarket: worker trustScore too low");

        j.worker = worker;
        j.status = JobStatus.ASSIGNED;

        emit JobAssigned(jobId, msg.sender, worker);
    }

    function submitWork(uint256 jobId) external {
        Job storage j = jobs[jobId];
        require(j.id != 0, "JobMarket: job not exist");
        require(j.worker == msg.sender, "JobMarket: not worker");
        require(j.status == JobStatus.ASSIGNED, "JobMarket: not ASSIGNED");

        j.status = JobStatus.SUBMITTED;
        emit JobSubmitted(jobId, msg.sender);
    }

    /// @notice Poster approve kerjaan dan memberi rating; hanya reward reputasi (tanpa gaji escrow).
    function approveJob(uint256 jobId, uint8 rating) external {
        Job storage j = jobs[jobId];
        require(j.id != 0, "JobMarket: job not exist");
        require(j.poster == msg.sender, "JobMarket: not poster");
        require(j.status == JobStatus.SUBMITTED, "JobMarket: not SUBMITTED");
        require(j.worker != address(0), "JobMarket: no worker");
        require(rating >= 1 && rating <= 5, "JobMarket: invalid rating");

        j.status = JobStatus.COMPLETED;

        uint256 scoreDelta = _computeScoreDelta(rating);
        trustCore.rewardJobCompletion(j.worker, scoreDelta);

        if (address(reputation1155) != address(0)) {
            reputation1155.mint(j.worker, JOB_COMPLETION_ACHIEVEMENT_ID, 1);
        }

        emit JobApproved(jobId, j.worker, rating, scoreDelta);
    }

    function rejectJob(uint256 jobId, string calldata reason) external {
        Job storage j = jobs[jobId];
        require(j.id != 0, "JobMarket: job not exist");
        require(j.poster == msg.sender, "JobMarket: not poster");
        require(j.status == JobStatus.SUBMITTED, "JobMarket: not SUBMITTED");
        require(j.worker != address(0), "JobMarket: no worker");

        j.status = JobStatus.ASSIGNED;
        emit JobRejected(jobId, j.worker, reason);
    }

    function cancelJob(uint256 jobId) external {
        Job storage j = jobs[jobId];
        require(j.id != 0, "JobMarket: job not exist");
        require(j.poster == msg.sender, "JobMarket: not poster");
        require(
            j.status == JobStatus.OPEN || j.status == JobStatus.ASSIGNED,
            "JobMarket: cannot cancel"
        );

        j.status = JobStatus.CANCELLED;
        emit JobCancelled(jobId, msg.sender);
    }

    function _computeScoreDelta(uint8 rating) internal pure returns (uint256) {
        if (rating >= 5) return 200;
        if (rating == 4) return 150;
        if (rating == 3) return 100;
        if (rating == 2) return 50;
        return 20;
    }
}
