// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title TrustReputation1155
/// @notice ERC1155 soulbound untuk reputasi, achievement, dan akses chat/role.
contract TrustReputation1155 is ERC1155, Ownable {
    /// @dev modul yang diizinkan untuk mint/burn (TrustCoreImpl, RewardEngine, dll)
    mapping(address => bool) public authorized;

    event AuthorizedModuleUpdated(address indexed module, bool allowed);

    constructor(
        string memory baseURI_,
        address owner_
    ) ERC1155(baseURI_) Ownable(owner_) {
        require(owner_ != address(0), "1155-SBT: zero owner");
    }

    // ========= SBT LOGIC (NON-TRANSFERABLE) =========

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual override {
        // allow mint (from=0) dan burn (to=0); block pure transfer.
        if (from != address(0) && to != address(0)) {
            revert("1155-SBT: non-transferable");
        }
        super._update(from, to, ids, amounts);
    }

    // ========= AUTH MANAGEMENT =========

    modifier onlyAuthorized() {
        require(authorized[msg.sender], "1155-SBT: not authorized");
        _;
    }

    /// @notice Tambah/hapus modul yang diizinkan mint/burn.
    function setAuthorized(address module, bool allowed) external onlyOwner {
        authorized[module] = allowed;
        emit AuthorizedModuleUpdated(module, allowed);
    }

    /// @notice Ubah base URI global (optional, kalau mau ganti IPFS gateway).
    function setURI(string calldata newURI) external onlyOwner {
        _setURI(newURI);
    }

    // ========= MINT / BURN API (dipanggil core / reward engine) =========

    /// @notice Mint 1 jenis token reputasi/achievement.
    /// @param to penerima
    /// @param id token type ID (misal: 1001=LikeStamp, 2001=JobStamp)
    /// @param amount jumlah (bisa >1 kalau stacking)
    function mint(
        address to,
        uint256 id,
        uint256 amount
    ) external onlyAuthorized {
        require(to != address(0), "1155-SBT: zero address");
        _mint(to, id, amount, "");
    }

    /// @notice Mint batch beberapa jenis token sekaligus.
    function mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external onlyAuthorized {
        require(to != address(0), "1155-SBT: zero address");
        _mintBatch(to, ids, amounts, "");
    }

    /// @notice Burn token (misal untuk revoke akses / penalti reputasi).
    function burn(
        address from,
        uint256 id,
        uint256 amount
    ) external onlyAuthorized {
        require(from != address(0), "1155-SBT: zero address");
        _burn(from, id, amount);
    }

    function burnBatch(
        address from,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external onlyAuthorized {
        require(from != address(0), "1155-SBT: zero address");
        _burnBatch(from, ids, amounts);
    }
}
