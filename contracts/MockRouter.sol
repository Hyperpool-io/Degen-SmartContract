// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IRouter.sol";

contract MockRouter is IRouter {
    // price: tokenOut per tokenIn, 18 decimals
    mapping(address => mapping(address => uint256)) public price;

    function setPrice(address tokenIn, address tokenOut, uint256 price_) external {
        price[tokenIn][tokenOut] = price_;
    }

    function swapExactInput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        address to
    ) external override returns (uint256 amountOut) {
        require(price[tokenIn][tokenOut] > 0, "No price");
        amountOut = amountIn * price[tokenIn][tokenOut] / 1e18;
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(to, amountOut);
    }

    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view override returns (uint256 amountOut) {
        require(price[tokenIn][tokenOut] > 0, "No price");
        amountOut = amountIn * price[tokenIn][tokenOut] / 1e18;
    }
}