package main

import (
	"context"
	"encoding/json"
	"fmt"
	"math/big"
	"time"

	"github.com/Layr-Labs/hourglass-monorepo/ponos/pkg/performer/server"
	performerV1 "github.com/Layr-Labs/protocol-apis/gen/protos/eigenlayer/hourglass/v1/performer"
	"go.uber.org/zap"
)

// RewardFlowTaskWorker implements the AVS performer interface for RewardFlow
// This handles reward distribution tasks from Uniswap V4 hooks across multiple chains
type RewardFlowTaskWorker struct {
	logger *zap.Logger
	stats  *TaskStats
}

// TaskStats tracks RewardFlow task processing statistics
type TaskStats struct {
	TotalTasksProcessed     int64    `json:"total_tasks_processed"`
	TotalRewardsDistributed *big.Int `json:"total_rewards_distributed"`
	TotalMEVCaptured        *big.Int `json:"total_mev_captured"`
	AverageProcessingTime   int64    `json:"average_processing_time_ms"`
	SuccessRate             float64  `json:"success_rate"`
}

// RewardDistributionTask represents a reward distribution task from Uniswap V4 hooks
type RewardDistributionTask struct {
	User            string   `json:"user"`
	Amount          *big.Int `json:"amount"`
	ChainID         uint64   `json:"chain_id"`
	PoolID          string   `json:"pool_id"`
	RewardType      string   `json:"reward_type"` // "liquidity", "swap", "mev"
	Timestamp       int64    `json:"timestamp"`
	HookAddress     string   `json:"hook_address"`
	TransactionHash string   `json:"transaction_hash"`
}

// RewardDistributionResult represents the result of processing a reward distribution task
type RewardDistributionResult struct {
	TaskID            string   `json:"task_id"`
	Success           bool     `json:"success"`
	DistributedAmount *big.Int `json:"distributed_amount"`
	FeeAmount         *big.Int `json:"fee_amount"`
	TargetChain       uint64   `json:"target_chain"`
	TransactionHash   string   `json:"transaction_hash,omitempty"`
	Error             string   `json:"error,omitempty"`
	ProcessedAt       int64    `json:"processed_at"`
}

// NewRewardFlowTaskWorker creates a new RewardFlow task worker
func NewRewardFlowTaskWorker(logger *zap.Logger) *RewardFlowTaskWorker {
	return &RewardFlowTaskWorker{
		logger: logger,
		stats: &TaskStats{
			TotalRewardsDistributed: big.NewInt(0),
			TotalMEVCaptured:        big.NewInt(0),
		},
	}
}

// ValidateTask validates incoming reward distribution task requests
func (rf *RewardFlowTaskWorker) ValidateTask(t *performerV1.TaskRequest) error {
	rf.logger.Sugar().Infow("Validating RewardFlow task",
		zap.String("task_id", string(t.TaskId)),
		zap.String("task_type", "reward_distribution"),
	)

	// Parse the task data
	var task RewardDistributionTask
	if err := json.Unmarshal(t.Payload, &task); err != nil {
		rf.logger.Error("Failed to unmarshal task data", zap.Error(err))
		return fmt.Errorf("invalid task data format: %w", err)
	}

	// Validate task parameters
	if err := rf.validateTaskParameters(&task); err != nil {
		rf.logger.Error("Task validation failed", zap.Error(err))
		return err
	}

	rf.logger.Sugar().Infow("Task validation successful",
		zap.String("user", task.User),
		zap.String("amount", task.Amount.String()),
		zap.Uint64("chain_id", task.ChainID),
		zap.String("reward_type", task.RewardType),
	)

	return nil
}

