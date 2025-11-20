// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Global Errors for TrustyDust
/// @notice Digunakan di seluruh modul (core, jobs, reward, identity, dll).
library Errors {
    // ===== Generic =====
    error ZeroAddress();
    error NotAuthorized();
    error InvalidAmount();
    error InvalidInput();
    error AlreadyExists();
    error NotFound();

    // ===== Permission =====
    error NotOwner();
    error NotProxyAdmin();
    error NotMinter();
    error NotVerifier();

    // ===== Trust / Scoring =====
    error InsufficientTrustScore();
    error InvalidTier();
    error InvalidScore();

    // ===== SBT / 1155 =====
    error Soulbound();
    error TokenLocked();
    error TokenNotOwned();

    // ===== Job Matching =====
    error JobNotOpen();
    error JobNotAssigned();
    error JobNotSubmitted();
    error JobAlreadyCompleted();
    error JobAlreadyCancelled();
    error WorkerNotSelected();
    error JobQuotaExceeded();

    // ===== Escrow =====
    error EscrowNotFunded();
    error EscrowAlreadyReleased();
    error EscrowAlreadyRefunded();
}
