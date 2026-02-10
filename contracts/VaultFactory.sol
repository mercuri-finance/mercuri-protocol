// SPDX-License-Identifier: MIT
pragma solidity 0.8.32;

import "./Vault.sol";
import "./interfaces/ManagerRegistry.sol";
import "./FeeConfig.sol";
import "./interfaces/ISwapRouter02.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

/// @title Mercuri Vault Factory
/// @notice Deploys and manages Mercuri Vaults that control Uniswap V3 LP positions.
/// @dev The factory also maintains global protocol fee configuration for all Mercuri vaults.
contract VaultFactory is Ownable2Step {
    using FeeConfig for FeeConfig.Fees;

    /// @notice Address of the Uniswap V3 Factory.
    address public immutable UNISWAP_V3_FACTORY;

    /// @notice Address of the Uniswap V3 NonfungiblePositionManager.
    address public immutable POSITION_MANAGER;

    /// @notice Address of the Mercuri Manager Registry contract.
    address public immutable MANAGER_REGISTRY;

    /// @notice Address of the WETH contract used by all vaults.
    address public immutable WETH;

    /// @notice Global protocol performance fee configuration
    /// @dev Applied by Vaults during fee collection or position closure.
    ///      Fee values are interpreted in basis points (BPS).
    ///      A value of 0 disables protocol fees entirely.
    FeeConfig.Fees public protocolFees;

    /// @notice Mapping from owner to list of deployed vault addresses.
    mapping(address => address[]) private _vaultsByOwner;

    /// @notice Mapping from owner and pool to a specific vault address.
    mapping(address => mapping(address => address)) private _vaultByOwnerAndPool;

    /// @notice Emitted when a new Mercuri Vault is deployed
    /// @dev Emitted exactly once per (owner, pool) pair
    /// @param owner Address of the vault owner
    /// @param vault Address of the deployed vault contract
    /// @param pool Address of the associated Uniswap V3 pool
    event VaultCreated(address indexed owner, address indexed vault, address indexed pool);

    /// @notice Emitted when global protocol performance fees are updated.
    /// @param performanceFeeBps The new performance fee in basis points.
    /// @param feeRecipient The address receiving protocol fees.
    event ProtocolFeesUpdated(uint16 performanceFeeBps, address feeRecipient);

    /// @notice Approved Uniswap swap router for vault rebalancing
    /// @dev This router address is immutable and shared by all vaults deployed
    ///      by this factory. Vaults will reject swaps via any other router.
    address public immutable SWAP_ROUTER;

    /// @notice Initializes the Mercuri Vault Factory with core dependencies and default fee configuration.
    /// @param uniswapFactory Address of the Uniswap V3 factory.
    /// @param positionManager Address of the Uniswap V3 NonfungiblePositionManager.
    /// @param managerRegistry Address of the Mercuri Manager Registry.
    /// @param weth Address of the WETH contract.
    constructor(
        address uniswapFactory,
        address positionManager,
        address managerRegistry,
        address weth,
        address swapRouter
    ) Ownable(msg.sender) {
        require(uniswapFactory != address(0), "zero uniswap");
        require(positionManager != address(0), "zero posman");
        require(managerRegistry != address(0), "zero registry");
        require(weth != address(0), "zero weth");
        require(swapRouter != address(0), "zero router");

        UNISWAP_V3_FACTORY = uniswapFactory;
        POSITION_MANAGER = positionManager;
        MANAGER_REGISTRY = managerRegistry;
        WETH = weth;
        SWAP_ROUTER = swapRouter;

        protocolFees = FeeConfig.Fees({performanceFeeBps: 0, feeRecipient: msg.sender});
    }

    /// @notice Updates the global protocol fee configuration for all Mercuri vaults.
    /// @dev Only callable by the contract owner.
    /// @param performanceFeeBps The new performance fee in basis points.
    /// @param feeRecipient The address that will receive protocol fees.
    function setProtocolFees(uint16 performanceFeeBps, address feeRecipient) external onlyOwner {
        require(feeRecipient != address(0), "zero feeRecipient");
        require(performanceFeeBps <= FeeConfig.BPS_DIVISOR, "FEE_TOO_HIGH");

        protocolFees = FeeConfig.Fees({
            performanceFeeBps: performanceFeeBps,
            feeRecipient: feeRecipient
        });

        emit ProtocolFeesUpdated(performanceFeeBps, feeRecipient);
    }

    /// @notice Deploys a new Mercuri Vault for a specific Uniswap V3 pool
    ///         and assigns ownership to the caller.
    /// @dev Security & invariants:
    /// - Each owner may deploy at most one vault per pool
    /// - The pool must belong to the configured Uniswap V3 factory
    /// - The vault is deployed with immutable references to:
    ///     - This factory (for fee configuration)
    ///     - The Uniswap V3 position manager
    ///     - The approved swap router
    /// - The authorized manager is stored but cannot withdraw funds
    ///
    /// Trust assumptions:
    /// - The factory owner controls protocol fee parameters
    /// - The manager address is assumed to be globally approved via ManagerRegistry
    ///
    /// @param pool Address of the Uniswap V3 pool managed by the vault
    /// @param manager Address of the authorized automation manager
    /// @return vaultAddr Address of the newly deployed vault
    function createVault(address pool, address manager) external returns (address vaultAddr) {
        require(pool != address(0), "zero pool");
        require(manager != address(0), "zero manager");

        require(ManagerRegistry(MANAGER_REGISTRY).isApproved(manager), "MANAGER_NOT_APPROVED");

        require(_vaultByOwnerAndPool[msg.sender][pool] == address(0), "vault exists for this pool");

        address token0 = IUniswapV3Pool(pool).token0();
        address token1 = IUniswapV3Pool(pool).token1();
        uint24 fee = IUniswapV3Pool(pool).fee();
        address expectedPool = IUniswapV3Factory(UNISWAP_V3_FACTORY).getPool(token0, token1, fee);

        require(expectedPool == pool, "INVALID_POOL");

        vaultAddr = address(
            new Vault(
                address(this),
                msg.sender,
                manager,
                MANAGER_REGISTRY,
                POSITION_MANAGER,
                pool,
                WETH,
                ISwapRouter02(SWAP_ROUTER)
            )
        );

        _vaultByOwnerAndPool[msg.sender][pool] = vaultAddr;
        _vaultsByOwner[msg.sender].push(vaultAddr);

        emit VaultCreated(msg.sender, vaultAddr, pool);
    }

    /// @notice Returns the vault address for a specific owner and pool.
    /// @param owner Address of the vault owner.
    /// @param pool Address of the Uniswap V3 pool.
    /// @return The address of the corresponding vault, or zero if none exists.
    function getVault(address owner, address pool) external view returns (address) {
        return _vaultByOwnerAndPool[owner][pool];
    }

    /// @notice Returns all vaults created by a specific owner.
    /// @param owner Address of the vault owner.
    /// @return An array of vault addresses owned by the given address.
    function getVaultsByOwner(address owner) external view returns (address[] memory) {
        return _vaultsByOwner[owner];
    }
}
