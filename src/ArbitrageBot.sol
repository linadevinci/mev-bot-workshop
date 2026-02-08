// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ISimpleDEX
 * @notice Interface to interact with our DEX
 */
interface ISimpleDEX {
    function swapPool1(address tokenIn, uint256 amountIn) external returns (uint256);
    function swapPool2(address tokenIn, uint256 amountIn) external returns (uint256);
    function getAmountOut(uint256 poolId, address tokenIn, uint256 amountIn) external view returns (uint256);
    function getPrice1() external view returns (uint256);
    function getPrice2() external view returns (uint256);
    function getPriceSpread() external view returns (uint256);
}

/**
 * @title ArbitrageBot
 * @notice MEV bot that exploits price differences between two DEX pools
 * @dev Executes atomic arbitrage: buy low on one pool, sell high on another
 * 
 * THE STRATEGY:
 * 1. Check prices on both pools
 * 2. If spread > minimum threshold (0.3%)
 * 3. Buy token on cheaper pool
 * 4. Sell same token on expensive pool
 * 5. Keep the profit!
 * 
 * Example:
 * Pool 1: 1 USDT = 1.00 USDC (cheaper)
 * Pool 2: 1 USDT = 1.05 USDC (expensive)
 * 
 * Action:
 * - Spend 100 USDC on Pool 1 → get ~100 USDT
 * - Sell 100 USDT on Pool 2 → get ~105 USDC
 * - Profit: 5 USDC! (minus fees)
 */
