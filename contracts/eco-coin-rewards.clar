;; eco-coin-rewards-v1
;; This contract implements a fungible token (ECO) to incentivize recycling.
;; Sponsors fund a treasury, and certified centers distribute claim rights
;; to users who can then mint their reward tokens.

;; --- Constants and Errors ---
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_CERTIFIED_CENTER (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_CLAIM_NOT_FOUND (err u103))
(define-constant ERR_CLAIM_ALREADY_PROCESSED (err u104))
(define-constant ERR_TREASURY_EMPTY (err u105))
(define-constant ERR_INSUFFICIENT_BALANCE (err u106))
(define-constant ERR_INSUFFICIENT_STX (err u107))

;; --- Token and Data Definitions ---

;; Define the Eco-Coin fungible token
(define-fungible-token eco-coin)

(define-data-var token-uri (string-utf8 256) u"")
(define-data-var total-supply uint u0)

;; Map of certified recycling centers
(define-map certified-recycling-centers principal { name: (string-ascii 50) })

;; Map of pending claims for users, authorized by recycling centers.
;; A user can have one pending claim per center.
(define-map pending-claims { user: principal, center: principal } { amount: uint, claim-id: uint })
(define-data-var next-claim-id uint u1)

;; Map to prevent replay attacks on claims
(define-map processed-claims uint bool)

;; Data var for the treasury balance, funded by sponsors
(define-data-var treasury-balance uint u0)

;; --- Initialization ---
(map-set certified-recycling-centers CONTRACT_OWNER { name: "Genesis Center" })

;; --- Private Functions ---

(define-private (is-owner) 
  (is-eq tx-sender CONTRACT_OWNER))

(define-private (is-center (center principal)) 
  (is-some (map-get? certified-recycling-centers center)))

;; --- Administrative Functions ---

;; Add a new certified recycling center.
;; @param center-principal: The principal of the recycling center.
;; @param center-name: The name of the center.
(define-public (add-center (center-principal principal) (center-name (string-ascii 50)))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (ok (map-set certified-recycling-centers center-principal { name: center-name }))))

;; Remove a certified recycling center.
;; @param center-principal: The principal of the center to remove.
(define-public (remove-center (center-principal principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (ok (map-delete certified-recycling-centers center-principal))))

;; Update the token metadata URI.
(define-public (set-token-uri (new-uri (string-utf8 256)))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (ok (var-set token-uri new-uri))))

;; --- Sponsor and Treasury Functions ---

;; Allow anyone to sponsor the program by depositing STX.
;; @param amount: The amount of STX to deposit (in microSTX).
(define-public (fund-treasury (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= (stx-get-balance tx-sender) amount) ERR_INSUFFICIENT_STX)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set treasury-balance (+ (var-get treasury-balance) amount))
    (print { type: "treasury-funded", sponsor: tx-sender, amount: amount })
    (ok true)))

;; --- Core Recycling Reward Functions ---

;; A certified center authorizes a reward for a user.
;; This creates a claim that the user can then process.
;; @param user: The principal of the user who recycled.
;; @param amount: The amount of Eco-Coins to award.
(define-public (authorize-claim (user principal) (amount uint))
  (begin
    (asserts! (is-center tx-sender) ERR_NOT_CERTIFIED_CENTER)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (let ((claim-id (var-get next-claim-id)))
      (map-set pending-claims { user: user, center: tx-sender } { amount: amount, claim-id: claim-id })
      (var-set next-claim-id (+ claim-id u1))
      (print { type: "claim-authorized", center: tx-sender, user: user, amount: amount, claim-id: claim-id })
      (ok claim-id))))

;; The user calls this function to process their claim and mint Eco-Coins.
;; @param center: The principal of the center that authorized the claim.
(define-public (process-my-claim (center principal))
  (let ((claim-data (unwrap! (map-get? pending-claims { user: tx-sender, center: center }) ERR_CLAIM_NOT_FOUND)))
    (let ((claim-id (get claim-id claim-data))
          (amount (get amount claim-data)))
      (asserts! (not (default-to false (map-get? processed-claims claim-id))) ERR_CLAIM_ALREADY_PROCESSED)

      ;; Mint the tokens to the user
      (try! (ft-mint? eco-coin amount tx-sender))

      ;; Update total supply
      (var-set total-supply (+ (var-get total-supply) amount))

      ;; Mark claim as processed and delete the pending entry
      (map-set processed-claims claim-id true)
      (map-delete pending-claims { user: tx-sender, center: center })

      (print { type: "claim-processed", user: tx-sender, amount: amount, claim-id: claim-id })
      (ok true))))

;; A function to demonstrate token utility, e.g., redeeming for STX from the treasury.
;; @param amount: The amount of eco-coins to redeem.
(define-public (redeem-for-stx (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= (ft-get-balance eco-coin tx-sender) amount) ERR_INSUFFICIENT_BALANCE)

    ;; For this example, 100 eco-coins = 1 STX (1,000,000 uSTX)
    ;; Rate: 10,000 uSTX per ECO token
    (let ((stx-value (/ (* amount u10000) u1)))
      (asserts! (>= (var-get treasury-balance) stx-value) ERR_TREASURY_EMPTY)

      ;; Burn user's eco-coins
      (try! (ft-burn? eco-coin amount tx-sender))

      ;; Update total supply
      (var-set total-supply (- (var-get total-supply) amount))

      ;; Pay user from treasury
      (try! (as-contract (stx-transfer? stx-value tx-sender tx-sender)))

      ;; Update treasury balance
      (var-set treasury-balance (- (var-get treasury-balance) stx-value))
      (print { type: "tokens-redeemed", user: tx-sender, eco-amount: amount, stx-amount: stx-value })
      (ok true))))

;; --- Transfer Functions ---

;; Transfer eco-coins between users
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (or (is-eq tx-sender sender) (is-eq contract-caller sender)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-valid-principal sender) ERR_INVALID_PRINCIPAL)
    (asserts! (is-valid-principal recipient) ERR_INVALID_PRINCIPAL)
    (asserts! (not (is-eq sender recipient)) ERR_INVALID_PRINCIPAL)
    (ft-transfer? eco-coin amount sender recipient)))

;; --- Read-Only Functions ---

(define-read-only (get-name) 
  (ok "Eco-Coin"))

(define-read-only (get-symbol) 
  (ok "ECO"))

(define-read-only (get-decimals) 
  (ok u6))

(define-read-only (get-balance (who principal)) 
  (ok (ft-get-balance eco-coin who)))

(define-read-only (get-total-supply) 
  (ok (var-get total-supply)))

(define-read-only (get-token-uri) 
  (ok (some (var-get token-uri))))

(define-read-only (get-treasury-balance) 
  (ok (var-get treasury-balance)))

(define-read-only (is-claim-processed (claim-id uint)) 
  (default-to false (map-get? processed-claims claim-id)))

(define-read-only (get-pending-claim (user principal) (center principal)) 
  (map-get? pending-claims { user: user, center: center }))

(define-read-only (get-center-info (center principal)) 
  (map-get? certified-recycling-centers center))

(define-read-only (is-certified-center (center principal))
  (is-some (map-get? certified-recycling-centers center)))

(define-read-only (get-contract-owner)
  CONTRACT_OWNER)