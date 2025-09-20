# RewardFlow Tier System Documentation

## Overview

The RewardFlow tier system is designed to reward long-term, engaged liquidity providers with enhanced benefits and higher reward multipliers. The system encourages user retention and cross-chain participation through a sophisticated 5-tier structure.

## Tier Structure

### Diamond Tier 🏆
- **Multiplier**: 2.0x
- **Requirements**: 
  - 1000+ ETH total liquidity across all chains
  - 90+ loyalty score
  - 6+ months active participation
- **Benefits**:
  - Maximum reward multiplier (2.0x)
  - Priority distribution (24-hour processing)
  - Exclusive features and analytics
  - Lower minimum claim thresholds
  - Direct access to support team
  - Early access to new features

### Platinum Tier 💎
- **Multiplier**: 1.5x
- **Requirements**:
  - 500+ ETH total liquidity across all chains
  - 70+ loyalty score
  - 3+ months active participation
- **Benefits**:
  - High reward multiplier (1.5x)
  - Fast distribution (48-hour processing)
  - Advanced analytics dashboard
  - Reduced claim thresholds
  - Priority customer support

### Gold Tier 🥇
- **Multiplier**: 1.2x
- **Requirements**:
  - 100+ ETH total liquidity across all chains
  - 50+ loyalty score
  - 1+ month active participation
- **Benefits**:
  - Moderate reward boost (1.2x)
  - Standard distribution (72-hour processing)
  - Enhanced analytics
  - Standard support

### Silver Tier 🥈
- **Multiplier**: 1.1x
- **Requirements**:
  - 10+ ETH total liquidity across all chains
  - 30+ loyalty score
  - 2+ weeks active participation
- **Benefits**:
  - Small reward boost (1.1x)
  - Standard distribution (5-day processing)
  - Basic analytics
  - Community support

### Base Tier 🥉
- **Multiplier**: 1.0x
- **Requirements**:
  - Any liquidity provision
  - No minimum loyalty score
  - Immediate participation
- **Benefits**:
  - Standard rewards (1.0x)
  - Standard distribution (7-day processing)
  - Basic tracking
  - Community support

## Loyalty Score Calculation

The loyalty score is calculated based on multiple factors:

### 1. Consistency Score (40% weight)
- **Formula**: `(Days Active / Total Days) × 100`
- **Range**: 0-100 points
- **Description**: Measures how consistently a user provides liquidity

### 2. Duration Score (30% weight)
- **Formula**: `min(Average Position Duration / 30 days, 1) × 100`
- **Range**: 0-100 points
- **Description**: Rewards longer-term positions

### 3. Volume Score (20% weight)
- **Formula**: `min(Total Volume / 1000 ETH, 1) × 100`
- **Range**: 0-100 points
- **Description**: Rewards higher volume providers

### 4. Cross-Chain Score (10% weight)
- **Formula**: `(Chains Active / Total Supported Chains) × 100`
- **Range**: 0-100 points
- **Description**: Rewards multi-chain participation

### Final Loyalty Score
```
Loyalty Score = (Consistency × 0.4) + (Duration × 0.3) + (Volume × 0.2) + (CrossChain × 0.1)
```

## Tier Progression

### Automatic Progression
- **Evaluation Frequency**: Weekly
- **Requirements**: Must meet all criteria for new tier
- **Effective Date**: Next reward calculation cycle

### Manual Review
- **Request Process**: Users can request tier review
- **Review Period**: 7-14 days
- **Appeal Process**: Available for tier decisions

### Tier Demotion
- **Conditions**: 
  - Liquidity falls below tier requirements
  - Inactivity for 90+ days
  - Loyalty score drops significantly
- **Grace Period**: 30 days to regain requirements
- **Effective Date**: End of grace period

## Tier Benefits Details

### 1. Reward Multipliers
- **Applied To**: All reward types (liquidity, MEV, engagement)
- **Calculation**: `Base Reward × Tier Multiplier`
- **Effective**: Immediately upon tier achievement

### 2. Distribution Priority
- **Processing Order**: Diamond → Platinum → Gold → Silver → Base
- **Time Advantage**: Higher tiers process faster
- **Batch Optimization**: Similar tiers processed together

