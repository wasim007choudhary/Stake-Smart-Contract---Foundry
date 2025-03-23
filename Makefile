-include .env
.PHONY: all test deploy

build:; forge build
test:; forge test

install:; forge install cyfrin/foundry-devops --no-commit ** forge install smartcontractkit/chainlink-brownie-contracts --no-commit ** forge install foundry-rs/forge-std --no-commit ** forge install transmissions11/solmate --no-commit

deploy-sepolia: 
	@forge script script/DeployStake.s.sol:DeployStake --rpc-url $(SEPOLIA_RPC_URL) --account PK1 --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

test-staging:
	@forge test --fork-url $(SEPOLIA_RPC_URL) --match-path test/Staging/Staging.t.sol -vvvv