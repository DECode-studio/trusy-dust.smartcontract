// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title JobEvents
/// @notice Shared events & enum untuk modul JobMarketplace.
abstract contract JobEvents {
    /// @notice Status job di on-chain.
    enum JobStatus {
        OPEN,
        ASSIGNED,
        SUBMITTED,
        COMPLETED,
        CANCELLED
    }

    event JobCreated(
        uint256 indexed jobId,
        address indexed poster,
        address token,
        uint256 rewardAmount,
        uint256 minScore
    );

    event JobApplied(uint256 indexed jobId, address indexed worker);

    event JobAssigned(
        uint256 indexed jobId,
        address indexed poster,
        address indexed worker
    );

    event JobSubmitted(uint256 indexed jobId, address indexed worker);

    event JobApproved(
        uint256 indexed jobId,
        address indexed worker,
        uint8 rating,
        uint256 scoreDelta
    );

    event JobRejected(
        uint256 indexed jobId,
        address indexed worker,
        string reason
    );

    event JobCancelled(uint256 indexed jobId, address indexed poster);
}