// HandleTask processes reward distribution tasks and returns results
func (rf *RewardFlowTaskWorker) HandleTask(t *performerV1.TaskRequest) (*performerV1.TaskResponse, error) {
	startTime := time.Now()

	rf.logger.Sugar().Infow("Processing RewardFlow task",
		zap.String("task_id", string(t.TaskId)),
		zap.String("task_type", "reward_distribution"),
	)

	// Parse the task data
	var task RewardDistributionTask
	if err := json.Unmarshal(t.Payload, &task); err != nil {
		return nil, fmt.Errorf("failed to unmarshal task data: %w", err)
	}

	// Process the reward distribution
	result, err := rf.processRewardDistribution(string(t.TaskId), &task)
	if err != nil {
		rf.logger.Error("Failed to process reward distribution", zap.Error(err))
		result = &RewardDistributionResult{
			TaskID:      string(t.TaskId),
			Success:     false,
			Error:       err.Error(),
			ProcessedAt: time.Now().Unix(),
		}
	}

	// Update statistics
	rf.updateStats(result, time.Since(startTime))

	// Marshal the result
	resultBytes, err := json.Marshal(result)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal result: %w", err)
	}

	rf.logger.Sugar().Infow("Task processing completed",
		zap.String("task_id", string(t.TaskId)),
		zap.Bool("success", result.Success),
		zap.Duration("processing_time", time.Since(startTime)),
	)

	return &performerV1.TaskResponse{
		TaskId: t.TaskId,
		Result: resultBytes,
	}, nil
}

// validateTaskParameters validates the parameters of a reward distribution task
func (rf *RewardFlowTaskWorker) validateTaskParameters(task *RewardDistributionTask) error {
	// Validate user address
	if task.User == "" {
		return fmt.Errorf("user address is required")
	}

	// Validate amount
	if task.Amount == nil || task.Amount.Cmp(big.NewInt(0)) <= 0 {
		return fmt.Errorf("invalid reward amount")
	}

	// Validate minimum reward amount (0.001 ETH)
	minReward := big.NewInt(1000000000000000) // 0.001 ETH in wei
	if task.Amount.Cmp(minReward) < 0 {
		return fmt.Errorf("reward amount below minimum threshold")
	}

	// Validate maximum reward amount (100 ETH)
	maxReward := new(big.Int).Mul(big.NewInt(100), big.NewInt(1e18))
	if task.Amount.Cmp(maxReward) > 0 {
		return fmt.Errorf("reward amount exceeds maximum threshold")
	}

	// Validate chain ID
	if task.ChainID == 0 {
		return fmt.Errorf("chain ID is required")
	}

	// Validate reward type
	validRewardTypes := map[string]bool{
		"liquidity": true,
		"swap":      true,
		"mev":       true,
	}
	if !validRewardTypes[task.RewardType] {
		return fmt.Errorf("invalid reward type: %s", task.RewardType)
	}

	// Validate timestamp
	if task.Timestamp <= 0 {
		return fmt.Errorf("invalid timestamp")
	}

	// Validate timestamp is not too old (max 24 hours)
	maxAge := int64(24 * 60 * 60) // 24 hours in seconds
	if time.Now().Unix()-task.Timestamp > maxAge {
		return fmt.Errorf("task timestamp too old")
	}

	return nil
}

