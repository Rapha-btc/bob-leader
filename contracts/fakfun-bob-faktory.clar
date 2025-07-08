;; ;; not reviewed by Rapha yet
;; ;; Newcomer Streak Incentive Contract
;; ;; Rewards new participants who complete a 3-day streak between epochs 14-28
;; ;; Must not have participated in burn competition before epoch 14

;; ;; Constants
;; (define-constant BURN-COMPETITION-CONTRACT 'SP000000000000000000002Q6VF78.pepe-burn-competition) ;; Replace with actual
;; (define-constant FAKFUN-TOKEN 'SP000000000000000000002Q6VF78.fakfun-token) ;; Replace with actual
;; (define-constant THIS-CONTRACT (as-contract tx-sender))
;; (define-constant CONTRACT-OWNER tx-sender)

;; ;; Incentive parameters
;; (define-constant INCENTIVE-START-EPOCH u14)
;; (define-constant INCENTIVE-END-EPOCH u28)
;; (define-constant REQUIRED-STREAK u3) ;; 3 consecutive days
;; (define-constant REWARD-AMOUNT u69000000000) ;; 69000 FAKFUN (assuming 6 decimals)

;; ;; Error constants
;; (define-constant ERR-UNAUTHORIZED (err u401))
;; (define-constant ERR-NOT-NEWCOMER (err u402))
;; (define-constant ERR-INSUFFICIENT-STREAK (err u403))
;; (define-constant ERR-ALREADY-CLAIMED (err u404))
;; (define-constant ERR-OUTSIDE-INCENTIVE-PERIOD (err u405))
;; (define-constant ERR-TOKEN-TRANSFER-FAILED (err u406))
;; (define-constant ERR-INSUFFICIENT-CONTRACT-BALANCE (err u407))

;; ;; Data structures
;; (define-map newcomer-claims
;;   principal
;;   {
;;     claimed-at-epoch: uint,
;;     streak-completed: uint,
;;     reward-amount: uint
;;   }
;; )

;; (define-map newcomer-streaks
;;   principal
;;   {
;;     current-streak: uint,
;;     last-burn-epoch: uint,
;;     first-burn-epoch: uint
;;   }
;; )

;; (define-map contract-stats
;;   { metric: (string-ascii 20) }
;;   { value: uint }
;; )

;; ;; Initialize stats
;; (map-set contract-stats { metric: "total-claimed" } { value: u0 })
;; (map-set contract-stats { metric: "total-rewards" } { value: u0 })

;; ;; Helper functions
;; (define-read-only (current-epoch)
;;   ;; Get current epoch from burn competition contract
;;   (unwrap-panic (contract-call? BURN-COMPETITION-CONTRACT current-epoch)))

;; (define-read-only (is-newcomer (user principal))
;;   ;; Check if user never participated before epoch 14
;;   (let ((participated-early (check-early-participation user)))
;;     (not participated-early)))

;; (define-read-only (check-early-participation (user principal))
;;   ;; Check epochs 0-13 for any burns
;;   (let ((epochs (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13)))
;;     (fold check-epoch-participation epochs { user: user, found: false })))

;; (define-private (check-epoch-participation (epoch uint) (data { user: principal, found: bool }))
;;   (if (get found data)
;;     data
;;     (let ((burn-data (unwrap-panic (contract-call? BURN-COMPETITION-CONTRACT get-user-burn-for-epoch (get user data) epoch))))
;;       { user: (get user data), found: (> (get amount burn-data) u0) })))

;; (define-read-only (get-user-streak (user principal))
;;   (default-to 
;;     { current-streak: u0, last-burn-epoch: u0, first-burn-epoch: u0 }
;;     (map-get? newcomer-streaks user)))

;; (define-read-only (has-claimed (user principal))
;;   (is-some (map-get? newcomer-claims user)))

;; (define-read-only (is-eligible (user principal))
;;   (let ((current (current-epoch))
;;         (streak-data (get-user-streak user)))
;;     (and 
;;       (>= current INCENTIVE-START-EPOCH)
;;       (<= current INCENTIVE-END-EPOCH)
;;       (is-newcomer user)
;;       (>= (get current-streak streak-data) REQUIRED-STREAK)
;;       (not (has-claimed user)))))

;; (define-read-only (get-claim-info (user principal))
;;   (map-get? newcomer-claims user))

;; (define-read-only (get-contract-balance)
;;   (unwrap-panic (contract-call? FAKFUN-TOKEN get-balance THIS-CONTRACT)))

;; (define-read-only (get-stat (metric (string-ascii 20)))
;;   (get value (default-to { value: u0 } (map-get? contract-stats { metric: metric }))))

;; ;; Update user streak when they burn
;; (define-public (update-user-streak (user principal) (epoch uint))
;;   (let ((current-streak-data (get-user-streak user))
;;         (last-epoch (get last-burn-epoch current-streak-data))
;;         (current-streak (get current-streak current-streak-data))
;;         (first-burn (get first-burn-epoch current-streak-data)))
    
;;     ;; Only contract owner or burn competition contract can call this
;;     (asserts! (or (is-eq tx-sender CONTRACT-OWNER) 
;;                   (is-eq tx-sender BURN-COMPETITION-CONTRACT)) ERR-UNAUTHORIZED)
    
;;     (let ((is-consecutive (is-eq epoch (+ last-epoch u1)))
;;           (new-streak (if is-consecutive (+ current-streak u1) u1))
;;           (new-first-burn (if (is-eq first-burn u0) epoch first-burn)))
      
;;       ;; Update streak data
;;       (map-set newcomer-streaks user {
;;         current-streak: new-streak,
;;         last-burn-epoch: epoch,
;;         first-burn-epoch: new-first-burn
;;       })
      
;;       ;; Emit event
;;       (print {
;;         contract: THIS-CONTRACT,
;;         event: "streak-updated",
;;         user: user,
;;         epoch: epoch,
;;         new-streak: new-streak,
;;         is-consecutive: is-consecutive,
;;         first-burn: new-first-burn
;;       })
      
;;       (ok true))))

;; ;; Main claim function
;; (define-public (claim-newcomer-reward)
;;   (let ((user tx-sender)
;;         (current (current-epoch))
;;         (streak-data (get-user-streak user)))
    
;;     ;; Check if within incentive period
;;     (asserts! (and (>= current INCENTIVE-START-EPOCH) 
;;                    (<= current INCENTIVE-END-EPOCH)) ERR-OUTSIDE-INCENTIVE-PERIOD)
    
;;     ;; Check if user is newcomer
;;     (asserts! (is-newcomer user) ERR-NOT-NEWCOMER)
    
;;     ;; Check if user already claimed
;;     (asserts! (not (has-claimed user)) ERR-ALREADY-CLAIMED)
    
;;     ;; Check if user has sufficient streak
;;     (asserts! (>= (get current-streak streak-data) REQUIRED-STREAK) ERR-INSUFFICIENT-STREAK)
    
;;     ;; Check contract has sufficient balance
;;     (asserts! (>= (get-contract-balance) REWARD-AMOUNT) ERR-INSUFFICIENT-CONTRACT-BALANCE)
    
;;     ;; Transfer reward
;;     (try! (as-contract (contract-call? FAKFUN-TOKEN transfer 
;;            REWARD-AMOUNT 
;;            THIS-CONTRACT 
;;            user 
;;            (some 0x6e6577636f6d65722d737472656b)))) ;; "newcomer-streak"
    
;;     ;; Record the claim
;;     (map-set newcomer-claims user {
;;       claimed-at-epoch: current,
;;       streak-completed: (get current-streak streak-data),
;;       reward-amount: REWARD-AMOUNT
;;     })
    
;;     ;; Update stats
;;     (map-set contract-stats { metric: "total-claimed" } 
;;       { value: (+ (get-stat "total-claimed") u1) })
;;     (map-set contract-stats { metric: "total-rewards" } 
;;       { value: (+ (get-stat "total-rewards") REWARD-AMOUNT) })
    
;;     ;; Emit event
;;     (print {
;;       contract: THIS-CONTRACT,
;;       token-contract: FAKFUN-TOKEN,
;;       event: "newcomer-reward-claimed",
;;       user: user,
;;       epoch: current,
;;       streak: (get current-streak streak-data),
;;       reward: REWARD-AMOUNT,
;;       first-burn-epoch: (get first-burn-epoch streak-data)
;;     })
    
;;     (ok true)))

;; ;; Admin functions
;; (define-public (fund-contract (amount uint))
;;   (begin
;;     (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
;;     (try! (contract-call? FAKFUN-TOKEN transfer amount tx-sender THIS-CONTRACT none))
;;     (ok true)))

;; (define-public (emergency-withdraw (amount uint))
;;   (begin
;;     (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
;;     (try! (as-contract (contract-call? FAKFUN-TOKEN transfer amount THIS-CONTRACT CONTRACT-OWNER none)))
;;     (ok true)))

;; (define-public (extend-incentive-period (new-end-epoch uint))
;;   (begin
;;     (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
;;     ;; This would require a contract upgrade or using a data var
;;     (ok true)))

;; ;; View functions for frontend
;; (define-read-only (get-incentive-info)
;;   {
;;     start-epoch: INCENTIVE-START-EPOCH,
;;     end-epoch: INCENTIVE-END-EPOCH,
;;     required-streak: REQUIRED-STREAK,
;;     reward-amount: REWARD-AMOUNT,
;;     current-epoch: (current-epoch),
;;     total-claimed: (get-stat "total-claimed"),
;;     total-rewards: (get-stat "total-rewards"),
;;     contract-balance: (get-contract-balance)
;;   })

;; (define-read-only (check-user-eligibility (user principal))
;;   (let ((current (current-epoch))
;;         (streak-data (get-user-streak user))
;;         (is-new (is-newcomer user)))
;;     {
;;       user: user,
;;       is-newcomer: is-new,
;;       current-streak: (get current-streak streak-data),
;;       required-streak: REQUIRED-STREAK,
;;       is-eligible: (is-eligible user),
;;       has-claimed: (has-claimed user),
;;       first-burn-epoch: (get first-burn-epoch streak-data),
;;       last-burn-epoch: (get last-burn-epoch streak-data),
;;       epochs-remaining: (if (<= current INCENTIVE-END-EPOCH) 
;;                           (- INCENTIVE-END-EPOCH current) 
;;                           u0)
;;     }))

;; ;; Batch check for multiple users
;; (define-read-only (check-multiple-users (users (list 10 principal)))
;;   (map check-user-eligibility users))