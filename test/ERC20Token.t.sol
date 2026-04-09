// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ERC20Token.sol";

contract ERC20TokenTest is Test {
    ERC20Token token;
    address alice = address(0x1);
    address bob = address(0x2);
    uint256 constant INITIAL_SUPPLY = 1_000_000 ether;

    function setUp() public {
        token = new ERC20Token("TestToken", "TTK", INITIAL_SUPPLY);
    }

    function test_InitialSupply() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(address(this)), INITIAL_SUPPLY);
    }

    function test_Name() public view {
        assertEq(token.name(), "TestToken");
        assertEq(token.symbol(), "TTK");
    }

    function test_Mint() public {
        token.mint(alice, 100 ether);
        assertEq(token.balanceOf(alice), 100 ether);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + 100 ether);
    }

    function test_Transfer() public {
        token.transfer(alice, 500 ether);
        assertEq(token.balanceOf(alice), 500 ether);
        assertEq(token.balanceOf(address(this)), INITIAL_SUPPLY - 500 ether);
    }

    function test_TransferRevertsInsufficientBalance() public {
        vm.expectRevert("Insufficient balance");
        token.transfer(alice, INITIAL_SUPPLY + 1);
    }

    function test_TransferRevertsZeroAddress() public {
        vm.expectRevert("Transfer to zero address");
        token.transfer(address(0), 100 ether);
    }

    function test_Approve() public {
        token.approve(alice, 200 ether);
        assertEq(token.allowance(address(this), alice), 200 ether);
    }

    function test_TransferFrom() public {
        token.approve(alice, 300 ether);
        vm.prank(alice);
        token.transferFrom(address(this), bob, 300 ether);
        assertEq(token.balanceOf(bob), 300 ether);
        assertEq(token.allowance(address(this), alice), 0);
    }

    function test_TransferFromRevertsInsufficientAllowance() public {
        token.approve(alice, 100 ether);
        vm.prank(alice);
        vm.expectRevert("Insufficient allowance");
        token.transferFrom(address(this), bob, 200 ether);
    }

    function test_Burn() public {
        token.burn(address(this), 100 ether);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - 100 ether);
    }

    function test_TransferFromRevertsZeroAddress() public {
        token.approve(alice, 100 ether);
        vm.prank(alice);
        vm.expectRevert("Transfer to zero address");
        token.transferFrom(address(this), address(0), 100 ether);
    }

    function test_ApproveOverwrite() public {
        token.approve(alice, 100 ether);
        token.approve(alice, 200 ether);
        assertEq(token.allowance(address(this), alice), 200 ether);
    }

    function testFuzz_Transfer(uint256 amount) public {
        amount = bound(amount, 0, INITIAL_SUPPLY);
        token.transfer(alice, amount);
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(address(this)), INITIAL_SUPPLY - amount);
    }

    function testFuzz_Mint(address to, uint256 amount) public {
    vm.assume(to != address(0));
    vm.assume(to != address(this));
    amount = bound(amount, 0, 1e30);
    uint256 supplyBefore = token.totalSupply();
    token.mint(to, amount);
    assertEq(token.totalSupply(), supplyBefore + amount);
    assertEq(token.balanceOf(to), amount);
    }
}

contract ERC20InvariantTest is Test {
    ERC20Token token;
    address alice = address(0x1);
    address bob = address(0x2);
    uint256 constant INITIAL_SUPPLY = 1_000_000 ether;

    function setUp() public {
        token = new ERC20Token("TestToken", "TTK", INITIAL_SUPPLY);
        token.transfer(alice, 100 ether);
        token.transfer(bob, 100 ether);
    }

    function invariant_TotalSupplyUnchangedByTransfers() public view {
        assertGe(token.totalSupply(), INITIAL_SUPPLY);
    }

    function invariant_NoAddressExceedsTotalSupply() public view {
        assert(token.balanceOf(address(this)) <= token.totalSupply());
        assert(token.balanceOf(alice) <= token.totalSupply());
        assert(token.balanceOf(bob) <= token.totalSupply());
    }
}
