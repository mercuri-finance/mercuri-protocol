// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Mercuri WETH Interface
/// @notice Interface for Wrapped Ether (WETH) operations used in Mercuri Finance vaults.
/// @dev Provides standard WETH deposit and withdrawal methods for wrapping and unwrapping ETH.
interface IWETH {
    /// @notice Deposits ETH and mints an equivalent amount of WETH.
    /// @dev The caller must send ETH with the transaction.
    function deposit() external payable;

    /// @notice Withdraws ETH by burning the specified amount of WETH.
    /// @param amount The amount of WETH to unwrap and return as ETH.
    function withdraw(uint256 amount) external;
}
