// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {
    ProxyAdmin as OZProxyAdmin,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/// @title ProxyAdmin for TrustCore
/// @notice Thin wrapper di atas OZ ProxyAdmin dengan helper `upgrade` tanpa data.
contract ProxyAdmin is OZProxyAdmin {
    constructor(address initialOwner) OZProxyAdmin(initialOwner) {}

    /// @notice Upgrade implementation tanpa calldata init.
    /// @dev TransparentUpgradeableProxy v5 hanya expose upgradeToAndCall; gunakan data kosong.
    function upgrade(
        ITransparentUpgradeableProxy proxy,
        address newImplementation
    ) external onlyOwner {
        upgradeAndCall(proxy, newImplementation, "");
    }
}
