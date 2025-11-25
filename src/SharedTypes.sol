// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

library SharedTypes {
    enum SocialAction {
        LIKE,
        COMMENT,
        REPOST
    }

    enum JobStatus {
        OPEN,
        COMPLETED,
        CANCELLED
    }

    struct User {
        uint256 trustScore;
        uint256 tier;
        uint256 reputation;
        uint256 posts;
        uint256 jobsCompleted;
        bool hasBadge;
    }

    struct Job {
        uint256 id;
        address poster;
        address worker;
        uint256 minScore;
        uint8 rating;
        JobStatus status;
    }
}
