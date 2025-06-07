# Automated Dollar-Cost Averaging (DCA) Smart Contract

A comprehensive smart contract system for automated dollar-cost averaging on the Stacks blockchain, written in Clarity.

## Overview

This smart contract enables users to create and manage automated investment strategies that purchase tokens at regular intervals, implementing the dollar-cost averaging investment strategy. The system supports multiple token pairs, configurable execution frequencies, slippage protection, and comprehensive performance tracking.

## Features

### Core Functionality
- **Automated DCA Strategies**: Create recurring purchase orders with customizable parameters
- **Multi-Token Support**: Trade between any supported SIP-010 compliant tokens
- **Flexible Scheduling**: Configure execution frequency in blocks
- **Slippage Protection**: Set maximum acceptable slippage for trades
- **Balance Management**: Secure deposit and withdrawal system
- **Performance Tracking**: Monitor investment performance and average purchase prices

### Advanced Features
- **Batch Execution**: Execute multiple strategies in a single transaction
- **Strategy Management**: Pause, resume, update, or cancel strategies
- **Price Feeds**: Oracle-based price data for accurate calculations
- **Platform Fees**: Configurable fee structure for platform sustainability
- **Emergency Controls**: Admin pause functionality for security

## Contract Architecture

### Data Structures

#### DCA Strategies
Each strategy contains:
- Owner and token pair information
- Investment amount and frequency settings
- Execution tracking and performance metrics
- Status and configuration parameters

#### User Balances
- Per-user, per-token balance tracking
- Secure deposit/withdrawal system
- Integration with strategy execution

#### Token Management
- Supported token registry with metadata
- Trading pair configurations
- Price feed integration

### Key Functions

#### User Functions

**`create-dca-strategy`**
```clarity
(create-dca-strategy token-in token-out amount-per-execution frequency max-slippage)
```
Create a new DCA strategy with specified parameters.

**`execute-dca-strategy`**
```clarity
(execute-dca-strategy strategy-id)
```
Execute a strategy if conditions are met (timing, balance, etc.).

**`deposit-tokens`** / **`withdraw-tokens`**
```clarity
(deposit-tokens token amount)
(withdraw-tokens token amount)
```
Manage token balances within the contract.

**`toggle-strategy-status`**
```clarity
(toggle-strategy-status strategy-id)
```
Pause or resume a strategy.

#### Read-Only Functions

**`get-strategy-performance`**
```clarity
(get-strategy-performance strategy-id)
```
Returns comprehensive performance metrics including average price, current value, and P&L.

**`is-execution-due`**
```clarity
(is-execution-due strategy-id)
```
Check if a strategy is ready for execution.

### Admin Functions

**Token and Pair Management**
- `add-supported-token`: Add new tradeable tokens
- `add-token-pair`: Configure trading pairs with DEX integration
- `update-price-feed`: Update token price information

**System Configuration**
- `set-platform-fee-rate`: Configure platform fees
- `toggle-contract-pause`: Emergency pause functionality

## Usage Examples

### Creating a DCA Strategy

```clarity
;; Create a strategy to buy 1 STX worth of USDC every 1000 blocks
(contract-call? .dca-contract create-dca-strategy
  'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx-token  ;; STX token
  'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard  ;; USDC token
  u1000000  ;; 1 STX per execution
  u1000     ;; Every 1000 blocks (~7 days)
  u300      ;; 3% max slippage
)
```

### Depositing Tokens

```clarity
;; Deposit 10 STX to fund DCA strategies
(contract-call? .dca-contract deposit-tokens .wstx-token u10000000)
```

### Executing a Strategy

```clarity
;; Execute strategy with ID 1
(contract-call? .dca-contract execute-dca-strategy u1)
```

### Checking Performance

```clarity
;; Get performance metrics for strategy 1
(contract-call? .dca-contract get-strategy-performance u1)
```

## Security Features

