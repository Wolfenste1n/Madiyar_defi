// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IUSDC {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface IUniswapV2Router {
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract ForkTest is Test {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    uint256 mainnetFork;
    string MAINNET_RPC = vm.envOr("MAINNET_RPC_URL", string("https://eth-mainnet.public.blastapi.io"));

    function setUp() public {
        mainnetFork = vm.createSelectFork(MAINNET_RPC);
    }

    function test_ForkUSDCTotalSupply() public view {
        IUSDC usdc = IUSDC(USDC);
        uint256 supply = usdc.totalSupply();
        assertGt(supply, 0, "USDC total supply should be > 0");
        assertEq(usdc.decimals(), 6, "USDC decimals should be 6");
        console.log("USDC total supply:", supply);
    }

    function test_ForkUSDCBalanceOf() public view {
        IUSDC usdc = IUSDC(USDC);
        uint256 balance = usdc.balanceOf(UNISWAP_V2_ROUTER);
        console.log("Uniswap router USDC balance:", balance);
    }

    function test_ForkRollFork() public {
        uint256 blockBefore = block.number;
        vm.rollFork(blockBefore - 10);
        assertEq(block.number, blockBefore - 10);
        vm.rollFork(blockBefore);
        assertEq(block.number, blockBefore);
    }

    function test_ForkUniswapGetAmountsOut() public view {
        IUniswapV2Router router = IUniswapV2Router(UNISWAP_V2_ROUTER);
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = DAI;
        uint256[] memory amounts = router.getAmountsOut(1 ether, path);
        assertGt(amounts[1], 0, "DAI output should be > 0");
        console.log("1 WETH => DAI:", amounts[1]);
    }
}
