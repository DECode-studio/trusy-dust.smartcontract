// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ITrustCore
/// @notice Interface ke TrustCoreImpl (proxy) untuk fitur trustScore & badge.
interface ITrustCore {
    /// @notice Cek apakah user punya minimal trustScore tertentu.
    /// @param user alamat user
    /// @param minScore nilai minimal (dalam "score unit", bukan wei; core yang convert ke wei)
    function hasMinTrustScore(
        address user,
        uint256 minScore
    ) external view returns (bool);

    /// @notice Ambil trustScore user (biasanya = balance DUST).
    function getTrustScore(address user) external view returns (uint256);

    /// @notice Ambil tier user berdasarkan DUST balance.
    /// @return tier 0 = Dust, 1 = Spark, 2 = Flare, 3 = Nova
    function getTier(address user) external view returns (uint8);

    /// @notice Reward untuk job completion (dipanggil JobMarketplace / RewardEngine).
    /// @param user worker yang menyelesaikan job
    /// @param scoreDelta penambahan score (misal 50–200)
    function rewardJobCompletion(address user, uint256 scoreDelta) external;

    /// @notice Sinkronisasi / update Soulbound Badge user berdasarkan hasil ZK proof.
    /// @dev Hanya modul trusted (TrustVerification / RewardEngine) yang boleh memanggil.
    function setUserBadgeTier(
        address user,
        uint256 tier,
        string calldata metadataURI
    ) external;
}
