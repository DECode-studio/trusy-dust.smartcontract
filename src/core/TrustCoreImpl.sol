// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @notice Minimal interface ERC20 DUST token
interface IDustToken {
    function mint(address to, uint256 amount) external;

    function balanceOf(address account) external view returns (uint256);
}

/// @notice Minimal interface TrustBadge SBT (ERC721)
interface ITrustBadgeSBT {
    function mintBadge(
        address user,
        uint256 tier,
        string calldata uri
    ) external;

    function updateBadgeMetadata(
        address user,
        uint256 tier,
        string calldata uri
    ) external;

    function tokenOf(address user) external view returns (uint256);
}

/// @notice Minimal interface Reputation ERC1155
interface ITrustReputation1155 {
    function mint(address to, uint256 id, uint256 amount) external;
}

/// @title TrustCoreImpl
/// @notice Implementasi utama core logic TrustyDust (tanpa storage layout bentrok, upgradeable).
contract TrustCoreImpl is Initializable, OwnableUpgradeable {
    /// @dev token kepercayaan (DUST)
    IDustToken public dust;

    /// @dev soulbound badge (tier Dust/Spark/Flare/Nova)
    ITrustBadgeSBT public badge;

    /// @dev reputation & achievement 1155
    ITrustReputation1155 public reputation1155;

    /// @dev operator yang boleh memanggil fungsi reward (backend/service)
    address public rewardOperator;

    /// @dev reward per aksi sosial (dalam "score", nanti dikali 1e18 saat mint DUST)
    uint256 public likeReward; // default 1
    uint256 public commentReward; // default 3
    uint256 public repostReward; // default 1
    uint256 public jobCompleteRewardBase; // default 50 (bisa dikali rating di layer lain)

    /// @dev ID token 1155 untuk basic achievement (contoh, bisa kamu extend)
    uint256 public constant LIKE_ACHIEVEMENT_ID = 1001;
    uint256 public constant COMMENT_ACHIEVEMENT_ID = 1002;
    uint256 public constant JOB_COMPLETION_ACHIEVEMENT_ID = 2001;

    /// @dev tier thresholds (berdasarkan DUST balance, misal 18 desimal)
    uint256 public dustTierSpark; // contoh: 300 * 1e18
    uint256 public dustTierFlare; // contoh: 600 * 1e18
    uint256 public dustTierNova; // contoh: 800 * 1e18

    /// EVENTS
    event RewardOperatorUpdated(
        address indexed previousOperator,
        address indexed newOperator
    );
    event RewardsUpdated(
        uint256 likeReward,
        uint256 commentReward,
        uint256 repostReward,
        uint256 jobBaseReward
    );
    event SocialReward(
        address indexed user,
        bytes32 action,
        uint256 scoreDelta,
        uint256 dustAmount
    );
    event JobReward(
        address indexed user,
        uint256 scoreDelta,
        uint256 dustAmount
    );
    event TierThresholdsUpdated(uint256 spark, uint256 flare, uint256 nova);

    modifier onlyRewardOperator() {
        require(msg.sender == rewardOperator, "TrustCore: not reward operator");
        _;
    }

    /// @notice initializer dipanggil via proxy (bukan constructor)
    /// @param owner_ owner awal (biasanya deployer atau multi-sig)
    /// @param dust_ alamat ERC20 DUST
    /// @param badge_ alamat ERC721 SBT
    /// @param rep1155_ alamat ERC1155 reputasi
    /// @param rewardOperator_ alamat operator reward (backend / service)
    function initialize(
        address owner_,
        address dust_,
        address badge_,
        address rep1155_,
        address rewardOperator_
    ) external initializer {
        __Ownable_init(owner_);

        require(dust_ != address(0), "TrustCore: dust is zero");
        require(badge_ != address(0), "TrustCore: badge is zero");
        require(rep1155_ != address(0), "TrustCore: rep1155 is zero");
        require(
            rewardOperator_ != address(0),
            "TrustCore: rewardOperator is zero"
        );

        dust = IDustToken(dust_);
        badge = ITrustBadgeSBT(badge_);
        reputation1155 = ITrustReputation1155(rep1155_);
        rewardOperator = rewardOperator_;

        // default reward config (bisa diubah owner)
        likeReward = 1;
        commentReward = 3;
        repostReward = 1;
        jobCompleteRewardBase = 50;

        // default tier thresholds (dalam DUST token unit, 18 desimal)
        dustTierSpark = 300 ether;
        dustTierFlare = 600 ether;
        dustTierNova = 800 ether;
    }

    // ============ ADMIN CONFIG ============

    function setRewardOperator(address newOperator) external onlyOwner {
        require(newOperator != address(0), "TrustCore: zero operator");
        emit RewardOperatorUpdated(rewardOperator, newOperator);
        rewardOperator = newOperator;
    }

    function setRewardConfig(
        uint256 like_,
        uint256 comment_,
        uint256 repost_,
        uint256 jobBase_
    ) external onlyOwner {
        likeReward = like_;
        commentReward = comment_;
        repostReward = repost_;
        jobCompleteRewardBase = jobBase_;
        emit RewardsUpdated(like_, comment_, repost_, jobBase_);
    }

    function setDustTierThresholds(
        uint256 spark,
        uint256 flare,
        uint256 nova
    ) external onlyOwner {
        require(
            spark < flare && flare < nova,
            "TrustCore: invalid tier ordering"
        );
        dustTierSpark = spark;
        dustTierFlare = flare;
        dustTierNova = nova;
        emit TierThresholdsUpdated(spark, flare, nova);
    }

    // ============ REWARD FUNCTIONS ============

    /// @notice reward untuk LIKE (dipanggil backend/rewardOperator)
    function rewardLike(address user) external onlyRewardOperator {
        _rewardSocial(user, likeReward, "LIKE", LIKE_ACHIEVEMENT_ID);
    }

    /// @notice reward untuk COMMENT
    function rewardComment(address user) external onlyRewardOperator {
        _rewardSocial(user, commentReward, "COMMENT", COMMENT_ACHIEVEMENT_ID);
    }

    /// @notice reward untuk REPOST
    function rewardRepost(address user) external onlyRewardOperator {
        _rewardSocial(user, repostReward, "REPOST", 0); // tidak mint 1155 kalau tidak perlu
    }

    /// @notice reward untuk job completion (scoreDelta bisa disesuaikan rating)
    function rewardJobCompletion(
        address user,
        uint256 scoreDelta
    ) external onlyRewardOperator {
        require(scoreDelta > 0, "TrustCore: scoreDelta = 0");

        uint256 dustAmount = scoreDelta * 1e18;
        dust.mint(user, dustAmount);

        // optional: mint reputasi 1155
        reputation1155.mint(user, JOB_COMPLETION_ACHIEVEMENT_ID, 1);

        emit JobReward(user, scoreDelta, dustAmount);
    }

    /// @dev fungsi internal yang dipakai LIKE/COMMENT/REPOST
    function _rewardSocial(
        address user,
        uint256 scoreDelta,
        bytes32 action,
        uint256 achievementId
    ) internal {
        if (scoreDelta == 0) return;

        uint256 dustAmount = scoreDelta * 1e18;
        dust.mint(user, dustAmount);

        if (achievementId != 0) {
            // mint satu kali per event, bisa kamu modifikasi jadi conditional
            reputation1155.mint(user, achievementId, 1);
        }

        emit SocialReward(user, action, scoreDelta, dustAmount);
    }

    // ============ VIEW HELPERS ============

    /// @notice trust score = DUST balance
    function getTrustScore(address user) public view returns (uint256) {
        return dust.balanceOf(user);
    }

    /// @notice tier berdasarkan panjang DUST (Dust / Spark / Flare / Nova)
    /// @return tier: 0 = Dust, 1 = Spark, 2 = Flare, 3 = Nova
    function getTier(address user) public view returns (uint8) {
        uint256 bal = dust.balanceOf(user);

        if (bal >= dustTierNova) {
            return 3;
        } else if (bal >= dustTierFlare) {
            return 2;
        } else if (bal >= dustTierSpark) {
            return 1;
        } else {
            return 0;
        }
    }

    /// @notice helper untuk external module (JobMarketplace, frontend, dll)
    function hasMinTrustScore(
        address user,
        uint256 minScore
    ) external view returns (bool) {
        return dust.balanceOf(user) >= minScore * 1e18;
    }

    /// @notice optional: sinkronisasi badge tier (dipanggil off-chain/ZK verifier)
    function setUserBadgeTier(
        address user,
        uint256 tier,
        string calldata metadataURI
    ) external onlyRewardOperator {
        // diasumsikan ZK verification & tier check sudah dilakukan off-chain / modul lain
        if (badge.tokenOf(user) == 0) {
            badge.mintBadge(user, tier, metadataURI);
        } else {
            badge.updateBadgeMetadata(user, tier, metadataURI);
        }
    }
}
