;; mainnet revert: 'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
;; PEPE Burn-to-Play Competition Contract - Fast Games
;; Short competitions (3 blocks = ~30 minutes) where highest burner wins 90% of total burned
;; Anyone can create a new game if no active game exists

;; Constants
(define-constant BURN-ADDRESS 'SP000000000000000000002Q6VF78) 
(define-constant THIS-CONTRACT (as-contract tx-sender))
(define-constant FAKTORY 'SM3NY5HXXRNCHS1B65R78CYAC1TQ6DEMN3C0DN74S) 

;; Game system using Bitcoin block timing
(define-constant GAME-LENGTH u3) ;; ~30 minutes at ~10min/block

;; Percentages (basis points for precision)
(define-constant WINNER-PERCENTAGE u9000) ;; 90%
(define-constant BASIS-POINTS u10000)     ;; 100%

;; Error constants
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-INVALID-AMOUNT (err u402))
(define-constant ERR-NO-BURNS-THIS-GAME (err u403))
(define-constant ERR-ALREADY-SETTLED (err u404))
(define-constant ERR-TOKEN-TRANSFER-FAILED (err u405))
(define-constant ERR-INSUFFICIENT-PARTICIPANTS (err u406))
(define-constant ERR-GAME-NOT-ENDED (err u407))
(define-constant ERR-GAME-ALREADY-ACTIVE (err u408))
(define-constant ERR-NO-ACTIVE-GAME (err u409))

(define-constant ERR-GAME-ENDED (err u411))

;; Data structures
(define-map game-burns
  { user: principal, game-id: uint }
  { amount: uint, block-height: uint }
)

(define-map games
  uint ;; game-id
  { 
    creator: principal,
    start-block: uint,
    end-block: uint,
    total-burned: uint,
    participant-count: uint,
    highest-burner: (optional principal),
    highest-amount: uint,
    settled: bool
  }
)

(define-map user-total-burns
  principal
  uint ;; total amount burned across all games
)

;; Global state
(define-data-var current-game-id uint u0)
(define-data-var next-game-id uint u1)

;; Helper functions
(define-read-only (get-current-game-id)
  (var-get current-game-id))

(define-read-only (get-next-game-id)
  (var-get next-game-id))

(define-read-only (get-game-info (game-id uint))
  (map-get? games game-id))

(define-read-only (get-current-game) ;; latest created game
  (let ((current-id (get-current-game-id)))
    (if (is-eq current-id u0)
        none
        (get-game-info current-id))))

(define-read-only (is-game-active (game-id uint))
  (match (get-game-info game-id)
    game-info (<= burn-block-height (get end-block game-info))
    false))

(define-read-only (is-game-ended (game-id uint))
  (match (get-game-info game-id)
    game-info (> burn-block-height (get end-block game-info))
    false))

(define-read-only (get-user-burn-for-game (user principal) (game-id uint))
  (default-to 
    { amount: u0, block-height: u0 }
    (map-get? game-burns { user: user, game-id: game-id })))

(define-read-only (get-user-total-burns (user principal))
  (default-to u0 (map-get? user-total-burns user)))

(define-read-only (get-blocks-until-game-end (game-id uint))
  (match (get-game-info game-id)
    game-info (if (>= burn-block-height (get end-block game-info))
                  u0
                  (- (get end-block game-info) burn-block-height))
    u0))

(define-read-only (has-active-game)
  (let ((current-id (get-current-game-id)))
    (and (> current-id u0) (is-game-active current-id))))

;; Create a new game
(define-public (create-game)
  (let (
    (creator tx-sender)
    (new-game-id (get-next-game-id))
    (start-block burn-block-height)
    (end-block (+ burn-block-height GAME-LENGTH))
  )
    ;; Check no active game exists
    (asserts! (not (has-active-game)) ERR-GAME-ALREADY-ACTIVE)
    
    ;; Create new game
    (map-set games new-game-id {
      creator: creator,
      start-block: start-block,
      end-block: end-block,
      total-burned: u0,
      participant-count: u0,
      highest-burner: none,
      highest-amount: u0,
      settled: false
    })
    
    ;; Update game counters
    (var-set current-game-id new-game-id)
    (var-set next-game-id (+ new-game-id u1))
    
    ;; Emit event
    (print {
      contract: THIS-CONTRACT,
      token-contract: .tokensoft-token-v4k68639zxz,
      event: "game-created",
      game-id: new-game-id,
      creator: creator,
      start-block: start-block,
      end-block: end-block,
      game-length: GAME-LENGTH,
      block-height: burn-block-height
    })
    
    (ok new-game-id)
  )
)

;; Main burn function
(define-public (burn-to-compete (amount uint))
  (let (
    (current-id (get-current-game-id))
    (user tx-sender)
  )
    ;; Check game is active and not ended
    (asserts! (is-game-active current-id) ERR-GAME-ENDED)
    
    ;; Get game info
    (let (
      (game-info (unwrap! (get-game-info current-id) ERR-NO-ACTIVE-GAME))
      (existing-burn (get-user-burn-for-game user current-id))
    )

      ;; Must burn a positive amount
      (asserts! (> amount u0) ERR-INVALID-AMOUNT)
      
      ;; Transfer PEPE tokens to this contract first
      (try! (contract-call? .tokensoft-token-v4k68639zxz transfer 
             amount 
             user 
             THIS-CONTRACT 
             (some 0x6920676f7420746865206a75696365))) ;; "i got the juice"
      
      ;; Calculate new amounts
      (let (
        (previous-amount (get amount existing-burn))
        (new-total-amount (+ previous-amount amount))
        (new-game-total (+ (get total-burned game-info) amount))
        (new-participant-count (if (is-eq previous-amount u0) 
                                  (+ (get participant-count game-info) u1)
                                  (get participant-count game-info)))
        (is-new-highest (> new-total-amount (get highest-amount game-info)))
        (new-highest-burner (if is-new-highest (some user) (get highest-burner game-info)))
        (new-highest-amount (if is-new-highest new-total-amount (get highest-amount game-info)))
      )
        ;; Update user's burn for this game
        (map-set game-burns 
          { user: user, game-id: current-id }
          { amount: new-total-amount, block-height: burn-block-height })
        
        ;; Update game info
        (map-set games current-id (merge game-info {
          total-burned: new-game-total,
          participant-count: new-participant-count,
          highest-burner: new-highest-burner,
          highest-amount: new-highest-amount
        }))
        
        ;; Update user's total burns across all time
        (map-set user-total-burns user 
          (+ (get-user-total-burns user) amount))
        
        ;; Emit event
        (print {
          contract: THIS-CONTRACT,
          token-contract: .tokensoft-token-v4k68639zxz,
          event: "burn-to-compete",
          game-id: current-id,
          user: user,
          amount: amount,
          total-user: new-total-amount,
          block-height: burn-block-height,
          is-leader: is-new-highest,
          total-burned: new-game-total,
          participant-count: new-participant-count,
          highest-burner: new-highest-burner,
          highest-amount: new-highest-amount
        })
        
        (ok true)
      )
    )
  )
)

;; Settle game - distribute rewards and burn tokens
(define-public (settle-game (game-id uint))
  (let (
    (game-info (unwrap! (get-game-info game-id) ERR-NO-ACTIVE-GAME))
    (total-burned (get total-burned game-info))
    (participant-count (get participant-count game-info))
    (highest-burner (get highest-burner game-info))
  )
    ;; Check that game actually had burns
    (asserts! (> total-burned u0) ERR-NO-BURNS-THIS-GAME)

    ;; Check game has ended
    (asserts! (> burn-block-height (get end-block game-info)) ERR-GAME-NOT-ENDED)
    
    ;; Check not already settled
    (asserts! (not (get settled game-info)) ERR-ALREADY-SETTLED)
    
    ;; Check minimum participants (2)
    (asserts! (>= participant-count u2) ERR-INSUFFICIENT-PARTICIPANTS)
    
    ;; Check we have a highest burner
    (asserts! (is-some highest-burner) ERR-NO-BURNS-THIS-GAME)
    
    (let (
      (winner (unwrap-panic highest-burner))
      (winner-amount (/ (* total-burned WINNER-PERCENTAGE) BASIS-POINTS))
      (remaining-amount (- total-burned winner-amount))
      (fee-amount (/ remaining-amount u10))        ;; 10% of remaining = 1% of total
      (burn-amount (- remaining-amount fee-amount)) ;; 90% of remaining = 9% of total
    )
      ;; Send winner their reward (90%)
      (if (> winner-amount u0)
            (try! (as-contract (contract-call? .tokensoft-token-v4k68639zxz transfer 
                    winner-amount 
                    THIS-CONTRACT 
                    winner 
                    (some 0x6920676f7420746865206a75696365))))
            true) 
      
      ;; Burn tokens (9%)
      (if (> burn-amount u0)
            (try! (as-contract (contract-call? .tokensoft-token-v4k68639zxz transfer 
                    burn-amount 
                    THIS-CONTRACT 
                    BURN-ADDRESS 
                    (some 0x70657065206275726e)))) ;; "pepe burn"
            true) 
      
      ;; Send fee to contract owner (1%)
      (if (> fee-amount u0)
            (try! (as-contract (contract-call? .tokensoft-token-v4k68639zxz transfer 
                    fee-amount 
                    THIS-CONTRACT 
                    FAKTORY
                    (some 0x6920676f7420746865206a75696365)))) 
            true) 
      
      ;; Mark game as settled
      (map-set games game-id 
        (merge game-info { settled: true }))
      
      ;; Emit settlement event
      (print {
        contract: THIS-CONTRACT,
        token-contract: .tokensoft-token-v4k68639zxz,
        event: "game-settled",
        game-id: game-id,
        total-burned: total-burned,
        participant-count: participant-count,
        highest-burner: highest-burner,
        highest-amount: (get highest-amount game-info),
        settled: true,
        winner: winner,
        winner-amount: winner-amount,
        burn-amount: burn-amount,
        fee-amount: fee-amount,
        block-height: burn-block-height
      })
      
      (ok true)
    )
  )
)

;; Refund function for games with only 1 participant
(define-public (refund-solo-game (game-id uint))
  (let (
    (game-info (unwrap! (get-game-info game-id) ERR-NO-ACTIVE-GAME))
    (total-burned (get total-burned game-info))
    (participant-count (get participant-count game-info))
    (highest-burner (get highest-burner game-info))
  )
    ;; Check that game actually had burns
    (asserts! (> total-burned u0) ERR-NO-BURNS-THIS-GAME)

    ;; Check game has ended
    (asserts! (> burn-block-height (get end-block game-info)) ERR-GAME-NOT-ENDED)
    
    ;; Check not already settled
    (asserts! (not (get settled game-info)) ERR-ALREADY-SETTLED)
    
    ;; Check exactly 1 participant
    (asserts! (is-eq participant-count u1) ERR-INSUFFICIENT-PARTICIPANTS)
    
    ;; Check we have a highest burner
    (asserts! (is-some highest-burner) ERR-NO-BURNS-THIS-GAME)
    
    (let ((solo-user (unwrap-panic highest-burner)))
      ;; Refund all tokens to the solo participant
      (try! (as-contract (contract-call? .tokensoft-token-v4k68639zxz transfer 
             total-burned 
             THIS-CONTRACT 
             solo-user 
             (some 0x6920676f7420746865206a75696365))))
      
      ;; Mark game as settled
      (map-set games game-id 
        (merge game-info { settled: true }))
      
      ;; Emit refund event
      (print {
        contract: THIS-CONTRACT,
        token-contract: .tokensoft-token-v4k68639zxz,
        event: "game-refunded",
        game-id: game-id,
        solo-user: solo-user,
        total-burned: total-burned,
        participant-count: participant-count,
        highest-burner: highest-burner,
        highest-amount: (get highest-amount game-info),
        settled: true
      })
      
      (ok true)
    )
  )
)