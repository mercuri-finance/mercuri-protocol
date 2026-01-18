// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Mercuri ERC-20 Token Interface
/// @notice Standard ERC-20 interface used by Mercuri Finance vaults and libraries.
/// @dev Simplified minimal version providing only the essential ERC-20 functions.
interface IERC20 {
    /// @notice Returns the token balance of a specific account.
    /// @param a The address of the account to query.
    /// @return The amount of tokens owned by the specified account.
    function balanceOf(address a) external view returns (uint256);

    /// @notice Approves a spender to transfer up to a specified amount of tokens on behalf of the caller.
    /// @param s The address authorized to spend the tokens.
    /// @param a The number of tokens approved for spending.
    /// @return True if the approval was successful.
    function approve(address s, uint256 a) external returns (bool);

    /// @notice Transfers a specified amount of tokens to a recipient.
    /// @param to The address of the recipient.
    /// @param a The number of tokens to transfer.
    /// @return True if the transfer was successful.
    function transfer(address to, uint256 a) external returns (bool);

    /// @notice Transfers tokens from one address to another using allowance mechanism.
    /// @param f The address to transfer tokens from.
    /// @param t The address to transfer tokens to.
    /// @param a The number of tokens to transfer.
    /// @return True if the transfer was successful.
    function transferFrom(address f, address t, uint256 a) external returns (bool);
}
