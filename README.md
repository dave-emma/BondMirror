# BondMirror Smart Contract

A comprehensive synthetic bond platform built on the Stacks blockchain using Clarity smart contracts. BondMirror enables the creation and management of government and corporate bonds with programmable yield structures, providing a decentralized alternative to traditional bond markets.

## Overview

BondMirror allows users to:
- Create synthetic government and corporate bonds
- Implement programmable yield schedules that change over time
- Purchase, hold, and redeem bonds with automatic interest calculation
- Track bond performance and metadata on-chain

## Features

### 🏛️ **Multi-Type Bond Support**
- Government bonds (Type 1)
- Corporate bonds (Type 2)
- Customizable face values, purchase prices, and maturity periods

### 📈 **Programmable Yield Structures**
- Set different yield rates for different time periods
- Automatic yield calculation based on current block height
- Fallback to base annual yield when no programmed schedule is active

### 💰 **Complete Bond Lifecycle**
- Bond issuance with metadata (name, symbol, description, rating)
- Purchase with STX payments
- Interest accrual calculation
- Maturity-based redemption

### 🔒 **Security & Validation**
- Comprehensive error handling
- Authorization checks for admin functions
- Parameter validation for all operations
- Protected against common smart contract vulnerabilities

## Contract Architecture

### Data Structures

#### Bonds Map
Stores core bond information:
```clarity
{
  issuer: principal,
  bond-type: uint,
  face-value: uint,
  purchase-price: uint,
  annual-yield: uint,  // Basis points (500 = 5%)
  issue-block: uint,
  maturity-blocks: uint,
  total-supply: uint,
  remaining-supply: uint,
  is-active: bool
}
```

#### Bond Holdings Map
Tracks individual investor positions:
```clarity
{
  quantity: uint,
  purchase-block: uint,
  redeemed: bool
}
```

#### Yield Schedule Map
Enables programmable yield rates:
```clarity
{
  yield-rate: uint,      // Basis points
  start-block: uint,
  end-block: uint
}
```

## Usage Guide

### For Bond Issuers (Contract Owner)

#### 1. Create a Bond
```clarity
(create-bond 
  BOND-TYPE-GOVERNMENT    ;; Bond type (1 = Government, 2 = Corporate)
  u1000                   ;; Face value (in microSTX)
  u950                    ;; Purchase price (in microSTX)
  u500                    ;; Annual yield (500 = 5%)
  u52560                  ;; Maturity in blocks (~1 year)
  u1000                   ;; Total supply
  "US Treasury 5Y"        ;; Bond name
  "UST5Y"                ;; Symbol
  "5-year Treasury bond"  ;; Description
  "AAA"                  ;; Credit rating
)
```

#### 2. Set Programmable Yield Schedule
```clarity
;; Set 3% yield for first 6 months
(set-yield-schedule u1 u1 u300 u1000 u26280)

;; Set 7% yield for remaining period
(set-yield-schedule u1 u2 u700 u26281 u52560)
```

### For Investors

#### 1. Purchase Bonds
```clarity
(purchase-bond u1 u10)  ;; Buy 10 units of bond ID 1
```

#### 2. Check Bond Value
```clarity
(get-bond-value u1 'SP1ABC...)  ;; Get current value with interest
```

#### 3. Redeem at Maturity
```clarity
(redeem-bond u1)  ;; Redeem all holdings for bond ID 1
```

### Read-Only Functions

#### Get Bond Information
```clarity
(get-bond-info u1)          ;; Bond configuration
(get-bond-metadata u1)      ;; Bond metadata
(get-bond-holding 'SP1ABC... u1)  ;; Investor holdings
(is-bond-matured u1)        ;; Maturity status
```

#### Calculate Yields and Interest
```clarity
(calculate-current-yield u1)              ;; Current applicable yield rate
(calculate-accrued-interest u1 'SP1ABC...) ;; Accrued interest for holder
```

## Interest Calculation

Interest is calculated using the formula:
```
Interest = (Face Value × Quantity × Yield Rate × Blocks Held) / (Annual Blocks × 10,000)
```

Where:
- **Annual Blocks**: ~52,560 (assuming 10-minute block times)
- **Yield Rate**: In basis points (500 = 5%)
- **Blocks Held**: Current block - purchase block

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | ERR-NOT-AUTHORIZED | Caller lacks required permissions |
| u101 | ERR-BOND-NOT-FOUND | Bond ID does not exist |
| u102 | ERR-INSUFFICIENT-BALANCE | Insufficient funds or supply |
| u103 | ERR-BOND-MATURED | Bond has already matured |
| u104 | ERR-BOND-NOT-MATURED | Bond hasn't reached maturity |
| u105 | ERR-INVALID-AMOUNT | Invalid amount parameter |
| u106 | ERR-INVALID-YIELD | Yield rate outside valid range |
| u107 | ERR-BOND-ALREADY-REDEEMED | Bond position already redeemed |
| u108 | ERR-TRANSFER-FAILED | STX transfer failed |

## Deployment Instructions

### Prerequisites
- Clarinet CLI installed
- Stacks wallet with STX for deployment
- Node.js and npm (for testing)

### Local Development
```bash
# Clone the repository
git clone <repository-url>
cd bondmirror

# Initialize Clarinet project
clarinet new bondmirror
cd bondmirror

# Add the contract
cp BondMirror.clar contracts/

# Run tests
clarinet test

# Check contract
clarinet check
```

### Deployment
```bash
# Deploy to testnet
clarinet deploy --network testnet

# Deploy to mainnet
clarinet deploy --network mainnet
```

## Testing

The contract includes comprehensive test coverage for:
- Bond creation and configuration
- Purchase and redemption flows
- Yield calculation accuracy
- Error condition handling
- Authorization controls

## Security Considerations

- **Admin Control**: Only the contract owner can create bonds and set yield schedules
- **Validation**: All inputs are validated for range and type correctness
- **Reentrancy Protection**: State changes occur before external calls
- **Integer Overflow**: All calculations use safe arithmetic operations
- **Access Control**: Proper permission checks for sensitive functions

## Gas Optimization

- Efficient data structures minimize storage costs
- Read-only functions for data queries
- Batch operations where possible
- Optimized calculation formulas

## Roadmap

### Phase 1 (Current)
- ✅ Basic bond creation and management
- ✅ Programmable yield structures
- ✅ Purchase and redemption functionality

### Phase 2 (Future)
- 🔄 Secondary market trading
- 🔄 Bond rating updates
- 🔄 Automated yield adjustments based on market conditions

### Phase 3 (Future)
- 🔄 Cross-chain bond wrapping
- 🔄 DeFi integration (lending/borrowing against bonds)
- 🔄 Governance token for protocol decisions

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add comprehensive tests
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.


## Disclaimer

This smart contract is provided as-is for educational and experimental purposes. Users should conduct thorough testing and security audits before using in production environments. The authors are not responsible for any financial losses incurred through the use of this contract.