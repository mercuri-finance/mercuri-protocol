// SPDX-License-Identifier: MIT
pragma solidity 0.8.32;

/// @title ISwapRouter02
/// @notice Minimal interface for Uniswap SwapRouter02
/// @dev
///  - Network-agnostic interface for Uniswap V3 SwapRouter02
///  - Intended to be used across multiple EVM chains (e.g. Ethereum, Base)
///  - Concrete router address MUST be supplied at deployment time
///  - Interface purposefully exposes only ExactInputSingle
///  - Caller is responsible for ensuring router compatibility on the target chain
interface ISwapRouter02 {
    /// @notice Parameters for a single-hop exact-input swap
    /// @dev
    ///  - `tokenIn` and `tokenOut` must be distinct ERC20 tokens
    ///  - `recipient` SHOULD be the calling contract in vault-controlled contexts
    ///  - `sqrtPriceLimitX96` can be set to 0 to disable price limits
    struct ExactInputSingleParams {
        /// @notice Input token address
        address tokenIn;
        /// @notice Output token address
        address tokenOut;
        /// @notice Pool fee tier (e.g. 500 = 0.05%)
        uint24 fee;
        /// @notice Recipient of the output tokens
        address recipient;
        /// @notice Amount of input tokens to swap
        uint256 amountIn;
        /// @notice Minimum acceptable output amount (slippage protection)
        uint256 amountOutMinimum;
        /// @notice Optional price limit encoded as sqrt(P) Q64.96
        /// @dev Set to 0 to disable price limit enforcement
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Executes a single-hop exact-input swap
    /// @dev
    ///  - Caller must approve `amountIn` of `tokenIn` prior to calling
    ///  - Reverts if `amountOutMinimum` is not met
    ///  - ETH may be received if router unwraps WETH
    /// @param params Swap execution parameters
    /// @return amountOut Amount of `tokenOut` received
    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);
}
