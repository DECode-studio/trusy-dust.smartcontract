// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title TrustBadgeSBT
/// @notice Soulbound badge untuk tier TrustyDust (Dust/Spark/Flare/Nova).
///         Satu user hanya boleh punya satu badge. Metadata bisa di-update.
contract TrustBadgeSBT is ERC721, Ownable {
    struct BadgeData {
        uint256 tier; // 0=Dust, 1=Spark, 2=Flare, 3=Nova
        string metadataURI; // IPFS/URL metadata JSON
        uint256 lastUpdated; // timestamp update terakhir
    }

    /// @dev mapping user => tokenId
    mapping(address => uint256) public tokenOf;

    /// @dev data badge per token
    mapping(uint256 => BadgeData) private _badgeData;

    /// @dev auto-increment token ID
    uint256 private _nextId = 1;

    event BadgeMinted(
        address indexed user,
        uint256 indexed tokenId,
        uint256 tier,
        string uri
    );
    event BadgeUpdated(
        address indexed user,
        uint256 indexed tokenId,
        uint256 newTier,
        string newUri
    );

    constructor(
        string memory name_,
        string memory symbol_,
        address owner_
    ) ERC721(name_, symbol_) Ownable(owner_) {
        require(owner_ != address(0), "SBT: zero owner");
    }

    // ========= SBT LOGIC (NON-TRANSFERABLE) =========

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        // allow mint (from=0) dan burn (to=0). selain itu reject.
        if (from != address(0) && to != address(0)) {
            revert("SBT: non-transferable");
        }
        return super._update(to, tokenId, auth);
    }

    function approve(address, uint256) public pure override {
        revert("SBT: approvals disabled");
    }

    function setApprovalForAll(address, bool) public pure override {
        revert("SBT: approvals disabled");
    }

    // ========= CORE FUNCTIONS =========

    /// @notice Mint badge pertama kali untuk user.
    /// @dev hanya owner (biasanya TrustCoreImpl) yang boleh.
    function mintBadge(
        address user,
        uint256 tier,
        string calldata uri
    ) external onlyOwner {
        require(user != address(0), "SBT: zero user");
        require(tokenOf[user] == 0, "SBT: badge exists");

        uint256 tokenId = _nextId++;
        tokenOf[user] = tokenId;

        _safeMint(user, tokenId);

        _badgeData[tokenId] = BadgeData({
            tier: tier,
            metadataURI: uri,
            lastUpdated: block.timestamp
        });

        emit BadgeMinted(user, tokenId, tier, uri);
    }

    /// @notice Update tier & metadata badge user (misal setelah ZK proof score ≥ tier baru).
    /// @dev hanya owner (TrustCoreImpl / RewardEngine via core) yang boleh.
    function updateBadgeMetadata(
        address user,
        uint256 newTier,
        string calldata newURI
    ) external onlyOwner {
        uint256 tokenId = tokenOf[user];
        require(tokenId != 0, "SBT: no badge");

        BadgeData storage bd = _badgeData[tokenId];
        bd.tier = newTier;
        bd.metadataURI = newURI;
        bd.lastUpdated = block.timestamp;

        emit BadgeUpdated(user, tokenId, newTier, newURI);
    }

    /// @notice Lihat detail badge (tier, metadata, lastUpdated).
    function getBadgeData(
        address user
    ) external view returns (BadgeData memory) {
        uint256 tokenId = tokenOf[user];
        require(tokenId != 0, "SBT: no badge");
        return _badgeData[tokenId];
    }

    /// @notice Override tokenURI untuk pakai metadataURI custom.
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "SBT: invalid token");
        return _badgeData[tokenId].metadataURI;
    }
}
