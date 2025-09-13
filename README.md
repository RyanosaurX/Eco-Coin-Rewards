# Eco-Coin Rewards Smart Contract

A Clarity smart contract that implements a fungible token (ECO) to incentivize recycling behavior through a decentralized reward system.

## Overview

The Eco-Coin Rewards contract creates an ecosystem where:
- **Sponsors** fund a treasury by depositing STX tokens
- **Certified recycling centers** authorize reward claims for users who recycle
- **Users** process their claims to mint ECO tokens
- **Token holders** can redeem ECO tokens for STX from the treasury

## Features

### 🌱 Core Functionality
- **Fungible Token (ECO)**: SIP-010 compliant token for recycling rewards
- **Claim System**: Two-step process for secure reward distribution
- **Treasury Management**: Community-funded pool for token redemption
- **Center Certification**: Only approved centers can authorize claims

### 🔒 Security Features
- **Authorization Controls**: Owner-only administrative functions
- **Replay Protection**: Claims can only be processed once
- **Input Validation**: Comprehensive checks for amounts and strings
- **Balance Verification**: Prevents overdrafts and invalid operations

### 📊 Token Economics
- **Symbol**: ECO
- **Decimals**: 6
- **Total Supply**: Dynamic (tracked manually)
- **Exchange Rate**: 100 ECO = 1 STX (configurable)

