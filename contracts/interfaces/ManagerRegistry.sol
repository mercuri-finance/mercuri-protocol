// SPDX-License-Identifier: MIT
pragma solidity 0.8.32;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title Mercuri Manager Registry
/// @notice Registry of globally approved manager addresses authorized to operate Mercuri Vaults.
/// @dev Only the contract owner can approve or revoke managers. Used by the Mercuri Vault Factory and Vaults for access control.
contract ManagerRegistry is Ownable2Step {

    /// @notice Initializes the registry and sets the deployer as the initial owner.
    constructor() Ownable(msg.sender) {}
    
    /// @notice Mapping of manager addresses to their approval status.
    /// @dev True means the manager is globally approved to manage Mercuri Vaults.
    mapping(address => bool) private approvedManagers;

    /// @notice Emitted when a manager's global approval status is updated.
    /// @param manager The address of the manager whose status changed.
    /// @param approved Whether the manager is now approved (`true`) or revoked (`false`).
    event ManagerApprovalUpdated(address indexed manager, bool approved);

    /// @notice Approves or revokes a manager globally for Mercuri Vault operations.
    /// @dev Only callable by the contract owner.
    /// @param manager The address of the manager to modify.
    /// @param approved Whether the manager is approved (`true`) or revoked (`false`).
    function setApproved(address manager, bool approved) external onlyOwner {
        require(manager != address(0), "zero manager");
        approvedManagers[manager] = approved;
        emit ManagerApprovalUpdated(manager, approved);
    }

    /// @notice Approves or revokes multiple managers in a single transaction.
    /// @dev Only callable by the contract owner.
    /// @param managers Array of manager addresses to modify.
    /// @param approved Whether the managers are approved (`true`) or revoked (`false`).
    function setApprovedBatch(address[] calldata managers, bool approved) external onlyOwner {
        uint256 length = managers.length;

        for (uint256 i; i < length; ) {
            address manager = managers[i];
            require(manager != address(0), "zero manager");

            approvedManagers[manager] = approved;
            emit ManagerApprovalUpdated(manager, approved);

            unchecked { ++i; }
        }
    }

    /// @notice Checks whether an manager is approved globally.
    /// @param manager The address of the manager to query.
    /// @return True if the manager is approved, false otherwise.
    function isApproved(address manager) external view returns (bool) {
        return approvedManagers[manager];
    }
}
