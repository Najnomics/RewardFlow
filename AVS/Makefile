# -----------------------------------------------------------------------------
# RewardFlow AVS Makefile
#
# This Makefile is used for building the RewardFlow AVS application.
# It contains targets for building the application, deploying contracts,
# running tests, and managing the RewardFlow AVS infrastructure.
#
# RewardFlow AVS: Uniswap V4 Hook Reward Distribution on EigenLayer
# -----------------------------------------------------------------------------

GO = $(shell which go)
OUT = ./bin
CONTRACTS_DIR = ./contracts
DOCKER_IMAGE = rewardflow-avs
VERSION = $(shell git describe --tags --always --dirty)

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m # No Color

.PHONY: help build build-contracts deps test clean deploy run devnet

# Default target
help:
	@echo "$(BLUE)RewardFlow AVS - Uniswap V4 Hook Reward Distribution$(NC)"
	@echo "$(BLUE)====================================================$(NC)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@echo "  $(YELLOW)build$(NC)           - Build RewardFlow AVS performer binary"
	@echo "  $(YELLOW)build-contracts$(NC) - Build RewardFlow smart contracts"
	@echo "  $(YELLOW)deps$(NC)            - Install Go dependencies"
	@echo "  $(YELLOW)test$(NC)            - Run all tests (Go + contracts)"
	@echo "  $(YELLOW)test-go$(NC)         - Run Go unit tests"
	@echo "  $(YELLOW)test-contracts$(NC)  - Run contract tests"
	@echo "  $(YELLOW)clean$(NC)           - Clean build artifacts"
	@echo "  $(YELLOW)run$(NC)             - Run RewardFlow AVS performer"
	@echo "  $(YELLOW)devnet$(NC)          - Start RewardFlow devnet"
	@echo "  $(YELLOW)deploy$(NC)          - Deploy RewardFlow contracts"
	@echo "  $(YELLOW)docker-build$(NC)    - Build Docker container"
	@echo "  $(YELLOW)docker-run$(NC)      - Run Docker container"
	@echo "  $(YELLOW)lint$(NC)            - Run linting"
	@echo "  $(YELLOW)format$(NC)          - Format code"
	@echo ""

# Build RewardFlow AVS performer
build: deps
	@echo "$(GREEN)Building RewardFlow AVS performer...$(NC)"
	@mkdir -p $(OUT) || true
	@echo "Building binaries..."
	@go build -ldflags "-X main.version=$(VERSION)" -o $(OUT)/rewardflow-avs ./cmd/main.go
	@echo "$(GREEN)✓ RewardFlow AVS performer built successfully$(NC)"
	@echo "Binary: $(OUT)/rewardflow-avs"

# Build RewardFlow smart contracts
build-contracts:
	@echo "$(GREEN)Building RewardFlow smart contracts...$(NC)"
	@cd $(CONTRACTS_DIR) && forge build
	@echo "$(GREEN)✓ RewardFlow contracts built successfully$(NC)"

