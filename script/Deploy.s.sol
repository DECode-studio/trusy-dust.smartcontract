// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {DustToken} from "src/DustToken.sol";
import {Identity} from "src/Identity.sol";
import {Core} from "src/Core.sol";
import {Content} from "src/Content.sol";
import {Jobs} from "src/Jobs.sol";
import {Verifier} from "src/Verifier.sol";

/// @notice One-shot deployment wiring all contracts together.
/// Uses PRIVATE_KEY from env when broadcasting.
contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);

        vm.startBroadcast(pk);

        // 1) Deploy token; deployer is OWNER
        DustToken dust = new DustToken("Dust", "DUST", deployer);

        // 2) Deploy core components
        Identity identity = new Identity();
        Core core = new Core(identity, dust);
        Content content = new Content(identity, dust);
        Jobs jobs = new Jobs(identity, dust, core);
        Verifier verifier = new Verifier(identity);

        // 3) Wire roles
        dust.setRole(address(core), DustToken.Role.OPERATOR);
        dust.setRole(address(content), DustToken.Role.OPERATOR);
        dust.setRole(address(jobs), DustToken.Role.OPERATOR);

        // 4) Optionally set external verifiers
        // verifier.setVerifiers(tierVerifierAddr, badgeVerifierAddr);

        vm.stopBroadcast();

        console2.log("Deployer", deployer);
        console2.log("DustToken", address(dust));
        console2.log("Identity", address(identity));
        console2.log("Core", address(core));
        console2.log("Content", address(content));
        console2.log("Jobs", address(jobs));
        console2.log("Verifier", address(verifier));
    }
}
