# Setup Guide - Step by Step

## Step 1: Install Foundry

```bash
# Install foundryup
curl -L https://foundry.paradigm.xyz | bash

# Install foundry tools
foundryup

# Verify installation
forge --version
cast --version
```

## Step 2: Initialize Project

```bash
# Navigate to project
cd mev-bot-workshop

# Initialize git
git init
git add .
git commit -m "Initial commit - Step 1: Tokens"

# Install dependencies
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts@v5.0.1
```

## Step 3: Build Contracts

```bash
# Compile everything
forge build

# You should see:
# [⠊] Compiling...
# [⠒] Compiling 6 files with 0.8.20
# [⠢] Solc 0.8.20 finished
# Compiler run successful!
```

## Step 4: Run Tests

```bash
# Run all tests
forge test

# Run with detailed output
forge test -vvv

# Run specific test file
forge test --match-contract TokenTest -vvv

# Run with gas report
forge test --gas-report
```

## Expected Test Output

```
Running 5 tests for test/TokenTest.t.sol:TokenTest
[PASS] test_Decimals() (gas: 9847)
[PASS] test_InitialSupply() (gas: 15329)
[PASS] test_Mint() (gas: 76241)
[PASS] test_RevertWhen_MintAsNonOwner() (gas: 15234)
[PASS] test_Transfer() (gas: 72845)
Test result: ok. 5 passed; 0 failed; finished in 2.31ms
```

## Troubleshooting

### "Failed to resolve dependencies"
```bash
# Update git submodules
git submodule update --init --recursive
```

### "Compiler not found"
```bash
# Update foundry
foundryup
```

### "forge: command not found"
```bash
# Add to PATH (restart terminal after)
source ~/.bashrc  # or ~/.zshrc
```
