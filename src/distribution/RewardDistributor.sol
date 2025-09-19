// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Removed AVS dependency - using direct reward distribution
import {DistributionUtils} from "./libraries/DistributionUtils.sol";
import {PreferenceManager} from "./libraries/PreferenceManager.sol";
import {Constants} from "../utils/Constants.sol";
import {Events} from "../utils/Events.sol";
import {Errors} from "../utils/Errors.sol";

/**
 * @title RewardDistributor
 * @notice Across Protocol integration for cross-chain reward distribution
 */
contract RewardDistributor {
    using DistributionUtils for DistributionRequest;
    using PreferenceManager for mapping(address => PreferenceManager.UserPreferences);

    /// @notice Distribution request structure
    struct DistributionRequest {
        address user;
        uint256 amount;
        uint256 sourceChain;
        uint256 targetChain;
        address rewardToken;
        uint256 timestamp;
        bool executed;
        bytes32 requestId;
    }

    /// @notice User preferences
    struct UserPreferences {
        uint256 preferredChain;
        uint256 claimThreshold;
        uint256 claimFrequency;
        bool autoClaimEnabled;
        uint256 lastUpdate;
    }

    /// @notice Distribution statistics
    struct DistributionStats {
        uint256 totalDistributed;
        uint256 totalRequests;
        uint256 successfulDistributions;
        uint256 failedDistributions;
        uint256 totalFees;
    }

    /// @notice State variables
    address public immutable rewardToken;
    address public immutable spokePool;
    
    mapping(bytes32 => DistributionRequest) public distributionRequests;
    mapping(address => UserPreferences) public userPreferences;
    mapping(uint256 => bool) public supportedChains;
    
    DistributionStats public distributionStats;
    
    address public owner;
    bool public paused;

    /// @notice Events
    event RewardDistributionInitiated(
        bytes32 indexed requestId,
        address indexed user,
        uint256 amount,
        uint256 targetChain
    );
    
    event RewardDistributionExecuted(
        bytes32 indexed requestId,
        uint256 depositId
    );
    
    event RewardDistributionFailed(
        bytes32 indexed requestId,
        string reason
    );
    
    event PreferencesUpdated(
        address indexed user,
        uint256 preferredChain,
        uint256 claimThreshold
    );
    
    event ChainSupportUpdated(
        uint256 chainId,
        bool supported
    );

    /// @notice Errors
    error Unauthorized();
    error Paused();
    error InvalidAmount();
    error UnsupportedChain();
    error DistributionFailed();
    error RequestNotFound();
    error RequestAlreadyExecuted();

    /// @notice Modifiers
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyAuthorized() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    constructor(
        address _rewardToken,
        address _spokePool
    ) {
        rewardToken = _rewardToken;
        spokePool = _spokePool;
        owner = msg.sender;
        
        // Initialize supported chains
        supportedChains[1] = true; // Ethereum
        supportedChains[42161] = true; // Arbitrum
        supportedChains[137] = true; // Polygon
        supportedChains[8453] = true; // Base
    }

    /// @notice Execute reward distribution
    function executeRewardDistribution(
        address user,
        uint256 amount,
        uint256 targetChain
    ) external onlyAuthorized whenNotPaused {
        _executeRewardDistribution(user, amount, targetChain);
    }

    /// @notice Internal reward distribution execution
    function _executeRewardDistribution(
        address user,
        uint256 amount,
        uint256 targetChain
    ) internal {
        if (amount == 0) revert InvalidAmount();
        if (!supportedChains[targetChain]) revert UnsupportedChain();
        
        // Create distribution request
        bytes32 requestId = keccak256(abi.encode(
            user, amount, block.chainid, targetChain, block.timestamp
        ));
        
        distributionRequests[requestId] = DistributionRequest({
            user: user,
            amount: amount,
            sourceChain: block.chainid,
            targetChain: targetChain,
            rewardToken: rewardToken,
            timestamp: block.timestamp,
            executed: false,
            requestId: requestId
        });
        
        // Execute via Across Protocol
        _executeAcrossTransfer(requestId);
        
        emit RewardDistributionInitiated(requestId, user, amount, targetChain);
    }

    /// @notice Set user preferences
    function setUserPreferences(
        uint256 preferredChain,
        uint256 claimThreshold,
        uint256 claimFrequency,
        bool autoClaimEnabled
    ) external {
        if (!supportedChains[preferredChain]) revert UnsupportedChain();
        
        userPreferences[msg.sender] = UserPreferences({
            preferredChain: preferredChain,
            claimThreshold: claimThreshold,
            claimFrequency: claimFrequency,
            autoClaimEnabled: autoClaimEnabled,
            lastUpdate: block.timestamp
        });
        
        emit PreferencesUpdated(msg.sender, preferredChain, claimThreshold);
    }

    /// @notice Execute instant claim
    function executeInstantClaim(
        address user,
        uint256 amount
    ) external onlyAuthorized whenNotPaused {
        UserPreferences memory prefs = userPreferences[user];
        
        if (amount < prefs.claimThreshold) revert InvalidAmount();
        
        // Execute immediate distribution to preferred chain
        _executeRewardDistribution(user, amount, prefs.preferredChain);
    }

    /// @notice Execute across transfer
    function _executeAcrossTransfer(bytes32 requestId) internal {
        DistributionRequest storage request = distributionRequests[requestId];
        
        // Calculate Across parameters
        uint64 depositId = _getNextDepositId();
        uint32 quoteTimestamp = uint32(block.timestamp);
        uint256 netAmount = request.amount * 99 / 100; // Account for fees
        
        // Execute cross-chain transfer via Across Protocol
        // This would call the actual Across spoke pool contract
        _callAcrossSpokePool(
            request.user,
            request.rewardToken,
            request.amount,
            netAmount,
            request.targetChain,
            quoteTimestamp
        );
        
        request.executed = true;
        distributionStats.successfulDistributions++;
        distributionStats.totalDistributed += request.amount;
        
        emit RewardDistributionExecuted(requestId, depositId);
    }

    /// @notice Call Across spoke pool
    function _callAcrossSpokePool(
        address recipient,
        address token,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 targetChain,
        uint32 quoteTimestamp
    ) internal {
        // This would be the actual Across Protocol integration
        // For now, we'll simulate the call
        
        // In practice, this would call:
        // IAcrossSpokePool(spokePool).deposit(
        //     address(this),           // depositor
        //     recipient,               // recipient
        //     token,                   // inputToken
        //     token,                   // outputToken
        //     inputAmount,             // inputAmount
        //     outputAmount,            // outputAmount
        //     targetChain,             // destinationChainId
        //     address(0),              // exclusiveRelayer
        //     quoteTimestamp,          // quoteTimestamp
        //     quoteTimestamp + 1800,   // fillDeadline (30 min)
        //     0,                       // exclusivityDeadline
        //     ""                       // message
        // );
    }

    /// @notice Get next deposit ID
    function _getNextDepositId() internal view returns (uint64) {
        // This would query the actual Across spoke pool
        return uint64(block.timestamp);
    }

    /// @notice Update chain support
    function updateChainSupport(
        uint256 chainId,
        bool supported
    ) external onlyOwner {
        supportedChains[chainId] = supported;
        emit ChainSupportUpdated(chainId, supported);
    }

    /// @notice Pause contract
    function pause() external onlyOwner {
        paused = true;
    }

    /// @notice Unpause contract
    function unpause() external onlyOwner {
        paused = false;
    }

    /// @notice Get distribution request
    function getDistributionRequest(
        bytes32 requestId
    ) external view returns (DistributionRequest memory) {
        return distributionRequests[requestId];
    }

    /// @notice Get user preferences
    function getUserPreferences(
        address user
    ) external view returns (UserPreferences memory) {
        return userPreferences[user];
    }

    /// @notice Get distribution statistics
    function getDistributionStats() external view returns (DistributionStats memory) {
        return distributionStats;
    }

    /// @notice Check if chain is supported
    function isChainSupported(uint256 chainId) external view returns (bool) {
        return supportedChains[chainId];
    }

    /// @notice Calculate distribution fees
    function calculateDistributionFees(
        uint256 amount,
        uint256 targetChain
    ) external pure returns (uint256) {
        return DistributionUtils.calculateFees(amount, targetChain);
    }

    /// @notice Get optimal distribution timing
    function getOptimalDistributionTiming(
        address user
    ) external view returns (uint256) {
        UserPreferences memory prefs = userPreferences[user];
        PreferenceManager.UserPreferences memory libPrefs = PreferenceManager.UserPreferences({
            preferredChain: prefs.preferredChain,
            claimThreshold: prefs.claimThreshold,
            claimFrequency: prefs.claimFrequency,
            autoClaimEnabled: prefs.autoClaimEnabled,
            lastUpdate: prefs.lastUpdate
        });
        return PreferenceManager.getOptimalTiming(libPrefs, block.timestamp);
    }
}
