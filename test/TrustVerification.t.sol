// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {
    TrustVerification,
    INoirVerifier,
    ITrustCore
} from "../src/verification/TrustVerification.sol";

contract MockVerifier is INoirVerifier {
    bool public result = true;

    function setResult(bool newResult) external {
        result = newResult;
    }

    function verify(
        bytes calldata,
        bytes32[] calldata
    ) external view returns (bool) {
        return result;
    }
}

contract MockTrustCore is ITrustCore {
    bool public badgeCalled;
    address public lastUser;
    uint256 public lastTier;
    string public lastUri;

    function setUserBadgeTier(
        address user,
        uint256 tier,
        string calldata metadataURI
    ) external {
        badgeCalled = true;
        lastUser = user;
        lastTier = tier;
        lastUri = metadataURI;
    }

    function hasMinTrustScore(
        address,
        uint256
    ) external pure returns (bool) {
        return true;
    }

    function getTrustScore(address) external pure returns (uint256) {
        return 0;
    }

    function getTier(address) external pure returns (uint8) {
        return 0;
    }

    function rewardJobCompletion(address, uint256) external pure {}
}

contract TrustVerificationTest is Test {
    TrustVerification internal verifier;
    MockVerifier internal trustScoreVerifier;
    MockVerifier internal tierVerifier;
    MockTrustCore internal core;

    function setUp() public {
        trustScoreVerifier = new MockVerifier();
        tierVerifier = new MockVerifier();
        core = new MockTrustCore();
        verifier = new TrustVerification(address(this), address(core));

        verifier.setTrustScoreVerifier(address(trustScoreVerifier));
        verifier.setTierVerifier(address(tierVerifier));
        verifier.setTrustCore(address(core));
    }

    function testVerifyTrustScoreSuccess() public {
        bool ok = verifier.verifyTrustScoreGeq(bytes("proof"), 100);
        assertTrue(ok);
    }

    function testVerifyTrustScoreFailsWhenVerifierRejects() public {
        trustScoreVerifier.setResult(false);
        vm.expectRevert(bytes("TrustVerify: invalid trustScore proof"));
        verifier.verifyTrustScoreGeq(bytes("bad"), 50);
    }

    function testVerifyTierUpdatesBadge() public {
        verifier.verifyTierAndUpdateBadge(bytes("proof"), 2, "ipfs://tier2");
        assertTrue(core.badgeCalled());
        assertEq(core.lastUser(), address(this));
        assertEq(core.lastTier(), 2);
        assertEq(core.lastUri(), "ipfs://tier2");
    }
}
