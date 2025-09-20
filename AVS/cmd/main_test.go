package main

import (
	"encoding/json"
	"math/big"
	"testing"
	"time"

	performerV1 "github.com/Layr-Labs/protocol-apis/gen/protos/eigenlayer/hourglass/v1/performer"
	"go.uber.org/zap"
)

func TestRewardFlowTaskWorker_ValidateTask(t *testing.T) {
	logger, err := zap.NewDevelopment()
	if err != nil {
		t.Fatalf("Failed to create logger: %v", err)
	}

	worker := NewRewardFlowTaskWorker(logger)

	tests := []struct {
		name        string
		task        RewardDistributionTask
		expectError bool
		errorMsg    string
	}{
		{
			name: "valid liquidity reward task",
			task: RewardDistributionTask{
				User:            "0x1234567890123456789012345678901234567890",
				Amount:          big.NewInt(1000000000000000000), // 1 ETH
				ChainID:         1,
				PoolID:          "0xabcdef1234567890abcdef1234567890abcdef12",
				RewardType:      "liquidity",
				Timestamp:       time.Now().Unix(),
				HookAddress:     "0x9876543210987654321098765432109876543210",
				TransactionHash: "0x1111111111111111111111111111111111111111111111111111111111111111",
			},
			expectError: false,
		},
		{
			name: "valid swap reward task",
			task: RewardDistributionTask{
				User:            "0x1234567890123456789012345678901234567890",
				Amount:          big.NewInt(500000000000000000), // 0.5 ETH
				ChainID:         10,
				PoolID:          "0xabcdef1234567890abcdef1234567890abcdef12",
				RewardType:      "swap",
				Timestamp:       time.Now().Unix(),
				HookAddress:     "0x9876543210987654321098765432109876543210",
				TransactionHash: "0x2222222222222222222222222222222222222222222222222222222222222222",
			},
			expectError: false,
		},
		{
			name: "valid MEV reward task",
			task: RewardDistributionTask{
				User:            "0x1234567890123456789012345678901234567890",
				Amount:          big.NewInt(2000000000000000000), // 2 ETH
				ChainID:         42161,
				PoolID:          "0xabcdef1234567890abcdef1234567890abcdef12",
				RewardType:      "mev",
				Timestamp:       time.Now().Unix(),
				HookAddress:     "0x9876543210987654321098765432109876543210",
				TransactionHash: "0x3333333333333333333333333333333333333333333333333333333333333333",
			},
			expectError: false,
		},
		{
			name: "invalid user address",
			task: RewardDistributionTask{
				User:            "",
				Amount:          big.NewInt(1000000000000000000),
				ChainID:         1,
				PoolID:          "0xabcdef1234567890abcdef1234567890abcdef12",
				RewardType:      "liquidity",
				Timestamp:       time.Now().Unix(),
				HookAddress:     "0x9876543210987654321098765432109876543210",
				TransactionHash: "0x1111111111111111111111111111111111111111111111111111111111111111",
			},
			expectError: true,
			errorMsg:    "user address is required",
		},
		{
			name: "amount too small",
			task: RewardDistributionTask{
				User:            "0x1234567890123456789012345678901234567890",
				Amount:          big.NewInt(100000000000000), // 0.0001 ETH (too small)
				ChainID:         1,
				PoolID:          "0xabcdef1234567890abcdef1234567890abcdef12",
				RewardType:      "liquidity",
				Timestamp:       time.Now().Unix(),
				HookAddress:     "0x9876543210987654321098765432109876543210",
				TransactionHash: "0x1111111111111111111111111111111111111111111111111111111111111111",
			},
			expectError: true,
			errorMsg:    "reward amount below minimum threshold",
		},
		{
			name: "amount too large",
			task: RewardDistributionTask{
				User:            "0x1234567890123456789012345678901234567890",
				Amount:          big.NewInt(101).Mul(big.NewInt(101), big.NewInt(1e18)), // 101 ETH (too large)
				ChainID:         1,
				PoolID:          "0xabcdef1234567890abcdef1234567890abcdef12",
				RewardType:      "liquidity",
				Timestamp:       time.Now().Unix(),
				HookAddress:     "0x9876543210987654321098765432109876543210",
				TransactionHash: "0x1111111111111111111111111111111111111111111111111111111111111111",
			},
			expectError: true,
			errorMsg:    "reward amount exceeds maximum threshold",
		},
		{
			name: "invalid chain ID",
			task: RewardDistributionTask{
				User:            "0x1234567890123456789012345678901234567890",
				Amount:          big.NewInt(1000000000000000000),
				ChainID:         0,
				PoolID:          "0xabcdef1234567890abcdef1234567890abcdef12",
				RewardType:      "liquidity",
				Timestamp:       time.Now().Unix(),
				HookAddress:     "0x9876543210987654321098765432109876543210",
				TransactionHash: "0x1111111111111111111111111111111111111111111111111111111111111111",
			},
			expectError: true,
			errorMsg:    "chain ID is required",
		},
		{
			name: "invalid reward type",
			task: RewardDistributionTask{
				User:            "0x1234567890123456789012345678901234567890",
				Amount:          big.NewInt(1000000000000000000),
				ChainID:         1,
				PoolID:          "0xabcdef1234567890abcdef1234567890abcdef12",
				RewardType:      "invalid",
				Timestamp:       time.Now().Unix(),
				HookAddress:     "0x9876543210987654321098765432109876543210",
				TransactionHash: "0x1111111111111111111111111111111111111111111111111111111111111111",
			},
			expectError: true,
			errorMsg:    "invalid reward type",
		},
		{
			name: "timestamp too old",
			task: RewardDistributionTask{
				User:            "0x1234567890123456789012345678901234567890",
				Amount:          big.NewInt(1000000000000000000),
				ChainID:         1,
				PoolID:          "0xabcdef1234567890abcdef1234567890abcdef12",
				RewardType:      "liquidity",
				Timestamp:       time.Now().Unix() - 25*60*60, // 25 hours ago
				HookAddress:     "0x9876543210987654321098765432109876543210",
				TransactionHash: "0x1111111111111111111111111111111111111111111111111111111111111111",
			},
			expectError: true,
			errorMsg:    "task timestamp too old",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Marshal task to JSON
			taskData, err := json.Marshal(tt.task)
			if err != nil {
				t.Fatalf("Failed to marshal task: %v", err)
			}

			// Create task request
			taskRequest := &performerV1.TaskRequest{
				TaskId:  []byte("test-task-id-" + tt.name),
				Payload: taskData,
			}

			// Validate task
			err = worker.ValidateTask(taskRequest)
			if tt.expectError {
				if err == nil {
					t.Errorf("Expected error but got none")
				} else if tt.errorMsg != "" && err.Error() != tt.errorMsg {
					t.Errorf("Expected error message '%s', got '%s'", tt.errorMsg, err.Error())
				}
			} else {
				if err != nil {
					t.Errorf("Unexpected error: %v", err)
				}
			}
		})
	}
}

