// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {DustToken} from "src/DustToken.sol";
import {Identity} from "src/Identity.sol";
import {Core} from "src/Core.sol";
import {Content} from "src/Content.sol";
import {Jobs} from "src/Jobs.sol";
import {Verifier} from "src/Verifier.sol";

contract BaseTest is Test {
    address internal user1 = address(0xA11CE);
    address internal user2 = address(0xB0B);
    address internal operator = address(0xC0DE);

    DustToken internal dust;
    Identity internal identity;
    Core internal core;
    Content internal content;
    Jobs internal jobs;
    Verifier internal verifier;

    function setUp() public virtual {
        dust = new DustToken("Dust", "DUST", address(this));
        identity = new Identity();
        core = new Core(identity, dust);
        content = new Content(identity, dust);
        jobs = new Jobs(identity, dust, core);
        verifier = new Verifier(identity);

        // grant operator roles to contracts that mint/burn
        dust.setRole(address(core), DustToken.Role.OPERATOR);
        dust.setRole(address(content), DustToken.Role.OPERATOR);
        dust.setRole(address(jobs), DustToken.Role.OPERATOR);

        // seed balances for tests
        dust.mint(user1, 1_000e18);
        dust.mint(user2, 1_000e18);
    }
}
