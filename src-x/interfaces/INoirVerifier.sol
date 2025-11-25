// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title INoirVerifier
/// @notice Interface generic ke verifier ZK (Noir / Plonk / Barretenberg).
/// @dev Implementasi konkret biasanya di-generate oleh tooling Noir.
interface INoirVerifier {
    /// @param proof        bukti ZK (bytes)
    /// @param publicInputs array field elements yang jadi public input di circuit
    /// @return true jika proof valid
    function verify(
        bytes calldata proof,
        bytes32[] calldata publicInputs
    ) external view returns (bool);
}
