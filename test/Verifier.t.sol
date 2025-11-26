// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Identity} from "src/Identity.sol";
import {Verifier, IExternalVerifier} from "src/Verifier.sol";

contract MockVerifier is IExternalVerifier {
    bool public result = true;
    function setResult(bool r) external { result = r; }
    function verify(bytes calldata, bytes32[] calldata) external view override returns (bool) {
        return result;
    }
}

contract VerifierTest is Test {
    Identity internal identity;
    Verifier internal verifier;
    MockVerifier internal trustScore;
    MockVerifier internal tier;
    address internal user = address(this);

    function setUp() public {
        identity = new Identity();
        verifier = new Verifier(identity);
        trustScore = new MockVerifier();
        tier = new MockVerifier();
        verifier.setVerifiers(address(trustScore), address(tier));
    }

    function testVerifyTierUpdatesIdentity() public {
        bytes memory proof = hex"01";
        bool ok = verifier.verifyTier(proof, 2, 100);
        assertTrue(ok);
        (, uint256 tierVal,,,,bool hasBadge) = identity.users(user);
        assertEq(tierVal, 2);
        assertTrue(hasBadge);
    }

    function testVerifyTierFails() public {
        tier.setResult(false);
        bool ok = verifier.verifyTier(hex"01", 1, 50);
        assertFalse(ok);
    }
}
