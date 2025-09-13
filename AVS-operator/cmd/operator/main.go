package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"

	"rewardflow-operator/pkg/config"
	"rewardflow-operator/pkg/operator"
)

func main() {
	// Load configuration
	cfg, err := config.LoadConfig()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Create operator instance
	op, err := operator.NewOperator(cfg)
	if err != nil {
		log.Fatalf("Failed to create operator: %v", err)
	}

	// Start operator
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle shutdown signals
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-sigChan
		log.Println("Shutting down operator...")
		cancel()
	}()

	// Run operator
	if err := op.Run(ctx); err != nil {
		log.Fatalf("Operator failed: %v", err)
	}

	log.Println("Operator stopped")
}
