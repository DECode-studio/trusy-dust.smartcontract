// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {JobEvents} from "./JobEvents.sol";
import {EscrowVault} from "./EscrowVault.sol";

/// @notice Interface ke TrustCoreImpl khusus fitur jobs
interface ITrustCoreJobs {
    /// @dev minScore dalam "score unit" (misal 600), core yang convert ke wei (600 * 1e18)
    function hasMinTrustScore(
        address user,
        uint256 minScore
    ) external view returns (bool);

    /// @dev dipanggil ketika job selesai, scoreDelta: 50–200 dsb
    function rewardJobCompletion(address user, uint256 scoreDelta) external;
}

/// @notice Interface minimal ke ERC1155 reputasi (dipakai untuk achievement job)
interface IReputation1155Jobs {
    function mint(address to, uint256 id, uint256 amount) external;
}

/// @title JobMarketplace
/// @notice Marketplace job berbasis reputasi (trust-score gated) untuk TrustyDust.
///         Detail job (title, desc, dsb) disimpan off-chain; on-chain hanya id, poster, worker, reward, status.
contract JobMarketplace is Ownable, JobEvents {
    /// @dev data utama job yang disimpan on-chain
    struct Job {
        uint256 id;
        address poster;
        address token; // ERC20 yang dipakai untuk reward
        uint256 rewardAmount;
        uint256 minScore; // minimum trustScore (dalam "score unit", bukan wei)
        address worker; // worker yang dipilih poster
        JobStatus status;
        uint64 createdAt;
    }

    /// @dev jobId => Job
    mapping(uint256 => Job) public jobs;

    /// @dev auto increment ID job
    uint256 public nextJobId = 1;

    /// @dev reference ke EscrowVault
    EscrowVault public escrow;

    /// @dev reference ke TrustCoreImpl (via interface jobs)
    ITrustCoreJobs public trustCore;

    /// @dev reference ke ERC1155 reputasi (untuk achievement job)
    IReputation1155Jobs public reputation1155;

    /// @dev ID achievement ERC1155 untuk job completion
    uint256 public constant JOB_COMPLETION_ACHIEVEMENT_ID = 2001;

    event Reputation1155Updated(
        address indexed previous,
        address indexed current
    );
    event TrustCoreUpdated(address indexed previous, address indexed current);
    event EscrowVaultUpdated(address indexed previous, address indexed current);

    // ============================================================
    //                         CONSTRUCTOR
    // ============================================================

    constructor(
        address owner_,
        address trustCore_,
        address escrowVault_,
        address reputation1155_
    ) Ownable(owner_) {
        require(owner_ != address(0), "JobMarket: zero owner");

        require(trustCore_ != address(0), "JobMarket: zero trustCore");
        require(escrowVault_ != address(0), "JobMarket: zero escrow");
        require(reputation1155_ != address(0), "JobMarket: zero rep1155");

        trustCore = ITrustCoreJobs(trustCore_);
        escrow = EscrowVault(escrowVault_);
        reputation1155 = IReputation1155Jobs(reputation1155_);
    }

    // ============================================================
    //                         ADMIN CONFIG
    // ============================================================

    function setTrustCore(address core) external onlyOwner {
        require(core != address(0), "JobMarket: zero core");
        emit TrustCoreUpdated(address(trustCore), core);
        trustCore = ITrustCoreJobs(core);
    }

    function setEscrowVault(address vault) external onlyOwner {
        require(vault != address(0), "JobMarket: zero vault");
        emit EscrowVaultUpdated(address(escrow), vault);
        escrow = EscrowVault(vault);
    }

    function setReputation1155(address rep) external onlyOwner {
        require(rep != address(0), "JobMarket: zero rep");
        emit Reputation1155Updated(address(reputation1155), rep);
        reputation1155 = IReputation1155Jobs(rep);
    }

    // ============================================================
    //                         CORE JOB LOGIC
    // ============================================================

    /// @notice Poster membuat job baru.
    /// @param token ERC20 token yang dipakai untuk reward.
    /// @param rewardAmount jumlah token yang di-lock di escrow.
    /// @param minScore minimum trustScore (bukan wei) yang dibutuhkan worker.
    ///
    /// @dev Poster harus terlebih dahulu approve EscrowVault untuk `rewardAmount`.
    ///      Detail (title, desc, kategori, dll) disimpan off-chain dan di-link via jobId.
    function createJob(
        address token,
        uint256 rewardAmount,
        uint256 minScore
    ) external returns (uint256) {
        require(token != address(0), "JobMarket: zero token");
        require(rewardAmount > 0, "JobMarket: zero reward");
        require(minScore > 0, "JobMarket: zero minScore");

        uint256 jobId = nextJobId++;

        jobs[jobId] = Job({
            id: jobId,
            poster: msg.sender,
            token: token,
            rewardAmount: rewardAmount,
            minScore: minScore,
            worker: address(0),
            status: JobStatus.OPEN,
            createdAt: uint64(block.timestamp)
        });

        // lock dana ke escrow
        escrow.fundJob(jobId, token, msg.sender, rewardAmount);

        emit JobCreated(jobId, msg.sender, token, rewardAmount, minScore);
        return jobId;
    }

    /// @notice Worker apply ke job.
    /// @dev Hanya cek trustScore on-chain; ZK gating tambahan tetap via modul TrustVerification (off-chain/frontend).
    function applyToJob(uint256 jobId) external {
        Job storage j = jobs[jobId];
        require(j.id != 0, "JobMarket: job not exist");
        require(j.status == JobStatus.OPEN, "JobMarket: not OPEN");

        // trustScore check (minScore dalam "score unit"; core convert ke wei)
        bool ok = trustCore.hasMinTrustScore(msg.sender, j.minScore);
        require(ok, "JobMarket: trustScore too low");

        // kita tidak simpan list applicant on-chain untuk hemat gas, cukup event
        emit JobApplied(jobId, msg.sender);
    }

    /// @notice Poster pilih worker dari applicant (list applicant dikelola off-chain via event + DB).
    function assignWorker(uint256 jobId, address worker) external {
        Job storage j = jobs[jobId];
        require(j.id != 0, "JobMarket: job not exist");
        require(j.poster == msg.sender, "JobMarket: not poster");
        require(j.status == JobStatus.OPEN, "JobMarket: not OPEN");
        require(worker != address(0), "JobMarket: zero worker");

        // optional: re-check trustScore (kalau takut front manipulasi)
        bool ok = trustCore.hasMinTrustScore(worker, j.minScore);
        require(ok, "JobMarket: worker trustScore too low");

        j.worker = worker;
        j.status = JobStatus.ASSIGNED;

        emit JobAssigned(jobId, msg.sender, worker);
    }

    /// @notice Worker submit bahwa kerjaan sudah selesai.
    function submitWork(uint256 jobId) external {
        Job storage j = jobs[jobId];
        require(j.id != 0, "JobMarket: job not exist");
        require(j.worker == msg.sender, "JobMarket: not worker");
        require(j.status == JobStatus.ASSIGNED, "JobMarket: not ASSIGNED");

        j.status = JobStatus.SUBMITTED;
        emit JobSubmitted(jobId, msg.sender);
    }

    /// @notice Poster approve kerjaan, kasih rating 1-5.
    ///         - escrow release to worker
    ///         - trustCore reward job completion (DUST)
    ///         - mint achievement ERC1155
    function approveJob(uint256 jobId, uint8 rating) external {
        Job storage j = jobs[jobId];
        require(j.id != 0, "JobMarket: job not exist");
        require(j.poster == msg.sender, "JobMarket: not poster");
        require(j.status == JobStatus.SUBMITTED, "JobMarket: not SUBMITTED");
        require(j.worker != address(0), "JobMarket: no worker");
        require(rating >= 1 && rating <= 5, "JobMarket: invalid rating");

        j.status = JobStatus.COMPLETED;

        // tentukan delta score berdasarkan rating
        uint256 scoreDelta = _computeScoreDelta(rating);

        // release escrow ke worker
        escrow.releaseToWorker(jobId, j.worker);

        // reward trust score via core (mint DUST + reputasi lainnya)
        trustCore.rewardJobCompletion(j.worker, scoreDelta);

        // mint achievement 1155
        if (address(reputation1155) != address(0)) {
            reputation1155.mint(j.worker, JOB_COMPLETION_ACHIEVEMENT_ID, 1);
        }

        emit JobApproved(jobId, j.worker, rating, scoreDelta);
    }

    /// @notice Poster reject kerjaan (tidak release escrow).
    ///         Escrow behavior bisa di-handle off-chain (misal: revisi, nego ulang) atau kemudian cancel.
    function rejectJob(uint256 jobId, string calldata reason) external {
        Job storage j = jobs[jobId];
        require(j.id != 0, "JobMarket: job not exist");
        require(j.poster == msg.sender, "JobMarket: not poster");
        require(j.status == JobStatus.SUBMITTED, "JobMarket: not SUBMITTED");
        require(j.worker != address(0), "JobMarket: no worker");

        // balik ke ASSIGNED biar worker bisa submit ulang (revisi)
        j.status = JobStatus.ASSIGNED;
        emit JobRejected(jobId, j.worker, reason);
    }

    /// @notice Poster cancel job sebelum job SUBMITTED/COMPLETED.
    ///         - OPEN → boleh cancel
    ///         - ASSIGNED → boleh cancel (mungkin worker tidak respons)
    ///         - SUBMITTED/COMPLETED → tidak boleh cancel
    function cancelJob(uint256 jobId) external {
        Job storage j = jobs[jobId];
        require(j.id != 0, "JobMarket: job not exist");
        require(j.poster == msg.sender, "JobMarket: not poster");
        require(
            j.status == JobStatus.OPEN || j.status == JobStatus.ASSIGNED,
            "JobMarket: cannot cancel"
        );

        j.status = JobStatus.CANCELLED;

        // refund escrow kalau belum released/refunded
        escrow.refundPoster(jobId);

        emit JobCancelled(jobId, msg.sender);
    }

    // ============================================================
    //                      INTERNAL SCORE LOGIC
    // ============================================================

    /// @dev Mengkonversi rating 1-5 menjadi delta trustScore (sesuai konsep 50–200).
    /// 5 ⭐ → 200
    /// 4 ⭐ → 150
    /// 3 ⭐ → 100
    /// 2 ⭐ → 50
    /// 1 ⭐ → 20
    function _computeScoreDelta(uint8 rating) internal pure returns (uint256) {
        if (rating >= 5) {
            return 200;
        } else if (rating == 4) {
            return 150;
        } else if (rating == 3) {
            return 100;
        } else if (rating == 2) {
            return 50;
        } else {
            return 20;
        }
    }
}