### 3. Claim Thresholds
- **Diamond**: $10 minimum
- **Platinum**: $25 minimum
- **Gold**: $50 minimum
- **Silver**: $100 minimum
- **Base**: $200 minimum

### 4. Analytics Access
- **Diamond**: Full analytics suite, custom reports, API access
- **Platinum**: Advanced analytics, detailed insights
- **Gold**: Enhanced analytics, basic insights
- **Silver**: Standard analytics, basic tracking
- **Base**: Basic analytics, simple tracking

## Special Features by Tier

### Diamond Tier Exclusives
- **Private Discord Channel**: Direct access to team
- **Custom Rewards**: Special reward programs
- **Beta Testing**: Early access to new features
- **White-Label Solutions**: Custom deployment options

### Platinum Tier Features
- **Advanced Analytics**: Detailed performance metrics
- **Priority Support**: Faster response times
- **Exclusive Events**: Special webinars and AMAs

### Gold Tier Benefits
- **Enhanced Dashboard**: Better user interface
- **Educational Content**: Advanced tutorials and guides
- **Community Access**: Special community channels

## Tier Maintenance

### 1. Regular Evaluation
- **Frequency**: Weekly automatic evaluation
- **Criteria**: All tier requirements must be met
- **Notification**: Users notified of tier changes

### 2. Grace Periods
- **Temporary Drop**: 30-day grace period
- **Re-engagement**: Opportunity to regain tier
- **Support**: Guidance on maintaining tier status

### 3. Appeals Process
- **Request**: Users can appeal tier decisions
- **Review**: Manual review by team
- **Decision**: Final determination within 14 days

## Future Enhancements

### 1. Additional Tiers
- **Legendary Tier**: Ultra-high requirements and benefits
- **Seasonal Tiers**: Temporary tiers with special rewards
- **Custom Tiers**: Personalized tier structures

### 2. Enhanced Benefits
- **NFT Rewards**: Tier-specific NFTs
- **Staking Rewards**: Additional staking benefits
- **Governance Rights**: Voting power based on tier

### 3. Gamification
- **Achievements**: Tier-specific achievements
- **Leaderboards**: Tier-based competitions
- **Social Features**: Tier-based communities

## Implementation Details

### Smart Contract Integration
```solidity
enum TierLevel {
    BASE,      // 1.0x multiplier
    SILVER,    // 1.1x multiplier
    GOLD,      // 1.2x multiplier
    PLATINUM,  // 1.5x multiplier
    DIAMOND    // 2.0x multiplier
}

function calculateTier(address user) public view returns (TierLevel) {
    UserMetrics memory metrics = getUserMetrics(user);
    
    if (metrics.totalLiquidity >= DIAMOND_THRESHOLD && 
        metrics.loyaltyScore >= 90) {
        return TierLevel.DIAMOND;
    } else if (metrics.totalLiquidity >= PLATINUM_THRESHOLD && 
               metrics.loyaltyScore >= 70) {
        return TierLevel.PLATINUM;
    } else if (metrics.totalLiquidity >= GOLD_THRESHOLD && 
               metrics.loyaltyScore >= 50) {
        return TierLevel.GOLD;
    } else if (metrics.totalLiquidity >= SILVER_THRESHOLD && 
               metrics.loyaltyScore >= 30) {
        return TierLevel.SILVER;
    } else {
        return TierLevel.BASE;
    }
}
```

### Database Schema
```sql
CREATE TABLE user_tiers (
    user_address VARCHAR(42) PRIMARY KEY,
    current_tier VARCHAR(20) NOT NULL,
    loyalty_score INTEGER NOT NULL,
    total_liquidity DECIMAL(78,0) NOT NULL,
    last_evaluation TIMESTAMP NOT NULL,
    tier_history JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Monitoring and Analytics

### 1. Tier Distribution
- **Real-time Tracking**: Current tier distribution
- **Historical Analysis**: Tier progression over time
- **Predictive Analytics**: Tier change predictions

### 2. User Behavior
- **Engagement Patterns**: How tiers affect behavior
- **Retention Analysis**: Tier-based retention rates
- **Reward Optimization**: Tier-based reward optimization

### 3. System Health
- **Tier Stability**: How often users change tiers
- **Requirement Analysis**: Effectiveness of tier requirements
- **Benefit Utilization**: How users use tier benefits
