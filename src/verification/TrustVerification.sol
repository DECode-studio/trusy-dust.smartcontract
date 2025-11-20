// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Interface generic ke verifier ZK (Noir / Plonk / Barretenberg)
interface INoirVerifier {
    function verify(
        bytes calldata proof,
        bytes32[] calldata publicInputs
    ) external view returns (bool);
}

/// @notice Interface tipis ke TrustCoreImpl
interface ITrustCore {
    /// @dev Hanya bisa dipanggil oleh rewardOperator di TrustCoreImpl
    function setUserBadgeTier(
        address user,
        uint256 tier,
        string calldata metadataURI
    ) external;
}

/// @title TrustVerification
/// @notice Modul verifikasi ZK untuk TrustyDust:
///         - Gating trustScore ≥ minScore (job, fitur premium, dll)
///         - Verifikasi tier + update SBT badge via TrustCore
contract TrustVerification is Ownable {
    /// @dev Verifier untuk circuit "trust_score_geq" (score ≥ threshold)
    INoirVerifier public trustScoreVerifier;

    /// @dev Verifier untuk circuit "tier_membership" (score di range tier tertentu)
    INoirVerifier public tierVerifier;

    /// @dev Alamat TrustCoreImpl (proxy) untuk update badge tier
    ITrustCore public trustCore;

    /// @dev Event ketika proof trustScore ≥ minScore berhasil diverifikasi
    event TrustScoreVerified(address indexed user, uint256 minScore);

    /// @dev Event ketika proof tier berhasil diverifikasi & badge di-update
    event TierVerified(address indexed user, uint256 tier, string metadataURI);

    /// @param owner_ owner awal (bisa multisig / deployer)
    /// @param trustCore_ alamat TrustCoreImpl (proxy, bukan implementation)
    constructor(address owner_, address trustCore_) Ownable(owner_) {
        require(owner_ != address(0), "TrustVerify: zero owner");
        if (trustCore_ != address(0)) {
            trustCore = ITrustCore(trustCore_);
        }
    }

    // ========= ADMIN CONFIG =========

    /// @notice Set alamat verifier untuk circuit "trust_score_geq"
    function setTrustScoreVerifier(address verifier) external onlyOwner {
        require(verifier != address(0), "TrustVerify: zero verifier");
        trustScoreVerifier = INoirVerifier(verifier);
    }

    /// @notice Set alamat verifier untuk circuit "tier_membership"
    function setTierVerifier(address verifier) external onlyOwner {
        require(verifier != address(0), "TrustVerify: zero verifier");
        tierVerifier = INoirVerifier(verifier);
    }

    /// @notice Update alamat TrustCoreImpl (proxy)
    function setTrustCore(address core) external onlyOwner {
        require(core != address(0), "TrustVerify: zero core");
        trustCore = ITrustCore(core);
    }

    // ========= HELPER INTERNAL =========

    /// @dev Konversi address → field-compatible (uint256) untuk dipakai sebagai public input Noir
    function _addrToField(address a) internal pure returns (uint256) {
        return uint256(uint160(a));
    }

    // ========= PUBLIC API: TRUST SCORE GATING =========

    /// @notice Verifikasi ZK proof bahwa trustScore(user) ≥ minScore.
    ///
    /// Circuit Noir (kurang lebih):
    ///   fn main(
    ///       user_addr: pub Field,
    ///       min_score: pub u32,
    ///       wallet_age_score: u32,
    ///       social_score: u32,
    ///       job_score: u32,
    ///   ) -> pub Field { ... qualified = 1 }
    ///
    /// Public inputs yang dikirim ke verifier:
    ///   [ user_addr_field, min_score_field, qualified_field ]
    ///
    /// Di sini:
    ///   - user_addr_field = uint256(uint160(msg.sender))
    ///   - min_score_field = minScore
    ///   - qualified_field = 1
    ///
    /// @param proof bukti ZK (bytes) yang di-generate off-chain (Noir)
    /// @param minScore threshold yang ingin dibuktikan
    /// @return true kalau proof valid (kalau invalid → revert)
    function verifyTrustScoreGeq(
        bytes calldata proof,
        uint256 minScore
    ) external returns (bool) {
        require(
            address(trustScoreVerifier) != address(0),
            "TrustVerify: score verifier not set"
        );

        // Build public inputs
        uint256 addrField = _addrToField(msg.sender);
        uint256 qualifiedField = 1;

        bytes32[] memory pubInputs = new bytes32[](3);
        pubInputs[0] = bytes32(addrField);
        pubInputs[1] = bytes32(minScore);
        pubInputs[2] = bytes32(qualifiedField);

        bool ok = trustScoreVerifier.verify(proof, pubInputs);
        require(ok, "TrustVerify: invalid trustScore proof");

        emit TrustScoreVerified(msg.sender, minScore);
        return true;
    }

    // ========= PUBLIC API: TIER PROOF + UPDATE BADGE =========

    /// @notice Verifikasi ZK proof bahwa user berada pada tier tertentu,
    ///         lalu update SBT badge melalui TrustCoreImpl.
    ///
    /// Circuit Noir (kurang lebih):
    ///   fn main(
    ///       user_addr: pub Field,
    ///       tier_id: pub u32,
    ///       wallet_age_score: u32,
    ///       social_score: u32,
    ///       job_score: u32
    ///   ) -> pub Field { ... qualified = 1 }
    ///
    /// Public inputs:
    ///   [ user_addr_field, tier_id_field, qualified_field ]
    ///
    /// @param proof bukti ZK untuk membership tier tertentu
    /// @param tier ID tier (0=Dust, 1=Spark, 2=Flare, 3=Nova)
    /// @param metadataURI metadata baru untuk badge (IPFS/URL, biasanya disiapkan oleh backend)
    /// @return true jika proof valid dan badge berhasil di-update
    function verifyTierAndUpdateBadge(
        bytes calldata proof,
        uint256 tier,
        string calldata metadataURI
    ) external returns (bool) {
        require(
            address(tierVerifier) != address(0),
            "TrustVerify: tier verifier not set"
        );
        require(
            address(trustCore) != address(0),
            "TrustVerify: trustCore not set"
        );
        require(
            bytes(metadataURI).length > 0,
            "TrustVerify: empty metadata URI"
        );

        uint256 addrField = _addrToField(msg.sender);
        uint256 qualifiedField = 1;

        bytes32[] memory pubInputs = new bytes32[](3);
        pubInputs[0] = bytes32(addrField);
        pubInputs[1] = bytes32(tier);
        pubInputs[2] = bytes32(qualifiedField);

        bool ok = tierVerifier.verify(proof, pubInputs);
        require(ok, "TrustVerify: invalid tier proof");

        // call core untuk update badge (hanya sukses jika TrustVerification sudah jadi rewardOperator di TrustCoreImpl)
        trustCore.setUserBadgeTier(msg.sender, tier, metadataURI);

        emit TierVerified(msg.sender, tier, metadataURI);
        return true;
    }
}
