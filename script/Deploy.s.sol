// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/ERC20Token.sol";
import "../src/AMM.sol";
import "../src/LendingPool.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        ERC20Token tokenA = new ERC20Token("TokenA", "TKA", 1_000_000 ether);
        ERC20Token tokenB = new ERC20Token("TokenB", "TKB", 1_000_000 ether);
        AMM ammContract = new AMM(address(tokenA), address(tokenB));

        ERC20Token collateral = new ERC20Token("Collateral", "COL", 1_000_000 ether);
        ERC20Token borrowToken = new ERC20Token("BorrowToken", "BRW", 1_000_000 ether);
        LendingPool lendingPool = new LendingPool(address(collateral), address(borrowToken));

        console.log("TokenA:", address(tokenA));
        console.log("TokenB:", address(tokenB));
        console.log("AMM:", address(ammContract));
        console.log("Collateral:", address(collateral));
        console.log("BorrowToken:", address(borrowToken));
        console.log("LendingPool:", address(lendingPool));

        vm.stopBroadcast();
    }
}
