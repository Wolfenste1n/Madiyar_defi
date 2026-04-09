// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AMM.sol";
import "../src/ERC20Token.sol";
import "../src/LPToken.sol";

contract AMMTest is Test {
    AMM amm;
    ERC20Token tokenA;
    ERC20Token tokenB;
    address alice = address(0x1);
    address bob = address(0x2);

    uint256 constant INITIAL = 1_000_000 ether;

    function setUp() public {
        tokenA = new ERC20Token("TokenA", "TKA", INITIAL * 10);
        tokenB = new ERC20Token("TokenB", "TKB", INITIAL * 10);
        amm = new AMM(address(tokenA), address(tokenB));

        tokenA.transfer(alice, INITIAL);
        tokenB.transfer(alice, INITIAL);
        tokenA.transfer(bob, INITIAL);
        tokenB.transfer(bob, INITIAL);
    }

    function _approveAndAdd(address user, uint256 a, uint256 b) internal returns (uint256 lp) {
        vm.startPrank(user);
        tokenA.approve(address(amm), a);
        tokenB.approve(address(amm), b);
        lp = amm.addLiquidity(a, b);
        vm.stopPrank();
    }

    function test_AddLiquidityFirst() public {
        uint256 lp = _approveAndAdd(alice, 1000 ether, 1000 ether);
        assertGt(lp, 0);
        (uint256 rA, uint256 rB) = amm.getReserves();
        assertEq(rA, 1000 ether);
        assertEq(rB, 1000 ether);
    }

    function test_AddLiquiditySubsequent() public {
        _approveAndAdd(alice, 1000 ether, 1000 ether);
        uint256 lpBob = _approveAndAdd(bob, 500 ether, 500 ether);
        assertGt(lpBob, 0);
        (uint256 rA, uint256 rB) = amm.getReserves();
        assertEq(rA, 1500 ether);
        assertEq(rB, 1500 ether);
    }

    function test_RemoveLiquidityFull() public {
        uint256 lp = _approveAndAdd(alice, 1000 ether, 1000 ether);
        uint256 balABefore = tokenA.balanceOf(alice);
        uint256 balBBefore = tokenB.balanceOf(alice);
        vm.startPrank(alice);
        (uint256 outA, uint256 outB) = amm.removeLiquidity(lp);
        vm.stopPrank();
        assertGt(outA, 0);
        assertGt(outB, 0);
        assertEq(tokenA.balanceOf(alice), balABefore + outA);
        assertEq(tokenB.balanceOf(alice), balBBefore + outB);
    }

    function test_RemoveLiquidityPartial() public {
        uint256 lp = _approveAndAdd(alice, 1000 ether, 1000 ether);
        vm.prank(alice);
        (uint256 outA, uint256 outB) = amm.removeLiquidity(lp / 2);
        assertGt(outA, 0);
        assertGt(outB, 0);
        (uint256 rA, uint256 rB) = amm.getReserves();
        assertGt(rA, 0);
        assertGt(rB, 0);
    }

    function test_SwapAtoB() public {
        _approveAndAdd(alice, 10000 ether, 10000 ether);
        uint256 balBefore = tokenB.balanceOf(bob);
        vm.startPrank(bob);
        tokenA.approve(address(amm), 100 ether);
        uint256 out = amm.swap(address(tokenA), 100 ether, 0);
        vm.stopPrank();
        assertGt(out, 0);
        assertEq(tokenB.balanceOf(bob), balBefore + out);
    }

    function test_SwapBtoA() public {
        _approveAndAdd(alice, 10000 ether, 10000 ether);
        uint256 balBefore = tokenA.balanceOf(bob);
        vm.startPrank(bob);
        tokenB.approve(address(amm), 100 ether);
        uint256 out = amm.swap(address(tokenB), 100 ether, 0);
        vm.stopPrank();
        assertGt(out, 0);
        assertEq(tokenA.balanceOf(bob), balBefore + out);
    }

    function test_KIncreasesAfterSwap() public {
        _approveAndAdd(alice, 10000 ether, 10000 ether);
        (uint256 rA0, uint256 rB0) = amm.getReserves();
        uint256 kBefore = rA0 * rB0;
        vm.startPrank(bob);
        tokenA.approve(address(amm), 100 ether);
        amm.swap(address(tokenA), 100 ether, 0);
        vm.stopPrank();
        (uint256 rA1, uint256 rB1) = amm.getReserves();
        uint256 kAfter = rA1 * rB1;
        assertGe(kAfter, kBefore);
    }

    function test_SlippageProtectionReverts() public {
        _approveAndAdd(alice, 10000 ether, 10000 ether);
        vm.startPrank(bob);
        tokenA.approve(address(amm), 100 ether);
        vm.expectRevert("Slippage: insufficient output");
        amm.swap(address(tokenA), 100 ether, type(uint256).max);
        vm.stopPrank();
    }

    function test_SwapRevertsZeroAmount() public {
        _approveAndAdd(alice, 1000 ether, 1000 ether);
        vm.startPrank(bob);
        tokenA.approve(address(amm), 0);
        vm.expectRevert("Amount must be > 0");
        amm.swap(address(tokenA), 0, 0);
        vm.stopPrank();
    }

    function test_AddLiquidityRevertsZero() public {
        vm.startPrank(alice);
        tokenA.approve(address(amm), 0);
        tokenB.approve(address(amm), 0);
        vm.expectRevert("Amounts must be > 0");
        amm.addLiquidity(0, 0);
        vm.stopPrank();
    }

    function test_GetAmountOut() public view {
        uint256 out = amm.getAmountOut(1000 ether, 10000 ether, 10000 ether);
        assertGt(out, 0);
        assertLt(out, 1000 ether);
    }

    function test_LargeSwapHighPriceImpact() public {
        _approveAndAdd(alice, 10000 ether, 10000 ether);
        vm.startPrank(bob);
        tokenA.approve(address(amm), 5000 ether);
        uint256 out = amm.swap(address(tokenA), 5000 ether, 0);
        vm.stopPrank();
        assertLt(out, 5000 ether);
    }

    function test_SwapInvalidToken() public {
        _approveAndAdd(alice, 1000 ether, 1000 ether);
        vm.startPrank(bob);
        vm.expectRevert("Invalid token");
        amm.swap(address(0xdead), 100 ether, 0);
        vm.stopPrank();
    }

    function test_RemoveLiquidityRevertsZero() public {
        _approveAndAdd(alice, 1000 ether, 1000 ether);
        vm.prank(alice);
        vm.expectRevert("LP amount must be > 0");
        amm.removeLiquidity(0);
    }

    function testFuzz_Swap(uint256 amountIn) public {
        _approveAndAdd(alice, 100000 ether, 100000 ether);
        amountIn = bound(amountIn, 1 ether, 10000 ether);
        vm.startPrank(bob);
        tokenA.approve(address(amm), amountIn);
        uint256 out = amm.swap(address(tokenA), amountIn, 0);
        vm.stopPrank();
        assertGt(out, 0);
    }
}
