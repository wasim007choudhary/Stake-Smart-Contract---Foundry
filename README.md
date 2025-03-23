# 🏆 Stake Smart Contract

## 📘 Overview
This repository contains a fully functional **Stake Smart Contract** built using Solidity. The contract utilizes **Chainlink VRF v2.5** for secure randomness and **Chainlink Automation** for automated execution.

- **👤 Author:** Wasim Choudhary
- **🌐 Blockchain:** Ethereum (Sepolia Testnet)
- **⚙️ Framework:** Foundry
- **🎯 Purpose:** A decentralized staking platform where participants enter by sending ETH. A winner is randomly chosen at the end of each staking period using Chainlink VRF.

---

## 🚀 Features
- ✅ **Stake Entry:** Users can enter the stake pool by sending the required ETH entry fee.
- 🎲 **Random Winner Selection:** Chainlink VRF is used to ensure fair and verifiable randomness.
- 🤖 **Automated Execution:** Chainlink Automation performs upkeep to trigger winner selection.
- 📡 **Event Emission:** Events are emitted for transparency and off-chain tracking.

---

## 🧰 Prerequisites
- [Foundry](https://book.getfoundry.sh/) installed.
- Node.js and npm installed.
- Sepolia ETH for testing on the Sepolia testnet.
- Chainlink subscription with LINK tokens.

---

## ⚙️ Installation
1. Clone the repository:
    ```bash
    git clone https://github.com/your-repo-url.git
    cd stake-contract
    ```

2. Install Foundry dependencies:
    ```bash
    forge install
    ```

3. Install additional packages (e.g., Chainlink contracts):
    ```bash
    npm install
    ```

---

## 📦 Contract Deployment

### 🛠 Environment Setup
1. Create a `.env` file with the following variables:
    ```env
    SEPOLIA_RPC_URL=YOUR_RPC_URL
    PRIVATE_KEY=YOUR_PRIVATE_KEY
    CHAINLINK_VRF_COORDINATOR=YOUR_COORDINATOR_ADDRESS
    CHAINLINK_SUBSCRIPTION_ID=YOUR_SUBSCRIPTION_ID
    CHAINLINK_GAS_LANE=YOUR_GAS_LANE
    CALLBACK_GAS_LIMIT=YOUR_CALLBACK_GAS_LIMIT
    ENTRY_FEE=YOUR_ENTRY_FEE
    INTERVAL=YOUR_INTERVAL
    ```

### 🚀 Deploy Contract
1. Run the deployment script:
    ```bash
    forge script script/DeployStake.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
    ```

2. Verify on Etherscan (if needed):
    ```bash
    forge verify-contract --chain sepolia --watch --etherscan-api-key YOUR_API_KEY CONTRACT_ADDRESS src/Stake.sol:Stake
    ```

---

## 🧪 Testing
Run tests using Foundry:
```bash
forge test --fork-url $SEPOLIA_RPC_URL
