// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/ArbitrageBot.sol";
import "../src/SimpleDEX.sol";

/**
 * @title ExecuteArbitrage
 * @notice Execute MEV arbitrage on Sepolia testnet!
 * 
 * AUTOMATIC: Reads addresses from environment
 * 
 * Run with:
 * forge script script/ExecuteArbitrage.s.sol:ExecuteArbitrage --rpc-url sepolia --broadcast -vvvv
 */
contract ExecuteArbitrage is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Read addresses from environment
        address SIMPLE_DEX = vm.envAddress("SIMPLE_DEX");
        address ARBITRAGE_BOT = vm.envAddress("ARBITRAGE_BOT");
        
        console.log("=== EXECUTING MEV ARBITRAGE ===");
        console.log("Using addresses:");
        console.log("DEX:", SIMPLE_DEX);
        console.log("Bot:", ARBITRAGE_BOT);
        
        vm.startBroadcast(deployerPrivateKey);
        
        SimpleDEX dex = SimpleDEX(SIMPLE_DEX);
        ArbitrageBot bot = ArbitrageBot(ARBITRAGE_BOT);
        
        // 1. Check state before
        console.log("\n--- BEFORE ARBITRAGE ---");
        uint256 priceBefore1 = dex.getPrice1();
        uint256 priceBefore2 = dex.getPrice2();
        uint256 spreadBefore = dex.getPriceSpread();
        
        console.log("Pool 1 price:", priceBefore1 / 1e15, "milli-USDC per USDT");
        console.log("Pool 2 price:", priceBefore2 / 1e15, "milli-USDC per USDT");
        console.log("Spread:", spreadBefore, "bp (", spreadBefore / 100, "%)");
        
        (uint256 balance0Before, uint256 balance1Before) = bot.getBalances();
        console.log("\nBot balances:");
        console.log("USDT:", balance0Before / 10**6);
        console.log("USDC:", balance1Before / 10**6);
        
        // 2. Check if profitable
        (bool exists, uint256 currentSpread, bool profitable) = bot.checkOpportunity();
        console.log("\nOpportunity check:");
        console.log("Exists:", exists);
        console.log("Spread:", currentSpread, "bp");
        console.log("Profitable:", profitable);
        
        require(profitable, "No profitable opportunity!");
        
        // 3. Simulate first
        console.log("\n--- SIMULATION ---");
        uint256 tradeAmount = 100 * 10**6; // 100 USDC
        (bool simProfitable, uint256 estimatedProfit) = bot.simulateArbitrage(tradeAmount);
        
        console.log("Amount to trade:", tradeAmount / 10**6, "USDC");
        console.log("Profitable:", simProfitable);
        console.log("Estimated profit:", estimatedProfit / 10**6, "USDC");
        
        require(simProfitable, "Simulation shows no profit!");
        
        // 4. EXECUTE THE ARBITRAGE!
        console.log("\n--- EXECUTING ARBITRAGE ---");
        console.log("Trading", tradeAmount / 10**6, "USDC...");
        
        try bot.executeArbitrage(tradeAmount) returns (uint256 profit) {
            console.log("\n=== SUCCESS! ===");
            console.log("Actual profit:", profit / 10**6, "USDC");
            console.log("ROI:", (profit * 100) / tradeAmount, "%");
        } catch Error(string memory reason) {
            console.log("\n=== FAILED ===");
            console.log("Reason:", reason);
            revert(reason);
        }
        
        // 5. Check state after
        console.log("\n--- AFTER ARBITRAGE ---");
        uint256 priceAfter1 = dex.getPrice1();
        uint256 priceAfter2 = dex.getPrice2();
        uint256 spreadAfter = dex.getPriceSpread();
        
        console.log("Pool 1 price:", priceAfter1 / 1e15, "milli-USDC per USDT");
        console.log("Pool 2 price:", priceAfter2 / 1e15, "milli-USDC per USDT");
        console.log("Spread:", spreadAfter, "bp (", spreadAfter / 100, "%)");
        
        (uint256 balance0After, uint256 balance1After) = bot.getBalances();
        console.log("\nBot balances:");
        console.log("USDT:", balance0After / 10**6);
        console.log("USDC:", balance1After / 10**6);
        
        // 6. Calculate profit
        console.log("\n--- PROFIT ANALYSIS ---");
        
        if (balance1After > balance1Before) {
            uint256 profitUSDC = balance1After - balance1Before;
            console.log("USDC profit:", profitUSDC / 10**6);
            console.log("Percentage gain:", (profitUSDC * 10000) / balance1Before, "bp");
        }
        
        if (balance0After > balance0Before) {
            uint256 profitUSDT = balance0After - balance0Before;
            console.log("USDT profit:", profitUSDT / 10**6);
        }
        
        // Price impact
        console.log("\n--- MARKET IMPACT ---");
        console.log("Spread before:", spreadBefore, "bp");
        console.log("Spread after:", spreadAfter, "bp");
        console.log("Spread reduced by:", spreadBefore - spreadAfter, "bp");
        console.log("\nOur arbitrage helped equalize prices! ");
        
        vm.stopBroadcast();
        
        console.log("\n=== MEV ARBITRAGE COMPLETE! ===");
        console.log("Check Sepolia Etherscan for transaction details");
    }
}
