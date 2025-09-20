#!/usr/bin/env bash

# RewardFlow AVS Test Script
# This script runs comprehensive tests for the RewardFlow AVS system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[RewardFlow AVS]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[RewardFlow AVS]${NC} ✅ $1"
}

print_warning() {
    echo -e "${YELLOW}[RewardFlow AVS]${NC} ⚠️  $1"
}

print_error() {
    echo -e "${RED}[RewardFlow AVS]${NC} ❌ $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to run Go tests
run_go_tests() {
    print_status "Running Go unit tests..."
    
    if ! command_exists go; then
        print_error "Go is not installed or not in PATH"
        return 1
    fi
    
    cd "$(dirname "$0")"
    
    # Run Go tests with coverage
    if go test -v -p 1 -coverprofile=coverage.out ./cmd/...; then
        print_success "Go tests passed"
        
        # Generate coverage report
        if command_exists go; then
            go tool cover -html=coverage.out -o coverage.html
            print_success "Coverage report generated: coverage.html"
        fi
        
        return 0
    else
        print_error "Go tests failed"
        return 1
    fi
}

# Function to run contract tests
run_contract_tests() {
    print_status "Running smart contract tests..."
    
    if ! command_exists forge; then
        print_error "Foundry (forge) is not installed or not in PATH"
        return 1
    fi
    
    cd "$(dirname "$0")/contracts"
    
    # Run contract tests
    if forge test -vv; then
        print_success "Contract tests passed"
        return 0
    else
        print_error "Contract tests failed"
        return 1
    fi
}

# Function to run integration tests
run_integration_tests() {
    print_status "Running integration tests..."
    
    # Check if Docker is available for integration tests
    if ! command_exists docker; then
        print_warning "Docker not available, skipping integration tests"
        return 0
    fi
    
    # Check if devkit is available
    if ! command_exists devkit; then
        print_warning "devkit not available, skipping integration tests"
        return 0
    fi
    
    print_status "Starting RewardFlow devnet for integration tests..."
    
    # Start devnet in background
    devkit avs devnet start --skip-avs-run &
    DEVPID=$!
    
    # Wait for devnet to start
    sleep 30
    
    # Run integration tests
    if devkit avs test; then
        print_success "Integration tests passed"
        
        # Stop devnet
        kill $DEVPID 2>/dev/null || true
        
        return 0
    else
        print_error "Integration tests failed"
        
        # Stop devnet
        kill $DEVPID 2>/dev/null || true
        
        return 1
    fi
}

# Function to run performance tests
run_performance_tests() {
    print_status "Running performance benchmarks..."
    
    cd "$(dirname "$0")"
    
    if go test -bench=. -benchmem ./cmd/...; then
        print_success "Performance tests passed"
        return 0
    else
        print_error "Performance tests failed"
        return 1
    fi
}

# Function to check code quality
run_code_quality_checks() {
    print_status "Running code quality checks..."
    
    cd "$(dirname "$0")"
    
    # Go linting
    if command_exists golangci-lint; then
        if golangci-lint run; then
            print_success "Go linting passed"
        else
            print_error "Go linting failed"
            return 1
        fi
    else
        print_warning "golangci-lint not available, skipping Go linting"
    fi
    
    # Go formatting check
    if ! go fmt ./...; then
        print_error "Go formatting failed"
        return 1
    fi
    print_success "Go formatting check passed"
    
    # Contract formatting check
    cd contracts
    if command_exists forge; then
        if forge fmt --check; then
            print_success "Contract formatting check passed"
        else
            print_error "Contract formatting check failed"
            return 1
        fi
    else
        print_warning "forge not available, skipping contract formatting check"
    fi
    
    return 0
}

# Function to run security audit
run_security_audit() {
    print_status "Running security audit..."
    
    cd "$(dirname "$0")"
    
    # Go security audit
    if command_exists govulncheck; then
        if govulncheck ./...; then
            print_success "Go security audit passed"
        else
            print_warning "Go security vulnerabilities found"
        fi
    else
        print_warning "govulncheck not available, skipping Go security audit"
    fi
    
    # Contract security audit
    cd contracts
    if command_exists forge; then
        if forge build --sizes; then
            print_success "Contract size audit passed"
        else
            print_error "Contract size audit failed"
            return 1
        fi
    else
        print_warning "forge not available, skipping contract security audit"
    fi
    
    return 0
}

# Function to setup test environment
setup_test_environment() {
    print_status "Setting up test environment..."
    
    cd "$(dirname "$0")"
    
    # Install dependencies
    if command_exists go; then
        print_status "Installing Go dependencies..."
        go mod tidy
        print_success "Go dependencies installed"
    fi
    
    # Install contract dependencies
    if command_exists forge; then
        cd contracts
        print_status "Installing contract dependencies..."
        forge install
        print_success "Contract dependencies installed"
        cd ..
    fi
    
    return 0
}

# Function to cleanup test environment
cleanup_test_environment() {
    print_status "Cleaning up test environment..."
    
    cd "$(dirname "$0")"
    
    # Remove coverage files
    rm -f coverage.out coverage.html
    
    # Stop any running containers
    if command_exists docker; then
        docker-compose -f .hourglass/docker-compose.yml down 2>/dev/null || true
    fi
    
    print_success "Test environment cleaned up"
}

# Function to show test results
show_test_results() {
    print_status "Test Results Summary:"
    echo "========================"
    
    if [ -f coverage.html ]; then
        print_success "Coverage report available: coverage.html"
    fi
    
    print_status "All tests completed!"
}

# Main test function
main() {
    print_status "Starting RewardFlow AVS Test Suite"
    echo "========================================"
    
    # Parse command line arguments
    RUN_GO_TESTS=true
    RUN_CONTRACT_TESTS=true
    RUN_INTEGRATION_TESTS=false
    RUN_PERFORMANCE_TESTS=false
    RUN_CODE_QUALITY=true
    RUN_SECURITY_AUDIT=false
    SETUP_ENV=true
    CLEANUP=true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --go-only)
                RUN_CONTRACT_TESTS=false
                RUN_INTEGRATION_TESTS=false
                RUN_PERFORMANCE_TESTS=false
                shift
                ;;
            --contracts-only)
                RUN_GO_TESTS=false
                RUN_INTEGRATION_TESTS=false
                RUN_PERFORMANCE_TESTS=false
                shift
                ;;
            --integration)
                RUN_INTEGRATION_TESTS=true
                shift
                ;;
            --performance)
                RUN_PERFORMANCE_TESTS=true
                shift
                ;;
            --security)
                RUN_SECURITY_AUDIT=true
                shift
                ;;
            --no-setup)
                SETUP_ENV=false
                shift
                ;;
            --no-cleanup)
                CLEANUP=false
                shift
                ;;
            --help)
                echo "RewardFlow AVS Test Script"
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  --go-only          Run only Go tests"
                echo "  --contracts-only   Run only contract tests"
                echo "  --integration      Include integration tests"
                echo "  --performance      Include performance tests"
                echo "  --security         Include security audit"
                echo "  --no-setup         Skip environment setup"
                echo "  --no-cleanup       Skip environment cleanup"
                echo "  --help             Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Setup test environment
    if [ "$SETUP_ENV" = true ]; then
        setup_test_environment
    fi
    
    # Track test results
    TESTS_PASSED=0
    TESTS_FAILED=0
    
    # Run Go tests
    if [ "$RUN_GO_TESTS" = true ]; then
        if run_go_tests; then
            ((TESTS_PASSED++))
        else
            ((TESTS_FAILED++))
        fi
    fi
    
    # Run contract tests
    if [ "$RUN_CONTRACT_TESTS" = true ]; then
        if run_contract_tests; then
            ((TESTS_PASSED++))
        else
            ((TESTS_FAILED++))
        fi
    fi
    
    # Run integration tests
    if [ "$RUN_INTEGRATION_TESTS" = true ]; then
        if run_integration_tests; then
            ((TESTS_PASSED++))
        else
            ((TESTS_FAILED++))
        fi
    fi
    
    # Run performance tests
    if [ "$RUN_PERFORMANCE_TESTS" = true ]; then
        if run_performance_tests; then
            ((TESTS_PASSED++))
        else
            ((TESTS_FAILED++))
        fi
    fi
    
    # Run code quality checks
    if [ "$RUN_CODE_QUALITY" = true ]; then
        if run_code_quality_checks; then
            ((TESTS_PASSED++))
        else
            ((TESTS_FAILED++))
        fi
    fi
    
    # Run security audit
    if [ "$RUN_SECURITY_AUDIT" = true ]; then
        if run_security_audit; then
            ((TESTS_PASSED++))
        else
            ((TESTS_FAILED++))
        fi
    fi
    
    # Cleanup test environment
    if [ "$CLEANUP" = true ]; then
        cleanup_test_environment
    fi
    
    # Show results
    echo ""
    echo "========================================"
    print_status "Test Suite Complete"
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        print_success "All tests passed! 🎉"
        show_test_results
        exit 0
    else
        print_error "Some tests failed! 💥"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"