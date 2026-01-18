// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Mercuri Manager Registry
/// @notice Registry of globally approved manager addresses authorized to operate Mercuri Vaults.
/// @dev Only the contract owner can approve or revoke managers. Used by the Mercuri Vault Factory and Vaults for access control.
contract ManagerRegistry {
    /// @notice Address of the contract owner with exclusive rights to update manager approvals.
    address public owner;

    /// @notice Mapping of manager addresses to their approval status.
    /// @dev True means the manager is globally approved to manage Mercuri Vaults.
    mapping(address => bool) private approvedManagers;

    /// @notice Emitted when an manager global approval status is updated.
    /// @param manager The address of the manager whose status changed.
    /// @param approved Whether the manager is now approved (`true`) or revoked (`false`).
    event ManagertApprovalUpdated(address indexed manager, bool approved);

    /// @notice Error raised when a non-owner attempts to call an owner-restricted function.
    error NotOwner();

    /// @notice Restricts function access to the contract owner.
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @notice Initializes the Manager Registry and sets the deployer as the initial owner.
    constructor() {
        owner = msg.sender;
    }

    /// @notice Approves or revokes an manager globally for Mercuri Vault operations.
    /// @dev Only callable by the contract owner.
    /// @param manager The address of the manager to modify.
    /// @param approved Whether the manager is approved (`true`) or revoked (`false`).
    function setApproved(address manager, bool approved) external onlyOwner {
        approvedManagers[manager] = approved;
        emit ManagertApprovalUpdated(manager, approved);
    }

    /// @notice Checks whether an manager is approved globally.
    /// @param manager The address of the manager to query.
    /// @return True if the manager is approved, false otherwise.
    function isApproved(address manager) external view returns (bool) {
        return approvedManagers[manager];
    }
}
