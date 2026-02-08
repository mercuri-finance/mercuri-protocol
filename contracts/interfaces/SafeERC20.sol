// SPDX-License-Identifier: MIT
pragma solidity 0.8.32;

import "./IERC20.sol";

/// @title Mercuri SafeERC20 Library
/// @notice Provides safe wrappers around ERC-20 operations that revert on failure.
/// @dev This library ensures ERC-20 `transfer`, `transferFrom`, and `approve` calls do not silently fail.
///      It should be used for all token interactions within Mercuri Finance Vaults.
library SafeERC20 {
    /// @notice Safely transfers tokens from the current contract to a recipient.
    /// @dev Reverts if the underlying ERC-20 `transfer` returns false.
    /// @param token The ERC-20 token interface.
    /// @param to The recipient address.
    /// @param amount The number of tokens to transfer.
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        require(token.transfer(to, amount), "transfer fail");
    }

    /// @notice Safely transfers tokens from one address to another using allowance.
    /// @dev Reverts if the underlying ERC-20 `transferFrom` returns false.
    /// @param token The ERC-20 token interface.
    /// @param from The source address holding the tokens.
    /// @param to The recipient address.
    /// @param amount The number of tokens to transfer.
    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        require(token.transferFrom(from, to, amount), "transferFrom fail");
    }

    /// @notice Safely sets a spender’s allowance over the caller’s tokens.
    /// @dev Reverts if the underlying ERC-20 `approve` returns false.
    /// @param token The ERC-20 token interface.
    /// @param spender The address authorized to spend tokens.
    /// @param amount The number of tokens approved for spending.
    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        require(token.approve(spender, amount), "approve fail");
    }
}
