// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IDustToken} from "../interfaces/IDustToken.sol";

interface IReputation1155Post {
    function mint(address to, uint256 id, uint256 amount) external;
}

/// @title PostContentNFT
/// @notice ERC721 untuk konten/post; mint membakar 10 DUST dan optional mint ERC1155 badge/stamp.
contract PostContentNFT is ERC721, Ownable {
    IDustToken public dust;
    IReputation1155Post public reputation1155;
    uint256 public postBadgeId; // 0 = nonaktif

    uint256 public constant POST_FEE = 10 ether; // 10 DUST (18 desimal)
    uint256 private _nextId = 1;
    mapping(uint256 => string) private _tokenURIs;

    event PostMinted(
        address indexed user,
        uint256 indexed tokenId,
        string uri
    );
    event ReputationUpdated(address indexed previous, address indexed current);
    event PostBadgeUpdated(uint256 previous, uint256 current);

    constructor(
        string memory name_,
        string memory symbol_,
        address owner_,
        address dust_,
        address reputation1155_,
        uint256 postBadgeId_
    ) ERC721(name_, symbol_) Ownable(owner_) {
        require(dust_ != address(0), "PostNFT: zero dust");
        require(owner_ != address(0), "PostNFT: zero owner");
        dust = IDustToken(dust_);
        reputation1155 = IReputation1155Post(reputation1155_);
        postBadgeId = postBadgeId_;
    }

    function setReputation1155(address rep) external onlyOwner {
        require(rep != address(0), "PostNFT: zero rep");
        emit ReputationUpdated(address(reputation1155), rep);
        reputation1155 = IReputation1155Post(rep);
    }

    function setPostBadgeId(uint256 id) external onlyOwner {
        emit PostBadgeUpdated(postBadgeId, id);
        postBadgeId = id;
    }

    /// @notice Mint NFT post, membakar 10 DUST dari caller dan optional mint achievement 1155.
    function mintPost(string calldata uri) external returns (uint256 tokenId) {
        require(bytes(uri).length > 0, "PostNFT: empty uri");
        // burn fee; kontrak harus di-set sebagai minter di DustToken
        dust.burn(msg.sender, POST_FEE);

        tokenId = _nextId++;
        _safeMint(msg.sender, tokenId);
        _tokenURIs[tokenId] = uri;

        if (postBadgeId != 0 && address(reputation1155) != address(0)) {
            reputation1155.mint(msg.sender, postBadgeId, 1);
        }

        emit PostMinted(msg.sender, tokenId, uri);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "PostNFT: invalid token");
        return _tokenURIs[tokenId];
    }
}
