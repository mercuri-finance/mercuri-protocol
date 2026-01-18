// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/INonfungiblePositionManager.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/ISwapRouter02.sol";
import "./interfaces/SafeERC20.sol";
import "./interfaces/IERC20.sol";
import "./FeeConfig.sol";
import "./VaultFactory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Mercuri Vault
/// @author Mercuri Finance
/// @notice
///  A non-custodial smart vault managing a single Uniswap V3 liquidity position.
///  Allows controlled deposits, liquidity management, fee collection, and withdrawals.
/// @dev
///  - Invariants:
///    - At most one active Uniswap V3 position (`positionId`) at any time
///    - Only `owner` or `manager` may mutate LP state
///    - Protocol fees are enforced on fee collection and position closure
///  - Trust assumptions:
///    - Factory provides correct protocol fee configuration
///    - Uniswap V3 contracts behave as specified
///  - Upgradeability:
///    - None (immutable deployment)
///  - Security:
///    - Reentrancy protected
///    - Uses SafeERC20 throughout
contract Vault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Factory that deployed this vault
    /// @dev Used to fetch protocol fee configuration
    address public immutable factory;

    /// @notice Vault owner with full administrative authority
    address public immutable owner;

    /// @notice Optional delegated manager for operational actions
    /// @dev Cannot withdraw funds to arbitrary addresses
    /// ManagerRegistry is advisory.
    /// The protocol does not enforce manager approval at the vault level.
    address public manager;

    /// @notice Mercuri registry contract address
    address public immutable registry;

    /// @notice Uniswap V3 NonfungiblePositionManager
    address public immutable positionManager;

    /// @notice Uniswap V3 pool managed by this vault
    address public immutable pool;

    /// @notice Pool token0
    address public immutable token0;

    /// @notice Pool token1
    address public immutable token1;

    /// @notice Pool fee tier (e.g. 500 = 0.05%)
    uint24 public immutable fee;

    /// @notice Wrapped ETH contract
    address public immutable WETH;

    /// @notice Approved Uniswap V3 swap router used for rebalancing
    ISwapRouter02 public immutable swapRouter;

    /// @notice Current Uniswap V3 position NFT ID (0 if none)
    uint256 public positionId;

    /// @notice Emitted when the manager address is updated
    /// @param newManager Newly authorized manager
    event ManagerChanged(address indexed newManager);

    /// @notice Emitted when assets are deposited into the vault
    /// @param token Deposited token address
    /// @param amount Amount deposited
    event Deposit(address indexed token, uint256 amount);

    /// @notice Emitted when ERC20 tokens are withdrawn
    /// @param token Token withdrawn
    /// @param amount Amount withdrawn
    event Withdraw(address indexed token, uint256 amount);

    /// @notice Emitted when ETH is withdrawn
    /// @param amount ETH amount withdrawn
    event ETHWithdraw(uint256 amount);

    /// @notice Emitted when a position NFT is fully closed
    /// @param tokenId Closed position ID
    event PositionClosed(uint256 tokenId);

    /// @notice Emitted when protocol performance fees are paid
    /// @param tokenId Position ID
    /// @param fee0 Token0 fee paid
    /// @param fee1 Token1 fee paid
    event PerformanceFeeTaken(uint256 indexed tokenId, uint256 fee0, uint256 fee1);

    /// @notice Restricts execution to the vault owner
    /// @dev Used for administrative and capital-moving operations
    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    /// @notice Restricts execution to owner or delegated manager
    /// @dev Used for LP lifecycle, swaps, and rebalancing
    modifier onlyAuthorized() {
        require(msg.sender == owner || msg.sender == manager, "not authorized");
        _;
    }

    /// @notice Deploys a new Mercuri Vault instance
    /// @dev All addresses are immutable and validated
    /// @param factory_ Vault factory address
    /// @param owner_ Vault owner
    /// @param manager_ Initial manager
    /// @param registry_ Mercuri registry
    /// @param positionManager_ Uniswap position manager
    /// @param pool_ Uniswap V3 pool
    /// @param weth_ Wrapped ETH address
    /// @param swapRouter_ Approved swap router
    constructor(
        address factory_,
        address owner_,
        address manager_,
        address registry_,
        address positionManager_,
        address pool_,
        address weth_,
        ISwapRouter02 swapRouter_
    ) {
        require(factory_ != address(0), "zero factory");
        require(owner_ != address(0), "zero owner");
        require(manager_ != address(0), "zero manager");
        require(registry_ != address(0), "zero registry");
        require(positionManager_ != address(0), "zero positionManager");
        require(pool_ != address(0), "zero pool");
        require(weth_ != address(0), "zero WETH");
        require(address(swapRouter_) != address(0), "zero router");

        factory = factory_;
        owner = owner_;
        manager = manager_;
        registry = registry_;
        positionManager = positionManager_;
        pool = pool_;
        WETH = weth_;
        swapRouter = swapRouter_;

        token0 = IUniswapV3Pool(pool_).token0();
        token1 = IUniswapV3Pool(pool_).token1();
        fee = IUniswapV3Pool(pool_).fee();
    }

    /// @notice Updates the authorized operational manager
    /// @dev
    /// - Initial manager is assigned by the protocol and registry-approved
    /// - Vault owners may override the manager at their own risk
    /// - ManagerRegistry is not enforced after deployment
    /// @param newManager Address of the new manager
    function setManager(address newManager) external onlyOwner {
        manager = newManager;
        emit ManagerChanged(newManager);
    }

    /// @notice Deposits token0 and token1 into the vault
    /// @dev
    ///  - Accepts ETH only if corresponding pool token is WETH
    ///  - Wraps ETH into WETH automatically
    ///  - Caller must approve ERC20 transfers beforehand
    ///  - Emits two Deposit events (one per token)
    /// @param amount0 Amount of token0 or ETH → WETH to deposit
    /// @param amount1 Amount of token1 or ETH → WETH to deposit
    function deposit(uint256 amount0, uint256 amount1)
        external
        payable
        nonReentrant
    {
        if (token0 == WETH && msg.value > 0) {
            require(amount0 == msg.value, "wrong ETH amount0");
            IWETH(WETH).deposit{value: msg.value}();
        } else {
            IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        }

        if (token1 == WETH && msg.value > 0 && token0 != WETH) {
            require(amount1 == msg.value, "wrong ETH amount1");
            IWETH(WETH).deposit{value: msg.value}();
        } else {
            IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);
        }

        emit Deposit(token0, amount0);
        emit Deposit(token1, amount1);
    }

    /// @notice Applies protocol performance fees to a position
    /// @dev
    ///  - Fetches fee configuration from VaultFactory
    ///  - Collects all owed fees from Uniswap first
    ///  - Transfers protocol share to fee recipient
    ///  - Emits PerformanceFeeTaken
    /// @param tokenId ID of the Uniswap V3 position NFT
    function _applyPerformanceFee(uint256 tokenId) internal {
        (uint16 perf, address recipient) = VaultFactory(factory).protocolFees();

        FeeConfig.Fees memory feesCfg = FeeConfig.Fees({
            performanceFeeBps: perf,
            feeRecipient: recipient
        });

        uint16 perfBps = feesCfg.performanceFeeBps;
        if (perfBps == 0) return;

        (, , , , , , , , , , uint128 owed0, uint128 owed1) =
            INonfungiblePositionManager(positionManager).positions(tokenId);

        if (owed0 == 0 && owed1 == 0) return;

        INonfungiblePositionManager(positionManager).collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        uint256 fee0 = (owed0 * perfBps) / FeeConfig.BPS_DIVISOR;
        uint256 fee1 = (owed1 * perfBps) / FeeConfig.BPS_DIVISOR;

        if (fee0 > 0) IERC20(token0).safeTransfer(feesCfg.feeRecipient, fee0);
        if (fee1 > 0) IERC20(token1).safeTransfer(feesCfg.feeRecipient, fee1);

        emit PerformanceFeeTaken(tokenId, fee0, fee1);
    }

    /// @notice Withdraws all liquidity and assets to the owner
    /// @dev
    ///  - Decreases all liquidity
    ///  - Applies protocol performance fees
    ///  - Collects remaining fees
    ///  - Burns the position NFT
    ///  - Resets positionId to zero
    ///  - Transfers all token balances to owner
    function withdrawAll() external onlyOwner nonReentrant {
        uint256 posId = positionId;

        if (posId != 0) {
            (, , , , , , , uint128 liq, , , ,) =
                INonfungiblePositionManager(positionManager).positions(posId);

            if (liq > 0) {
                INonfungiblePositionManager(positionManager).decreaseLiquidity(
                    INonfungiblePositionManager.DecreaseLiquidityParams({
                        tokenId: posId,
                        liquidity: liq,
                        amount0Min: 0,
                        amount1Min: 0,
                        deadline: block.timestamp
                    })
                );
            }

            _applyPerformanceFee(posId);

            INonfungiblePositionManager(positionManager).collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: posId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );

            INonfungiblePositionManager(positionManager).burn(posId);
            positionId = 0;
        }

        _withdrawTokenOrETH(token0);
        _withdrawTokenOrETH(token1);
    }

    /// @notice Withdraws all token balances without touching the LP position
    /// @dev
    ///  - Intended for emergency recovery
    ///  - Does not apply protocol fees
    ///  - Does not modify positionId
    function emergencyWithdrawAll() external onlyOwner nonReentrant {
        _withdrawTokenOrETH(token0);
        _withdrawTokenOrETH(token1);
    }

    /// @notice Withdraws full balance of a token or ETH to the owner
    /// @dev
    ///  - Unwraps WETH into ETH before transfer
    ///  - Reverts if ETH transfer fails
    /// @param token Address of the token to withdraw
    function _withdrawTokenOrETH(address token) internal {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal == 0) return;

        if (token == WETH) {
            IWETH(WETH).withdraw(bal);
            (bool ok, ) = owner.call{value: bal}("");
            require(ok, "eth transfer failed");
            emit ETHWithdraw(bal);
        } else {
            IERC20(token).safeTransfer(owner, bal);
            emit Withdraw(token, bal);
        }
    }

    /// @notice Mints a new Uniswap V3 liquidity position
    /// @dev
    ///  - Reverts if a position already exists
    ///  - Approves tokens exactly as needed
    ///  - Position NFT is held by this vault
    /// @param params Mint parameters per INonfungiblePositionManager
    /// @return tokenId ID of the newly minted position
    /// @return liquidity Amount of liquidity added
    /// @return amount0 Token0 spent
    /// @return amount1 Token1 spent
    function mintPosition(
        INonfungiblePositionManager.MintParams calldata params
    )
        external
        onlyAuthorized
        nonReentrant
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        require(params.token0 == token0 && params.token1 == token1, "wrong tokens");
        require(params.fee == fee, "wrong fee");
        require(positionId == 0, "position exists");

        if (params.amount0Desired > 0) {
            IERC20(token0).safeApprove(positionManager, 0);
            IERC20(token0).safeApprove(positionManager, params.amount0Desired);
        }
        if (params.amount1Desired > 0) {
            IERC20(token1).safeApprove(positionManager, 0);
            IERC20(token1).safeApprove(positionManager, params.amount1Desired);
        }

        (tokenId, liquidity, amount0, amount1) =
            INonfungiblePositionManager(positionManager).mint(params);

        positionId = tokenId;
    }

    /// @notice Increases liquidity for the active position
    /// @dev
    ///  - Requires an existing position
    ///  - Approves tokens only for the desired amounts
    /// @param params Increase parameters per INonfungiblePositionManager
    /// @return liquidity Liquidity added
    /// @return amount0 Token0 spent
    /// @return amount1 Token1 spent
    function increaseLiquidity(
        INonfungiblePositionManager.IncreaseLiquidityParams calldata params
    )
        external
        onlyAuthorized
        nonReentrant
        returns (uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        if (params.amount0Desired > 0) {
            IERC20(token0).safeApprove(positionManager, 0);
            IERC20(token0).safeApprove(positionManager, params.amount0Desired);
        }
        if (params.amount1Desired > 0) {
            IERC20(token1).safeApprove(positionManager, 0);
            IERC20(token1).safeApprove(positionManager, params.amount1Desired);
        }

        return INonfungiblePositionManager(positionManager).increaseLiquidity(params);
    }

    /// @notice Decreases liquidity from the active position
    /// @dev Does not collect fees or burn the position
    /// @param params Decrease parameters per INonfungiblePositionManager
    /// @return amount0 Token0 returned
    /// @return amount1 Token1 returned
    function decreaseLiquidity(
        INonfungiblePositionManager.DecreaseLiquidityParams calldata params
    )
        external
        onlyAuthorized
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        return INonfungiblePositionManager(positionManager).decreaseLiquidity(params);
    }

    /// @notice Collects swap fees from the active position
    /// @dev
    ///  - Does not apply protocol fees
    ///  - Fees remain in vault balance
    /// @param params Collect parameters per INonfungiblePositionManager
    /// @return amount0 Token0 collected
    /// @return amount1 Token1 collected
    function collect(
        INonfungiblePositionManager.CollectParams calldata params
    )
        external
        onlyAuthorized
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        return INonfungiblePositionManager(positionManager).collect(params);
    }

    /// @notice Burns a Uniswap V3 position NFT
    /// @dev
    ///  - Does not automatically withdraw liquidity
    ///  - Clears positionId if burning active position
    /// @param tokenId ID of the NFT to burn
    function burn(uint256 tokenId)
        external
        onlyAuthorized
        nonReentrant
    {
        INonfungiblePositionManager(positionManager).burn(tokenId);
        if (tokenId == positionId) positionId = 0;
    }

    /// @notice Fully closes a Uniswap V3 position
    /// @dev
    ///  - Decreases all liquidity
    ///  - Applies protocol performance fees
    ///  - Collects remaining fees
    ///  - Burns the NFT
    /// @param tokenId ID of the position to close
    function closePosition(uint256 tokenId)
        external
        onlyAuthorized
        nonReentrant
    {
        (, , , , , , , uint128 liquidity, , , ,) =
            INonfungiblePositionManager(positionManager).positions(tokenId);

        if (liquidity > 0) {
            INonfungiblePositionManager(positionManager).decreaseLiquidity(
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                })
            );
        }

        _applyPerformanceFee(tokenId);

        INonfungiblePositionManager(positionManager).collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        INonfungiblePositionManager(positionManager).burn(tokenId);
        emit PositionClosed(tokenId);

        if (tokenId == positionId) positionId = 0;
    }

    /// @notice Swaps between pool tokens for rebalancing
    /// @dev
    ///  - Swap recipient must be this vault
    ///  - Only allows swaps between token0 and token1
    /// @param params Swap parameters per ISwapRouter02
    /// @return amountOut Amount of token received
    function rebalanceExactInputSingle(
        ISwapRouter02.ExactInputSingleParams calldata params
    )
        external
        onlyAuthorized
        nonReentrant
        returns (uint256 amountOut)
    {
        require(params.recipient == address(this), "BAD_RECIPIENT");

        require(
            (params.tokenIn == token0 && params.tokenOut == token1) ||
            (params.tokenIn == token1 && params.tokenOut == token0),
            "INVALID_PAIR"
        );

        IERC20(params.tokenIn).safeApprove(address(swapRouter), 0);
        IERC20(params.tokenIn).safeApprove(address(swapRouter), params.amountIn);

        amountOut = swapRouter.exactInputSingle(params);
    }

    /// @notice Receives ETH from trusted contracts only
    /// @dev
    ///  - Accepts ETH only from WETH unwraps or swap router
    ///  - Automatically wraps ETH sent by router
    receive() external payable {
        address router = address(swapRouter);

        require(
            msg.sender == WETH || msg.sender == router,
            "unauthorized eth sender"
        );

        if (msg.sender == router) {
            IWETH(WETH).deposit{value: msg.value}();
        }
    }
}
