#!/bin/bash

echo "🚀 MEV Arbitrage Bot - Automated Deployment"
echo "==========================================="
echo ""

# Step 1: Deploy Tokens
echo "Step 1: Deploying Tokens..."
forge script script/DeployTokens.s.sol:DeployTokens \
  --rpc-url sepolia \
  --broadcast \
  --verify

if [ -f .env.tokens ]; then
    cat .env.tokens >> .env
    echo "✅ Token addresses added to .env"
    rm .env.tokens
fi

echo ""
echo "Step 2: Deploying DEX & Bot..."
forge script script/DeploySystem.s.sol:DeploySystem \
  --rpc-url sepolia \
  --broadcast \
  --verify

if [ -f .env.system ]; then
    cat .env.system >> .env
    echo "✅ DEX & Bot addresses added to .env"
    rm .env.system
fi

echo ""
echo "Step 3: Executing Arbitrage..."
forge script script/ExecuteArbitrage.s.sol:ExecuteArbitrage \
  --rpc-url sepolia \
  --broadcast

echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo "Check your .env file for all addresses"
