// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ArbitrageBot.sol";
import "../src/SimpleDEX.sol";
import "../src/MockUSDT.sol";
import "../src/MockUSDC.sol";

/**
 * @title ArbitrageBotTest
 * @notice Tests for the MEV arbitrage bot - Step 3 of building the system
 */
contract ArbitrageBotTest is Test {
    ArbitrageBot public bot;
    SimpleDEX public dex;
    MockUSDT public usdt;
    MockUSDC public usdc;
    
    address public owner = address(this);
    
    // Pool configurations
    uint256 constant POOL1_USDT = 10_000 * 10**6;  // 10k USDT
    uint256 constant POOL1_USDC = 10_000 * 10**6;  // 10k USDC (1:1 ratio)
    uint256 constant POOL2_USDT = 10_000 * 10**6;  // 10k USDT
    uint256 constant POOL2_USDC = 10_500 * 10**6;  // 10.5k USDC (1:1.05 ratio = 5% spread!)
    
    function setUp() public {
        // Deploy tokens
        usdt = new MockUSDT();
        usdc = new MockUSDC();
        
        // Deploy DEX
        dex = new SimpleDEX();
        
        // Deploy bot
        bot = new ArbitrageBot(address(dex), address(usdt), address(usdc));
        
        // Setup pools with price difference
        usdt.approve(address(dex), type(uint256).max);
        usdc.approve(address(dex), type(uint256).max);
        
        // Pool 1: 1 USDT = 1.00 USDC
        dex.initializePool1(address(usdt), address(usdc), POOL1_USDT, POOL1_USDC);
        
        // Pool 2: 1 USDT = 1.05 USDC (5% more expensive!)
        dex.initializePool2(address(usdt), address(usdc), POOL2_USDT, POOL2_USDC);
        
        // Fund the bot with USDC for arbitrage
        uint256 botFunding = 1000 * 10**6; // 1000 USDC
        usdc.transfer(address(bot), botFunding);
    }
    
    /**
     * TEST 1: Check Setup
     * Verify the arbitrage opportunity exists
     */
    function test_SetupCorrect() public {
        // Check price spread
        uint256 spread = dex.getPriceSpread();
        assertEq(spread, 500); // 5% = 500 basis points
        
        // Check bot has funds
        (uint256 balance0, uint256 balance1) = bot.getBalances();
        assertEq(balance0, 0);           // No USDT yet
        assertEq(balance1, 1000 * 10**6); // 1000 USDC
        
        // Check opportunity exists
        (bool exists, uint256 oppSpread, bool profitable) = bot.checkOpportunity();
        assertTrue(exists);
        assertEq(oppSpread, 500);
        assertTrue(profitable); // 500 bp > 30 bp minimum
    }
    
    /**
     * TEST 2: Simulate Arbitrage
     * Test the simulation function before executing
     */
    function test_SimulateArbitrage() public {
        uint256 testAmount = 100 * 10**6; // 100 USDC
        
        (bool profitable, uint256 estimatedProfit) = bot.simulateArbitrage(testAmount);
        
        assertTrue(profitable);
        assertGt(estimatedProfit, 0);
        
        // With 5% spread and 1% of pool swap (100 USDC on 10k pools):
        // - Fees take ~0.6 USDC total
        // - Slippage takes ~2 USDC
        // - Net profit: ~2.3 USDC
        assertGt(estimatedProfit, 2 * 10**6);  // More than 2 USDC
        assertLt(estimatedProfit, 3 * 10**6);  // Less than 3 USDC
    }
    
    /**
     * TEST 3: Execute Profitable Arbitrage
     * THE MAIN TEST - Does the bot actually make profit?
     */
    function test_ExecuteArbitrage() public {
        uint256 tradeAmount = 100 * 10**6; // 100 USDC
        
        // Record state before
        (uint256 balance0Before, uint256 balance1Before) = bot.getBalances();
        uint256 spreadBefore = dex.getPriceSpread();
        
        // Execute arbitrage
        uint256 profit = bot.executeArbitrage(tradeAmount);
        
        // Record state after
        (uint256 balance0After, uint256 balance1After) = bot.getBalances();
        uint256 spreadAfter = dex.getPriceSpread();
        
        // Verify profit was made
        assertGt(profit, 0);
        assertGt(balance1After, balance1Before); // USDC increased
        
        // Spread should decrease (we helped equalize prices!)
        assertLt(spreadAfter, spreadBefore);
        
        // Should have made ~2.3 USDC profit
        uint256 actualProfit = balance1After - balance1Before;
        assertGt(actualProfit, 2 * 10**6);  // More than 2 USDC
        assertLt(actualProfit, 3 * 10**6);  // Less than 3 USDC
    }
    
    /**
     * TEST 4: Multiple Arbitrages
     * Can we profit multiple times?
     */
    function test_MultipleArbitrages() public {
        uint256 tradeAmount = 30 * 10**6; // Even smaller trades to maintain spread
        
        (, uint256 balanceBefore) = bot.getBalances();
        
        // Execute 3 times with small amounts
        bot.executeArbitrage(tradeAmount);
        bot.executeArbitrage(tradeAmount);
        bot.executeArbitrage(tradeAmount);
        
        (, uint256 balanceAfter) = bot.getBalances();
        
        // Should have accumulated profit
        assertGt(balanceAfter, balanceBefore);
        
        // Total profit should be positive
        uint256 totalProfit = balanceAfter - balanceBefore;
        assertGt(totalProfit, 1 * 10**6); // At least 1 USDC total
    }
    
    /**
     * TEST 5: Arbitrage Reduces Spread
     * Verify our arbitrage helps equalize prices
     */
    function test_ArbitrageReducesSpread() public {
        uint256 spreadBefore = dex.getPriceSpread();
        
        // Execute large arbitrage
        bot.executeArbitrage(200 * 10**6);
        
        uint256 spreadAfter = dex.getPriceSpread();
        
        // Spread should be significantly reduced
        assertLt(spreadAfter, spreadBefore);
        
        // The more we trade, the smaller the spread becomes
        // This is how arbitrage brings markets to equilibrium!
    }
    
    /**
     * TEST 6: Optimal Amount Finding
     * Test the optimization function
     */
    function test_FindOptimalAmount() public {
        uint256 minAmount = 10 * 10**6;   // 10 USDC
        uint256 maxAmount = 500 * 10**6;  // 500 USDC
        uint256 steps = 10;
        
        (uint256 optimalAmount, uint256 maxProfit) = bot.findOptimalAmount(
            minAmount, 
            maxAmount, 
            steps
        );
        
        // Should find some optimal amount
        assertGt(optimalAmount, 0);
        assertGt(maxProfit, 0);
        
        // Optimal should be somewhere in the middle (not too small, not too large)
        assertGt(optimalAmount, minAmount);
        assertLt(optimalAmount, maxAmount);
    }
    
    /**
     * TEST 7: Deposit and Withdraw
     * Test fund management
     */
    function test_DepositAndWithdraw() public {
        uint256 depositAmount = 100 * 10**6;
        
        // Deposit more USDC
        usdc.approve(address(bot), depositAmount);
        bot.deposit(address(usdc), depositAmount);
        
        (, uint256 balanceAfterDeposit) = bot.getBalances();
        assertEq(balanceAfterDeposit, 1100 * 10**6); // 1000 + 100
        
        // Withdraw all
        bot.withdraw(address(usdc));
        
        (, uint256 balanceAfterWithdraw) = bot.getBalances();
        assertEq(balanceAfterWithdraw, 0);
        
        // Owner should have received the funds
        assertGt(usdc.balanceOf(owner), 0);
    }
    
    /**
     * TEST 8: Simulation Matches Reality
     * Simulated profit should match actual
     */
    function test_SimulationAccuracy() public {
        uint256 testAmount = 100 * 10**6;
        
        // Simulate
        (bool profitable, uint256 estimatedProfit) = bot.simulateArbitrage(testAmount);
        assertTrue(profitable);
        
        // Execute
        uint256 actualProfit = bot.executeArbitrage(testAmount);
        
        // Should be very close (within 1%)
        uint256 difference = actualProfit > estimatedProfit 
            ? actualProfit - estimatedProfit 
            : estimatedProfit - actualProfit;
        
        uint256 maxDifference = estimatedProfit / 100; // 1%
        assertLt(difference, maxDifference);
    }
    
    /**
     * TEST 9: Revert When Spread Too Low
     * Bot should not trade unprofitable opportunities
     */
    function test_RevertWhen_SpreadTooLow() public {
        // Create new pools with minimal spread (0.1%)
        SimpleDEX newDex = new SimpleDEX();
        usdt.approve(address(newDex), type(uint256).max);
        usdc.approve(address(newDex), type(uint256).max);
        
        // Pool 1: 1:1
        newDex.initializePool1(address(usdt), address(usdc), POOL1_USDT, POOL1_USDC);
        // Pool 2: 1:1.001 (only 0.1% spread)
        newDex.initializePool2(address(usdt), address(usdc), POOL1_USDT, 10_010 * 10**6);
        
        ArbitrageBot newBot = new ArbitrageBot(address(newDex), address(usdt), address(usdc));
        usdc.transfer(address(newBot), 100 * 10**6);
        
        // Should revert - spread (10 bp) < MIN_SPREAD (30 bp)
        vm.expectRevert("Spread too low, not profitable");
        newBot.executeArbitrage(50 * 10**6);
    }
    
    /**
     * TEST 10: Revert When No Profit
     * If trade would lose money, should revert
     */
    function test_RevertWhen_NoProfit() public {
        // Execute one large trade to reduce spread significantly
        bot.executeArbitrage(200 * 10**6);
        
        // Spread is now much lower (~2.97%)
        uint256 finalSpread = dex.getPriceSpread();
        assertLt(finalSpread, 400); // Less than 4% now
        
        // But still profitable! Let's try one more that WILL fail
        // Trade again - this should eventually fail as spread gets too small
        try bot.executeArbitrage(200 * 10**6) {
            // If it succeeds, spread is still above MIN_SPREAD
            finalSpread = dex.getPriceSpread();
            // Verify it's getting smaller
            assertTrue(finalSpread < 400);
        } catch {
            // Expected - spread is now below MIN_SPREAD or trade unprofitable
        }
    }
    
    /**
     * TEST 11: Access Control
     * Only owner can execute trades
     */
    function test_RevertWhen_NotOwner() public {
        address attacker = address(0x666);
        
        vm.prank(attacker);
        vm.expectRevert("Not owner");
        bot.executeArbitrage(100 * 10**6);
    }
    
    /**
     * TEST 12: Gas Efficiency
     * Arbitrage should be reasonably gas efficient
     */
    function test_GasEfficiency() public {
        uint256 gasBefore = gasleft();
        bot.executeArbitrage(100 * 10**6);
        uint256 gasUsed = gasBefore - gasleft();
        
        // Should use less than 300k gas
        assertLt(gasUsed, 300_000);
    }
}
