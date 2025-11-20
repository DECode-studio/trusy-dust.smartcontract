// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {
    RewardEngine,
    IDustTokenReward,
    IReputation1155Reward
} from "../src/reward/RewardEngine.sol";

contract MockDustToken is IDustTokenReward {
    mapping(address => uint256) public minted;

    function mint(address to, uint256 amount) external {
        minted[to] += amount;
    }
}

contract MockReputation1155 is IReputation1155Reward {
    mapping(address => mapping(uint256 => uint256)) public minted;

    function mint(address to, uint256 id, uint256 amount) external {
        minted[to][id] += amount;
    }
}

contract RewardEngineTest is Test {
    RewardEngine internal engine;
    MockDustToken internal dust;
    MockReputation1155 internal rep;
    address internal owner = address(0xA11CE);
    address internal caller = address(0xBEEF);
    address internal user = address(0xCAFE);

    function setUp() public {
        dust = new MockDustToken();
        rep = new MockReputation1155();
        vm.prank(owner);
        engine = new RewardEngine(owner, address(dust), address(rep));
        vm.prank(owner);
        engine.setAuthorizedCaller(caller, true);
    }

    function testLikeQuotaCappedPerDay() public {
        vm.startPrank(caller);
        // default maxSocialScorePerDay = 10, likeReward = 1
        for (uint256 i = 0; i < 12; i++) {
            engine.rewardLike(user);
        }
        vm.stopPrank();

        // Only 10 likes counted → 10 * 1e18 minted
        assertEq(dust.minted(user), 10 * 1e18);
        // Achievement minted 10 times as well
        assertEq(rep.minted(user, engine.LIKE_ACHIEVEMENT_ID()), 10);
    }

    function testCommentRewardMinted() public {
        vm.prank(caller);
        engine.rewardComment(user);

        assertEq(dust.minted(user), 3 * 1e18); // commentReward default 3
        assertEq(rep.minted(user, engine.COMMENT_ACHIEVEMENT_ID()), 1);
    }

    function testJobCompletionRewarded() public {
        vm.prank(caller);
        engine.rewardJobCompletion(user, 50);

        assertEq(dust.minted(user), 50 * 1e18);
        assertEq(rep.minted(user, engine.JOB_COMPLETION_ACHIEVEMENT_ID()), 1);
    }
}
