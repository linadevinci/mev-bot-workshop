# MEV Arbitrage Bot - Complete Workshop 🤖💰

Complete MEV arbitrage system from scratch and execute real profitable trades on Sepolia testnet!

MEV arbitrage bot that:
- Detects price differences between DEX pools
- Executes atomic arbitrage (buy low, sell high)
- Makes profit on-chain
- All in ~2000 lines of well-documented Solidity

**Result:** ~2 USDC profit per 100 USDC trade (2% ROI per transaction!)

---

## 📚 Architecture

```
┌─────────────────────────────────────┐
│         ArbitrageBot                │
│  - Detects opportunities            │
│  - Simulates profit                 │
│  - Executes atomically   💰         │
└──────────┬──────────────────────────┘
           │
           ↓
┌─────────────────────────────────────┐
│          SimpleDEX (AMM)            │
│  ┌─────────────┐  ┌─────────────┐  │
│  │   Pool 1    │  │   Pool 2    │  │
│  │  10k USDT   │  │  10k USDT   │  │
│  │  10k USDC   │  │  10.5k USDC │  │
│  │  1.00 price │  │  1.05 price │  │
│  └─────────────┘  └─────────────┘  │
│         ↑ 5% SPREAD! ↑              │
└─────────────────────────────────────┘
           │
           ↓
┌─────────────────────────────────────┐
│      ERC20 Tokens                   │
│  - MockUSDT (6 decimals)            │
│  - MockUSDC (6 decimals)            │
└─────────────────────────────────────┘
```

---

## 🚀 Quick Start (10 minutes)

### Prerequisites

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Get Sepolia ETH (~0.01 ETH needed)
# https://sepoliafaucet.com/

# Get Alchemy RPC (free)
# https://www.alchemy.com/
```

### Setup

```bash
# 1. Initialize git (required for forge)
git init
git add .
git commit -m "init"

# 3. Install dependencies
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts@v5.0.1


# 3. Setup environment
cp .env.example .env
# Edit .env and add:
#   - PRIVATE_KEY (with 0x prefix)
#   - SEPOLIA_RPC_URL
#   - ETHERSCAN_API_KEY (optional)

# 4. Run tests
forge test
# Expected: 31 tests passing ✅
```

---

### One-Command Deploy Everything:

```bash
bash deploy.sh
```

This automatically:
1. ✅ Deploys tokens
2. ✅ Saves addresses to `.env`
3. ✅ Deploys DEX & Bot
4. ✅ Saves addresses to `.env`
5. ✅ Executes arbitrage
6. ✅ Shows profit!
  
**Expected profit:** ~2 USDC per execution

---

## 🔧 Manual Deployment (Step-by-Step)

### Step 1: Deploy Tokens

```bash
forge script script/DeployTokens.s.sol:DeployTokens \
  --rpc-url sepolia \
  --broadcast \
  --verify

# Addresses auto-saved to .env.tokens
cat .env.tokens >> .env
```

### Step 2: Deploy DEX & Bot

```bash
forge script script/DeploySystem.s.sol:DeploySystem \
  --rpc-url sepolia \
  --broadcast \
  --verify

# Addresses auto-saved to .env.system
cat .env.system >> .env
```

### Step 3: Execute Arbitrage!

```bash
forge script script/ExecuteArbitrage.s.sol:ExecuteArbitrage \
  --rpc-url sepolia \
  --broadcast
```

**Output:**
```
Spread: 500 bp (5%)
Bot USDC: 1000
Profitable: true
Estimated profit: 2 USDC

--- EXECUTING ---

Profit: 2 USDC ✅
Bot USDC after: 1002 ✅
Spread reduced by: 406 bp
```

---

## 📊 What's Included

### Smart Contracts (src/)

**MockUSDT.sol & MockUSDC.sol** (Step 1)
- ERC20 tokens with 6 decimals
- 1M initial supply
- Ownable minting

**SimpleDEX.sol** (Step 2)  
- Constant product AMM (x*y=k)
- Two independent pools
- 0.3% swap fees
- Price oracle & spread calculation

**ArbitrageBot.sol** (Step 3)
- Atomic arbitrage execution
- Profit simulation
- Optimal amount finding
- MIN_SPREAD protection (30 bp)

### Tests (test/)

```bash
forge test -vv

TokenTest:          5 tests ✅
DEXTest:           14 tests ✅
ArbitrageBotTest:  12 tests ✅
Total:             31 tests ✅
```

### Scripts (script/)

- `DeployTokens.s.sol` - Deploy USDT/USDC
- `DeploySystem.s.sol` - Deploy DEX + Bot
- `ExecuteArbitrage.s.sol` - Run arbitrage
- `deploy.sh` - Automated full deployment




## 🔍 Project Structure

```
mev-bot-workshop/
├── src/
│   ├── MockUSDT.sol          # Token (6 decimals)
│   ├── MockUSDC.sol          # Token (6 decimals)
│   ├── SimpleDEX.sol         # AMM with 2 pools
│   └── ArbitrageBot.sol      # MEV bot
├── test/
│   ├── TokenTest.t.sol       # 5 tests
│   ├── DEXTest.t.sol         # 14 tests
│   └── ArbitrageBotTest.t.sol # 12 tests
├── script/
│   ├── DeployTokens.s.sol    # Step 1
│   ├── DeploySystem.s.sol    # Step 2
│   ├── ExecuteArbitrage.s.sol # Step 3
│   └── deploy.sh             # Automated
├── .env.example              # Template
└── README.md                 # This file!
```

---

## 🐛 Troubleshooting

### "Insufficient funds"
→ Get more Sepolia ETH from faucets

### "Spread too low, not profitable"
→ Success! Market is efficient now
→ Spread < 0.3%, not worth trading

### "Unable to locate ContractCode"
→ Etherscan verification timing issue
→ Contract deployed successfully, just not verified
→ Can verify manually later or ignore

### "vm.envUint: missing hex prefix"
→ Add `0x` prefix to PRIVATE_KEY in `.env`

### Tests failing?
→ Run `forge install` to reinstall dependencies
→ Make sure lib/ folder exists

---
