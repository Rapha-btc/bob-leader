;; Caturday Faktory - Saturday LEO Bonus for BOB Winners
;; Awards LEO tokens to BOB daily winners on Saturdays

(define-constant err-unauthorized (err u401))
(define-constant err-not-saturday (err u402))
(define-constant err-already-claimed (err u403))
(define-constant err-no-bob-winner (err u404))
(define-constant err-transfer-failed (err u405))
(define-constant err-epoch-not-drawn (err u406))
(define-constant err-insufficient-balance (err u407))
(define-constant err-already-set (err u408))
(define-constant ERR_OPERATION_NOT_ALLOWED (err u1103))


(define-constant admin 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22)
(define-constant SPONSOR_1 'SP2VG7S0R4Z8PYNYCAQ04HCBX1MH75VT11VXCWQ6G)
(define-constant SPONSOR_2 'SP2KZ24AM4X9HGTG8314MS4VSY1CVAFH0G1KBZZ1D)

(define-constant SPONSORS (list  SPONSOR_1 SPONSOR_2 admin))

;; Saturday calculation constants
(define-constant BURN-GENESIS-BLOCK u902351)
(define-constant EPOCH-LENGTH u144)
(define-data-var saturday-offset uint u41) ;; Epoch 41 is Saturday, so offset from epoch 0

;; Storage
(define-map saturday-claims uint bool) ;; Track which Saturday epochs have been claimed
(define-map leo-bonus-amounts uint uint) ;; LEO bonus amount per Saturday epoch
(define-data-var default-leo-bonus uint u1000000000) ;; Default 1000 LEO (8 decimals)

;; Calculate if an epoch falls on Saturday
(define-read-only (is-saturday-epoch (epoch uint))
    (is-eq (mod (- epoch (var-get saturday-offset)) u7) u0))

;; Get the current epoch (from BOB contract logic)
(define-read-only (calc-epoch (block uint))
    (/ (- block BURN-GENESIS-BLOCK) EPOCH-LENGTH))

(define-read-only (current-epoch)
    (calc-epoch burn-block-height))

;; Check if we can claim Saturday LEO bonus right now
(define-read-only (can-claim-now)
    (let ((current-epoch (current-epoch))
          (previous-epoch (- current-epoch u1))
          (is-current-saturday (is-saturday-epoch current-epoch))
          (is-already-claimed (default-to false (map-get? saturday-claims previous-epoch)))
          (bob-winner (contract-call? 'SP29D6YMDNAKN1P045T6Z817RTE1AC0JAA99WAX2B.bob-bonus-faktory get-epoch-bonus-recipient previous-epoch))
          (leo-bonus (default-to (var-get default-leo-bonus) (map-get? leo-bonus-amounts previous-epoch)))
          (contract-balance (unwrap-panic (contract-call? 'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token get-balance (as-contract tx-sender)))))
        (and is-current-saturday
                           (not is-already-claimed)
                           (is-some bob-winner)
                           (>= contract-balance leo-bonus))
        ))

(define-public (can-claim-rn)
  (let ((wrappedResult (ok (can-claim-now))))
    (ok (unwrap! wrappedResult ERR_OPERATION_NOT_ALLOWED))
  )
)

;; Admin function to adjust Saturday offset if timing slips
(define-public (adjust-saturday-offset (new-offset uint))
    (begin
        (asserts! (is-eq tx-sender admin) err-unauthorized)
        (let ((old-offset (var-get saturday-offset)))
            (var-set saturday-offset new-offset)
            (print {
                event: "saturday-offset-adjusted",
                old-offset: old-offset,
                new-offset: new-offset,
                adjusted-by: tx-sender
            })
            (ok true))))

;; Admin function to set LEO bonus for specific Saturday epoch
(define-public (set-saturday-leo-bonus (epoch uint) (leo-amount uint))
    (begin
        (asserts! (is-sponsor tx-sender) err-unauthorized)
        (asserts! (is-saturday-epoch epoch) err-not-saturday)
        (asserts! (map-insert leo-bonus-amounts epoch leo-amount) err-already-set)
        (print {
            event: "saturday-leo-bonus-set",
            epoch: epoch,
            leo-amount: leo-amount
        })
        (ok true)))

;; Set default LEO bonus amount
(define-public (set-default-leo-bonus (leo-amount uint))
    (begin
        (asserts! (is-eq tx-sender admin) err-unauthorized)
        (var-set default-leo-bonus leo-amount)
        (print {
            event: "default-leo-bonus-updated",
            leo-amount: leo-amount
        })
        (ok true)))

;; Main function: Claim Saturday LEO bonus for previous day's BOB winner
;; When it's Saturday (e.g., epoch 41), award LEO to Friday's winner (epoch 40)
(define-public (claim-saturday-leo-bonus)
    (let ((current-epoch (current-epoch))
          (previous-epoch (- current-epoch u1))
          (is-current-saturday (is-saturday-epoch current-epoch))
          (bob-winner (unwrap! (contract-call? 'SP29D6YMDNAKN1P045T6Z817RTE1AC0JAA99WAX2B.bob-bonus-faktory get-epoch-bonus-recipient previous-epoch) err-no-bob-winner))
          (is-already-claimed (default-to false (map-get? saturday-claims previous-epoch)))
          (leo-bonus (default-to (var-get default-leo-bonus) (map-get? leo-bonus-amounts previous-epoch)))
          (contract-leo-balance (unwrap-panic (contract-call? 'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token get-balance (as-contract tx-sender)))))
        
        ;; Validation checks
        (asserts! is-current-saturday err-not-saturday)
        (asserts! (not is-already-claimed) err-already-claimed)
        (asserts! (>= contract-leo-balance leo-bonus) err-insufficient-balance)
        
        ;; Mark previous epoch as claimed (since that's the winner we're rewarding)
        (map-set saturday-claims previous-epoch true)
        
        ;; Transfer LEO tokens to previous day's BOB winner
        (try! (as-contract (contract-call? 'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token transfer 
                           leo-bonus (as-contract tx-sender) bob-winner none)))
        
        (print {
            event: "saturday-leo-bonus-claimed",
            current-epoch: current-epoch,
            winner-epoch: previous-epoch,
            bob-winner: bob-winner,
            leo-bonus: leo-bonus,
            remaining-balance: (- contract-leo-balance leo-bonus)
        })
        
        (ok bob-winner)))

;; Fund the contract with LEO tokens
(define-public (fund-leo-bonus (leo-amount uint))
    (begin
        (asserts! (> leo-amount u0) err-transfer-failed)
        
        (try! (contract-call? 'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token transfer 
               leo-amount tx-sender (as-contract tx-sender) none))
        
        (print {
            event: "contract-funded-leo",
            funder: tx-sender,
            leo-amount: leo-amount
        })
        
        (ok true)))

;; Withdraw LEO tokens (admin/sponsor only)
(define-public (withdraw-leo)
    (let ((withdrawer tx-sender))
        (asserts! (is-sponsor tx-sender) err-unauthorized)
        (let ((leo-balance (unwrap-panic (contract-call? 'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token get-balance (as-contract tx-sender)))))
            
            (if (> leo-balance u0)
                (try! (as-contract (contract-call? 'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token transfer
                                            leo-balance (as-contract tx-sender) withdrawer none)))
                true)
            
            (print {
                event: "leo-withdrawn",
                withdrawer: tx-sender,
                amount: leo-balance
            })
            
            (ok leo-balance))))

;; Read-only functions
(define-read-only (get-leo-balance)
    (contract-call? 'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token get-balance (as-contract tx-sender)))

(define-read-only (get-saturday-offset)
    (var-get saturday-offset))

(define-read-only (get-saturday-claim-status (epoch uint))
    (default-to false (map-get? saturday-claims epoch)))

(define-read-only (get-saturday-leo-bonus (epoch uint))
    (default-to (var-get default-leo-bonus) (map-get? leo-bonus-amounts epoch)))

(define-read-only (get-default-leo-bonus)
    (var-get default-leo-bonus))


;; Get comprehensive Saturday info for current situation
(define-read-only (get-current-saturday-info)
    (let ((current-epoch (current-epoch))
          (previous-epoch (- current-epoch u1))
          (is-current-saturday (is-saturday-epoch current-epoch))
          (leo-bonus (get-saturday-leo-bonus previous-epoch))
          (bob-winner (default-to 'SP000000000000000000002Q6VF78 (contract-call? 'SP29D6YMDNAKN1P045T6Z817RTE1AC0JAA99WAX2B.bob-bonus-faktory get-epoch-bonus-recipient previous-epoch))))
        {
            current-epoch: current-epoch,
            previous-epoch: previous-epoch,
            is-current-saturday: is-current-saturday,
            leo-bonus: leo-bonus,
            previous-epoch-bob-winner: bob-winner,
            contract-leo-balance: (unwrap-panic (get-leo-balance))
        }))

(define-read-only (is-sponsor (who principal))
  (is-some (index-of SPONSORS who))
)