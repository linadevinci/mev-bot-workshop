# MEV Arbitrage Bot - Complete Workshop 🤖💰

Build a complete MEV arbitrage system from scratch and execute real profitable trades on Sepolia testnet!

## 🎯 What You'll Build

A production-ready MEV arbitrage bot that:
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
# 1. initialize git
git init

# 2. Install dependencies

forge install

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

## 🎮 Automated Deployment (Recommended)

### One-Command Deploy Everything:

```bash
./deploy.sh
```

This automatically:
1. ✅ Deploys tokens
2. ✅ Saves addresses to `.env`
3. ✅ Deploys DEX & Bot
4. ✅ Saves addresses to `.env`
5. ✅ Executes arbitrage
6. ✅ Shows profit!

**Total time:** ~2 minutes  
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

---

## 🎓 Learning Path

### Step 1: ERC20 Tokens
**Learn:** Token mechanics, decimals, minting, transfers

**Key concepts:**
- Why 6 decimals for stablecoins?
- How does `_mint()` work?
- What is `Ownable`?

**Tests:** 5 passing

### Step 2: AMM DEX
**Learn:** Constant product formula, liquidity pools, price impact

**Key concepts:**
```
Constant Product: x * y = k
Price = reserve1 / reserve0
Spread = |price1 - price2| / min(price1, price2)
```

**Fee vs Slippage:**
- Fee: Always 0.3% per swap
- Slippage: Increases with trade size!
  - 0.1% of pool → ~0.1% slippage
  - 1% of pool → ~1% slippage
  - 10% of pool → ~9% slippage

**Tests:** 14 passing

### Step 3: Arbitrage Bot
**Learn:** MEV strategies, atomic execution, profit calculation

**The Strategy:**
1. Monitor prices on both pools
2. If spread > 0.3% (covers fees)
3. Buy token on cheaper pool
4. Sell token on expensive pool
5. Keep the profit!

**The Math:**
```
Setup:
  Pool 1: 1 USDT = 1.00 USDC
  Pool 2: 1 USDT = 1.05 USDC
  Spread: 5%

Trade 100 USDC:
  Naive: 5% = 5 USDC profit
  
  Reality:
  - Fees: 0.6 USDC (0.3% × 2)
  - Slippage: ~2 USDC
  - Net: ~2.3 USDC ✅
  
  ROI: 2.3%
```

**Tests:** 12 passing

### Step 4: Deployment
**Learn:** Foundry scripts, testnet deployment, transaction execution

**Gas costs on Sepolia:**
- Deploy tokens: ~0.0015 ETH
- Deploy DEX + Bot: ~0.003 ETH
- Execute arbitrage: ~0.0002 ETH
- **Total:** ~0.005 ETH (~$12)

---

## 💡 Key Insights

### Why Arbitrage Helps Markets

**Before arbitrage:**
```
Pool 1: 1.00 USDC/USDT
Pool 2: 1.05 USDC/USDT
Inefficient! Price should be equal ❌
```

**After arbitrage:**
```
Pool 1: 1.02 USDC/USDT
Pool 2: 1.03 USDC/USDT
More efficient! Prices converging ✅
```

**Eventually:**
```
Both pools: ~1.025 USDC/USDT
Perfect equilibrium! 🎯
```

### Why Small Trades Better?

```
Trade 10% of pool:
  Input: 1000 USDC
  Slippage: ~9%
  Output after fees: ~906 USDC
  Loss: 94 USDC ❌

Trade 1% of pool:
  Input: 100 USDC
  Slippage: ~1%
  Output after fees: ~98.3 USDC
  Profit from 5% spread: ~2.3 USDC ✅
```

**Lesson:** Many small trades > Few large trades

---

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

## 🎯 Success Criteria

- [x] All 31 tests passing
- [x] Tokens deployed to Sepolia
- [x] DEX deployed with 5% spread
- [x] Bot deployed and funded
- [x] Arbitrage executed successfully
- [x] Profit made on-chain! 💰

---

## 🚀 Next Steps

### Execute More Trades

```bash
# Run arbitrage again
forge script script/ExecuteArbitrage.s.sol:ExecuteArbitrage \
  --rpc-url sepolia \
  --broadcast

# Each trade:
# - Reduces spread further
# - Makes smaller profit
# - Eventually unprofitable (equilibrium!)
```

### Advanced Challenges

1. **Optimize Trade Size**
   - Find amount that maximizes profit
   - Balance gas costs vs profit

2. **Flash Loans**
   - Borrow capital
   - Execute larger arbitrage
   - Repay + keep profit

3. **Multi-DEX Arbitrage**
   - Monitor Uniswap, Sushiswap, etc.
   - Cross-DEX opportunities
   - Gas optimization crucial

4. **Mainnet Fork Testing**
   - Test against real Uniswap pools
   - No risk, real data
   - `--fork-url` flag

5. **MEV Protection**
   - Study Flashbots
   - Private mempools
   - MEV-Boost integration

---

## 📖 Additional Resources

**MEV Concepts:**
- [Flashbots Docs](https://docs.flashbots.net/)
- [MEV Wiki](https://github.com/flashbots/mev-research)
- [Uniswap V2 Whitepaper](https://uniswap.org/whitepaper.pdf)

**Foundry:**
- [Foundry Book](https://book.getfoundry.sh/)
- [Foundry Cheatsheet](https://github.com/dabit3/foundry-cheatsheet)

**Solidity:**
- [Solidity Docs](https://docs.soliditylang.org/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)

---

## ⚠️ Disclaimer

**FOR EDUCATIONAL PURPOSES ONLY**

This is a learning project. Before using on mainnet:
- Get professional security audit
- Understand MEV competition
- Calculate real gas costs
- Consider MEV protection
- Know the risks

DO NOT:
- Deploy to mainnet without audit
- Use with real funds without testing
- Share private keys
- Commit `.env` to git

---

## 🎉 Congratulations!

You've built a complete MEV arbitrage system from scratch!

**You now understand:**
- ✅ Smart contract development
- ✅ AMM mathematics (x*y=k)
- ✅ MEV strategies
- ✅ Foundry testing & deployment
- ✅ Real profit extraction

**You're now an MEV Developer!** 🚀

---

## 📞 Support

**Questions? Issues?**
- Check the inline code comments (heavily documented)
- Run tests with `-vvvv` for detailed traces
- Review transaction on Etherscan

**Share Your Success:**
- Deployed bot address: _______________
- Total profit made: _______________
- Lessons learned: _______________

---

**Built with:** Foundry • Solidity 0.8.20 • OpenZeppelin

**License:** MIT
