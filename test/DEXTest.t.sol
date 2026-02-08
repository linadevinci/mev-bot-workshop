// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SimpleDEX.sol";
import "../src/MockUSDT.sol";
import "../src/MockUSDC.sol";

/**
 * @title DEXTest
 * @notice Tests for our SimpleDEX AMM - Step 2 of building the MEV bot
 */
contract DEXTest is Test {
    SimpleDEX public dex;
    MockUSDT public usdt;
    MockUSDC public usdc;
    
    address public owner = address(this);
    address public user = address(0x1);
    
    // Standard amounts for testing
    uint256 constant POOL_AMOUNT_USDT = 10_000 * 10**6;  // 10,000 USDT
    uint256 constant POOL_AMOUNT_USDC = 10_000 * 10**6;  // 10,000 USDC
    uint256 constant SWAP_AMOUNT = 100 * 10**6;          // 100 tokens
    
    function setUp() public {
        // Deploy contracts
        dex = new SimpleDEX();
        usdt = new MockUSDT();
        usdc = new MockUSDC();
        
        // Approve DEX to spend our tokens
        usdt.approve(address(dex), type(uint256).max);
        usdc.approve(address(dex), type(uint256).max);
        
        // Give user some tokens
        usdt.transfer(user, 1000 * 10**6);
        usdc.transfer(user, 1000 * 10**6);
    }
    
    /**
     * TEST 1: Pool Initialization
     * Verify pools can be set up correctly
     */
    function test_InitializePool1() public {
        // Initialize pool with 1:1 ratio
        dex.initializePool1(address(usdt), address(usdc), POOL_AMOUNT_USDT, POOL_AMOUNT_USDC);
        
        // Check reserves
        (uint256 reserve0, uint256 reserve1) = dex.getPool1Reserves();
        assertEq(reserve0, POOL_AMOUNT_USDT);
        assertEq(reserve1, POOL_AMOUNT_USDC);
        
        // Check price (should be 1.0 with 18 decimals = 1e18)
        uint256 price = dex.getPrice1();
        assertEq(price, 1e18);  // 1 USDT = 1 USDC
    }
    
    function test_InitializePool2() public {
        // Initialize pool with 1:1.05 ratio (5% more expensive)
        uint256 pool2USDC = 10_500 * 10**6;  // 10,500 USDC
        dex.initializePool2(address(usdt), address(usdc), POOL_AMOUNT_USDT, pool2USDC);
        
        (uint256 reserve0, uint256 reserve1) = dex.getPool2Reserves();
        assertEq(reserve0, POOL_AMOUNT_USDT);
        assertEq(reserve1, pool2USDC);
        
        // Price should be 1.05 (1.05 * 1e18)
        uint256 price = dex.getPrice2();
        assertEq(price, 1.05e18);  // 1 USDT = 1.05 USDC
    }
    
    function test_RevertWhen_InitializingTwice() public {
        dex.initializePool1(address(usdt), address(usdc), POOL_AMOUNT_USDT, POOL_AMOUNT_USDC);
        
        vm.expectRevert("Pool 1 already initialized");
        dex.initializePool1(address(usdt), address(usdc), POOL_AMOUNT_USDT, POOL_AMOUNT_USDC);
    }
    
    /**
     * TEST 2: Basic Swaps
     * Verify swap functionality works correctly
     */
    function test_SwapUSDTforUSDC() public {
        // Setup: Initialize pool
        dex.initializePool1(address(usdt), address(usdc), POOL_AMOUNT_USDT, POOL_AMOUNT_USDC);
        
        // User swaps 100 USDT for USDC
        vm.startPrank(user);
        usdt.approve(address(dex), SWAP_AMOUNT);
        
        uint256 usdtBefore = usdt.balanceOf(user);
        uint256 usdcBefore = usdc.balanceOf(user);
        
        uint256 amountOut = dex.swapPool1(address(usdt), SWAP_AMOUNT);
        
        uint256 usdtAfter = usdt.balanceOf(user);
        uint256 usdcAfter = usdc.balanceOf(user);
        vm.stopPrank();
        
        // Verify USDT was taken
        assertEq(usdtBefore - usdtAfter, SWAP_AMOUNT);
        
        // Verify USDC was received
        assertEq(usdcAfter - usdcBefore, amountOut);
        
        // Swapping 100 USDT from a 10,000 pool (1% of pool)
        // With 0.3% fee + price impact, we get ~98.7 USDC
        // Should get less than 100 USDC due to fee and slippage
        assertGt(amountOut, 98 * 10**6);  // More than 98
        assertLt(amountOut, 100 * 10**6); // Less than 100
    }
    
    function test_SwapUSDCforUSDT() public {
        dex.initializePool1(address(usdt), address(usdc), POOL_AMOUNT_USDT, POOL_AMOUNT_USDC);
        
        vm.startPrank(user);
        usdc.approve(address(dex), SWAP_AMOUNT);
        
        uint256 usdcBefore = usdc.balanceOf(user);
        uint256 usdtBefore = usdt.balanceOf(user);
        
        uint256 amountOut = dex.swapPool1(address(usdc), SWAP_AMOUNT);
        
        uint256 usdcAfter = usdc.balanceOf(user);
        uint256 usdtAfter = usdt.balanceOf(user);
        vm.stopPrank();
        
        // Verify swap happened
        assertEq(usdcBefore - usdcAfter, SWAP_AMOUNT);
        assertEq(usdtAfter - usdtBefore, amountOut);
    }
    
    /**
     * TEST 3: Price Calculations
     * Verify price oracle works correctly
     */
    function test_PriceCalculation() public {
        // Pool 1: 1:1 ratio
        dex.initializePool1(address(usdt), address(usdc), POOL_AMOUNT_USDT, POOL_AMOUNT_USDC);
        
        // Pool 2: 1:1.05 ratio (5% more expensive)
        uint256 pool2USDC = 10_500 * 10**6;
        dex.initializePool2(address(usdt), address(usdc), POOL_AMOUNT_USDT, pool2USDC);
        
        uint256 price1 = dex.getPrice1();
        uint256 price2 = dex.getPrice2();
        
        // Verify prices
        assertEq(price1, 1.00e18);
        assertEq(price2, 1.05e18);
        
        // Verify spread is 5% (500 basis points)
        uint256 spread = dex.getPriceSpread();
        assertEq(spread, 500);  // 5% = 500 bp
    }
    
    /**
     * TEST 4: Price Impact
     * Large swaps should affect the price
     */
    function test_PriceImpact() public {
        dex.initializePool1(address(usdt), address(usdc), POOL_AMOUNT_USDT, POOL_AMOUNT_USDC);
        
        uint256 priceBefore = dex.getPrice1();
        
        // Large swap: 1000 USDT (10% of pool!)
        uint256 largeSwap = 1000 * 10**6;
        usdt.approve(address(dex), largeSwap);
        dex.swapPool1(address(usdt), largeSwap);
        
        uint256 priceAfter = dex.getPrice1();
        
        // Price should have decreased (USDC became cheaper relative to USDT)
        assertLt(priceAfter, priceBefore);
    }
    
    /**
     * TEST 5: Fee vs Price Impact
     * Understand the difference between fees and slippage
     */
    function test_FeeVsPriceImpact() public {
        dex.initializePool1(address(usdt), address(usdc), POOL_AMOUNT_USDT, POOL_AMOUNT_USDC);
        
        // Small swap: 10 USDT (0.1% of pool)
        uint256 smallSwap = 10 * 10**6;
        usdt.approve(address(dex), smallSwap);
        uint256 smallOut = dex.swapPool1(address(usdt), smallSwap);
        
        // Small swaps have minimal price impact
        // Mostly just the 0.3% fee affects output
        // Expected: ~9.96 USDC (99.6% of input)
        assertGt(smallOut, 9.9 * 10**6);   // More than 9.9
        assertLt(smallOut, 10 * 10**6);    // Less than 10
        
        // Re-approve for pool2 initialization (approval was used by pool1)
        usdt.approve(address(dex), type(uint256).max);
        usdc.approve(address(dex), type(uint256).max);
        
        // Initialize pool2 for large swap test
        dex.initializePool2(address(usdt), address(usdc), POOL_AMOUNT_USDT, POOL_AMOUNT_USDC);
        
        // Large swap: 1000 USDT (10% of pool)  
        uint256 largeSwap = 1000 * 10**6;
        usdt.approve(address(dex), largeSwap);
        uint256 largeOut = dex.swapPool2(address(usdt), largeSwap);
        
        // Large swaps have BOTH fee AND significant price impact
        // Expected: ~906 USDC (90.6% of input)
        // The extra loss is from moving the price!
        assertGt(largeOut, 900 * 10**6);   // More than 900
        assertLt(largeOut, 920 * 10**6);   // Less than 920
    }
    
    /**
     * TEST 6: Fee Application
     * Verify 0.3% fee is applied
     */
    function test_FeeApplication() public {
        dex.initializePool1(address(usdt), address(usdc), POOL_AMOUNT_USDT, POOL_AMOUNT_USDC);
        
        // Swap 1000 USDT (10% of pool - significant price impact!)
        uint256 swapAmount = 1000 * 10**6;
        usdt.approve(address(dex), swapAmount);
        uint256 amountOut = dex.swapPool1(address(usdt), swapAmount);
        
        // With 1000 USDT input on a 10k pool:
        // - 0.3% fee reduces input to 997 USDT
        // - Price impact from 10% pool size is significant
        // - Expected output: ~906 USDC (not 997 due to slippage!)
        
        // Should get less than input amount due to fee + price impact
        assertLt(amountOut, swapAmount);
        
        // For 10% of pool swap, expect significant slippage
        // Should get roughly 90-92% of input
        assertGt(amountOut, 900 * 10**6);  // More than 900
        assertLt(amountOut, 920 * 10**6);  // Less than 920
    }
    
    /**
     * TEST 7: Estimate Swap Output
     * getAmountOut should match actual swap
     */
    function test_EstimateSwapOutput() public {
        dex.initializePool1(address(usdt), address(usdc), POOL_AMOUNT_USDT, POOL_AMOUNT_USDC);
        
        // Estimate output
        uint256 estimated = dex.getAmountOut(1, address(usdt), SWAP_AMOUNT);
        
        // Execute actual swap
        vm.startPrank(user);
        usdt.approve(address(dex), SWAP_AMOUNT);
        uint256 actual = dex.swapPool1(address(usdt), SWAP_AMOUNT);
        vm.stopPrank();
        
        // Should match exactly
        assertEq(estimated, actual);
    }
    
    /**
     * TEST 8: Multiple Swaps
     * Verify consecutive swaps work
     */
    function test_MultipleSwaps() public {
        dex.initializePool1(address(usdt), address(usdc), POOL_AMOUNT_USDT, POOL_AMOUNT_USDC);
        
        vm.startPrank(user);
        
        // Swap 1: USDT -> USDC
        usdt.approve(address(dex), SWAP_AMOUNT);
        uint256 usdcReceived = dex.swapPool1(address(usdt), SWAP_AMOUNT);
        
        // Swap 2: USDC -> USDT (swap back)
        usdc.approve(address(dex), usdcReceived);
        uint256 usdtReceived = dex.swapPool1(address(usdc), usdcReceived);
        
        vm.stopPrank();
        
        // Due to fees, should get back less than we started with
        assertLt(usdtReceived, SWAP_AMOUNT);
    }
    
    /**
     * TEST 9: Error Cases
     */
    function test_RevertWhen_SwapUninitializedPool() public {
        vm.expectRevert("Pool not initialized");
        dex.swapPool1(address(usdt), SWAP_AMOUNT);
    }
    
    function test_RevertWhen_SwapInvalidToken() public {
        dex.initializePool1(address(usdt), address(usdc), POOL_AMOUNT_USDT, POOL_AMOUNT_USDC);
        
        vm.expectRevert("Invalid token");
        dex.swapPool1(address(0x123), SWAP_AMOUNT);
    }
    
    function test_RevertWhen_SwapZeroAmount() public {
        dex.initializePool1(address(usdt), address(usdc), POOL_AMOUNT_USDT, POOL_AMOUNT_USDC);
        
        vm.expectRevert("Amount must be > 0");
        dex.swapPool1(address(usdt), 0);
    }
}
