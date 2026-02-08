// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockUSDC
 * @notice A simple ERC20 token that simulates USDC for testing
 * @dev Similar to MockUSDT - both use 6 decimals
 */
contract MockUSDC is ERC20, Ownable {
    
    /**
     * @notice Creates the token and mints initial supply
     * @dev We mint 1 million USDC to the deployer
     */
    constructor() ERC20("Mock USD Coin", "mUSDC") Ownable(msg.sender) {
        // Mint 1,000,000 USDC (with 6 decimals = 1,000,000 * 10^6)
        _mint(msg.sender, 1_000_000 * 10**6);
    }
    
    /**
     * @notice Override decimals to match real USDC
     * @dev Real USDC uses 6 decimals, not 18
     */
    function decimals() public pure override returns (uint8) {
        return 6;
    }
    
    /**
     * @notice Mint new tokens - useful for testing
     * @param to Who receives the tokens
     * @param amount How many tokens (in base units)
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
