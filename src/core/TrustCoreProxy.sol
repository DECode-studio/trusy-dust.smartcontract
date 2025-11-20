// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title TrustCoreProxy
/// @notice Transparent upgradeable proxy untuk TrustCoreImpl.
contract TrustCoreProxy is TransparentUpgradeableProxy {
    /// @param implementation address dari kontrak implementasi awal (TrustCoreImpl)
    /// @param admin admin proxy (biasanya ProxyAdmin)
    /// @param data calldata untuk panggilan initialize() pada implementasi
    constructor(
        address implementation,
        address admin,
        bytes memory data
    ) TransparentUpgradeableProxy(implementation, admin, data) {}
}
