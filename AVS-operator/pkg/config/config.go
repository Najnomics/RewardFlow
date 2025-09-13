package config

import (
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/spf13/viper"
)

// Config holds all configuration for the operator
type Config struct {
	// Ethereum configuration
	EthereumRPCURL string `mapstructure:"ethereum_rpc_url"`
	PrivateKey     string `mapstructure:"private_key"`
	
	// AVS configuration
	AVSContractAddress string `mapstructure:"avs_contract_address"`
	OperatorAddress    string `mapstructure:"operator_address"`
	
	// Reward aggregation configuration
	AggregationInterval time.Duration `mapstructure:"aggregation_interval"`
	MinRewardThreshold  string        `mapstructure:"min_reward_threshold"`
	MaxBatchSize        int           `mapstructure:"max_batch_size"`
	
	// Cross-chain configuration
	SupportedChains []ChainConfig `mapstructure:"supported_chains"`
	
	// Database configuration
	DatabaseURL string `mapstructure:"database_url"`
	
	// Monitoring configuration
	MetricsPort int `mapstructure:"metrics_port"`
	LogLevel    string `mapstructure:"log_level"`
}

// ChainConfig holds configuration for a supported chain
type ChainConfig struct {
	ChainID     uint64 `mapstructure:"chain_id"`
	RPCURL      string `mapstructure:"rpc_url"`
	BridgeAddress string `mapstructure:"bridge_address"`
}

// LoadConfig loads configuration from environment variables and config file
func LoadConfig() (*Config, error) {
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath("./config")
	viper.AddConfigPath(".")
	
	// Set default values
	setDefaults()
	
	// Read config file
	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, fmt.Errorf("error reading config file: %w", err)
		}
	}
	
	// Override with environment variables
	viper.AutomaticEnv()
	
	var config Config
	if err := viper.Unmarshal(&config); err != nil {
		return nil, fmt.Errorf("error unmarshaling config: %w", err)
	}
	
	// Validate required fields
	if err := validateConfig(&config); err != nil {
		return nil, fmt.Errorf("config validation failed: %w", err)
	}
	
	return &config, nil
}

// setDefaults sets default configuration values
func setDefaults() {
	viper.SetDefault("ethereum_rpc_url", "http://localhost:8545")
	viper.SetDefault("aggregation_interval", "1h")
	viper.SetDefault("min_reward_threshold", "1000000000000000") // 0.001 ETH
	viper.SetDefault("max_batch_size", 100)
	viper.SetDefault("metrics_port", 8080)
	viper.SetDefault("log_level", "info")
	
	// Default supported chains
	viper.SetDefault("supported_chains", []ChainConfig{
		{
			ChainID:       1,
			RPCURL:        "https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY",
			BridgeAddress: "0x0000000000000000000000000000000000000000",
		},
		{
			ChainID:       42161,
			RPCURL:        "https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY",
			BridgeAddress: "0x0000000000000000000000000000000000000000",
		},
		{
			ChainID:       137,
			RPCURL:        "https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY",
			BridgeAddress: "0x0000000000000000000000000000000000000000",
		},
		{
			ChainID:       8453,
			RPCURL:        "https://base-mainnet.g.alchemy.com/v2/YOUR_KEY",
			BridgeAddress: "0x0000000000000000000000000000000000000000",
		},
	})
}

// validateConfig validates the configuration
func validateConfig(config *Config) error {
	if config.EthereumRPCURL == "" {
		return fmt.Errorf("ethereum_rpc_url is required")
	}
	
	if config.PrivateKey == "" {
		return fmt.Errorf("private_key is required")
	}
	
	if config.AVSContractAddress == "" {
		return fmt.Errorf("avs_contract_address is required")
	}
	
	if config.OperatorAddress == "" {
		return fmt.Errorf("operator_address is required")
	}
	
	if len(config.SupportedChains) == 0 {
		return fmt.Errorf("at least one supported chain is required")
	}
	
	return nil
}

// GetEnvOrDefault gets an environment variable or returns the default value
func GetEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// GetEnvOrDefaultInt gets an environment variable as int or returns the default value
func GetEnvOrDefaultInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}
