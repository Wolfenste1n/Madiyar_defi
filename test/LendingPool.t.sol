// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LendingPool.sol";
import "../src/ERC20Token.sol";

contract LendingPoolTest is Test {
    LendingPool pool;
    ERC20Token collateral;
    ERC20Token borrow;
    address alice = address(0x1);
    address bob = address(0x2);
    address liquidator = address(0x3);

    uint256 constant INITIAL = 1_000_000 ether;

    function setUp() public {
        collateral = new ERC20Token("Collateral", "COL", INITIAL * 10);
        borrow = new ERC20Token("BorrowToken", "BRW", INITIAL * 10);
        pool = new LendingPool(address(collateral), address(borrow));

        borrow.transfer(address(pool), INITIAL * 5);

        collateral.transfer(alice, 10000 ether);
        collateral.transfer(liquidator, 1000 ether);
        borrow.transfer(alice, 10000 ether);
        borrow.transfer(liquidator, 10000 ether);
    }

    function test_Deposit() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 ether);
        pool.deposit(1000 ether);
        vm.stopPrank();
        (uint256 deposited,,) = pool.positions(alice);
        assertEq(deposited, 1000 ether);
    }

    function test_WithdrawAfterDeposit() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 ether);
        pool.deposit(1000 ether);
        pool.withdraw(500 ether);
        vm.stopPrank();
        (uint256 deposited,,) = pool.positions(alice);
        assertEq(deposited, 500 ether);
    }

    function test_BorrowWithinLTV() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 ether);
        pool.deposit(1000 ether);
        pool.borrow(700 ether);
        vm.stopPrank();
        (, uint256 borrowed,) = pool.positions(alice);
        assertEq(borrowed, 700 ether);
    }

    function test_BorrowExceedsLTVReverts() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 ether);
        pool.deposit(1000 ether);
        vm.expectRevert("Exceeds LTV");
        pool.borrow(800 ether);
        vm.stopPrank();
    }

    function test_RepayFull() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 ether);
        pool.deposit(1000 ether);
        pool.borrow(500 ether);
        borrow.approve(address(pool), 500 ether);
        pool.repay(500 ether);
        vm.stopPrank();
        (, uint256 borrowed,) = pool.positions(alice);
        assertEq(borrowed, 0);
    }

    function test_RepayPartial() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 ether);
        pool.deposit(1000 ether);
        pool.borrow(600 ether);
        borrow.approve(address(pool), 200 ether);
        pool.repay(200 ether);
        vm.stopPrank();
        (, uint256 borrowed,) = pool.positions(alice);
        assertLe(borrowed, 400 ether + 1e15);
    }

    function test_WithdrawWhileInDebtReverts() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 ether);
        pool.deposit(1000 ether);
        pool.borrow(700 ether);
        vm.expectRevert("Health factor too low");
        pool.withdraw(500 ether);
        vm.stopPrank();
    }

    function test_Liquidation() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 ether);
        pool.deposit(1000 ether);
        pool.borrow(700 ether);
        vm.stopPrank();

        pool.setCollateralPrice(0.5e18);

        vm.startPrank(liquidator);
        borrow.approve(address(pool), 700 ether);
        pool.liquidate(alice);
        vm.stopPrank();

        (, uint256 borrowed,) = pool.positions(alice);
        assertEq(borrowed, 0);
    }

    function test_InterestAccrual() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 ether);
        pool.deposit(1000 ether);
        pool.borrow(500 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 365 days);

        uint256 accrued = pool.getAccruedDebt(alice);
        assertGt(accrued, 500 ether);
    }

    function test_DepositRevertsZero() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 0);
        vm.expectRevert("Amount must be > 0");
        pool.deposit(0);
        vm.stopPrank();
    }

    function test_BorrowWithZeroCollateralReverts() public {
        vm.startPrank(bob);
        vm.expectRevert("Exceeds LTV");
        pool.borrow(100 ether);
        vm.stopPrank();
    }

    function test_LiquidateHealthyPositionReverts() public {
        vm.startPrank(alice);
        collateral.approve(address(pool), 1000 ether);
        pool.deposit(1000 ether);
        pool.borrow(500 ether);
        vm.stopPrank();

        vm.startPrank(liquidator);
        borrow.approve(address(pool), 500 ether);
        vm.expectRevert("Position is healthy");
        pool.liquidate(alice);
        vm.stopPrank();
    }
}
