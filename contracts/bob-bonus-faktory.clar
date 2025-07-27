;; Burn Bob Daily Bonus Contract
;; Selects random bonus recipients from daily burn participants

(define-constant err-block-not-found (err u404))
(define-constant err-not-at-draw-block (err u400))
(define-constant err-standard-principal-only (err u401))
(define-constant err-unable-to-get-random-seed (err u500))
(define-constant err-no-participants (err u403))
(define-constant err-unauthorized (err u402))
(define-constant err-epoch-already-drawn (err u405))
(define-constant err-epoch-not-ready (err u406))
(define-constant err-transfer-failed (err u407))
(define-constant err-already-set (err u408))

;; Contract admin (your backend)
(define-constant admin tx-sender) 
(define-constant SPONSOR 'SP2VG7S0R4Z8PYNYCAQ04HCBX1MH75VT11VXCWQ6G) 

;; Bonus amount for next epoch only
(define-map epoch-bonus uint uint)

;; Reference to the burn contract for validation
(define-constant BURN-CONTRACT 'SP29D6YMDNAKN1P045T6Z817RTE1AC0JAA99WAX2B.burn-bob-faktory)
(define-constant BURN-GENESIS-BLOCK u902351) ;; When burn contract was deployed
(define-constant EPOCH-LENGTH u144) ;; Same as burn contract: ~1 day at ~10min/block

;; Random number generation (same VRF approach)
(define-read-only (get-rnd (block uint))
    (let (
        (vrf (buff-to-uint-be (unwrap-panic (as-max-len? (unwrap-panic (slice? (unwrap! (get-block-info? vrf-seed block) err-block-not-found) u16 u32)) u16))))
        (time (unwrap! (get-block-info? time block) err-block-not-found)))
        ;; Because time is not deterministic we ignore it in testing envs
        (ok (if is-in-mainnet (+ vrf time) vrf))))

;; Storage for bonus data
(define-map epoch-participants uint (list 1000 principal)) ;; Max 500 participants per epoch
(define-map epoch-bonus-recipients uint principal)
(define-map epoch-draw-blocks uint uint) ;; When each epoch bonus can be drawn
(define-map epoch-status uint bool) ;; Track if epoch bonus has been drawn

;; Private helper functions
(define-private (is-standard-principal-call)
    (is-none (get name (unwrap-panic (principal-destruct? contract-caller)))))

;; Calculate epoch from burn block height (matches burn contract logic)
(define-read-only (calc-epoch (block uint))
  (/ (- block BURN-GENESIS-BLOCK) EPOCH-LENGTH))

;; Calculate when an epoch ends
(define-read-only (calc-epoch-end (epoch uint))
  (- (+ BURN-GENESIS-BLOCK (* EPOCH-LENGTH (+ epoch u1))) u1))

;; Check if an epoch is finished
(define-read-only (is-epoch-finished (epoch uint))
  (> burn-block-height (calc-epoch-end epoch)))

;; Get current epoch
(define-read-only (current-epoch)
  (calc-epoch burn-block-height))

;; Admin function: Set participants for an epoch
;; Called by your backend after epoch ends
(define-public (set-burners (epoch uint) (participants (list 1000 principal)))
    (begin
        (asserts! (is-eq tx-sender admin) err-unauthorized)
        (asserts! (is-none (map-get? epoch-status epoch)) err-epoch-already-drawn)
        (asserts! (is-epoch-finished epoch) err-epoch-not-ready)

        ;; Store participants
        (map-set epoch-participants epoch participants)
        
        ;; Set draw block: Current block + 6 blocks (for confirmation safety)
        (map-set epoch-draw-blocks epoch (+ burn-block-height u6))
        
        ;; Mark epoch as ready for bonus draw
        (map-set epoch-status epoch false)
        
        (print {
            event: "epoch-participants-set",
            epoch: epoch,
            epoch-end-block: (calc-epoch-end epoch),
            current-burn-block: burn-block-height,
            participant-count: (len participants),
            draw-block: (+ burn-block-height u6)
        })
        
        (ok true)))

;; Public function: Pick bonus recipient for an epoch
;; Anyone can call this after the draw block
(define-public (reveal-winner (epoch uint))
    (begin
        (asserts! (is-standard-principal-call) err-standard-principal-only)
        
        (let 
            ((participants (unwrap! (map-get? epoch-participants epoch) err-no-participants))
             (draw-block (unwrap! (map-get? epoch-draw-blocks epoch) err-not-at-draw-block))
             (already-drawn (default-to false (map-get? epoch-status epoch)))
             (taille (len participants))
             (sponsor-bonus (default-to u0 (map-get? epoch-bonus epoch)))
             (max-bonus (if (> sponsor-bonus taille) sponsor-bonus taille)))
            
            ;; Ensure we haven't drawn this epoch bonus yet
            (asserts! (not already-drawn) err-epoch-already-drawn)
            
            ;; Ensure we're past the draw block
            (asserts! (> burn-block-height draw-block) err-not-at-draw-block)
            
            ;; Ensure there are participants
            (asserts! (> taille u0) err-no-participants)
            
            (let
                ((random-number (unwrap! (get-rnd draw-block) err-unable-to-get-random-seed))
                 (recipient-index (mod random-number taille))
                 (chosen-recipient (unwrap! (element-at? participants recipient-index) err-no-participants)))
                
                ;; Store the bonus recipient
                (map-set epoch-bonus-recipients epoch chosen-recipient)
                
                ;; Mark epoch as drawn
                (map-set epoch-status epoch true)

                ;; Transfer BOBs to winner
                (try! (as-contract (contract-call? 'SP2VG7S0R4Z8PYNYCAQ04HCBX1MH75VT11VXCWQ6G.built-on-bitcoin-stxcity 
                           transfer (* max-bonus u1000000) (as-contract tx-sender) chosen-recipient none)))
                
                (try! (as-contract (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-faktory 
                           transfer (* max-bonus u100000000) (as-contract tx-sender) chosen-recipient none)))
                
                ;; Emit event
                (print {
                    event: "epoch-bonus-recipient-selected",
                    epoch: epoch,
                    recipient: chosen-recipient,
                    total-participants: taille,
                    sponsor-bonus: sponsor-bonus,
                    final-bonus: max-bonus,
                    draw-block: draw-block,
                    random-seed: random-number
                })
                
                (ok chosen-recipient)))))

;; Read-only functions
(define-read-only (get-epoch-participants (epoch uint))
    (map-get? epoch-participants epoch))

(define-read-only (get-epoch-bonus-recipient (epoch uint))
    (map-get? epoch-bonus-recipients epoch))

(define-read-only (get-epoch-draw-block (epoch uint))
    (map-get? epoch-draw-blocks epoch))

(define-read-only (is-epoch-drawn (epoch uint))
    (default-to false (map-get? epoch-status epoch)))

(define-read-only (get-bonus-info (epoch uint))
    (let ((participants (map-get? epoch-participants epoch))
          (recipient (map-get? epoch-bonus-recipients epoch))
          (draw-block (map-get? epoch-draw-blocks epoch))
          (is-drawn (default-to false (map-get? epoch-status epoch))))
        {
            participants: participants,
            recipient: recipient,
            draw-block: draw-block,
            is-drawn: is-drawn,
            can-draw: (and (is-some draw-block) 
                          (not is-drawn)
                          (> burn-block-height (unwrap-panic draw-block)))
        }))

;; Sponsor
(define-public (set-next-epoch-bonus (bonus-amount uint))
    (let 
        ((next-epoch (+ (current-epoch) u1)))
        (asserts! (is-eq tx-sender SPONSOR) err-unauthorized)
        
        ;; Set bonus for next epoch
        (unwrap! (map-insert epoch-bonus next-epoch bonus-amount) err-already-set)
        
        (print {
            event: "next-epoch-bonus-set",
            next-epoch: next-epoch,
            bonus-amount: bonus-amount,
            sponsor: SPONSOR
        })
        
        (ok true)))

(define-read-only (get-epoch-sponsor-bonus (epoch uint))
    (map-get? epoch-bonus epoch))

;; Allow anyone to fund the contract with BOB and FAKFUN tokens
(define-public (fund-bonus (bob-bonus uint))
    (begin
        ;; Transfer BOB tokens to contract
        (if (> bob-bonus u0)
            (begin
            (try! (contract-call? 'SP2VG7S0R4Z8PYNYCAQ04HCBX1MH75VT11VXCWQ6G.built-on-bitcoin-stxcity 
                   transfer bob-bonus tx-sender (as-contract tx-sender) none))
            (try! (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-faktory 
                   transfer (* bob-bonus u100) tx-sender (as-contract tx-sender) none)))
            (ok true))
        
        ;; Emit funding event
        (print {
            event: "contract-funded",
            funder: tx-sender,
            bob-bonus: bob-bonus,
            fakfun-bonus: (* bob-bonus u100)
        })
        
        (ok true)))

;; Check contract's BOB balance
(define-read-only (get-bob-balance)
    (contract-call? 'SP2VG7S0R4Z8PYNYCAQ04HCBX1MH75VT11VXCWQ6G.built-on-bitcoin-stxcity 
                    get-balance (as-contract tx-sender)))

;; Check contract's FAKFUN balance  
(define-read-only (get-fakfun-balance)
    (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-faktory 
                    get-balance (as-contract tx-sender)))

(define-public (withdraw-dble)
    (let ((contract-balance-1 (unwrap-panic (contract-call? 'SP2VG7S0R4Z8PYNYCAQ04HCBX1MH75VT11VXCWQ6G.built-on-bitcoin-stxcity get-balance (as-contract tx-sender))))
          (contract-balance-2 (unwrap-panic (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-faktory get-balance (as-contract tx-sender)))))
        (if (> contract-balance-1 u0)
            (as-contract (contract-call? 'SP2VG7S0R4Z8PYNYCAQ04HCBX1MH75VT11VXCWQ6G.built-on-bitcoin-stxcity transfer
                                        contract-balance-1 tx-sender SPONSOR none))
            (ok true))
            
            (as-contract (contract-call? 'SP2VG7S0R4Z8PYNYCAQ04HCBX1MH75VT11VXCWQ6G.built-on-bitcoin-stxcity transfer
                                        contract-balance-2 tx-sender SPONSOR none))
            (ok true)
        )
    )
)

(define-public (withdraw-ft (ft <sip010-trait>))
    (let ((contract-balance (unwrap-panic (contract-call? ft get-balance (as-contract tx-sender)))))
        (if (> contract-balance u0)
            (as-contract (contract-call? ft transfer
                                        contract-balance tx-sender SPONSOR none))
            (ok true)
        )
    )
)