// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./WalletLogic.sol";
import "./IUniV3LiquidityProtocol.sol";
import "./IRouter.sol";

abstract contract ReentrancyGuard is Initializable {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;
    function __ReentrancyGuard_init() internal onlyInitializing {
        _status = _NOT_ENTERED;
    }
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
    modifier isHuman() {
        require(tx.origin == msg.sender, "sorry humans only");
        _;
    }
}

contract AggregatorManager is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuard
{
    address public logicImplementation;
    address public usdc;
    address public univ3NFTManager;
    address public router;

    bool public active;
    struct UserWalletInfo {
        address proxy;
        uint256 tokenId;
        address token0;
        address token1;
        uint256 initialDeposit;
    }
    mapping(address => UserWalletInfo[]) public userWallets;
    mapping(address => bool) public walletExists;

    event Deposit(
        address indexed user,
        address mappingWallet,
        uint256 initialDeposit,
        uint256 tokenId
    );
    event Withdraw(
        address indexed user,
        address mappingWallet,
        uint256 amount0,
        uint256 amount1
    );

    function initialize(
        address _usdc,
        address _logicImplementation,
        address _univ3NFTManager,
        address _router
    ) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        logicImplementation = _logicImplementation;
        usdc = _usdc;
        univ3NFTManager = _univ3NFTManager;
        router = _router;
        active = true;
    }
    receive() external payable {}

    modifier whenActive() {
        require(active == true, "Inactive");
        _;
    }

    function deposit(
        uint256 amount,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper
    ) external isHuman nonReentrant whenActive {
        require(token0 == usdc, "token0 must be USDC.e");
        IERC20(usdc).transferFrom(msg.sender, address(this), amount);

        // Get ratio from router (token0 -> token1)
        // uint256 amount1 = IRouter(router).getAmountOut(token0, token1, amount);
        // uint256 amount0 = amount/(1+amount1 * 1e6 / 1e18*amount); // adjust for decimals

        // Swap half USDC.e to token1
        uint256 swapAmount = amount / 2;
        IERC20(usdc).approve(router, swapAmount);
        uint256 token1Received = IRouter(router).swapExactInput(
            token0,
            token1,
            swapAmount,
            address(this)
        );

        // Prepare mapping wallet
        address mappingWallet = Clones.clone(logicImplementation);
        WalletLogic(mappingWallet).initialize(address(this), address(this));

        // Transfer tokens to mapping wallet
        IERC20(token0).approve(mappingWallet, amount - swapAmount);
        IERC20(token0).transfer(mappingWallet, amount - swapAmount);
        IERC20(token1).approve(mappingWallet, token1Received);
        IERC20(token1).transfer(mappingWallet, token1Received);

        IUniV3LiquidityProtocol.MintParams
            memory params = IUniV3LiquidityProtocol.MintParams(
                token0,
                token1,
                fee,
                tickLower,
                tickUpper,
                amount - swapAmount,
                token1Received,
                0,
                0,
                mappingWallet,
                block.timestamp + 10 minutes
            );
        (uint256 tokenId, , ) = WalletLogic(mappingWallet).supplyToProtocol(
            univ3NFTManager,
            params
        );

        userWallets[msg.sender].push(
            UserWalletInfo(mappingWallet, tokenId, token0, token1, amount)
        );
        walletExists[mappingWallet] = true;

        emit Deposit(msg.sender, mappingWallet, amount, tokenId);
    }

    function getUserWallets(
        address user
    ) external view returns (UserWalletInfo[] memory) {
        return userWallets[user];
    }

    function withdraw(
        address user,
        uint256 walletId
    ) external isHuman nonReentrant whenActive {
        require(user == msg.sender || msg.sender == owner(), "NOT_ALLOWED");
        UserWalletInfo storage info = userWallets[user][walletId];
        WalletLogic logic = WalletLogic(info.proxy);

        (uint256 amt0, uint256 amt1) = logic.withdrawFromProtocol(
            univ3NFTManager,
            type(uint128).max,
            address(this)
        );
        // Swap token1 to USDC.e
        IERC20(info.token1).approve(router, amt1);
        uint256 usdcReceived = IRouter(router).swapExactInput(
            info.token1,
            usdc,
            amt1,
            address(this)
        );
        IERC20(info.token0).transfer(user, amt0 + usdcReceived);

        emit Withdraw(user, info.proxy, amt0, amt1);
    }

    // OnlyOwner, restake: Withdraw -> Mint new LP in new protocol
    function restake(
        address user,
        uint256 walletId,
        address newToken1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper
    ) external onlyOwner {
        UserWalletInfo storage info = userWallets[user][walletId];
        WalletLogic logic = WalletLogic(info.proxy);

        // Remove all liquidity to AggregatorManager
        (uint256 amt0, uint256 amt1) = logic.withdrawFromProtocol(
            univ3NFTManager,
            type(uint128).max, // withdraw all
            address(this)
        );

        // Swap token1 to USDC.e
        IERC20(info.token1).approve(router, amt1);
        uint256 usdcReceived = IRouter(router).swapExactInput(
            info.token1,
            usdc,
            amt1,
            address(this)
        );
        uint256 totalUsdc = amt0 + usdcReceived;

        // Get ratio from router (token0 -> token1)
        // uint256 amount1 = IRouter(router).getAmountOut(token0, token1, amount);
        // uint256 amount0 = amount/(1+amount1 * 1e6 / 1e18*amount); // adjust for decimals

        // Swap half USDC.e to newToken1
        uint256 swapAmount = totalUsdc / 2;
        IERC20(usdc).approve(router, swapAmount);
        uint256 newToken1Received = IRouter(router).swapExactInput(
            usdc,
            newToken1,
            swapAmount,
            address(this)
        );

        // Transfer tokens to mapping wallet
        IERC20(usdc).approve(info.proxy, totalUsdc - swapAmount);
        IERC20(usdc).transfer(info.proxy, totalUsdc - swapAmount);
        IERC20(newToken1).approve(info.proxy, newToken1Received);
        IERC20(newToken1).transfer(info.proxy, newToken1Received);

        IUniV3LiquidityProtocol.MintParams
            memory params = IUniV3LiquidityProtocol.MintParams(
                usdc,
                newToken1,
                fee,
                tickLower,
                tickUpper,
                totalUsdc - swapAmount,
                newToken1Received,
                0,
                0,
                info.proxy,
                block.timestamp + 10 minutes
            );
        (uint256 tokenId, , ) = WalletLogic(info.proxy).supplyToProtocol(
            univ3NFTManager,
            params
        );
        info.token1 = newToken1;
        info.tokenId = tokenId;
    }
}