func TestRewardFlowTaskWorker_HandleTask(t *testing.T) {
	logger, err := zap.NewDevelopment()
	if err != nil {
		t.Fatalf("Failed to create logger: %v", err)
	}

	worker := NewRewardFlowTaskWorker(logger)

	task := RewardDistributionTask{
		User:            "0x1234567890123456789012345678901234567890",
		Amount:          big.NewInt(1000000000000000000), // 1 ETH
		ChainID:         1,
		PoolID:          "0xabcdef1234567890abcdef1234567890abcdef12",
		RewardType:      "liquidity",
		Timestamp:       time.Now().Unix(),
		HookAddress:     "0x9876543210987654321098765432109876543210",
		TransactionHash: "0x1111111111111111111111111111111111111111111111111111111111111111",
	}

	// Marshal task to JSON
	taskData, err := json.Marshal(task)
	if err != nil {
		t.Fatalf("Failed to marshal task: %v", err)
	}

	// Create task request
	taskRequest := &performerV1.TaskRequest{
		TaskId:  []byte("test-task-id-handle"),
		Payload: taskData,
	}

	// Handle task
	response, err := worker.HandleTask(taskRequest)
	if err != nil {
		t.Fatalf("HandleTask failed: %v", err)
	}

	// Verify response
	if string(response.TaskId) != string(taskRequest.TaskId) {
		t.Errorf("Expected task ID %s, got %s", string(taskRequest.TaskId), string(response.TaskId))
	}

	// Parse result
	var result RewardDistributionResult
	err = json.Unmarshal(response.Result, &result)
	if err != nil {
		t.Fatalf("Failed to unmarshal result: %v", err)
	}

	// Verify result
	if !result.Success {
		t.Errorf("Expected successful processing, but got error: %s", result.Error)
	}

	if result.DistributedAmount == nil || result.DistributedAmount.Cmp(big.NewInt(0)) <= 0 {
		t.Errorf("Expected positive distributed amount, got %v", result.DistributedAmount)
	}

	if result.FeeAmount == nil || result.FeeAmount.Cmp(big.NewInt(0)) <= 0 {
		t.Errorf("Expected positive fee amount, got %v", result.FeeAmount)
	}

	// Verify fee calculation (should be 0.1% of original amount)
	expectedFee := new(big.Int).Div(new(big.Int).Mul(task.Amount, big.NewInt(1)), big.NewInt(1000))
	if result.FeeAmount.Cmp(expectedFee) != 0 {
		t.Errorf("Expected fee %v, got %v", expectedFee, result.FeeAmount)
	}

	// Verify distributed amount (should be original amount minus fee)
	expectedDistributed := new(big.Int).Sub(task.Amount, expectedFee)
	if result.DistributedAmount.Cmp(expectedDistributed) != 0 {
		t.Errorf("Expected distributed amount %v, got %v", expectedDistributed, result.DistributedAmount)
	}
}

