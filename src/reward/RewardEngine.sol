// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Interface minimal ke DustToken (ERC20)
interface IDustTokenReward {
    function mint(address to, uint256 amount) external;
}

/// @notice Interface minimal ke TrustReputation1155 (ERC1155 SBT)
interface IReputation1155Reward {
    function mint(address to, uint256 id, uint256 amount) external;
}

/// @title RewardEngine
/// @notice Engine reward untuk TrustyDust:
///         - Social reward (like, repost, comment)
///         - Job completion reward
///         - Recommendation & DAO vote reward
///         - Mint DUST (ERC20) + reputasi ERC1155
///
/// Catatan:
///  - RewardEngine harus diset sebagai minter di DustToken
///  - RewardEngine harus diset sebagai authorized minter di TrustReputation1155
///  - Hanya authorizedCaller (backend / modul lain) yang boleh memanggil fungsi reward
contract RewardEngine is Ownable {
    // ============================================================
    //                           STATE
    // ============================================================

    IDustTokenReward public dust;
    IReputation1155Reward public reputation1155;

    /// @dev modul atau backend yang boleh memanggil reward (middleware, social indexer, job module, dll)
    mapping(address => bool) public authorizedCaller;

    /// @dev reward score (bukan wei, nanti dikali 1e18 saat mint DUST)
    uint256 public likeReward; // default: 1
    uint256 public repostReward; // default: 1
    uint256 public commentReward; // default: 3
    uint256 public recommendationReward; // default: 100
    uint256 public daoVoteWinReward; // default: 30

    /// @dev limit harian untuk like+repost (max 10/hari)
    uint256 public maxSocialScorePerDay; // default: 10

    /// @dev pencatatan reward harian per user (hanya untuk like+repost)
    struct DailySocialCounter {
        uint64 day; // hari ke-n (block.timestamp / 1 days)
        uint16 likeRepostCount; // total like+repost yang sudah dihitung hari ini
    }

    mapping(address => DailySocialCounter) public dailySocial;

    /// @dev ID reputasi ERC1155 untuk beberapa achievement
    uint256 public constant LIKE_ACHIEVEMENT_ID = 1001;
    uint256 public constant COMMENT_ACHIEVEMENT_ID = 1002;
    uint256 public constant JOB_COMPLETION_ACHIEVEMENT_ID = 2001;
    uint256 public constant RECOMMENDATION_ACHIEVEMENT_ID = 2002;
    uint256 public constant DAO_VOTE_WIN_ACHIEVEMENT_ID = 2003;

    // ============================================================
    //                           EVENTS
    // ============================================================

    event AuthorizedCallerUpdated(address indexed caller, bool allowed);
    event RewardConfigUpdated(
        uint256 likeReward,
        uint256 repostReward,
        uint256 commentReward,
        uint256 recommendationReward,
        uint256 daoVoteWinReward,
        uint256 maxSocialPerDay
    );

    event SocialRewarded(
        address indexed user,
        bytes32 indexed action,
        uint256 scoreDelta,
        uint256 dustAmount
    );

    event JobRewarded(
        address indexed user,
        uint256 scoreDelta,
        uint256 dustAmount
    );

    event ExtraRewarded(
        address indexed user,
        bytes32 indexed action,
        uint256 scoreDelta,
        uint256 dustAmount
    );

    event DustAddressUpdated(address indexed previous, address indexed current);
    event ReputationAddressUpdated(
        address indexed previous,
        address indexed current
    );

    // ============================================================
    //                         CONSTRUCTOR
    // ============================================================

    constructor(address owner_, address dustToken_, address reputation1155_)
        Ownable(owner_)
    {
        require(owner_ != address(0), "Reward: zero owner");

        require(dustToken_ != address(0), "Reward: zero dust");
        require(reputation1155_ != address(0), "Reward: zero rep1155");

        dust = IDustTokenReward(dustToken_);
        reputation1155 = IReputation1155Reward(reputation1155_);

        // default konfigurasi reward (bisa diubah owner)
        likeReward = 1;
        repostReward = 1;
        commentReward = 3;
        recommendationReward = 100;
        daoVoteWinReward = 30;
        maxSocialScorePerDay = 10;
    }

    // ============================================================
    //                         MODIFIERS
    // ============================================================

    modifier onlyAuthorized() {
        require(authorizedCaller[msg.sender], "Reward: not authorized");
        _;
    }

    // ============================================================
    //                         ADMIN CONFIG
    // ============================================================

    function setDustAddress(address dustToken_) external onlyOwner {
        require(dustToken_ != address(0), "Reward: zero dust");
        emit DustAddressUpdated(address(dust), dustToken_);
        dust = IDustTokenReward(dustToken_);
    }

    function setReputationAddress(address rep_) external onlyOwner {
        require(rep_ != address(0), "Reward: zero rep");
        emit ReputationAddressUpdated(address(reputation1155), rep_);
        reputation1155 = IReputation1155Reward(rep_);
    }

    /// @notice Set / revoke authorizedCaller (backend, social module, job module, dll).
    function setAuthorizedCaller(
        address caller,
        bool allowed
    ) external onlyOwner {
        require(caller != address(0), "Reward: zero caller");
        authorizedCaller[caller] = allowed;
        emit AuthorizedCallerUpdated(caller, allowed);
    }

    /// @notice Update konfigurasi reward.
    function setRewardConfig(
        uint256 like_,
        uint256 repost_,
        uint256 comment_,
        uint256 recommendation_,
        uint256 daoVoteWin_,
        uint256 maxSocialPerDay_
    ) external onlyOwner {
        likeReward = like_;
        repostReward = repost_;
        commentReward = comment_;
        recommendationReward = recommendation_;
        daoVoteWinReward = daoVoteWin_;
        maxSocialScorePerDay = maxSocialPerDay_;

        emit RewardConfigUpdated(
            like_,
            repost_,
            comment_,
            recommendation_,
            daoVoteWin_,
            maxSocialPerDay_
        );
    }

    // ============================================================
    //                     INTERNAL HELPERS
    // ============================================================

    function _currentDay() internal view returns (uint64) {
        return uint64(block.timestamp / 1 days);
    }

    /// @dev Update counter harian untuk like+repost, dan return berapa banyak aksi yang masih dapat reward.
    /// Misal: max=10, sudah 8, user like → rewardedActions = 1 (sisanya dibuang).
    function _consumeDailySocialQuota(
        address user,
        uint16 requestedActions
    ) internal returns (uint16) {
        uint64 today = _currentDay();
        DailySocialCounter storage counter = dailySocial[user];

        if (counter.day != today) {
            // reset untuk hari baru
            counter.day = today;
            counter.likeRepostCount = 0;
        }

        if (counter.likeRepostCount >= maxSocialScorePerDay) {
            return 0; // sudah mencapai limit
        }

        uint256 remaining = maxSocialScorePerDay - counter.likeRepostCount;
        uint16 applicable = requestedActions;

        if (applicable > remaining) {
            applicable = uint16(remaining);
        }

        counter.likeRepostCount += applicable;
        return applicable;
    }

    function _mintDust(address to, uint256 scoreDelta) internal {
        if (scoreDelta == 0) return;
        uint256 amount = scoreDelta * 1e18;
        dust.mint(to, amount);
    }

    // ============================================================
    //                     SOCIAL REWARD API
    // ============================================================

    /// @notice Reward untuk LIKE (dipanggil oleh backend / modul sosial).
    /// - +1 trustScore per like
    /// - Like & Repost share satu quota max 10/hari
    function rewardLike(address user) external onlyAuthorized {
        require(user != address(0), "Reward: zero user");

        // 1 aksi like
        uint16 applicable = _consumeDailySocialQuota(user, 1);
        if (applicable == 0) {
            // tidak revert, hanya tidak memberikan reward
            emit SocialRewarded(user, "LIKE_SKIPPED", 0, 0);
            return;
        }

        uint256 scoreDelta = likeReward * applicable;
        _mintDust(user, scoreDelta);

        // optional: mint achievement stamp
        reputation1155.mint(user, LIKE_ACHIEVEMENT_ID, 1);

        emit SocialRewarded(user, "LIKE", scoreDelta, scoreDelta * 1e18);
    }

    /// @notice Reward untuk REPOST (dipanggil oleh backend / modul sosial).
    /// - +1 trustScore per repost
    /// - Share quota harian dengan like (max 10/hari)
    function rewardRepost(address user) external onlyAuthorized {
        require(user != address(0), "Reward: zero user");

        uint16 applicable = _consumeDailySocialQuota(user, 1);
        if (applicable == 0) {
            emit SocialRewarded(user, "REPOST_SKIPPED", 0, 0);
            return;
        }

        uint256 scoreDelta = repostReward * applicable;
        _mintDust(user, scoreDelta);

        // optional: bisa pakai ID achievement lain jika mau
        reputation1155.mint(user, LIKE_ACHIEVEMENT_ID, 1);

        emit SocialRewarded(user, "REPOST", scoreDelta, scoreDelta * 1e18);
    }

    /// @notice Reward untuk COMMENT.
    /// - +3 trustScore per comment (default)
    /// - Tidak dibatasi quota harian (bisa diatur kalau mau)
    function rewardComment(address user) external onlyAuthorized {
        require(user != address(0), "Reward: zero user");

        uint256 scoreDelta = commentReward;
        _mintDust(user, scoreDelta);

        reputation1155.mint(user, COMMENT_ACHIEVEMENT_ID, 1);

        emit SocialRewarded(user, "COMMENT", scoreDelta, scoreDelta * 1e18);
    }

    // ============================================================
    //                      JOB REWARD API
    // ============================================================

    /// @notice Reward untuk job completion.
    /// @dev scoreDelta biasanya 50–200 (sesuai rating) dari JobMarketplace / backend.
    function rewardJobCompletion(
        address user,
        uint256 scoreDelta
    ) external onlyAuthorized {
        require(user != address(0), "Reward: zero user");
        require(scoreDelta > 0, "Reward: zero scoreDelta");

        _mintDust(user, scoreDelta);

        reputation1155.mint(user, JOB_COMPLETION_ACHIEVEMENT_ID, 1);

        emit JobRewarded(user, scoreDelta, scoreDelta * 1e18);
    }

    // ============================================================
    //                     EXTRA REWARD API
    // ============================================================

    /// @notice Reward untuk Recommendation (user direkomendasikan / kasih rekomendasi berkualitas).
    /// Default: +100 trustScore.
    function rewardRecommendation(address user) external onlyAuthorized {
        require(user != address(0), "Reward: zero user");

        uint256 scoreDelta = recommendationReward;
        _mintDust(user, scoreDelta);

        reputation1155.mint(user, RECOMMENDATION_ACHIEVEMENT_ID, 1);

        emit ExtraRewarded(
            user,
            "RECOMMENDATION",
            scoreDelta,
            scoreDelta * 1e18
        );
    }

    /// @notice Reward untuk pemenang DAO vote.
    /// Default: +30 trustScore.
    function rewardDaoVoteWin(address user) external onlyAuthorized {
        require(user != address(0), "Reward: zero user");

        uint256 scoreDelta = daoVoteWinReward;
        _mintDust(user, scoreDelta);

        reputation1155.mint(user, DAO_VOTE_WIN_ACHIEVEMENT_ID, 1);

        emit ExtraRewarded(user, "DAO_VOTE_WIN", scoreDelta, scoreDelta * 1e18);
    }
}
