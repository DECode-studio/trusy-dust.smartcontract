// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title ITrustBadgeSBT
/// @notice Interface untuk ERC721 Soulbound Badge (Dust / Spark / Flare / Nova).
interface ITrustBadgeSBT {
    /// @notice Mint badge pertama kali untuk user.
    /// @param user pemilik badge
    /// @param tier tier badge (0=Dust,1=Spark,2=Flare,3=Nova)
    /// @param uri metadata URI (IPFS / URL)
    function mintBadge(
        address user,
        uint256 tier,
        string calldata uri
    ) external;

    /// @notice Update tier & metadata badge user.
    /// @param user pemilik badge
    /// @param newTier tier baru
    /// @param newURI metadata baru (biasanya sesuai tier)
    function updateBadgeMetadata(
        address user,
        uint256 newTier,
        string calldata newURI
    ) external;

    /// @notice mapping user → tokenId (0 jika belum punya)
    function tokenOf(address user) external view returns (uint256);

    /// @notice Standard ERC721 balanceOf (optional, tapi sering dipakai).
    function balanceOf(address owner) external view returns (uint256);

    /// @notice Standard ERC721 ownerOf (optional).
    function ownerOf(uint256 tokenId) external view returns (address);
}
