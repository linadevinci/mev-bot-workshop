// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MockUSDT.sol";
import "../src/MockUSDC.sol";

contract DeployTokens is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("=== Deploying Mock Tokens ===");
        
        vm.startBroadcast(deployerPrivateKey);
        
        MockUSDT usdt = new MockUSDT();
        MockUSDC usdc = new MockUSDC();
        
        vm.stopBroadcast();
        
        console.log("\nMockUSDT:", address(usdt));
        console.log("MockUSDC:", address(usdc));
        
        // Auto-save to .env
        string memory envContent = string.concat(
            "MOCK_USDT=", vm.toString(address(usdt)), "\n",
            "MOCK_USDC=", vm.toString(address(usdc)), "\n"
        );
        vm.writeFile(".env.tokens", envContent);
        
        console.log("\n*** Addresses saved to .env.tokens ***");
        console.log("Run: cat .env.tokens >> .env");
    }
}
