// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SimpleDEX
 * @notice A simple Automated Market Maker (AMM) with 2 independent pools
 * @dev Uses the constant product formula: x * y = k
 * 
 * KEY CONCEPT: We have TWO separate pools to create price differences!
 * - Pool 1 might have: 10,000 USDT + 10,000 USDC (price = 1.00)
 * - Pool 2 might have: 10,000 USDT + 10,500 USDC (price = 1.05)
 * - This 5% difference is our arbitrage opportunity!
 */
contract SimpleDEX is Ownable {
    
    /**
     * @dev Pool structure stores all data for one liquidity pool
     * 
     * Example:
     * token0 = USDT address
     * token1 = USDC address
     * reserve0 = 10,000 * 10^6 (10k USDT with 6 decimals)
     * reserve1 = 10,000 * 10^6 (10k USDC with 6 decimals)
     * k = 10,000 * 10,000 = 100,000,000 (the constant!)
     */
    struct Pool {
        address token0;      // First token address (e.g., USDT)
        address token1;      // Second token address (e.g., USDC)
        uint256 reserve0;    // Amount of token0 in pool
        uint256 reserve1;    // Amount of token1 in pool
        uint256 k;           // Constant product (reserve0 * reserve1)
    }
    
    // Our two independent pools
    Pool public pool1;
    Pool public pool2;
    
    // Events to track what happens
    event PoolInitialized(uint256 poolId, address token0, address token1, uint256 amount0, uint256 amount1);
    event Swap(uint256 poolId, address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);
    event PriceUpdate(uint256 poolId, uint256 price);
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @notice Initialize Pool 1 with liquidity
     * @dev This sets up the first pool with initial token reserves
     * 
     * Example call:
     * initializePool1(USDT_ADDRESS, USDC_ADDRESS, 10000 * 10^6, 10000 * 10^6)
     * This creates a pool with 10k USDT and 10k USDC (1:1 ratio)
     */
    function initializePool1(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) external onlyOwner {
        require(pool1.k == 0, "Pool 1 already initialized");
        require(amount0 > 0 && amount1 > 0, "Amounts must be > 0");
        
        // Transfer tokens from owner to this contract
        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);
        
        // Set up the pool
        pool1 = Pool({
            token0: token0,
            token1: token1,
            reserve0: amount0,
            reserve1: amount1,
            k: amount0 * amount1  // This is the constant!
        });
        
        emit PoolInitialized(1, token0, token1, amount0, amount1);
        emit PriceUpdate(1, (amount1 * 1e18) / amount0);
    }
    
    /**
     * @notice Initialize Pool 2 with liquidity
     * @dev Same as Pool 1, but typically with a DIFFERENT ratio to create arbitrage opportunity
     * 
     * Example call:
     * initializePool2(USDT_ADDRESS, USDC_ADDRESS, 10000 * 10^6, 10500 * 10^6)
     * This creates a pool with 10k USDT and 10.5k USDC (1:1.05 ratio)
     * Now we have a 5% price difference between pools!
     */
    function initializePool2(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) external onlyOwner {
        require(pool2.k == 0, "Pool 2 already initialized");
        require(amount0 > 0 && amount1 > 0, "Amounts must be > 0");
        
        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);
        
        pool2 = Pool({
            token0: token0,
            token1: token1,
            reserve0: amount0,
            reserve1: amount1,
            k: amount0 * amount1
        });
        
        emit PoolInitialized(2, token0, token1, amount0, amount1);
        emit PriceUpdate(2, (amount1 * 1e18) / amount0);
    }
    
    /**
     * @notice Swap tokens on Pool 1
     * @param tokenIn Which token you're selling
     * @param amountIn How much you're selling
     * @return amountOut How much you receive
     */
    function swapPool1(address tokenIn, uint256 amountIn) external returns (uint256 amountOut) {
        return _swap(1, tokenIn, amountIn);
    }
    
    /**
     * @notice Swap tokens on Pool 2
     */
    function swapPool2(address tokenIn, uint256 amountIn) external returns (uint256 amountOut) {
        return _swap(2, tokenIn, amountIn);
    }
    
    /**
     * @notice Internal swap logic - THE CORE OF THE AMM!
     * @dev Uses constant product formula with 0.3% fee
     * 
     * HOW IT WORKS:
     * 1. User sends tokenIn to pool
     * 2. We apply 0.3% fee (997/1000)
     * 3. Calculate tokenOut using: x * y = k
     * 4. Send tokenOut to user
     * 
     * MATH EXAMPLE:
     * Pool has: 10,000 USDT and 10,000 USDC, k = 100,000,000
     * User swaps 100 USDT:
     *   - After fee: 100 * 0.997 = 99.7 USDT added
     *   - New reserve0: 10,099.7
     *   - k / 10,099.7 = 9,901.28 (new reserve1)
     *   - User gets: 10,000 - 9,901.28 = 98.72 USDC
     */
    function _swap(uint256 poolId, address tokenIn, uint256 amountIn) internal returns (uint256 amountOut) {
        Pool storage pool = poolId == 1 ? pool1 : pool2;
        
        require(pool.k > 0, "Pool not initialized");
        require(tokenIn == pool.token0 || tokenIn == pool.token1, "Invalid token");
        require(amountIn > 0, "Amount must be > 0");
        
        // Determine swap direction
        bool is0to1 = tokenIn == pool.token0;
        
        // Transfer tokenIn from user to contract
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        
        // Apply 0.3% fee (multiply by 997/1000)
        uint256 amountInWithFee = amountIn * 997 / 1000;
        
        // Calculate amountOut using constant product formula
        if (is0to1) {
            // Selling token0 for token1
            // Formula: (reserve0 + amountIn) * (reserve1 - amountOut) = k
            // Solve for amountOut: amountOut = reserve1 - (k / (reserve0 + amountIn))
            uint256 newReserve0 = pool.reserve0 + amountInWithFee;
            uint256 newReserve1 = pool.k / newReserve0;
            amountOut = pool.reserve1 - newReserve1;
            
            // Update reserves
            pool.reserve0 = newReserve0;
            pool.reserve1 = newReserve1;
            
            // Transfer tokenOut to user
            IERC20(pool.token1).transfer(msg.sender, amountOut);
        } else {
            // Selling token1 for token0
            uint256 newReserve1 = pool.reserve1 + amountInWithFee;
            uint256 newReserve0 = pool.k / newReserve1;
            amountOut = pool.reserve0 - newReserve0;
            
            pool.reserve1 = newReserve1;
            pool.reserve0 = newReserve0;
            
            IERC20(pool.token0).transfer(msg.sender, amountOut);
        }
        
        emit Swap(poolId, msg.sender, tokenIn, amountIn, amountOut);
        emit PriceUpdate(poolId, (pool.reserve1 * 1e18) / pool.reserve0);
    }
    
    /**
     * @notice Get price in Pool 1 (how much token1 for 1 token0)
     * @return price Price scaled by 1e18
     * 
     * Example: If pool has 10k USDT and 10.5k USDC
     * Price = (10,500 * 1e18) / 10,000 = 1.05 * 1e18
     * This means 1 USDT = 1.05 USDC
     */
    function getPrice1() external view returns (uint256) {
        require(pool1.k > 0, "Pool 1 not initialized");
        return (pool1.reserve1 * 1e18) / pool1.reserve0;
    }
    
    /**
     * @notice Get price in Pool 2
     */
    function getPrice2() external view returns (uint256) {
        require(pool2.k > 0, "Pool 2 not initialized");
        return (pool2.reserve1 * 1e18) / pool2.reserve0;
    }
    
    /**
     * @notice Calculate price spread between pools (in basis points)
     * @return spread Spread in basis points (1% = 100 bp, 5% = 500 bp)
     * 
     * Example:
     * Pool 1 price: 1.00
     * Pool 2 price: 1.05
     * Spread: ((1.05 - 1.00) / 1.00) * 10000 = 500 bp = 5%
     */
    function getPriceSpread() external view returns (uint256) {
        uint256 price1 = (pool1.reserve1 * 1e18) / pool1.reserve0;
        uint256 price2 = (pool2.reserve1 * 1e18) / pool2.reserve0;
        
        if (price1 > price2) {
            return ((price1 - price2) * 10000) / price2;
        } else {
            return ((price2 - price1) * 10000) / price1;
        }
    }
    
    /**
     * @notice Estimate output for a swap WITHOUT executing it
     * @dev Useful for simulating trades before executing
     * 
     * This is what our arbitrage bot will use to check if a trade is profitable!
     */
    function getAmountOut(uint256 poolId, address tokenIn, uint256 amountIn) 
        external view returns (uint256 amountOut) 
    {
        Pool memory pool = poolId == 1 ? pool1 : pool2;
        require(pool.k > 0, "Pool not initialized");
        
        bool is0to1 = tokenIn == pool.token0;
        uint256 amountInWithFee = amountIn * 997 / 1000;
        
        if (is0to1) {
            uint256 newReserve0 = pool.reserve0 + amountInWithFee;
            uint256 newReserve1 = pool.k / newReserve0;
            amountOut = pool.reserve1 - newReserve1;
        } else {
            uint256 newReserve1 = pool.reserve1 + amountInWithFee;
            uint256 newReserve0 = pool.k / newReserve1;
            amountOut = pool.reserve0 - newReserve0;
        }
    }
    
    /**
     * @notice Get pool reserves for inspection
     */
    function getPool1Reserves() external view returns (uint256 reserve0, uint256 reserve1) {
        return (pool1.reserve0, pool1.reserve1);
    }
    
    function getPool2Reserves() external view returns (uint256 reserve0, uint256 reserve1) {
        return (pool2.reserve0, pool2.reserve1);
    }
}
