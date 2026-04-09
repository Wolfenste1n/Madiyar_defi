// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IERC20.sol";

contract LendingPool {
    IERC20 public collateralToken;
    IERC20 public borrowToken;

    uint256 public constant LTV = 75;
    uint256 public constant LIQUIDATION_THRESHOLD = 80;
    uint256 public constant INTEREST_RATE_PER_SECOND = 317097919; // ~1% APR in wei per second (1e18 base)
    uint256 public constant PRECISION = 1e18;
    uint256 public constant LIQUIDATION_BONUS = 5;

    struct Position {
        uint256 deposited;
        uint256 borrowed;
        uint256 lastInterestTime;
    }

    mapping(address => Position) public positions;

    uint256 public collateralPrice = 1e18;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event Liquidated(address indexed user, address indexed liquidator, uint256 debtRepaid, uint256 collateralSeized);

    constructor(address _collateralToken, address _borrowToken) {
        collateralToken = IERC20(_collateralToken);
        borrowToken = IERC20(_borrowToken);
    }

    function setCollateralPrice(uint256 price) external {
        collateralPrice = price;
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        collateralToken.transferFrom(msg.sender, address(this), amount);
        positions[msg.sender].deposited += amount;
        if (positions[msg.sender].lastInterestTime == 0) {
            positions[msg.sender].lastInterestTime = block.timestamp;
        }
        emit Deposited(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        _accrueInterest(msg.sender);

        uint256 maxBorrow = _maxBorrow(msg.sender);
        require(positions[msg.sender].borrowed + amount <= maxBorrow, "Exceeds LTV");

        positions[msg.sender].borrowed += amount;
        positions[msg.sender].lastInterestTime = block.timestamp;

        borrowToken.transfer(msg.sender, amount);
        emit Borrowed(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        _accrueInterest(msg.sender);

        uint256 debt = positions[msg.sender].borrowed;
        require(debt > 0, "No debt");

        uint256 repayAmount = amount > debt ? debt : amount;
        positions[msg.sender].borrowed -= repayAmount;
        positions[msg.sender].lastInterestTime = block.timestamp;

        borrowToken.transferFrom(msg.sender, address(this), repayAmount);
        emit Repaid(msg.sender, repayAmount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        _accrueInterest(msg.sender);

        require(positions[msg.sender].deposited >= amount, "Insufficient deposit");

        uint256 newDeposit = positions[msg.sender].deposited - amount;
        if (positions[msg.sender].borrowed > 0) {
            uint256 newCollateralValue = (newDeposit * collateralPrice) / PRECISION;
            uint256 minCollateral = (positions[msg.sender].borrowed * 100) / LTV;
            require(newCollateralValue >= minCollateral, "Health factor too low");
        }

        positions[msg.sender].deposited -= amount;
        collateralToken.transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function liquidate(address user) external {
        _accrueInterest(user);

        require(_healthFactor(user) < PRECISION, "Position is healthy");

        uint256 debt = positions[user].borrowed;
        require(debt > 0, "No debt to liquidate");

        uint256 collateralSeized = (debt * (100 + LIQUIDATION_BONUS)) / 100;
        if (collateralSeized > positions[user].deposited) {
            collateralSeized = positions[user].deposited;
        }

        positions[user].borrowed = 0;
        positions[user].deposited -= collateralSeized;

        borrowToken.transferFrom(msg.sender, address(this), debt);
        collateralToken.transfer(msg.sender, collateralSeized);

        emit Liquidated(user, msg.sender, debt, collateralSeized);
    }

    function healthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    function getAccruedDebt(address user) external view returns (uint256) {
        Position memory pos = positions[user];
        if (pos.borrowed == 0 || pos.lastInterestTime == 0) return pos.borrowed;
        uint256 elapsed = block.timestamp - pos.lastInterestTime;
        uint256 interest = (pos.borrowed * INTEREST_RATE_PER_SECOND * elapsed) / PRECISION;
        return pos.borrowed + interest;
    }

    function _accrueInterest(address user) internal {
        Position storage pos = positions[user];
        if (pos.borrowed == 0 || pos.lastInterestTime == 0) {
            pos.lastInterestTime = block.timestamp;
            return;
        }
        uint256 elapsed = block.timestamp - pos.lastInterestTime;
        uint256 interest = (pos.borrowed * INTEREST_RATE_PER_SECOND * elapsed) / PRECISION;
        pos.borrowed += interest;
        pos.lastInterestTime = block.timestamp;
    }

    function _maxBorrow(address user) internal view returns (uint256) {
        uint256 collateralValue = (positions[user].deposited * collateralPrice) / PRECISION;
        return (collateralValue * LTV) / 100;
    }

    function _healthFactor(address user) internal view returns (uint256) {
        if (positions[user].borrowed == 0) return type(uint256).max;
        uint256 collateralValue = (positions[user].deposited * collateralPrice) / PRECISION;
        uint256 liquidationValue = (collateralValue * LIQUIDATION_THRESHOLD) / 100;
        return (liquidationValue * PRECISION) / positions[user].borrowed;
    }
}