# Install dependencies
deps:
	@echo "$(GREEN)Installing dependencies...$(NC)"
	@GOPRIVATE=github.com/Layr-Labs/* go mod tidy
	@cd $(CONTRACTS_DIR) && forge install
	@echo "$(GREEN)✓ Dependencies installed$(NC)"

# Run all tests
test: test-go test-contracts
	@echo "$(GREEN)✓ All tests completed$(NC)"

# Run Go tests
test-go:
	@echo "$(GREEN)Running Go tests...$(NC)"
	@go test ./... -v -p 1 -cover
	@echo "$(GREEN)✓ Go tests completed$(NC)"

# Run contract tests
test-contracts:
	@echo "$(GREEN)Running contract tests...$(NC)"
	@cd $(CONTRACTS_DIR) && forge test -vv
	@echo "$(GREEN)✓ Contract tests completed$(NC)"

# Clean build artifacts
clean:
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	@rm -rf $(OUT)
	@cd $(CONTRACTS_DIR) && forge clean
	@echo "$(GREEN)✓ Clean completed$(NC)"

# Run RewardFlow AVS performer
run: build
	@echo "$(GREEN)Starting RewardFlow AVS performer...$(NC)"
	@echo "$(BLUE)Version: $(VERSION)$(NC)"
	@echo "$(BLUE)Port: 8080$(NC)"
	@echo "$(BLUE)Timeout: 30s$(NC)"
	@echo ""
	@$(OUT)/rewardflow-avs

# Start RewardFlow devnet
devnet:
	@echo "$(GREEN)Starting RewardFlow devnet...$(NC)"
	@echo "$(BLUE)This will deploy contracts and start the Hourglass infrastructure$(NC)"
	@echo "$(YELLOW)Note: Make sure you have devkit installed and configured$(NC)"
	@devkit avs devnet start --skip-avs-run
	@echo "$(GREEN)✓ RewardFlow devnet started$(NC)"

# Run RewardFlow performer in devnet
run-devnet: build
	@echo "$(GREEN)Running RewardFlow performer in devnet...$(NC)"
	@devkit avs run

# Deploy RewardFlow contracts
deploy: build-contracts
	@echo "$(GREEN)Deploying RewardFlow contracts...$(NC)"
	@echo "$(BLUE)Deploying L1 contracts...$(NC)"
	@cd $(CONTRACTS_DIR) && forge script script/DeployMyL1Contracts.s.sol --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) --broadcast
	@echo "$(BLUE)Deploying L2 contracts...$(NC)"
	@cd $(CONTRACTS_DIR) && forge script script/DeployMyL2Contracts.s.sol --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) --broadcast
	@echo "$(GREEN)✓ RewardFlow contracts deployed$(NC)"

# Deploy to testnet
deploy-testnet:
	@echo "$(GREEN)Deploying RewardFlow to testnet...$(NC)"
	@$(MAKE) deploy RPC_URL=$(TESTNET_RPC_URL) PRIVATE_KEY=$(TESTNET_PRIVATE_KEY)

# Deploy to mainnet
deploy-mainnet:
	@echo "$(GREEN)Deploying RewardFlow to mainnet...$(NC)"
	@echo "$(RED)⚠️  WARNING: This will deploy to mainnet!$(NC)"
	@echo "$(RED)⚠️  Make sure you have verified all contracts and configurations$(NC)"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ]
	@$(MAKE) deploy RPC_URL=$(MAINNET_RPC_URL) PRIVATE_KEY=$(MAINNET_PRIVATE_KEY)

# Build Docker container
docker-build:
	@echo "$(GREEN)Building RewardFlow Docker container...$(NC)"
	@docker build -t $(DOCKER_IMAGE):$(VERSION) .
	@docker tag $(DOCKER_IMAGE):$(VERSION) $(DOCKER_IMAGE):latest
	@echo "$(GREEN)✓ Docker container built$(NC)"
	@echo "Image: $(DOCKER_IMAGE):$(VERSION)"

# Run Docker container
docker-run: docker-build
	@echo "$(GREEN)Running RewardFlow Docker container...$(NC)"
	@docker run -p 8080:8080 $(DOCKER_IMAGE):latest

# Lint code
lint:
	@echo "$(GREEN)Running linters...$(NC)"
	@go vet ./...
	@go fmt ./...
	@cd $(CONTRACTS_DIR) && forge fmt --check
	@echo "$(GREEN)✓ Linting completed$(NC)"

# Format code
format:
	@echo "$(GREEN)Formatting code...$(NC)"
	@go fmt ./...
	@cd $(CONTRACTS_DIR) && forge fmt
	@echo "$(GREEN)✓ Code formatted$(NC)"

# Generate mocks
mocks:
	@echo "$(GREEN)Generating mocks...$(NC)"
	@go generate ./...
	@echo "$(GREEN)✓ Mocks generated$(NC)"

# Run benchmarks
benchmark:
	@echo "$(GREEN)Running benchmarks...$(NC)"
	@go test -bench=. -benchmem ./...
	@echo "$(GREEN)✓ Benchmarks completed$(NC)"

# Show version information
version:
	@echo "$(BLUE)RewardFlow AVS Version Information$(NC)"
	@echo "Version: $(VERSION)"
	@echo "Go Version: $(shell go version)"
	@echo "Git Commit: $(shell git rev-parse HEAD)"
	@echo "Build Time: $(shell date -u +%Y-%m-%dT%H:%M:%SZ)"

# Install devkit (if not already installed)
install-devkit:
	@echo "$(GREEN)Installing devkit...$(NC)"
	@curl -L https://github.com/Layr-Labs/devkit/releases/latest/download/devkit-$(shell uname -s | tr '[:upper:]' '[:lower:]')-$(shell uname -m) -o /usr/local/bin/devkit
	@chmod +x /usr/local/bin/devkit
	@echo "$(GREEN)✓ devkit installed$(NC)"

# Setup development environment
setup: install-devkit deps build-contracts
	@echo "$(GREEN)✓ Development environment setup completed$(NC)"
	@echo "$(BLUE)You can now run 'make devnet' to start the development environment$(NC)"

# Check if required tools are installed
check-deps:
	@echo "$(GREEN)Checking dependencies...$(NC)"
	@which go > /dev/null || (echo "$(RED)Go is not installed$(NC)" && exit 1)
	@which forge > /dev/null || (echo "$(RED)Foundry is not installed$(NC)" && exit 1)
	@which docker > /dev/null || (echo "$(RED)Docker is not installed$(NC)" && exit 1)
	@echo "$(GREEN)✓ All dependencies are installed$(NC)"

# Security audit
audit:
	@echo "$(GREEN)Running security audit...$(NC)"
	@go list -json -deps ./... | nancy sleuth
	@cd $(CONTRACTS_DIR) && forge build --sizes
	@echo "$(GREEN)✓ Security audit completed$(NC)"