// processRewardDistribution processes a reward distribution task
func (rf *RewardFlowTaskWorker) processRewardDistribution(taskID string, task *RewardDistributionTask) (*RewardDistributionResult, error) {
	rf.logger.Sugar().Infow("Processing reward distribution",
		zap.String("task_id", taskID),
		zap.String("user", task.User),
		zap.String("amount", task.Amount.String()),
		zap.String("reward_type", task.RewardType),
	)

	// Calculate fee (0.1% of reward amount)
	feeRate := big.NewInt(1) // 0.1% = 1/1000
	feeAmount := new(big.Int).Div(new(big.Int).Mul(task.Amount, feeRate), big.NewInt(1000))

	// Calculate distributed amount (reward - fee)
	distributedAmount := new(big.Int).Sub(task.Amount, feeAmount)

	// Simulate cross-chain distribution
	// In a real implementation, this would interact with the Across Protocol or other bridge
	targetChain := rf.determineTargetChain(task.ChainID, task.User)

	// Simulate processing delay
	time.Sleep(100 * time.Millisecond)

	// Update statistics
	rf.stats.TotalRewardsDistributed.Add(rf.stats.TotalRewardsDistributed, distributedAmount)

	if task.RewardType == "mev" {
		rf.stats.TotalMEVCaptured.Add(rf.stats.TotalMEVCaptured, task.Amount)
	}

	result := &RewardDistributionResult{
		TaskID:            taskID,
		Success:           true,
		DistributedAmount: distributedAmount,
		FeeAmount:         feeAmount,
		TargetChain:       targetChain,
		ProcessedAt:       time.Now().Unix(),
	}

	rf.logger.Sugar().Infow("Reward distribution completed",
		zap.String("task_id", taskID),
		zap.String("distributed_amount", distributedAmount.String()),
		zap.String("fee_amount", feeAmount.String()),
		zap.Uint64("target_chain", targetChain),
	)

	return result, nil
}

// determineTargetChain determines the target chain for reward distribution
func (rf *RewardFlowTaskWorker) determineTargetChain(sourceChainID uint64, user string) uint64 {
	// Simple logic: distribute to a different chain based on user hash
	// In a real implementation, this would use user preferences or other logic

	// Map of supported chains
	supportedChains := []uint64{
		1,     // Ethereum Mainnet
		10,    // Optimism
		42161, // Arbitrum
		137,   // Polygon
		8453,  // Base
	}

	// Use user address to deterministically select target chain
	userHash := len(user) % len(supportedChains)
	targetChain := supportedChains[userHash]

	// If target chain is the same as source, pick the next one
	if targetChain == sourceChainID {
		targetChain = supportedChains[(userHash+1)%len(supportedChains)]
	}

	return targetChain
}

// updateStats updates task processing statistics
func (rf *RewardFlowTaskWorker) updateStats(result *RewardDistributionResult, processingTime time.Duration) {
	rf.stats.TotalTasksProcessed++
	rf.stats.AverageProcessingTime = (rf.stats.AverageProcessingTime + processingTime.Milliseconds()) / 2

	// Calculate success rate
	if result.Success {
		rf.stats.SuccessRate = float64(rf.stats.TotalTasksProcessed) / float64(rf.stats.TotalTasksProcessed) * 100
	}
}

// GetStats returns current task processing statistics
func (rf *RewardFlowTaskWorker) GetStats() *TaskStats {
	return rf.stats
}

func main() {
	ctx := context.Background()

	// Initialize logger with RewardFlow-specific configuration
	config := zap.NewProductionConfig()
	config.EncoderConfig.TimeKey = "timestamp"
	config.EncoderConfig.EncodeTime = zap.TimeEncoderOfLayout(time.RFC3339)

	l, err := config.Build()
	if err != nil {
		panic(fmt.Errorf("failed to create logger: %w", err))
	}
	defer l.Sync()

	l.Info("Starting RewardFlow AVS Performer",
		zap.String("version", "1.0.0"),
		zap.String("description", "Uniswap V4 Hook Reward Distribution AVS"),
	)

	// Create RewardFlow task worker
	w := NewRewardFlowTaskWorker(l)

	// Start the performer server
	pp, err := server.NewPonosPerformerWithRpcServer(&server.PonosPerformerConfig{
		Port:    8080,
		Timeout: 30 * time.Second, // Increased timeout for cross-chain operations
	}, w, l)
	if err != nil {
		panic(fmt.Errorf("failed to create RewardFlow performer: %w", err))
	}

	l.Info("RewardFlow AVS Performer started successfully",
		zap.Int("port", 8080),
		zap.Duration("timeout", 30*time.Second),
	)

	if err := pp.Start(ctx); err != nil {
		panic(err)
	}
}
