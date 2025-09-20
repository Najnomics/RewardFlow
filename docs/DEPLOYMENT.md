# RewardFlow Deployment Guide

## Prerequisites

### Required Tools
- Foundry (latest version)
- Node.js 18+
- Docker (for local development)
- Git

### Environment Setup
1. Clone the repository
2. Copy `.env.example` to `.env`
3. Fill in your configuration values
4. Install dependencies

## Local Development (Anvil)

### Setup
```bash
# Start Anvil
anvil

# Deploy contracts
forge script script/DeployAnvil.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Configuration
- Uses mock contracts for testing
- No real network dependencies
- Perfect for development and testing

## Testnet Deployment

### Supported Testnets
- Sepolia (Ethereum)
- Arbitrum Sepolia
- Polygon Amoy
- Base Sepolia

### Deployment Process
```bash
# Set environment variables
export NETWORK=sepolia
export RPC_URL=$RPC_URL_SEPOLIA
export PRIVATE_KEY_DEPLOYER=$YOUR_PRIVATE_KEY
export REWARD_TOKEN_ADDRESS=$TOKEN_ADDRESS
export SPOKE_POOL_ADDRESS=$SPOKE_POOL_ADDRESS
export UNISWAP_V4_POOL_MANAGER=$POOL_MANAGER_ADDRESS

# Deploy
forge script script/DeployTestnet.s.sol --rpc-url $RPC_URL --broadcast --verify
```

### Verification
```bash
# Verify contracts
forge verify-contract $DISTRIBUTOR_ADDRESS src/distribution/RewardDistributor.sol:RewardDistributor --chain-id sepolia
```

## Mainnet Deployment

### Pre-Deployment Checklist
- [ ] All contracts tested thoroughly
- [ ] Security audit completed
- [ ] Environment variables configured
- [ ] Gas estimates calculated
- [ ] Emergency procedures documented

### Deployment Process
```bash
# Set environment variables
export NETWORK=mainnet
export RPC_URL=$RPC_URL_MAINNET
export PRIVATE_KEY_DEPLOYER=$YOUR_PRIVATE_KEY
export REWARD_TOKEN_ADDRESS=$TOKEN_ADDRESS
export SPOKE_POOL_ADDRESS=$SPOKE_POOL_ADDRESS
export UNISWAP_V4_POOL_MANAGER=$POOL_MANAGER_ADDRESS

# Deploy with verification
forge script script/DeployMainnet.s.sol --rpc-url $RPC_URL --broadcast --verify
```

### Post-Deployment
1. Verify all contracts on block explorers
2. Update frontend configuration
3. Configure monitoring and alerting
4. Test reward distribution flow
5. Announce deployment to community

## Configuration Management

### Environment Variables
See `.env.example` for complete list of required variables.

### Network-Specific Configuration
- RPC URLs for each network
- Contract addresses for dependencies
- Gas price configurations
- API keys for verification

## Security Considerations

### Private Key Management
- Use hardware wallets for mainnet deployments
- Never commit private keys to version control
- Use environment variables for sensitive data
- Implement proper access controls

### Contract Verification
- Verify all contracts on block explorers
- Use deterministic deployment for critical contracts
- Maintain deployment records
- Document all configuration changes

## Monitoring and Maintenance

### Health Checks
- Monitor contract interactions
- Track reward distribution success rates
- Monitor gas usage and costs
- Alert on unusual activity patterns

### Regular Maintenance
- Update dependencies regularly
- Monitor for security vulnerabilities
- Optimize gas usage
- Update documentation

## Troubleshooting

### Common Issues
1. **Gas Estimation Failures**: Check gas limits and prices
2. **Verification Failures**: Ensure source code matches deployment
3. **Network Connectivity**: Verify RPC URLs and network status
4. **Configuration Errors**: Double-check environment variables

### Support
- Check logs for detailed error messages
- Verify network status and RPC connectivity
- Consult documentation for configuration details
- Contact team for critical issues

## Rollback Procedures

### Emergency Rollback
1. Pause affected contracts
2. Migrate funds to safe addresses
3. Deploy fixed contracts
4. Update frontend configuration
5. Communicate with users

### Planned Updates
1. Deploy new contracts
2. Migrate state and funds
3. Update configurations
4. Test thoroughly
5. Announce changes
