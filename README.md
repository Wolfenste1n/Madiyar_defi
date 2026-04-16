# Madiyar — DeFi Protocol Development (Assignment 2)

## Project Structure

```
Madiyar_defi/
├── src/
│   ├── ERC20Token.sol        # ERC-20 token (Task 1)
│   ├── LPToken.sol           # LP token for AMM
│   ├── AMM.sol               # Constant product AMM (Task 3)
│   └── LendingPool.sol       # Lending protocol (Task 5)
├── test/
│   ├── ERC20Token.t.sol      # Unit + fuzz + invariant tests (Task 1)
│   ├── Fork.t.sol            # Mainnet fork tests (Task 2)
│   ├── AMM.t.sol             # AMM test suite (Task 3)
│   └── LendingPool.t.sol     # Lending pool tests (Task 5)
├── script/
│   └── Deploy.s.sol          # Deployment script
├── .github/
│   └── workflows/
│       └── test.yml          # CI/CD pipeline (Task 6)
├── report.docx               # Written report (Tasks 1,2,4,5,6)
├── foundry.toml
└── remappings.txt
```

## Setup

### 1. Install Foundry
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. Install dependencies
```bash
forge install foundry-rs/forge-std
```

### 3. Compile
```bash
forge build
```

## Running Tests

### All tests (unit + fuzz + invariant)
```bash
forge test -vv
```

### Gas report
```bash
forge test --gas-report
```

### Coverage report
```bash
forge coverage --report summary
```

### Fork tests (requires RPC URL)
```bash
export MAINNET_RPC_URL=https://eth-mainnet.public.blastapi.io
forge test --match-path test/Fork.t.sol -vv
```

### Run only AMM tests
```bash
forge test --match-path test/AMM.t.sol -vv
```

### Run only Lending tests
```bash
forge test --match-path test/LendingPool.t.sol -vv
```

## Contracts Overview

### ERC20Token.sol
Standard ERC-20 with mint and burn. Used as TokenA, TokenB, Collateral, and BorrowToken.

### AMM.sol
Constant product AMM (x * y = k) with:
- 0.3% swap fee
- LP token minting/burning
- Slippage protection via minAmountOut

### LendingPool.sol
Simplified lending protocol with:
- 75% LTV
- 80% liquidation threshold
- 5% liquidation bonus
- Linear interest (~1% APR)

## Test Counts
| File | Tests |
|------|-------|
| ERC20Token.t.sol | 12 unit + 2 fuzz + 2 invariant |
| Fork.t.sol | 4 fork tests |
| AMM.t.sol | 15 unit + 1 fuzz |
| LendingPool.t.sol | 11 unit |




## 
cd Madiyar_defi
forge install foundry-rs/forge-std
forge test -vv
forge test --gas-report

## 
source /Users/valerysovetov/.zshenv
foundryup
forge --version