## Contract Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│    Sponsors     │───▶│     Treasury     │◀───│  Token Holders  │
│                 │    │                  │    │                 │
│ Fund with STX   │    │  Holds STX for   │    │ Redeem ECO for  │
│                 │    │   redemptions    │    │      STX        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                              ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Recycling       │───▶│   Claim System   │◀───│     Users       │
│ Centers         │    │                  │    │                 │
│ Authorize       │    │ 1. Authorize     │    │ Process claims  │
│ claims          │    │ 2. Process       │    │ to mint ECO     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Installation & Deployment

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) 0.31.1 or later
- [Stacks CLI](https://docs.stacks.co/docs/cli)

### Setup
1. Clone the repository
2. Initialize Clarinet project (if not already done):
   ```bash
   clarinet new eco-coin-project
   cd eco-coin-project
   ```
3. Copy the contract to `contracts/eco-coin-rewards.clar`
4. Run checks:
   ```bash
   clarinet check
   ```

### Testing
```bash
# Check contract syntax
clarinet check

# Run test suite (create tests in tests/ directory)
clarinet test

# Start local development environment
clarinet integrate
```

## Usage Guide

### For Contract Owner

#### Deploy and Initialize
The contract automatically initializes with the deployer as the owner and adds them as the "Genesis Center".

#### Add Recycling Centers
```clarity
(contract-call? .eco-coin-rewards add-center 
    'SP1ABCD... 
    "Downtown Recycling Hub")
```

#### Remove Centers
```clarity
(contract-call? .eco-coin-rewards remove-center 'SP1ABCD...)
```

#### Set Token Metadata
```clarity
(contract-call? .eco-coin-rewards set-token-uri 
    "https://api.example.com/eco-coin/metadata.json")
```

### For Sponsors

#### Fund Treasury
```clarity
(contract-call? .eco-coin-rewards fund-treasury u1000000) ;; 1 STX in microSTX
```

### For Recycling Centers

#### Authorize User Rewards
```clarity
(contract-call? .eco-coin-rewards authorize-claim 
    'SP1USER... 
    u50000000) ;; 50 ECO tokens (6 decimals)
```

### For Users

#### Process Claims
```clarity
(contract-call? .eco-coin-rewards process-my-claim 'SP1CENTER...)
```

#### Transfer Tokens
```clarity
(contract-call? .eco-coin-rewards transfer 
    u10000000   ;; 10 ECO tokens
    tx-sender 
    'SP1RECIPIENT... 
    none)
```

#### Redeem for STX
```clarity
(contract-call? .eco-coin-rewards redeem-for-stx u100000000) ;; 100 ECO tokens
```

## API Reference

### Public Functions

#### Administrative Functions
- `add-center(center-principal, center-name)` - Add certified recycling center
- `remove-center(center-principal)` - Remove recycling center
- `set-token-uri(new-uri)` - Update token metadata URI

#### Treasury Functions
- `fund-treasury(amount)` - Deposit STX to fund rewards

#### Reward Functions
- `authorize-claim(user, amount)` - Center authorizes user reward
- `process-my-claim(center)` - User processes their claim
- `redeem-for-stx(amount)` - Exchange ECO tokens for STX

#### Token Functions
- `transfer(amount, sender, recipient, memo)` - Transfer tokens between users

### Read-Only Functions

#### Token Information
- `get-name()` → `"Eco-Coin"`
- `get-symbol()` → `"ECO"`
- `get-decimals()` → `u6`
- `get-total-supply()` → Current total supply
- `get-balance(who)` → User's token balance
- `get-token-uri()` → Token metadata URI

#### System Information
- `get-treasury-balance()` → Available STX in treasury
- `get-contract-owner()` → Contract owner principal
- `is-certified-center(center)` → Check if center is certified
- `get-center-info(center)` → Get center details

#### Claim Information
- `get-pending-claim(user, center)` → User's pending claim details
- `is-claim-processed(claim-id)` → Check if claim was processed

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | `ERR_UNAUTHORIZED` | Caller not authorized for this action |
| 101 | `ERR_NOT_CERTIFIED_CENTER` | Only certified centers can authorize claims |
| 102 | `ERR_INVALID_AMOUNT` | Amount must be greater than zero |
| 103 | `ERR_CLAIM_NOT_FOUND` | No pending claim found for user/center pair |
| 104 | `ERR_CLAIM_ALREADY_PROCESSED` | Claim has already been processed |
| 105 | `ERR_TREASURY_EMPTY` | Insufficient funds in treasury for redemption |
| 106 | `ERR_INSUFFICIENT_BALANCE` | User doesn't have enough tokens |
| 107 | `ERR_INSUFFICIENT_STX` | User doesn't have enough STX to fund treasury |
| 108 | `ERR_INVALID_PRINCIPAL` | Invalid principal address provided |
| 109 | `ERR_INVALID_STRING` | String parameter is invalid or too long |

## Token Economics

### Exchange Rate
- **Current Rate**: 100 ECO tokens = 1 STX
- **Precision**: 10,000 microSTX per ECO token
- **Configurable**: Can be modified in the `redeem-for-stx` function

### Supply Management
- **Dynamic Supply**: Tokens are minted when claims are processed
- **Deflationary**: Tokens are burned when redeemed for STX
- **Manual Tracking**: Total supply tracked via data variable

## Security Considerations

### Access Control
- **Owner-only functions**: Center management and configuration
- **Center-only functions**: Claim authorization
- **User-specific functions**: Claim processing and transfers

### Input Validation
- Amount validation (positive values only)
- String length validation for center names and URIs
- Self-transfer prevention in token transfers
- Balance verification before operations

### Replay Protection
- Unique claim IDs prevent double-processing
- Processed claims are permanently marked
- One pending claim per user-center pair

## Development & Contributing

### Code Quality
- ✅ Passes `clarinet check` with zero errors
- ✅ Compatible with Clarinet 0.31.1
- ✅ Follows Clarity best practices
- ✅ Comprehensive input validation

### Testing Strategy
Create test files in the `tests/` directory to cover:
- Administrative functions
- Claim authorization and processing
- Treasury funding and redemption
- Token transfers
- Error conditions
- Edge cases

### Example Test Structure
```clarity
;; tests/eco-coin-rewards_test.ts
import { describe, expect, it } from "vitest";

describe("eco-coin-rewards contract", () => {
  it("should allow owner to add recycling centers", () => {
    // Test implementation
  });
  
  it("should process valid claims correctly", () => {
    // Test implementation
  });
});
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For questions, issues, or contributions:
- Open an issue in the repository
- Check existing documentation
- Review the contract source code for implementation details

---

**Built with ❤️ for a sustainable future** 🌍♻️