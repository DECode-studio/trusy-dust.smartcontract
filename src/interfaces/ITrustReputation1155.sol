// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ITrustReputation1155
/// @notice Interface untuk ERC1155 Soulbound reputasi, achievement, dan akses.
interface ITrustReputation1155 {
    /// @notice Mint 1 jenis token reputasi/achievement.
    /// @param to penerima
    /// @param id token type ID (achievement / access / role)
    /// @param amount jumlah (bisa >1)
    function mint(address to, uint256 id, uint256 amount) external;

    /// @notice Mint beberapa jenis token sekaligus.
    function mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external;

    /// @notice Burn token (misal revoke akses / penalti reputasi).
    function burn(address from, uint256 id, uint256 amount) external;

    function burnBatch(
        address from,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external;

    /// @notice Set modul yang diizinkan mint/burn (TrustCore, RewardEngine, JobMarketplace, dll).
    function setAuthorized(address module, bool allowed) external;

    /// @notice Standard balanceOf ERC1155.
    function balanceOf(
        address account,
        uint256 id
    ) external view returns (uint256);
}
