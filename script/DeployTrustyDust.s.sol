// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {DustToken} from "../src/token/DustToken.sol";
import {TrustBadgeSBT} from "../src/identity/TrustBadgeSBT.sol";
import {TrustReputation1155} from "../src/identity/TrustReputation1155.sol";
import {TrustCoreImpl} from "../src/core/TrustCoreImpl.sol";
import {TrustCoreProxy} from "../src/core/TrustCoreProxy.sol";
import {RewardEngine} from "../src/reward/RewardEngine.sol";
import {JobMarketplace} from "../src/jobs/JobMarketplace.sol";
import {TrustVerification} from "../src/verification/TrustVerification.sol";
import {PostContentNFT} from "../src/identity/PostContentNFT.sol";

/// @notice Deployment script TrustyDust, reusable untuk test/integration.
contract DeployTrustyDust is Script {
    struct Config {
        uint256 deployerKey;
        address owner;
        address rewardOperator;
        address authorizedCaller;
        address verifierTrustScore;
        address verifierTier;
        string dustName;
        string dustSymbol;
        string badgeName;
        string badgeSymbol;
        string repBaseURI;
        string postName;
        string postSymbol;
        uint256 postBadgeId;
    }

    struct Deployed {
        DustToken dust;
        TrustBadgeSBT badge;
        TrustReputation1155 rep;
        TrustCoreImpl core;
        TrustCoreProxy proxy;
        RewardEngine rewardEngine;
        JobMarketplace jobMarket;
        TrustVerification verifier;
        PostContentNFT postNFT;
    }

    function run() external {
        Config memory cfg = loadConfig();
        deploy(cfg, true);
    }

    /// @notice Deploy seluruh modul; jika `broadcast` true maka startBroadcast.
    function deploy(
        Config memory cfg,
        bool broadcast
    ) public returns (Deployed memory d) {
        bool pranked = false;
        if (broadcast) {
            vm.startBroadcast(cfg.deployerKey);
        } else if (cfg.owner != address(0)) {
            vm.startPrank(cfg.owner);
            pranked = true;
        }

        d.dust = new DustToken(cfg.dustName, cfg.dustSymbol, cfg.owner);
        d.badge = new TrustBadgeSBT(
            cfg.badgeName,
            cfg.badgeSymbol,
            cfg.owner
        );
        d.rep = new TrustReputation1155(cfg.repBaseURI, cfg.owner);

        TrustCoreImpl impl = new TrustCoreImpl();
        bytes memory initData = abi.encodeCall(
            TrustCoreImpl.initialize,
            (
                cfg.owner,
                address(d.dust),
                address(d.badge),
                address(d.rep),
                cfg.rewardOperator
            )
        );
        d.proxy = new TrustCoreProxy(address(impl), cfg.owner, initData);
        d.core = TrustCoreImpl(address(d.proxy));

        d.rewardEngine = new RewardEngine(
            cfg.owner,
            address(d.dust),
            address(d.rep)
        );

        d.jobMarket = new JobMarketplace(
            cfg.owner,
            address(d.dust),
            address(d.core),
            address(d.rep)
        );

        d.postNFT = new PostContentNFT(
            cfg.postName,
            cfg.postSymbol,
            cfg.owner,
            address(d.dust),
            address(d.rep),
            cfg.postBadgeId
        );

        d.verifier = new TrustVerification(cfg.owner, address(d.core));
        if (cfg.verifierTrustScore != address(0)) {
            d.verifier.setTrustScoreVerifier(cfg.verifierTrustScore);
        }
        if (cfg.verifierTier != address(0)) {
            d.verifier.setTierVerifier(cfg.verifierTier);
        }

        // Role wiring
        d.dust.setMinter(address(d.core), true);
        d.dust.setMinter(address(d.rewardEngine), true);
        d.dust.setMinter(address(d.jobMarket), true);
        d.dust.setMinter(address(d.postNFT), true);
        d.rep.setAuthorized(address(d.core), true);
        d.rep.setAuthorized(address(d.rewardEngine), true);
        d.rep.setAuthorized(address(d.jobMarket), true);
        d.rep.setAuthorized(address(d.postNFT), true);

        if (cfg.rewardOperator != address(0) && cfg.rewardOperator != cfg.owner) {
            // rewardOperator ditetapkan saat inisialisasi TrustCore
        }
        if (cfg.authorizedCaller != address(0)) {
            d.rewardEngine.setAuthorizedCaller(cfg.authorizedCaller, true);
        }

        if (broadcast) {
            vm.stopBroadcast();
        } else if (pranked) {
            vm.stopPrank();
        }

        console2.log("DustToken       :", address(d.dust));
        console2.log("TrustBadgeSBT   :", address(d.badge));
        console2.log("TrustRep1155    :", address(d.rep));
        console2.log("TrustCoreImpl   :", address(impl));
        console2.log("TrustCoreProxy  :", address(d.proxy));
        console2.log("RewardEngine    :", address(d.rewardEngine));
        console2.log("JobMarketplace  :", address(d.jobMarket));
        console2.log("TrustVerification:", address(d.verifier));
        console2.log("PostContentNFT  :", address(d.postNFT));
    }

    function loadConfig() internal view returns (Config memory cfg) {
        cfg.deployerKey = vm.envUint("PRIVATE_KEY");
        cfg.owner = vm.envAddress("OWNER");
        cfg.rewardOperator = vm.envOr(
            "REWARD_OPERATOR",
            vm.envAddress("OWNER")
        );
        cfg.authorizedCaller = vm.envOr(
            "AUTHORIZED_CALLER",
            vm.envAddress("OWNER")
        );
        cfg.verifierTrustScore = vm.envOr("TRUST_SCORE_VERIFIER", address(0));
        cfg.verifierTier = vm.envOr("TIER_VERIFIER", address(0));
        cfg.dustName = vm.envOr("DUST_NAME", string("Dust"));
        cfg.dustSymbol = vm.envOr("DUST_SYMBOL", string("DUST"));
        cfg.badgeName = vm.envOr("BADGE_NAME", string("Trust Badge"));
        cfg.badgeSymbol = vm.envOr("BADGE_SYMBOL", string("TBDGE"));
        cfg.repBaseURI = vm.envOr("REP_BASE_URI", string("ipfs://rep/"));
        cfg.postName = vm.envOr("POST_NAME", string("Post"));
        cfg.postSymbol = vm.envOr("POST_SYMBOL", string("POST"));
        cfg.postBadgeId = vm.envOr("POST_BADGE_ID", uint256(4001));
    }
}
