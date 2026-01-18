// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Mercuri Fee Configuration Library
/// @notice Defines the shared fee configuration and constants used across Mercuri Finance vaults and the factory.
/// @dev All fees are expressed in basis points, where 10,000 = 100%.
library FeeConfig {
    /// @notice The divisor for calculating percentages in basis points (10,000 = 100%).
    uint256 internal constant BPS_DIVISOR = 10_000;

    /// @notice Structure representing protocol-level fee configuration.
    /// @dev Used by the Mercuri Vault Factory and individual Vaults for performance fee application.
    /// @param performanceFeeBps The performance fee rate expressed in basis points (e.g., 1,000 = 10%).
    /// @param feeRecipient The address that receives all protocol performance fees.
    struct Fees {
        uint16 performanceFeeBps;
        address feeRecipient;
    }
}
