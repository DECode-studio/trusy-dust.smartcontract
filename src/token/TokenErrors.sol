// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title TokenErrors
/// @notice Kumpulan error untuk modul token (hemat gas, rapi).
library TokenErrors {
    error ZeroAddress();
    error NotMinter();
    error InsufficientBalance();
}
