// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../script/DeployTrustyDust.s.sol";
import {INoirVerifier} from "../src/interfaces/INoirVerifier.sol";
import {DustToken} from "../src/token/DustToken.sol";
import {TrustReputation1155} from "../src/identity/TrustReputation1155.sol";
import {TrustCoreImpl} from "../src/core/TrustCoreImpl.sol";
import {RewardEngine} from "../src/reward/RewardEngine.sol";
import {EscrowVault} from "../src/jobs/EscrowVault.sol";
import {JobMarketplace} from "../src/jobs/JobMarketplace.sol";
import {TrustVerification} from "../src/verification/TrustVerification.sol";

contract MockVerifier is DeployTrustyDust, INoirVerifier {
    bool public ok = true;
    function setResult(bool v) external { ok = v; }
    function verify(bytes calldata, bytes32[] calldata) external view returns (bool) {
        return ok;
    }
}

contract DeploymentFlowTest is Test {
    DeployTrustyDust deployer;
    address owner = address(this);
    address rewardOperator = address(0xBEEF);
    address authorizedCaller = address(0xCAFE);
    address bonus = address(0xD00D);

    function setUp() public {
        deployer = new DeployTrustyDust();
    }

    function testDeploymentWiring() public {
        MockVerifier trustScore = new MockVerifier();
        MockVerifier tier = new MockVerifier();

        DeployTrustyDust.Config memory cfg;
        cfg.deployerKey = 0; // no broadcast in test
        cfg.owner = owner;
        cfg.rewardOperator = rewardOperator;
        cfg.authorizedCaller = authorizedCaller;
        cfg.trustBonusRecipient = bonus;
        cfg.verifierTrustScore = address(trustScore);
        cfg.verifierTier = address(tier);
        cfg.dustName = "Dust";
        cfg.dustSymbol = "DUST";
        cfg.badgeName = "TrustBadge";
        cfg.badgeSymbol = "TB";
        cfg.repBaseURI = "ipfs://rep/";

        DeployTrustyDust.Deployed memory d = deployer.deploy(cfg, false);

        // DustToken roles
        assertTrue(d.dust.isMinter(address(d.core)));
        assertTrue(d.dust.isMinter(address(d.rewardEngine)));

        // Reputation roles
        assertTrue(d.rep.authorized(address(d.core)));
        assertTrue(d.rep.authorized(address(d.rewardEngine)));

        // Core config
        assertEq(d.core.rewardOperator(), rewardOperator);
        assertEq(d.core.likeReward(), 1);

        // RewardEngine config
        assertEq(d.rewardEngine.authorizedCaller(authorizedCaller), true);

        // Job marketplace wiring
        assertEq(address(d.jobMarket.trustCore()), address(d.core));
        assertEq(address(d.jobMarket.escrow()), address(d.escrow));
        assertEq(address(d.escrow.marketplace()), address(d.jobMarket));
        assertEq(d.escrow.trustBonusRecipient(), bonus);

        // Verifier wiring
        assertEq(address(d.verifier.trustCore()), address(d.core));
        assertEq(address(d.verifier.trustScoreVerifier()), address(trustScore));
        assertEq(address(d.verifier.tierVerifier()), address(tier));
    }
}
