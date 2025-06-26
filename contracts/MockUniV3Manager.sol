// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IUniV3LiquidityProtocol.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockUniV3NFTManager is IUniV3LiquidityProtocol {
    uint256 public nextTokenId = 1;

    struct Position {
        address owner;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    mapping(uint256 => Position) public positionsMap;

    // Price oracle: priceX96 = token1 per token0, 96 bits fixed point
    mapping(bytes32 => uint256) public poolPriceX96;

    function setPoolPrice(
        address token0,
        address token1,
        uint24 fee,
        uint256 priceX96
    ) external {
        poolPriceX96[keccak256(abi.encode(token0, token1, fee))] = priceX96;
    }

    function getPoolPrice(
        address token0,
        address token1,
        uint24 fee
    ) external view override returns (uint256 priceX96) {
        return poolPriceX96[keccak256(abi.encode(token0, token1, fee))];
    }

    function mint(
        MintParams calldata params
    )
        external
        payable
        override
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        // For mock: use all desired as provided
        IERC20(params.token0).transferFrom(
            msg.sender,
            address(this),
            params.amount0Desired
        );
        IERC20(params.token1).transferFrom(
            msg.sender,
            address(this),
            params.amount1Desired
        );

        tokenId = nextTokenId++;
        liquidity = uint128(params.amount0Desired + params.amount1Desired); // mock
        amount0 = params.amount0Desired;
        amount1 = params.amount1Desired;

        positionsMap[tokenId] = Position(
            params.recipient,
            params.token0,
            params.token1,
            params.fee,
            params.tickLower,
            params.tickUpper,
            liquidity,
            0,
            0
        );
    }

    function decreaseLiquidity(
        uint256 tokenId,
        uint128 liquidity,
        uint256,
        uint256,
        uint256
    ) external override returns (uint256 amount0, uint256 amount1) {
        Position storage pos = positionsMap[tokenId];
        require(msg.sender == pos.owner, "Not owner");
        if (pos.liquidity < liquidity) {
            liquidity = pos.liquidity;
        }
        // For mock: just return all
        amount0 = liquidity / 3;
        amount1 = liquidity*2 / 3;
        pos.liquidity -= liquidity;
        pos.tokensOwed0 += uint128(amount0);
        pos.tokensOwed1 += uint128(amount1);
    }

    function collect(
        uint256 tokenId,
        address recipient,
        uint128 amount0Max,
        uint128 amount1Max
    ) external override returns (uint256 amount0, uint256 amount1) {
        Position storage pos = positionsMap[tokenId];
        require(msg.sender == pos.owner, "Not owner");
        amount0 = pos.tokensOwed0 > amount0Max ? amount0Max : pos.tokensOwed0;
        amount1 = pos.tokensOwed1 > amount1Max ? amount1Max : pos.tokensOwed1;
        pos.tokensOwed0 -= uint128(amount0);
        pos.tokensOwed1 -= uint128(amount1);
        IERC20(pos.token0).transfer(recipient, amount0);
        IERC20(pos.token1).transfer(recipient, amount1);
    }

    function positions(
        uint256 tokenId
    )
        external
        view
        override
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256,
            uint256,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        Position storage pos = positionsMap[tokenId];
        nonce = 0;
        operator = pos.owner;
        token0 = pos.token0;
        token1 = pos.token1;
        fee = pos.fee;
        tickLower = pos.tickLower;
        tickUpper = pos.tickUpper;
        liquidity = pos.liquidity;
        tokensOwed0 = pos.tokensOwed0;
        tokensOwed1 = pos.tokensOwed1;
    }

    function mintPosition(
        address owner,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1,
        uint256 tokenId
    ) external {
        positionsMap[tokenId] = Position({
            owner: owner,
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidity: uint128(amount0 + amount1), // or however you want to define
            tokensOwed0: uint128(amount0),
            tokensOwed1: uint128(amount1)
        });
    }
}
