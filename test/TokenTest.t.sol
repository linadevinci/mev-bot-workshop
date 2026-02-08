// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MockUSDT.sol";
import "../src/MockUSDC.sol";

/**
 * @title TokenTest
 * @notice Tests for our mock tokens - Step 1 of building the MEV bot
 */
contract TokenTest is Test {
    MockUSDT public usdt;
    MockUSDC public usdc;
    
    address public deployer = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    
    function setUp() public {
        // Deploy both tokens
        usdt = new MockUSDT();
        usdc = new MockUSDC();
    }
    
    function test_InitialSupply() public {
        // Check deployer has 1M tokens
        assertEq(usdt.balanceOf(deployer), 1_000_000 * 10**6);
        assertEq(usdc.balanceOf(deployer), 1_000_000 * 10**6);
    }
    
    function test_Decimals() public {
        // Both should have 6 decimals
        assertEq(usdt.decimals(), 6);
        assertEq(usdc.decimals(), 6);
    }
    
    function test_Transfer() public {
        // Transfer some tokens to user1
        uint256 amount = 1000 * 10**6; // 1000 tokens
        
        usdt.transfer(user1, amount);
        assertEq(usdt.balanceOf(user1), amount);
        
        usdc.transfer(user1, amount);
        assertEq(usdc.balanceOf(user1), amount);
    }
    
    function test_Mint() public {
        // Mint more tokens
        uint256 mintAmount = 100 * 10**6; // 100 tokens
        
        usdt.mint(user1, mintAmount);
        assertEq(usdt.balanceOf(user1), mintAmount);
        
        usdc.mint(user2, mintAmount);
        assertEq(usdc.balanceOf(user2), mintAmount);
    }
    
    function test_RevertWhen_MintAsNonOwner() public {
        // This should revert - only owner can mint
        vm.prank(user1);
        vm.expectRevert(); // Expect the next call to revert
        usdt.mint(user1, 100 * 10**6);
    }
}
