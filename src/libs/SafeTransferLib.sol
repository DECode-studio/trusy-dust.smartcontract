// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SafeTransferLib
/// @notice Low-level safe calls untuk ERC20 & native token.
///         Aman terhadap token yang tidak mengembalikan boolean.
library SafeTransferLib {
    // ===== Native Token (LSK / ETH) =====

    function safeTransferETH(address to, uint256 amount) internal {
        (bool success, ) = to.call{value: amount}("");
        require(success, "SAFE_TRANSFER_ETH_FAILED");
    }

    // ===== ERC20 =====

    function safeTransfer(address token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, amount)
        ); // transfer(address,uint256)
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SAFE_TRANSFER_FAILED"
        );
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, amount)
        ); // transferFrom
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SAFE_TRANSFER_FROM_FAILED"
        );
    }

    function safeApprove(
        address token,
        address spender,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x095ea7b3, spender, amount)
        ); // approve
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "SAFE_APPROVE_FAILED"
        );
    }
}
