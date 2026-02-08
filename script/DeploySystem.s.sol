// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/SimpleDEX.sol";
import "../src/ArbitrageBot.sol";
import "../src/MockUSDT.sol";
import "../src/MockUSDC.sol";

contract DeploySystem is Script {
    
    uint256 constant POOL1_USDT = 10_000 * 10**6;
    uint256 constant POOL1_USDC = 10_000 * 10**6;
    uint256 constant POOL2_USDT = 10_000 * 10**6;
    uint256 constant POOL2_USDC = 10_500 * 10**6;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address MOCK_USDT = vm.envAddress("MOCK_USDT");
        address MOCK_USDC = vm.envAddress("MOCK_USDC");
        
        console.log("=== Deploying DEX & Bot ===");
        
        vm.startBroadcast(deployerPrivateKey);
        
        MockUSDT usdt = MockUSDT(MOCK_USDT);
        MockUSDC usdc = MockUSDC(MOCK_USDC);
        
        SimpleDEX dex = new SimpleDEX();
        
        usdt.approve(address(dex), type(uint256).max);
        usdc.approve(address(dex), type(uint256).max);
        
        dex.initializePool1(MOCK_USDT, MOCK_USDC, POOL1_USDT, POOL1_USDC);
        dex.initializePool2(MOCK_USDT, MOCK_USDC, POOL2_USDT, POOL2_USDC);
        
        ArbitrageBot bot = new ArbitrageBot(address(dex), MOCK_USDT, MOCK_USDC);
        usdc.transfer(address(bot), 1000 * 10**6);
        
        vm.stopBroadcast();
        
        console.log("\nSimpleDEX:", address(dex));
        console.log("ArbitrageBot:", address(bot));
        
        // Auto-save to .env
        string memory envContent = string.concat(
            "SIMPLE_DEX=", vm.toString(address(dex)), "\n",
            "ARBITRAGE_BOT=", vm.toString(address(bot)), "\n"
        );
        vm.writeFile(".env.system", envContent);
        
        console.log("\n*** Addresses saved to .env.system ***");
        console.log("Run: cat .env.system >> .env");
    }
}