### Access Control
- Owner-only functions for strategy management
- Admin-only functions for system configuration
- Emergency pause functionality

### Input Validation
- Amount and frequency limits
- Slippage bounds checking
- Balance verification before execution

### Error Handling
- Comprehensive error codes for different failure scenarios
- Graceful handling of price feed failures
- Balance insufficiency protection

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | `ERR_NOT_AUTHORIZED` | Insufficient permissions |
| 101 | `ERR_STRATEGY_NOT_FOUND` | Strategy doesn't exist |
| 102 | `ERR_INSUFFICIENT_BALANCE` | Insufficient token balance |
| 103 | `ERR_INVALID_FREQUENCY` | Invalid execution frequency |
| 104 | `ERR_INVALID_AMOUNT` | Invalid investment amount |
| 105 | `ERR_STRATEGY_PAUSED` | Strategy is currently paused |
| 106 | `ERR_STRATEGY_ACTIVE` | Strategy must be paused for operation |
| 107 | `ERR_EXECUTION_TOO_EARLY` | Execution not yet due |
| 108 | `ERR_TOKEN_NOT_SUPPORTED` | Token not supported |
| 109 | `ERR_PRICE_FEED_ERROR` | Price data unavailable |
| 110 | `ERR_SLIPPAGE_TOO_HIGH` | Slippage exceeds tolerance |

## Configuration Parameters

### Default Settings
- **Minimum execution amount**: 1 STX (1,000,000 micro-STX)
- **Maximum slippage allowed**: 10% (1000 basis points)
- **Platform fee rate**: 0.5% (50 basis points)
- **Maximum platform fee**: 5% (500 basis points)

### Customizable Parameters
- Investment amount per execution
- Execution frequency (in blocks)
- Maximum acceptable slippage
- Strategy active/inactive status

## Integration Guide

### For DeFi Protocols
1. **Token Support**: Ensure your token implements SIP-010 standard
2. **Price Feeds**: Provide oracle integration for accurate pricing
3. **DEX Integration**: Configure trading pairs with your DEX contract

### For Frontend Applications
1. **Strategy Creation**: Build interfaces for parameter configuration
2. **Performance Monitoring**: Display strategy metrics and history
3. **Balance Management**: Implement deposit/withdrawal flows
4. **Execution Automation**: Set up automated execution triggers

## Deployment Considerations

### Prerequisites
- Clarinet development environment
- Supported token contracts deployed
- Price oracle contracts available
- DEX contracts for token swapping

### Configuration Steps
1. Deploy the DCA contract
2. Add supported tokens via `add-supported-token`
3. Configure trading pairs via `add-token-pair`
4. Set up price feeds via `update-price-feed`
5. Configure platform fee rate

## Testing

The contract includes comprehensive test coverage for:
- Strategy creation and management
- Token deposits and withdrawals
- Execution logic and timing
- Error handling and edge cases
- Performance calculations
- Admin functions

## Roadmap

### Planned Features
- **Advanced Strategies**: Support for more complex DCA patterns
- **Multi-DEX Support**: Routing through multiple exchanges
- **Governance Integration**: Community-driven parameter updates
- **Analytics Dashboard**: Enhanced performance tracking
- **Mobile Integration**: Native mobile app support

### Future Enhancements
- **Cross-chain Support**: Integration with other blockchain networks
- **AI-powered Strategies**: Machine learning-based optimization
- **Social Features**: Strategy sharing and copying
- **Institutional Tools**: Advanced portfolio management features

## Contributing

We welcome contributions to improve the DCA smart contract system. Please review our contribution guidelines and submit pull requests for review.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For technical support, feature requests, or bug reports, please open an issue in the project repository or contact our development team.

---

**Disclaimer**: This smart contract is provided as-is. Users should thoroughly test and audit the code before deploying to mainnet. Cryptocurrency investments carry inherent risks, and past performance does not guarantee future results.