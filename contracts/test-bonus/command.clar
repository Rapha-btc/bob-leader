Here are all the command lines to test your contract in Clarinet console:

## **1. Start Console**
```bash
clarinet console
```

## **2. Basic Contract State**
```clarity
;; Check current epoch
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory current-epoch)

;; Check if epoch 0 is finished (should be false initially)
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory is-epoch-finished u35)

;; Check current burn block height
burn-block-height

;; Check current stacks block height  
stacks-block-height

;; Get epoch end block for epoch 0
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory calc-epoch-end u35)
```

## **3. Test Random Number Generation**
```clarity
;; Test the random function with current block
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory get-rnd stacks-block-height)
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory get-rnd u2357000)

;; Test with a specific block
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory get-rnd u100)
```

## **4. Set Up Participants (As Admin)**
```clarity
;; You are already the admin (tx-sender), so set participants for epoch 0
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory set-burners u0 
    (list 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM 
          'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG 
          'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5))

::advance_chain_tip 7

;; Check if participants were set
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory get-epoch-participants u0)

;; Check the draw block that was set
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory get-epoch-draw-block u0)

;; Check bonus info
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory get-bonus-info u0)
```

## **5. Test Sponsor Functions**
```clarity
;; Switch to sponsor account
::set_tx_sender SP2VG7S0R4Z8PYNYCAQ04HCBX1MH75VT11VXCWQ6G

;; Set bonus for next epoch
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory set-next-epoch-bonus u100)

;; Check sponsor bonus was set
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory get-epoch-sponsor-bonus u1)

;; Switch back to admin
::set_tx_sender ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
```

## **6. Advance Time to Test Winner Selection**
```clarity
;; Advance stacks chain to pass the draw block
::advance_chain_tip 10

;; Check current stacks block height
stacks-block-height

;; Check if we can draw now
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory get-bonus-info u0)
```

::set_tx_sender SPHZFJCQCR6VWAAZXQ2DX3G3GZPAMCX42GKDK9AN

(contract-call? 'SP2VG7S0R4Z8PYNYCAQ04HCBX1MH75VT11VXCWQ6G.built-on-bitcoin-stxcity 
    transfer u1000000000000 'SPHZFJCQCR6VWAAZXQ2DX3G3GZPAMCX42GKDK9AN 
    'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory none)


::set_tx_sender SP3MZYWF2JWWYSP5NEH9Z8Y46D3HZVY3CZD5RGVHD

(contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-faktory 
    transfer u100000000000000 'SP3MZYWF2JWWYSP5NEH9Z8Y46D3HZVY3CZD5RGVHD 
    'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory none)


## **7. Reveal Winner**
```clarity
;; Try to reveal winner (should work after advancing blocks)
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory reveal-winner u0)

;; Check who won
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory get-epoch-bonus-recipient u0)

;; Check if epoch is now drawn
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory is-epoch-drawn u0)

;; Get full bonus info
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory get-bonus-info u0)
```

## **8. Test Error Cases**
```clarity
;; Try to set participants again (should fail - already drawn)
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory set-burners u0 
    (list 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM))

;; Try to reveal winner again (should fail - already drawn)  
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory reveal-winner u0)

;; Try unauthorized action (switch to different user first)
::set_tx_sender ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory set-burners u1 (list tx-sender))
```

## **9. Test Token Functions (Will Fail Without Real Tokens)**
```clarity
;; Switch back to admin
::set_tx_sender ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM

;; Try funding (will fail without real tokens but tests the call)
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory fund-bonus u1000000)

;; Check contract balances (will return 0 or error)
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory get-bob-balance)
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory get-fakfun-balance)

;; Test sponsor withdrawal (switch to sponsor first)
::set_tx_sender SP2VG7S0R4Z8PYNYCAQ04HCBX1MH75VT11VXCWQ6G
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory withdraw-dble)
```

## **10. Test Multiple Epochs**
```clarity
;; Switch back to admin for next epoch
::set_tx_sender ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM

;; Advance burn chain to make epoch 1 finished
::advance_burn_chain_tip 200

;; Check if epoch 1 is now finished
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory is-epoch-finished u1)
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory current-epoch)

;; Set participants for epoch 1
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory set-burners u1 
    (list 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM 
          'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG))
```

## **Useful Clarinet Commands:**
```clarity
;; Switch transaction sender
::set_tx_sender <principal>

;; Advance Stacks chain tip
::advance_chain_tip <blocks>

;; Advance burn chain tip (Bitcoin blocks)
::advance_burn_chain_tip <blocks>

;; Get current block heights
stacks-block-height
burn-block-height

;; Get transaction sender
tx-sender
```

Start with the basic state checks, then set participants, advance time, and reveal the winner! 🎯

::set_tx_sender SP2VG7S0R4Z8PYNYCAQ04HCBX1MH75VT11VXCWQ6G
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory set-next-epoch-bonus u100)
;; Switch back to admin  
::set_tx_sender ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
::set_tx_sender ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG

(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory is-epoch-finished u1)
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory is-epoch-finished u36)

(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory calc-epoch-end u36)

(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory set-burners u36 
    (list 'SP2VG7S0R4Z8PYNYCAQ04HCBX1MH75VT11VXCWQ6G 
          'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG))

(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory reveal-winner u36)
::advance_chain_tip 8

(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory current-epoch)
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory set-burners u37 (list tx-sender)) 

(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory reveal-winner u99)  
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory get-bob-balance)
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory get-fakfun-balance)
(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory withdraw-dble)

(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory fund-bonus u10000000000)  

(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bob-bonus-faktory set-burners u1 (list tx-sender))