func TestRewardFlowTaskWorker_Statistics(t *testing.T) {
	logger, err := zap.NewDevelopment()
	if err != nil {
		t.Fatalf("Failed to create logger: %v", err)
	}

	worker := NewRewardFlowTaskWorker(logger)

	// Initial stats should be zero
	stats := worker.GetStats()
	if stats.TotalTasksProcessed != 0 {
		t.Errorf("Expected 0 tasks processed, got %d", stats.TotalTasksProcessed)
	}

	// Process a task
	task := RewardDistributionTask{
		User:            "0x1234567890123456789012345678901234567890",
		Amount:          big.NewInt(1000000000000000000), // 1 ETH
		ChainID:         1,
		PoolID:          "0xabcdef1234567890abcdef1234567890abcdef12",
		RewardType:      "liquidity",
		Timestamp:       time.Now().Unix(),
		HookAddress:     "0x9876543210987654321098765432109876543210",
		TransactionHash: "0x1111111111111111111111111111111111111111111111111111111111111111",
	}

	taskData, err := json.Marshal(task)
	if err != nil {
		t.Fatalf("Failed to marshal task: %v", err)
	}

	taskRequest := &performerV1.TaskRequest{
		TaskId:  []byte("test-task-id-stats"),
		Payload: taskData,
	}

	_, err = worker.HandleTask(taskRequest)
	if err != nil {
		t.Fatalf("HandleTask failed: %v", err)
	}

	// Check updated stats
	stats = worker.GetStats()
	if stats.TotalTasksProcessed != 1 {
		t.Errorf("Expected 1 task processed, got %d", stats.TotalTasksProcessed)
	}

	if stats.TotalRewardsDistributed.Cmp(big.NewInt(0)) <= 0 {
		t.Errorf("Expected positive rewards distributed, got %v", stats.TotalRewardsDistributed)
	}
}

