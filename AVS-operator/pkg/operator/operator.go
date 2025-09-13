package operator

import (
	"context"
	"fmt"
	"log"
	"time"

	"rewardflow-operator/pkg/config"
	"rewardflow-operator/pkg/aggregator"
	"rewardflow-operator/pkg/monitor"
	"rewardflow-operator/pkg/database"
)

// Operator represents the RewardFlow AVS operator
type Operator struct {
	config     *config.Config
	aggregator *aggregator.Aggregator
	monitor    *monitor.Monitor
	database   *database.Database
}

// NewOperator creates a new operator instance
func NewOperator(cfg *config.Config) (*Operator, error) {
	// Initialize database
	db, err := database.NewDatabase(cfg.DatabaseURL)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize database: %w", err)
	}

	// Initialize aggregator
	agg, err := aggregator.NewAggregator(cfg, db)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize aggregator: %w", err)
	}

	// Initialize monitor
	mon, err := monitor.NewMonitor(cfg, db)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize monitor: %w", err)
	}

	return &Operator{
		config:     cfg,
		aggregator: agg,
		monitor:    mon,
		database:   db,
	}, nil
}

// Run starts the operator
func (o *Operator) Run(ctx context.Context) error {
	log.Println("Starting RewardFlow operator...")

	// Start aggregator
	go func() {
		if err := o.aggregator.Start(ctx); err != nil {
			log.Printf("Aggregator error: %v", err)
		}
	}()

	// Start monitor
	go func() {
		if err := o.monitor.Start(ctx); err != nil {
			log.Printf("Monitor error: %v", err)
		}
	}()

	// Wait for context cancellation
	<-ctx.Done()

	// Graceful shutdown
	log.Println("Shutting down operator...")
	
	// Stop aggregator
	if err := o.aggregator.Stop(); err != nil {
		log.Printf("Error stopping aggregator: %v", err)
	}

	// Stop monitor
	if err := o.monitor.Stop(); err != nil {
		log.Printf("Error stopping monitor: %v", err)
	}

	// Close database
	if err := o.database.Close(); err != nil {
		log.Printf("Error closing database: %v", err)
	}

	return nil
}

// GetStatus returns the current status of the operator
func (o *Operator) GetStatus() map[string]interface{} {
	return map[string]interface{}{
		"aggregator_status": o.aggregator.GetStatus(),
		"monitor_status":    o.monitor.GetStatus(),
		"database_status":   o.database.GetStatus(),
		"uptime":           time.Since(time.Now()).String(),
	}
}
