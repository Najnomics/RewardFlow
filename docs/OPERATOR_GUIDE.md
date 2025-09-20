# RewardFlow AVS Operator Guide

## Overview

This guide provides comprehensive instructions for operating the RewardFlow AVS (Actively Validated Service) on the EigenLayer network. The RewardFlow AVS processes reward distribution tasks from Uniswap V4 hooks and facilitates cross-chain reward distribution.

## Prerequisites

### System Requirements
- **Go**: Version 1.23.6 or higher
- **Docker**: For containerized deployment
- **PostgreSQL**: For data storage
- **Node.js**: For monitoring and utilities
- **Ethereum Node**: Access to Ethereum and L2 networks

### Network Access
- **Ethereum Mainnet**: For L1 AVS contracts
- **EigenLayer L2**: For task processing
- **Target Chains**: Arbitrum, Polygon, Base for reward distribution

### Initial Setup
- **EigenLayer Registration**: Register as an AVS operator
- **Stake Requirements**: Minimum stake for AVS participation
- **Key Management**: Secure key storage and management

## Installation

### 1. Clone Repository
```bash
git clone https://github.com/RewardFlow/RewardFlow.git
cd RewardFlow/AVS
```

### 2. Install Dependencies
```bash
# Install Go dependencies
go mod tidy

# Install contract dependencies
cd contracts && forge install && cd ..
```

### 3. Environment Configuration
```bash
# Copy environment template
cp .env.example .env

# Configure environment variables
nano .env
```

### 4. Database Setup
```bash
# Start PostgreSQL
docker run -d --name rewardflow-postgres \
  -e POSTGRES_DB=rewardflow \
  -e POSTGRES_USER=rewardflow \
  -e POSTGRES_PASSWORD=your_password \
  -p 5432:5432 postgres:14

# Run migrations
go run cmd/main.go migrate
```

## Configuration

### Environment Variables

#### Core Configuration
```bash
# AVS Configuration
AVS_PRIVATE_KEY=0x...                    # Your operator private key
AVS_ADDRESS=0x...                        # Your AVS address
EIGENLAYER_L1_RPC=https://...            # EigenLayer L1 RPC
EIGENLAYER_L2_RPC=https://...            # EigenLayer L2 RPC

# Database Configuration
DATABASE_URL=postgresql://...            # PostgreSQL connection string
DATABASE_HOST=localhost                  # Database host
DATABASE_PORT=5432                       # Database port
DATABASE_NAME=rewardflow                 # Database name
DATABASE_USER=rewardflow                 # Database user
DATABASE_PASSWORD=your_password          # Database password
```

#### Network Configuration
```bash
# Ethereum Configuration
ETHEREUM_RPC=https://...                 # Ethereum RPC URL
ETHEREUM_CHAIN_ID=1                      # Ethereum chain ID

# L2 Configuration
ARBITRUM_RPC=https://...                 # Arbitrum RPC URL
POLYGON_RPC=https://...                  # Polygon RPC URL
BASE_RPC=https://...                     # Base RPC URL

# Across Protocol
ACROSS_SPOKE_POOL_ETHEREUM=0x...         # Ethereum spoke pool
ACROSS_SPOKE_POOL_ARBITRUM=0x...         # Arbitrum spoke pool
ACROSS_SPOKE_POOL_POLYGON=0x...          # Polygon spoke pool
ACROSS_SPOKE_POOL_BASE=0x...             # Base spoke pool
```

#### Monitoring Configuration
```bash
# Logging
LOG_LEVEL=info                           # Log level (debug, info, warn, error)
LOG_FORMAT=json                          # Log format (json, text)

# Monitoring
PROMETHEUS_ENDPOINT=http://localhost:9090 # Prometheus endpoint
GRAFANA_ENDPOINT=http://localhost:3000   # Grafana endpoint

# Health Checks
HEALTH_CHECK_PORT=8080                   # Health check port
METRICS_PORT=9090                        # Metrics port
```

### Contract Configuration

#### L1 Contracts
```solidity
// RewardFlowAVSRegistrar configuration
address allocationManager = 0x...;       // EigenLayer AllocationManager
address keyRegistrar = 0x...;            // EigenLayer KeyRegistrar
address permissionController = 0x...;    // EigenLayer PermissionController
```

#### L2 Contracts
```solidity
// RewardFlowTaskHook configuration
address rewardToken = 0x...;             // Reward token address
uint96 taskFee = 0.0001 ether;           // Task fee amount
```

## Deployment

### 1. L1 Contract Deployment
```bash
# Deploy L1 contracts
cd contracts
forge script script/deploy/DeployAVSL1Contracts.s.sol \
  --rpc-url $EIGENLAYER_L1_RPC \
  --private-key $AVS_PRIVATE_KEY \
  --broadcast
```

### 2. L2 Contract Deployment
```bash
# Deploy L2 contracts
forge script script/deploy/DeployAVSL2Contracts.s.sol \
  --rpc-url $EIGENLAYER_L2_RPC \
  --private-key $AVS_PRIVATE_KEY \
  --broadcast
```

### 3. Configuration Setup
```bash
# Setup TaskMailbox configuration
forge script script/setup/SetupAVSTaskMailboxConfig.s.sol \
  --rpc-url $EIGENLAYER_L2_RPC \
  --private-key $AVS_PRIVATE_KEY \
  --broadcast
```

### 4. Operator Registration
```bash
# Register operator with AVS
go run cmd/main.go register-operator \
  --avs-address $AVS_ADDRESS \
  --private-key $AVS_PRIVATE_KEY
```

