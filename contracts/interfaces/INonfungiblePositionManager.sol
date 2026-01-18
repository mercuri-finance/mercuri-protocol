// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;
pragma abicoder v2;

import "@openzeppelin/contracts/interfaces/IERC721Metadata.sol";
import "@openzeppelin/contracts/interfaces/IERC721Enumerable.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IPoolInitializer.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IERC721Permit.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IPeripheryPayments.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IPeripheryImmutableState.sol";

/// @title Uniswap V3 Nonfungible Position Manager Interface
/// @notice Interface for managing Uniswap V3 liquidity positions represented as NFTs.
/// @dev This interface is identical to the official Uniswap V3 Periphery contract interface and
///      is used by Mercuri Vaults to mint, modify, and burn LP positions.
interface INonfungiblePositionManager {
    /// @notice Parameters required to mint a new Uniswap V3 liquidity position.
    /// @param token0 Address of the first ERC20 token of the pool.
    /// @param token1 Address of the second ERC20 token of the pool.
    /// @param fee Fee tier of the pool in hundredths of a bip (e.g., 3000 = 0.3%).
    /// @param tickLower Lower tick boundary of the position.
    /// @param tickUpper Upper tick boundary of the position.
    /// @param amount0Desired Desired amount of token0 to provide.
    /// @param amount1Desired Desired amount of token1 to provide.
    /// @param amount0Min Minimum amount of token0 to add (slippage protection).
    /// @param amount1Min Minimum amount of token1 to add (slippage protection).
    /// @param recipient Address that will receive the position NFT.
    /// @param deadline Transaction deadline as a Unix timestamp.
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    /// @notice Parameters for increasing liquidity in an existing Uniswap V3 position.
    /// @param tokenId ID of the position NFT.
    /// @param amount0Desired Desired amount of token0 to add.
    /// @param amount1Desired Desired amount of token1 to add.
    /// @param amount0Min Minimum amount of token0 to add (slippage protection).
    /// @param amount1Min Minimum amount of token1 to add (slippage protection).
    /// @param deadline Transaction deadline as a Unix timestamp.
    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    /// @notice Parameters for decreasing liquidity from an existing Uniswap V3 position.
    /// @param tokenId ID of the position NFT.
    /// @param liquidity Amount of liquidity to remove.
    /// @param amount0Min Minimum amount of token0 to receive.
    /// @param amount1Min Minimum amount of token1 to receive.
    /// @param deadline Transaction deadline as a Unix timestamp.
    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    /// @notice Parameters for collecting fees from an existing Uniswap V3 position.
    /// @param tokenId ID of the position NFT.
    /// @param recipient Address to receive the collected tokens.
    /// @param amount0Max Maximum amount of token0 to collect.
    /// @param amount1Max Maximum amount of token1 to collect.
    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    /// @notice Mints a new Uniswap V3 liquidity position.
    /// @param params Mint parameters.
    /// @return tokenId The ID of the newly minted position NFT.
    /// @return liquidity The amount of liquidity added.
    /// @return amount0 The amount of token0 used to mint the position.
    /// @return amount1 The amount of token1 used to mint the position.
    function mint(MintParams calldata params)
        external
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    /// @notice Increases liquidity for an existing Uniswap V3 position.
    /// @param params Increase liquidity parameters.
    /// @return liquidity The amount of new liquidity added.
    /// @return amount0 The amount of token0 spent.
    /// @return amount1 The amount of token1 spent.
    function increaseLiquidity(IncreaseLiquidityParams calldata params)
        external
        returns (uint128 liquidity, uint256 amount0, uint256 amount1);

    /// @notice Decreases liquidity from an existing Uniswap V3 position.
    /// @param params Decrease liquidity parameters.
    /// @return amount0 The amount of token0 returned.
    /// @return amount1 The amount of token1 returned.
    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        returns (uint256 amount0, uint256 amount1);

    /// @notice Collects accrued swap fees from a Uniswap V3 position.
    /// @param params Fee collection parameters.
    /// @return amount0 The amount of token0 collected.
    /// @return amount1 The amount of token1 collected.
    function collect(CollectParams calldata params)
        external
        returns (uint256 amount0, uint256 amount1);

    /// @notice Burns the NFT representing a Uniswap V3 position.
    /// @param tokenId ID of the position NFT to burn.
    function burn(uint256 tokenId) external;

    /// @notice Returns detailed information about a Uniswap V3 position.
    /// @param tokenId ID of the position NFT.
    /// @return nonce Incrementing counter used to invalidate permits.
    /// @return operator Address approved for managing the position.
    /// @return token0 Address of token0 for the pool.
    /// @return token1 Address of token1 for the pool.
    /// @return fee Fee tier of the pool.
    /// @return tickLower Lower tick of the position range.
    /// @return tickUpper Upper tick of the position range.
    /// @return liquidity Amount of liquidity in the position.
    /// @return feeGrowthInside0 Fee growth inside token0 range.
    /// @return feeGrowthInside1 Fee growth inside token1 range.
    /// @return tokensOwed0 Accumulated but uncollected fees in token0.
    /// @return tokensOwed1 Accumulated but uncollected fees in token1.
    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0,
            uint256 feeGrowthInside1,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
}