contract ArbitrageBot {
    
    // Immutable addresses (set once, never change)
    address public immutable dexAddress;
    address public immutable token0;  // USDT
    address public immutable token1;  // USDC
    address public owner;
    
    // Minimum spread to execute arbitrage (30 basis points = 0.3%)
    // This covers fees and ensures we make profit
    uint256 public constant MIN_SPREAD = 30;
    
    // Events to track our trades
    event ArbitrageExecuted(
        uint256 profit0,
        uint256 profit1,
        uint256 spreadBefore,
        uint256 spreadAfter,
        uint256 amountIn
    );
    
    event Deposit(address indexed token, uint256 amount);
    event Withdraw(address indexed token, uint256 amount);
    
    /**
     * @notice Deploy the bot with DEX and token addresses
     */
    constructor(address _dexAddress, address _token0, address _token1) {
        dexAddress = _dexAddress;
        token0 = _token0;
        token1 = _token1;
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    /**
     * @notice Execute arbitrage if profitable
     * @param amountIn How much to trade
     * @return profit Amount of profit made
     * 
     * THE ARBITRAGE LOGIC:
     * 1. Check price spread between pools
     * 2. If spread < MIN_SPREAD, revert (not profitable)
     * 3. Determine which pool is cheaper
     * 4. Execute: buy on cheap pool, sell on expensive pool
     * 5. Emit event with profit details
     */
    function executeArbitrage(uint256 amountIn) external onlyOwner returns (uint256 profit) {
        ISimpleDEX dex = ISimpleDEX(dexAddress);
        
        // Step 1: Check if opportunity exists
        uint256 spreadBefore = dex.getPriceSpread();
        require(spreadBefore > MIN_SPREAD, "Spread too low, not profitable");
        
        // Step 2: Get current prices
        uint256 price1 = dex.getPrice1();
        uint256 price2 = dex.getPrice2();
        
        // Step 3: Record balances before
        uint256 balance0Before = IERC20(token0).balanceOf(address(this));
        uint256 balance1Before = IERC20(token1).balanceOf(address(this));
        
        // Step 4: Execute arbitrage based on which pool is cheaper
        if (price1 < price2) {
            // Pool 1 is cheaper: buy token0 there, sell on pool 2
            profit = _arbitrage0to1(dex, amountIn);
        } else {
            // Pool 2 is cheaper: buy token0 there, sell on pool 1
            profit = _arbitrage1to0(dex, amountIn);
        }
        
        // Step 5: Calculate actual profit
        uint256 balance0After = IERC20(token0).balanceOf(address(this));
        uint256 balance1After = IERC20(token1).balanceOf(address(this));
        
        uint256 profit0 = balance0After > balance0Before ? balance0After - balance0Before : 0;
        uint256 profit1 = balance1After > balance1Before ? balance1After - balance1Before : 0;
        
        // Must have made profit!
        require(profit0 > 0 || profit1 > 0, "No profit made");
        
        // Step 6: Record final state
        uint256 spreadAfter = dex.getPriceSpread();
        
        emit ArbitrageExecuted(profit0, profit1, spreadBefore, spreadAfter, amountIn);
        
        return profit;
    }
    
    /**
     * @notice Arbitrage when Pool 1 is cheaper
     * @dev Buy token0 on pool1 (cheap), sell on pool2 (expensive)
     * 
     * Example:
     * Pool 1: 1 USDT = 1.00 USDC (cheap!)
     * Pool 2: 1 USDT = 1.05 USDC (expensive!)
     * 
     * Strategy:
     * 1. Spend 100 USDC on Pool 1 → get ~100 USDT
     * 2. Sell 100 USDT on Pool 2 → get ~105 USDC
     * 3. Profit: 5 USDC (minus fees ~0.6, net ~4.4 USDC)
     */
    function _arbitrage0to1(ISimpleDEX dex, uint256 amount1) internal returns (uint256) {
        // Step 1: Buy token0 on pool1 (cheaper) with token1
        IERC20(token1).approve(dexAddress, amount1);
        uint256 amount0 = dex.swapPool1(token1, amount1);
        
        // Step 2: Sell token0 on pool2 (more expensive) for token1
        IERC20(token0).approve(dexAddress, amount0);
        uint256 amount1Out = dex.swapPool2(token0, amount0);
        
        // Step 3: Verify we made profit
        require(amount1Out > amount1, "Arbitrage failed - no profit");
        
        return amount1Out - amount1;
    }
    
    /**
     * @notice Arbitrage when Pool 2 is cheaper
     * @dev Buy token0 on pool2 (cheap), sell on pool1 (expensive)
     */
    function _arbitrage1to0(ISimpleDEX dex, uint256 amount1) internal returns (uint256) {
        // Step 1: Buy token0 on pool2 (cheaper) with token1
        IERC20(token1).approve(dexAddress, amount1);
        uint256 amount0 = dex.swapPool2(token1, amount1);
        
        // Step 2: Sell token0 on pool1 (more expensive) for token1
        IERC20(token0).approve(dexAddress, amount0);
        uint256 amount1Out = dex.swapPool1(token0, amount0);
        
        // Step 3: Verify we made profit
        require(amount1Out > amount1, "Arbitrage failed - no profit");
        
        return amount1Out - amount1;
    }
    
    /**
     * @notice Simulate arbitrage without executing
     * @dev VERY IMPORTANT: Check profitability before spending gas!
     * 
     * This function lets you:
     * 1. Test different amounts to find optimal trade size
     * 2. Verify profit before executing
     * 3. Avoid failed transactions
     */
    function simulateArbitrage(uint256 amountIn) 
        external 
        view 
        returns (bool profitable, uint256 estimatedProfit) 
    {
        ISimpleDEX dex = ISimpleDEX(dexAddress);
        
        // Check if spread is sufficient
        uint256 spread = dex.getPriceSpread();
        if (spread <= MIN_SPREAD) {
            return (false, 0);
        }
        
        // Get prices
        uint256 price1 = dex.getPrice1();
        uint256 price2 = dex.getPrice2();
        
        // Simulate the trades
        if (price1 < price2) {
            // Simulate: token1 → token0 (pool1) → token1 (pool2)
            uint256 amount0 = dex.getAmountOut(1, token1, amountIn);
            uint256 amount1Out = dex.getAmountOut(2, token0, amount0);
            
            if (amount1Out > amountIn) {
                return (true, amount1Out - amountIn);
            }
        } else {
            // Simulate: token1 → token0 (pool2) → token1 (pool1)
            uint256 amount0 = dex.getAmountOut(2, token1, amountIn);
            uint256 amount1Out = dex.getAmountOut(1, token0, amount0);
            
            if (amount1Out > amountIn) {
                return (true, amount1Out - amountIn);
            }
        }
        
        return (false, 0);
    }
    
    /**
     * @notice Find optimal trade size
     * @dev Try different amounts to maximize profit
     * @param minAmount Minimum trade size to try
     * @param maxAmount Maximum trade size to try
     * @param steps How many amounts to test
     * @return optimalAmount Best trade size
     * @return maxProfit Expected profit at optimal size
     * 
     * NOTE: This is expensive to call (lots of computation)
     * Better to call off-chain or use binary search
     */
    function findOptimalAmount(uint256 minAmount, uint256 maxAmount, uint256 steps)
        external
        view
        returns (uint256 optimalAmount, uint256 maxProfit)
    {
        require(steps > 0 && steps <= 100, "Steps must be 1-100");
        require(maxAmount > minAmount, "Max must be > min");
        
        uint256 stepSize = (maxAmount - minAmount) / steps;
        
        for (uint256 i = 0; i <= steps; i++) {
            uint256 testAmount = minAmount + (i * stepSize);
            (bool profitable, uint256 profit) = this.simulateArbitrage(testAmount);
            
            if (profitable && profit > maxProfit) {
                maxProfit = profit;
                optimalAmount = testAmount;
            }
        }
    }
    
    /**
     * @notice Deposit tokens into the bot
     */
    function deposit(address token, uint256 amount) external onlyOwner {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        emit Deposit(token, amount);
    }
    
    /**
     * @notice Withdraw tokens from the bot
     */
    function withdraw(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No balance to withdraw");
        
        IERC20(token).transfer(owner, balance);
        emit Withdraw(token, balance);
    }
    
    /**
     * @notice View current balances
     */
    function getBalances() external view returns (uint256 balance0, uint256 balance1) {
        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));
    }
    
    /**
     * @notice Check if arbitrage opportunity exists
     * @return exists Is there an opportunity?
     * @return spread Current price spread
     * @return profitable Is MIN_SPREAD exceeded?
     */
    function checkOpportunity() external view returns (
        bool exists,
        uint256 spread,
        bool profitable
    ) {
        ISimpleDEX dex = ISimpleDEX(dexAddress);
        spread = dex.getPriceSpread();
        exists = spread > 0;
        profitable = spread > MIN_SPREAD;
    }
}