## Operation

### 1. Start AVS Performer
```bash
# Start the AVS performer
go run cmd/main.go start \
  --config config/operator.yaml \
  --log-level info
```

### 2. Docker Deployment
```bash
# Build Docker image
docker build -t rewardflow-avs .

# Run container
docker run -d \
  --name rewardflow-avs \
  --env-file .env \
  -p 8080:8080 \
  -p 9090:9090 \
  rewardflow-avs
```

### 3. Kubernetes Deployment
```bash
# Apply Kubernetes manifests
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

## Monitoring

### 1. Health Checks
```bash
# Check operator health
curl http://localhost:8080/health

# Check task processing status
curl http://localhost:8080/status
```

### 2. Metrics
```bash
# View Prometheus metrics
curl http://localhost:9090/metrics

# Access Grafana dashboard
open http://localhost:3000
```

### 3. Logs
```bash
# View logs
docker logs rewardflow-avs

# Follow logs
docker logs -f rewardflow-avs
```

### 4. Database Monitoring
```sql
-- Check task processing statistics
SELECT 
  status,
  COUNT(*) as count,
  AVG(processing_time) as avg_time
FROM tasks 
GROUP BY status;

-- Check reward distribution statistics
SELECT 
  chain_id,
  COUNT(*) as distributions,
  SUM(amount) as total_amount
FROM reward_distributions 
WHERE created_at >= NOW() - INTERVAL '24 hours'
GROUP BY chain_id;
```

## Task Processing

### 1. Task Types

#### Reward Distribution Tasks
```json
{
  "recipient": "0x...",
  "amount": "1000000000000000000",
  "token_address": "0x...",
  "chain_id": 1,
  "task_type": "liquidity_reward"
}
```

#### MEV Capture Tasks
```json
{
  "recipient": "0x...",
  "amount": "500000000000000000",
  "token_address": "0x...",
  "chain_id": 42161,
  "task_type": "mev_capture"
}
```

### 2. Task Processing Flow
1. **Task Validation**: Validate task parameters and permissions
2. **Reward Calculation**: Calculate final reward amounts
3. **Cross-Chain Routing**: Determine optimal distribution chain
4. **Distribution Execution**: Execute cross-chain transfer
5. **Confirmation**: Confirm successful distribution
6. **Recording**: Record transaction in database

### 3. Error Handling
- **Retry Logic**: Automatic retry for transient failures
- **Dead Letter Queue**: Failed tasks sent to DLQ for manual review
- **Alerting**: Real-time alerts for critical failures
- **Logging**: Comprehensive logging for debugging

## Security

### 1. Key Management
- **Hardware Security Modules**: Use HSMs for production
- **Key Rotation**: Regular key rotation schedule
- **Access Control**: Multi-factor authentication
- **Audit Logging**: Comprehensive audit trails

### 2. Network Security
- **Firewall Rules**: Restrict network access
- **VPN Access**: Secure remote access
- **DDoS Protection**: Protection against attacks
- **Rate Limiting**: API rate limiting

### 3. Data Protection
- **Encryption**: Encrypt sensitive data at rest and in transit
- **Backup Strategy**: Regular automated backups
- **Access Logging**: Monitor data access
- **Compliance**: Meet regulatory requirements

## Maintenance

### 1. Regular Updates
```bash
# Update AVS performer
git pull origin main
go mod tidy
go build -o bin/rewardflow-avs cmd/main.go

# Update contracts
cd contracts
forge update
forge build
```

### 2. Database Maintenance
```sql
-- Clean up old tasks
DELETE FROM tasks WHERE created_at < NOW() - INTERVAL '30 days';

-- Optimize database
VACUUM ANALYZE;

-- Check database health
SELECT * FROM pg_stat_activity;
```

### 3. Performance Optimization
- **Resource Monitoring**: Monitor CPU, memory, and disk usage
- **Database Optimization**: Regular query optimization
- **Caching**: Implement caching for frequently accessed data
- **Load Balancing**: Distribute load across multiple instances

## Troubleshooting

### 1. Common Issues

#### Task Processing Failures
```bash
# Check task status
curl http://localhost:8080/tasks/status

# View failed tasks
curl http://localhost:8080/tasks/failed
```

#### Database Connection Issues
```bash
# Test database connection
go run cmd/main.go test-db

# Check database logs
docker logs rewardflow-postgres
```

#### Network Connectivity
```bash
# Test RPC connectivity
curl -X POST $ETHEREUM_RPC \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### 2. Performance Issues
- **High CPU Usage**: Check for infinite loops or inefficient algorithms
- **Memory Leaks**: Monitor memory usage and restart if necessary
- **Database Slowdown**: Check for long-running queries
- **Network Latency**: Monitor RPC response times

### 3. Recovery Procedures
- **Service Restart**: Restart AVS performer service
- **Database Recovery**: Restore from backup if needed
- **Contract Recovery**: Redeploy contracts if corrupted
- **Key Recovery**: Use backup keys if primary keys are compromised

## Support

### 1. Documentation
- **API Documentation**: Available at `/docs` endpoint
- **Code Documentation**: Inline code documentation
- **Architecture Docs**: System architecture documentation

### 2. Community
- **Discord**: Join the RewardFlow Discord server
- **GitHub Issues**: Report bugs and feature requests
- **Forum**: Technical discussions and Q&A

### 3. Professional Support
- **Enterprise Support**: Available for enterprise operators
- **Consulting Services**: Custom deployment and optimization
- **Training Programs**: Operator training and certification
