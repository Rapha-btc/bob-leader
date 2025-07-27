# Burn Bob Daily Bonus Contract

A fair and transparent bonus distribution system for daily BOB token burners, built on Stacks blockchain with cryptographically secure randomness.

## Overview

The Burn Bob Daily Bonus Contract automatically selects random winners from users who participate in daily BOB burns. Winners receive bonuses in both BOB and FAKFUN tokens, with amounts determined by participant count and optional sponsor bonuses.

## How It Works

### 1. Daily Burn Tracking

- Users burn 1 BOB token daily through the [burn contract](https://explorer.stacks.co/txid/SP29D6YMDNAKN1P045T6Z817RTE1AC0JAA99WAX2B.burn-bob-faktory)
- Backend system tracks all daily participants per epoch
- Epochs are based on Bitcoin block timing (144 blocks ≈ 1 day)

### 2. Fair Winner Selection

```clarity
;; Cryptographically secure randomness using VRF + block timing
(define-read-only (get-rnd (block uint))
    (let (
        (vrf (buff-to-uint-be (unwrap-panic (as-max-len? (unwrap-panic (slice? (unwrap! (get-tenure-info? vrf-seed block) err-block-not-found) u16 u32)) u16))))
        (time (unwrap! (get-tenure-info? time block) err-block-not-found)))
        (ok (if is-in-mainnet (+ vrf time) vrf))))

;; Winner selection using modulo for fair distribution
(recipient-index (mod random-number (len participants)))
(chosen-recipient (unwrap! (element-at? participants recipient-index) err-no-participants))
```

### 3. Bonus Distribution

- **Default**: Winner receives `participant_count` BOB + equivalent FAKFUN
- **Sponsor Bonus**: Sponsor can set higher amounts for specific epochs
- **Final Amount**: `max(sponsor_bonus, participant_count)`

## User Guide

### For Participants

**How to Enter:**

1. Burn 1 BOB token daily through the burn contract
2. Your address automatically becomes eligible for that day's bonus
3. Winners are selected randomly after each epoch ends

**Checking Results:**

```clarity
;; Check if you won epoch 5
(contract-call? 'SP1234...bob-bonus-faktory get-epoch-bonus-recipient u5)

;; See all participants for epoch 5
(contract-call? 'SP1234...bob-bonus-faktory get-epoch-participants u5)

;; Check epoch info
(contract-call? 'SP1234...bob-bonus-faktory get-bonus-info u5)
```

### For Sponsors

**Setting Bonus Amounts:**

```clarity
;; Set 1000 BOB bonus for next epoch (sponsor only)
(contract-call? 'SP1234...bob-bonus-faktory set-next-epoch-bonus u1000)

;; Check current sponsor bonus for epoch
(contract-call? 'SP1234...bob-bonus-faktory get-epoch-sponsor-bonus u10)
```

**Funding the Contract:**

```clarity
;; Fund with 10,000 BOB (micro-BOB units)
;; This automatically funds equivalent FAKFUN (accounting for decimals)
(contract-call? 'SP1234...bob-bonus-faktory fund-bonus u10000000000)
```

**Withdrawing Funds:**

```clarity
;; Withdraw all BOB and FAKFUN (sponsor only)
(contract-call? 'SP1234...bob-bonus-faktory withdraw-dble)

;; Withdraw any SIP-010 token (sponsor only)
(contract-call? 'SP1234...bob-bonus-faktory withdraw-ft 'SP1234...token-contract)
```

## Technical Details

### Contract Architecture

**Key Constants:**

```clarity
(define-constant admin tx-sender)  ;; Set at deploy time
(define-constant SPONSOR 'SP2VG7S0R4Z8PYNYCAQ04HCBX1MH75VT11VXCWQ6G)
(define-constant BURN-GENESIS-BLOCK u902351)  ;; When burn contract deployed
(define-constant EPOCH-LENGTH u144)  ;; ~1 day in Bitcoin blocks
```

**Core Data Structures:**

```clarity
(define-map epoch-participants uint (list 1000 principal))
(define-map epoch-bonus-recipients uint principal)
(define-map epoch-draw-blocks uint uint)
(define-map epoch-bonus uint uint)  ;; Sponsor bonuses
```

### Randomness Security

The contract uses **VRF (Verifiable Random Function)** from Stacks tenures:

- **Source**: `get-tenure-info? vrf-seed block`
- **Enhancement**: Combined with block timestamp on mainnet
- **Deterministic**: Same draw block always produces same winner
- **Unpredictable**: Cannot be predicted before draw block is mined

### Timing & Delays

**Epoch System:**

```clarity
;; Calculate current epoch from Bitcoin blocks
(define-read-only (current-epoch)
  (calc-epoch burn-block-height))

;; Check if epoch has ended
(define-read-only (is-epoch-finished (epoch uint))
  (> burn-block-height (calc-epoch-end epoch)))
```

**Security Delay:**

- 6 Stacks blocks (~60 seconds) between participant submission and winner selection
- Prevents manipulation of randomness source
- Allows fair public access to winner selection

### Process Flow

1. **Epoch Ends** → Backend detects completion
2. **Admin Sets Participants** → `set-burners(epoch, [addresses])`
3. **6-Block Wait** → Ensures randomness security
4. **Public Draw** → Anyone can call `reveal-winner(epoch)`
5. **Automatic Payout** → Winner receives tokens immediately

## Security Analysis

### 🛡️ Strong Protections

**Access Control:**

```clarity
;; Only admin can set participants
(asserts! (is-eq tx-sender admin) err-unauthorized)

;; Only sponsor can set bonuses/withdraw
(asserts! (is-eq tx-sender SPONSOR) err-unauthorized)

;; Only regular users can trigger draws (not contracts)
(asserts! (is-standard-principal-call) err-standard-principal-only)
```

**Randomness Security:**

- Uses blockchain VRF - cryptographically secure
- 6-block delay prevents prediction attacks
- Deterministic but unpredictable results

**Economic Protections:**

- No direct fund withdrawal for users
- Sponsor can only withdraw remaining funds
- Winners receive predetermined amounts only

### ⚠️ Potential Attack Vectors

**1. Admin Key Compromise (High Impact)**

- **Risk**: If admin private key is stolen, attacker can manipulate participant lists
- **Impact**: Could add fake participants or bias selections
- **Mitigation**:
  - Use hardware wallet for admin key
  - Monitor all admin transactions
  - Consider multi-sig admin in future versions

**2. Sponsor Key Compromise (Medium Impact)**

- **Risk**: Attacker can withdraw all contract funds
- **Impact**: Loss of bonus funds, but can't manipulate winners
- **Mitigation**:
  - Keep contract minimally funded
  - Regular fund withdrawals
  - Monitor sponsor transactions

**3. VRF Prediction Attacks (Very Low Risk)**

- **Risk**: Theoretical attacks on VRF randomness
- **Impact**: Could predict winners with massive resources
- **Probability**: Extremely low - economically unfeasible
- **Mitigation**: Current VRF security is sufficient for bonus amounts

**4. Front-running (No Real Impact)**

- **Risk**: Attacker monitors mempool and calls `reveal-winner` first
- **Impact**: No benefit - winner is predetermined by VRF
- **Effect**: Only wastes gas for legitimate callers

**5. Timing Manipulation (Low Risk)**

- **Risk**: Influence when admin calls `set-burners`
- **Impact**: Limited - still can't predict VRF outcomes
- **Requirement**: Would need admin key compromise

### 🔒 Security Recommendations

**For Sponsors:**

1. **Secure Key Management**: Use hardware wallet for sponsor key
2. **Regular Monitoring**: Set up alerts for all sponsor transactions
3. **Fund Management**: Don't store large amounts long-term
4. **Withdrawal Schedule**: Regular withdrawals reduce exposure

**For Users:**

1. **Verify Transactions**: Check all contract calls before signing
2. **Monitor Results**: Winners and participants are publicly viewable
3. **Report Issues**: Contact team if anything seems unusual

**For Development:**

1. **Admin Security**: Consider multi-sig admin for production
2. **Upgrade Path**: Plan for admin key rotation if needed
3. **Monitoring**: Implement automated alerts for admin actions

## Contract Functions

### Public Functions

| Function               | Access       | Description                          |
| ---------------------- | ------------ | ------------------------------------ |
| `set-burners`          | Admin Only   | Set participants for completed epoch |
| `reveal-winner`        | Anyone       | Select winner after delay period     |
| `set-next-epoch-bonus` | Sponsor Only | Set bonus for upcoming epoch         |
| `fund-bonus`           | Anyone       | Add BOB/FAKFUN to contract           |
| `withdraw-dble`        | Sponsor Only | Withdraw all BOB/FAKFUN              |
| `withdraw-ft`          | Sponsor Only | Withdraw any SIP-010 token           |

### Read-Only Functions

| Function                    | Description                     |
| --------------------------- | ------------------------------- |
| `current-epoch`             | Get current epoch number        |
| `is-epoch-finished`         | Check if epoch has ended        |
| `get-epoch-participants`    | List all participants for epoch |
| `get-epoch-bonus-recipient` | Get winner for epoch            |
| `get-bonus-info`            | Complete epoch information      |
| `get-epoch-sponsor-bonus`   | Check sponsor bonus amount      |

## Token Economics

### Bonus Calculation

```clarity
;; Winner receives max of sponsor bonus or participant count
(max-bonus (if (> sponsor-bonus taille) sponsor-bonus taille))

;; Converted to tokens with proper decimals
BOB_amount = max-bonus * 1,000,000     ;; 6 decimals
FAKFUN_amount = max-bonus * 100,000,000 ;; 8 decimals
```

### Example Scenarios

**Scenario 1: Normal Day**

- 25 participants burn BOB
- No sponsor bonus set
- Winner receives: 25 BOB + 25 FAKFUN

**Scenario 2: Sponsored Day**

- 25 participants burn BOB
- Sponsor sets 100 BOB bonus
- Winner receives: 100 BOB + 100 FAKFUN

**Scenario 3: Low Participation + Sponsor**

- 5 participants burn BOB
- Sponsor sets 10 BOB bonus
- Winner receives: 10 BOB + 10 FAKFUN (sponsor amount wins)

## Development & Testing

### Local Testing

```bash
clarinet console

# Test basic functions
(contract-call? .bob-bonus-faktory current-epoch)
(contract-call? .bob-bonus-faktory get-rnd u100)

# Set test participants
(contract-call? .bob-bonus-faktory set-burners u0
    (list 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
          'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG))

# Advance time and reveal winner
::advance_chain_tip 10
(contract-call? .bob-bonus-faktory reveal-winner u0)
```

### Integration Requirements

- BOB Token: `SP2VG7S0R4Z8PYNYCAQ04HCBX1MH75VT11VXCWQ6G.built-on-bitcoin-stxcity`
- FAKFUN Token: `SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-faktory`
- Burn Contract: `SP29D6YMDNAKN1P045T6Z817RTE1AC0JAA99WAX2B.burn-bob-faktory`

## Conclusion

The Burn Bob Daily Bonus Contract provides a fair, transparent, and secure way to reward daily burn participants. The combination of VRF-based randomness, access controls, and economic protections creates a robust system suitable for community bonus distribution.

While no smart contract is 100% risk-free, the main security considerations are standard operational security (key management) rather than novel attack vectors. The contract's straightforward design and minimal complexity reduce the attack surface significantly.

**For maximum security**: Treat admin and sponsor keys with the same care as large crypto holdings, monitor all transactions, and maintain minimal on-contract fund balances.
