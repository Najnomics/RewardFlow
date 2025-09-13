// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RewardMath} from "../../hooks/libraries/RewardMath.sol";

/**
 * @title RewardScheduling
 * @notice Library for reward scheduling and task management
 */
library RewardScheduling {
    using RewardMath for uint256;

    /// @notice Aggregation task structure
    struct AggregationTask {
        uint256 taskId;
        address[] users;
        uint256[] amounts;
        uint256[] targetChains;
        uint256 deadline;
        TaskStatus status;
        uint256 createdAt;
        uint256 completedAt;
        string failureReason;
    }

    /// @notice Task status
    enum TaskStatus {
        PENDING,
        IN_PROGRESS,
        COMPLETED,
        FAILED,
        CANCELLED
    }

    /// @notice Scheduling configuration
    struct SchedulingConfig {
        uint256 aggregationWindow;
        uint256 maxTaskSize;
        uint256 minTaskSize;
        uint256 retryDelay;
        uint256 maxRetries;
        uint256 priorityThreshold;
    }

    /// @notice Task priority levels
    enum TaskPriority {
        LOW,
        MEDIUM,
        HIGH,
        URGENT
    }

    /// @notice Constants
    uint256 public constant DEFAULT_AGGREGATION_WINDOW = 1 hours;
    uint256 public constant DEFAULT_MAX_TASK_SIZE = 1000;
    uint256 public constant DEFAULT_MIN_TASK_SIZE = 10;
    uint256 public constant DEFAULT_RETRY_DELAY = 5 minutes;
    uint256 public constant DEFAULT_MAX_RETRIES = 3;
    uint256 public constant DEFAULT_PRIORITY_THRESHOLD = 100e18; // 100 ETH

    /// @notice Get default scheduling configuration
    function getDefaultConfig() internal pure returns (SchedulingConfig memory) {
        return SchedulingConfig({
            aggregationWindow: DEFAULT_AGGREGATION_WINDOW,
            maxTaskSize: DEFAULT_MAX_TASK_SIZE,
            minTaskSize: DEFAULT_MIN_TASK_SIZE,
            retryDelay: DEFAULT_RETRY_DELAY,
            maxRetries: DEFAULT_MAX_RETRIES,
            priorityThreshold: DEFAULT_PRIORITY_THRESHOLD
        });
    }

    /// @notice Calculate task priority
    function calculateTaskPriority(
        uint256 totalAmount,
        uint256 userCount,
        uint256 urgency
    ) internal pure returns (TaskPriority) {
        uint256 averageAmount = totalAmount / userCount;
        
        if (averageAmount >= 1000e18 || urgency >= 90) {
            return TaskPriority.URGENT;
        } else if (averageAmount >= 100e18 || urgency >= 70) {
            return TaskPriority.HIGH;
        } else if (averageAmount >= 10e18 || urgency >= 40) {
            return TaskPriority.MEDIUM;
        } else {
            return TaskPriority.LOW;
        }
    }

    /// @notice Check if task is ready for execution
    function isTaskReadyForExecution(
        AggregationTask storage task,
        SchedulingConfig memory config
    ) internal view returns (bool) {
        return task.status == TaskStatus.PENDING &&
               block.timestamp >= task.createdAt + config.aggregationWindow &&
               task.users.length >= config.minTaskSize;
    }

    /// @notice Check if task should be retried
    function shouldRetryTask(
        AggregationTask storage task,
        SchedulingConfig memory config
    ) internal view returns (bool) {
        return task.status == TaskStatus.FAILED &&
               block.timestamp >= task.completedAt + config.retryDelay &&
               task.createdAt + (config.maxRetries * config.retryDelay) > block.timestamp;
    }

    /// @notice Calculate optimal task size
    function calculateOptimalTaskSize(
        uint256 totalUsers,
        uint256 gasLimit,
        SchedulingConfig memory config
    ) internal pure returns (uint256) {
        uint256 optimalSize = gasLimit / 100000; // Approximate gas per user
        
        if (optimalSize > totalUsers) {
            optimalSize = totalUsers;
        }
        
        if (optimalSize < config.minTaskSize) {
            optimalSize = config.minTaskSize;
        }
        
        if (optimalSize > config.maxTaskSize) {
            optimalSize = config.maxTaskSize;
        }
        
        return optimalSize;
    }

    /// @notice Calculate task execution time
    function calculateExecutionTime(
        uint256 userCount,
        uint256 averageAmount
    ) internal pure returns (uint256) {
        // Base time for task processing
        uint256 baseTime = 5 minutes;
        
        // Additional time based on user count
        uint256 userTime = userCount * 30; // 30 seconds per user
        
        // Additional time based on amount (larger amounts take longer)
        uint256 amountTime = averageAmount / 1e18; // 1 second per ETH
        
        return baseTime + userTime + amountTime;
    }

    /// @notice Calculate task efficiency score
    function calculateTaskEfficiency(
        AggregationTask storage task
    ) internal view returns (uint256) {
        if (task.status != TaskStatus.COMPLETED) return 0;
        
        uint256 executionTime = task.completedAt - task.createdAt;
        uint256 totalAmount = _sum(task.amounts);
        uint256 averageAmount = totalAmount / task.users.length;
        
        // Efficiency = total amount / execution time
        return totalAmount.mulDiv(1e18, executionTime);
    }

    /// @notice Check if task is expired
    function isTaskExpired(
        AggregationTask storage task
    ) internal view returns (bool) {
        return block.timestamp > task.deadline;
    }

    /// @notice Calculate task completion percentage
    function calculateTaskCompletion(
        AggregationTask storage task
    ) internal view returns (uint256) {
        if (task.status == TaskStatus.COMPLETED) return 100;
        if (task.status == TaskStatus.FAILED) return 0;
        
        uint256 timeElapsed = block.timestamp - task.createdAt;
        uint256 totalTime = task.deadline - task.createdAt;
        
        if (totalTime == 0) return 0;
        
        return timeElapsed.mulDiv(100, totalTime);
    }

    /// @notice Calculate task cost
    function calculateTaskCost(
        AggregationTask storage task,
        uint256 gasPrice
    ) internal pure returns (uint256) {
        uint256 estimatedGas = task.users.length * 100000; // 100k gas per user
        return estimatedGas * gasPrice;
    }

    /// @notice Calculate task profitability
    function calculateTaskProfitability(
        AggregationTask storage task,
        uint256 gasPrice
    ) internal pure returns (bool) {
        uint256 totalAmount = _sum(task.amounts);
        uint256 taskCost = calculateTaskCost(task, gasPrice);
        
        // Task is profitable if total amount > 2x task cost
        return totalAmount > taskCost * 2;
    }

    /// @notice Get task statistics
    function getTaskStatistics(
        mapping(bytes32 => AggregationTask) storage tasks
    ) internal view returns (
        uint256 totalTasks,
        uint256 completedTasks,
        uint256 failedTasks,
        uint256 pendingTasks,
        uint256 totalAmount
    ) {
        // This would iterate through all tasks in practice
        // For now, return placeholder values
        return (0, 0, 0, 0, 0);
    }

    /// @notice Sum array of amounts
    function _sum(uint256[] memory amounts) internal pure returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
        return total;
    }

    /// @notice Validate task data
    function validateTask(
        AggregationTask memory task
    ) internal pure returns (bool) {
        return task.users.length > 0 &&
               task.users.length == task.amounts.length &&
               task.amounts.length == task.targetChains.length &&
               task.deadline > block.timestamp;
    }

    /// @notice Calculate task urgency
    function calculateTaskUrgency(
        AggregationTask storage task
    ) internal view returns (uint256) {
        uint256 timeRemaining = task.deadline - block.timestamp;
        uint256 totalAmount = _sum(task.amounts);
        
        // Urgency increases as time remaining decreases
        // Urgency increases with total amount
        uint256 timeUrgency = timeRemaining < 1 hours ? 100 : 50;
        uint256 amountUrgency = totalAmount > 1000e18 ? 100 : 25;
        
        return (timeUrgency + amountUrgency) / 2;
    }

    /// @notice Get task priority multiplier
    function getTaskPriorityMultiplier(
        TaskPriority priority
    ) internal pure returns (uint256) {
        if (priority == TaskPriority.URGENT) return 2e18; // 2x
        if (priority == TaskPriority.HIGH) return 15e17; // 1.5x
        if (priority == TaskPriority.MEDIUM) return 12e17; // 1.2x
        return 1e18; // 1x
    }
}