func TestRewardFlowTaskWorker_MEVRewards(t *testing.T) {
	logger, err := zap.NewDevelopment()
	if err != nil {
		t.Fatalf("Failed to create logger: %v", err)
	}

	worker := NewRewardFlowTaskWorker(logger)

	// Process a MEV reward task
	task := RewardDistributionTask{
		User:            "0x1234567890123456789012345678901234567890",
		Amount:          big.NewInt(5000000000000000000), // 5 ETH
		ChainID:         1,
		PoolID:          "0xabcdef1234567890abcdef1234567890abcdef12",
		RewardType:      "mev",
		Timestamp:       time.Now().Unix(),
		HookAddress:     "0x9876543210987654321098765432109876543210",
		TransactionHash: "0x1111111111111111111111111111111111111111111111111111111111111111",
	}

	taskData, err := json.Marshal(task)
	if err != nil {
		t.Fatalf("Failed to marshal task: %v", err)
	}

	taskRequest := &performerV1.TaskRequest{
		TaskId:  []byte("test-task-id-mev"),
		Payload: taskData,
	}

	_, err = worker.HandleTask(taskRequest)
	if err != nil {
		t.Fatalf("HandleTask failed: %v", err)
	}

	// Check MEV stats
	stats := worker.GetStats()
	if stats.TotalMEVCaptured.Cmp(big.NewInt(0)) <= 0 {
		t.Errorf("Expected positive MEV captured, got %v", stats.TotalMEVCaptured)
	}

	if stats.TotalMEVCaptured.Cmp(task.Amount) != 0 {
		t.Errorf("Expected MEV captured %v, got %v", task.Amount, stats.TotalMEVCaptured)
	}
}

func TestRewardFlowTaskWorker_CrossChainDistribution(t *testing.T) {
	logger, err := zap.NewDevelopment()
	if err != nil {
		t.Fatalf("Failed to create logger: %v", err)
	}

	worker := NewRewardFlowTaskWorker(logger)

	tests := []struct {
		name          string
		sourceChain   uint64
		user          string
		expectedChain uint64
	}{
		{
			name:          "Ethereum to Optimism",
			sourceChain:   1,
			user:          "0x1234567890123456789012345678901234567890",
			expectedChain: 10, // Should be different from source
		},
		{
			name:          "Optimism to Arbitrum",
			sourceChain:   10,
			user:          "0xabcdef1234567890abcdef1234567890abcdef12",
			expectedChain: 42161, // Should be different from source
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			task := RewardDistributionTask{
				User:            tt.user,
				Amount:          big.NewInt(1000000000000000000),
				ChainID:         tt.sourceChain,
				PoolID:          "0xabcdef1234567890abcdef1234567890abcdef12",
				RewardType:      "liquidity",
				Timestamp:       time.Now().Unix(),
				HookAddress:     "0x9876543210987654321098765432109876543210",
				TransactionHash: "0x1111111111111111111111111111111111111111111111111111111111111111",
			}

			taskData, err := json.Marshal(task)
			if err != nil {
				t.Fatalf("Failed to marshal task: %v", err)
			}

			taskRequest := &performerV1.TaskRequest{
				TaskId:  []byte("test-task-id-" + tt.name),
				Payload: taskData,
			}

			response, err := worker.HandleTask(taskRequest)
			if err != nil {
				t.Fatalf("HandleTask failed: %v", err)
			}

			var result RewardDistributionResult
			err = json.Unmarshal(response.Result, &result)
			if err != nil {
				t.Fatalf("Failed to unmarshal result: %v", err)
			}

			// Target chain should be different from source chain
			if result.TargetChain == tt.sourceChain {
				t.Errorf("Expected target chain to be different from source chain %d, got %d", tt.sourceChain, result.TargetChain)
			}

			// Target chain should be one of the supported chains
			supportedChains := []uint64{1, 10, 42161, 137, 8453}
			found := false
			for _, chain := range supportedChains {
				if result.TargetChain == chain {
					found = true
					break
				}
			}
			if !found {
				t.Errorf("Target chain %d is not in supported chains %v", result.TargetChain, supportedChains)
			}
		})
	}
}
