;; BondMirror - Synthetic Government and Corporate Bond Contract
;; A programmable yield bond system on Stacks blockchain

;; =================
;; CONSTANTS & ERRORS
;; =================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-BOND-NOT-FOUND (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-BOND-MATURED (err u103))
(define-constant ERR-BOND-NOT-MATURED (err u104))
(define-constant ERR-INVALID-AMOUNT (err u105))
(define-constant ERR-INVALID-YIELD (err u106))
(define-constant ERR-BOND-ALREADY-REDEEMED (err u107))
(define-constant ERR-TRANSFER-FAILED (err u108))

;; Bond types
(define-constant BOND-TYPE-GOVERNMENT u1)
(define-constant BOND-TYPE-CORPORATE u2)

;; =================
;; DATA STRUCTURES
;; =================

;; Bond configuration
(define-map bonds
  { bond-id: uint }
  {
    issuer: principal,
    bond-type: uint,
    face-value: uint,
    purchase-price: uint,
    annual-yield: uint,  ;; Basis points (e.g., 500 = 5%)
    issue-block: uint,
    maturity-blocks: uint,
    total-supply: uint,
    remaining-supply: uint,
    is-active: bool
  }
)

;; Individual bond holdings
(define-map bond-holdings
  { holder: principal, bond-id: uint }
  {
    quantity: uint,
    purchase-block: uint,
    redeemed: bool
  }
)

;; Bond metadata
(define-map bond-metadata
  { bond-id: uint }
  {
    name: (string-ascii 50),
    symbol: (string-ascii 10),
    description: (string-ascii 200),
    rating: (string-ascii 5)
  }
)

;; Yield schedule for programmable yields
(define-map yield-schedule
  { bond-id: uint, period: uint }
  {
    yield-rate: uint,  ;; Basis points
    start-block: uint,
    end-block: uint
  }
)

;; Global variables
(define-data-var next-bond-id uint u1)
(define-data-var total-bonds-issued uint u0)
(define-data-var contract-balance uint u0)

;; =================
;; ADMIN FUNCTIONS
;; =================

;; Create a new bond
(define-public (create-bond
  (bond-type uint)
  (face-value uint)
  (purchase-price uint)
  (annual-yield uint)
  (maturity-blocks uint)
  (total-supply uint)
  (name (string-ascii 50))
  (symbol (string-ascii 10))
  (description (string-ascii 200))
  (rating (string-ascii 5))
)
  (let
    (
      (bond-id (var-get next-bond-id))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> face-value u0) ERR-INVALID-AMOUNT)
    (asserts! (> purchase-price u0) ERR-INVALID-AMOUNT)
    (asserts! (and (>= annual-yield u0) (<= annual-yield u10000)) ERR-INVALID-YIELD)
    (asserts! (> maturity-blocks u0) ERR-INVALID-AMOUNT)
    (asserts! (> total-supply u0) ERR-INVALID-AMOUNT)

    ;; Store bond configuration
    (map-set bonds
      { bond-id: bond-id }
      {
        issuer: tx-sender,
        bond-type: bond-type,
        face-value: face-value,
        purchase-price: purchase-price,
        annual-yield: annual-yield,
        issue-block: current-block,
        maturity-blocks: maturity-blocks,
        total-supply: total-supply,
        remaining-supply: total-supply,
        is-active: true
      }
    )

    ;; Store metadata
    (map-set bond-metadata
      { bond-id: bond-id }
      {
        name: name,
        symbol: symbol,
        description: description,
        rating: rating
      }
    )

    ;; Update global state
    (var-set next-bond-id (+ bond-id u1))
    (var-set total-bonds-issued (+ (var-get total-bonds-issued) u1))

    (ok bond-id)
  )
)

;; Set programmable yield schedule
(define-public (set-yield-schedule
  (bond-id uint)
  (period uint)
  (yield-rate uint)
  (start-block uint)
  (end-block uint)
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? bonds { bond-id: bond-id })) ERR-BOND-NOT-FOUND)
    (asserts! (and (>= yield-rate u0) (<= yield-rate u10000)) ERR-INVALID-YIELD)
    (asserts! (< start-block end-block) ERR-INVALID-AMOUNT)

    (map-set yield-schedule
      { bond-id: bond-id, period: period }
      {
        yield-rate: yield-rate,
        start-block: start-block,
        end-block: end-block
      }
    )
    (ok true)
  )
)

;; =================
;; INVESTOR FUNCTIONS
;; =================

;; Purchase bonds
(define-public (purchase-bond (bond-id uint) (quantity uint))
  (let
    (
      (bond-info (unwrap! (map-get? bonds { bond-id: bond-id }) ERR-BOND-NOT-FOUND))
      (current-holding (default-to 
        { quantity: u0, purchase-block: u0, redeemed: false }
        (map-get? bond-holdings { holder: tx-sender, bond-id: bond-id })
      ))
      (total-cost (* (get purchase-price bond-info) quantity))
    )
    (asserts! (get is-active bond-info) ERR-BOND-NOT-FOUND)
    (asserts! (>= (get remaining-supply bond-info) quantity) ERR-INSUFFICIENT-BALANCE)
    (asserts! (> quantity u0) ERR-INVALID-AMOUNT)

    ;; Transfer STX from buyer
    (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))

    ;; Update bond supply
    (map-set bonds
      { bond-id: bond-id }
      (merge bond-info { remaining-supply: (- (get remaining-supply bond-info) quantity) })
    )

    ;; Update holder's position
    (map-set bond-holdings
      { holder: tx-sender, bond-id: bond-id }
      {
        quantity: (+ (get quantity current-holding) quantity),
        purchase-block: stacks-block-height,
        redeemed: false
      }
    )

    ;; Update contract balance
    (var-set contract-balance (+ (var-get contract-balance) total-cost))

    (ok quantity)
  )
)

;; Calculate current yield for a bond
(define-read-only (calculate-current-yield (bond-id uint))
  (let
    (
      (bond-info (unwrap! (map-get? bonds { bond-id: bond-id }) ERR-BOND-NOT-FOUND))
      (current-block stacks-block-height)
    )
    ;; Check for programmable yield first
    (match (get-active-yield-rate bond-id current-block)
      yield-rate (ok yield-rate)
      ;; Fall back to annual yield
      (ok (get annual-yield bond-info))
    )
  )
)

;; Get active yield rate from schedule
(define-read-only (get-active-yield-rate (bond-id uint) (current-block uint))
  (let
    (
      (period-1 (map-get? yield-schedule { bond-id: bond-id, period: u1 }))
      (period-2 (map-get? yield-schedule { bond-id: bond-id, period: u2 }))
      (period-3 (map-get? yield-schedule { bond-id: bond-id, period: u3 }))
    )
    (if (and (is-some period-1) 
             (>= current-block (get start-block (unwrap-panic period-1)))
             (<= current-block (get end-block (unwrap-panic period-1))))
      (some (get yield-rate (unwrap-panic period-1)))
      (if (and (is-some period-2)
               (>= current-block (get start-block (unwrap-panic period-2)))
               (<= current-block (get end-block (unwrap-panic period-2))))
        (some (get yield-rate (unwrap-panic period-2)))
        (if (and (is-some period-3)
                 (>= current-block (get start-block (unwrap-panic period-3)))
                 (<= current-block (get end-block (unwrap-panic period-3))))
          (some (get yield-rate (unwrap-panic period-3)))
          none
        )
      )
    )
  )
)

;; Calculate accrued interest
(define-read-only (calculate-accrued-interest (bond-id uint) (holder principal))
  (let
    (
      (bond-info (unwrap! (map-get? bonds { bond-id: bond-id }) ERR-BOND-NOT-FOUND))
      (holding (unwrap! (map-get? bond-holdings { holder: holder, bond-id: bond-id }) ERR-BOND-NOT-FOUND))
      (current-yield (unwrap! (calculate-current-yield bond-id) ERR-INVALID-YIELD))
      (blocks-held (- stacks-block-height (get purchase-block holding)))
      (annual-blocks u52560) ;; Approximate blocks per year (10 min blocks)
      (face-value (get face-value bond-info))
      (quantity (get quantity holding))
    )
    (ok (/ (* (* (* face-value quantity) current-yield) blocks-held) (* annual-blocks u10000)))
  )
)

;; Redeem matured bonds
(define-public (redeem-bond (bond-id uint))
  (let
    (
      (bond-info (unwrap! (map-get? bonds { bond-id: bond-id }) ERR-BOND-NOT-FOUND))
      (holding (unwrap! (map-get? bond-holdings { holder: tx-sender, bond-id: bond-id }) ERR-BOND-NOT-FOUND))
      (maturity-block (+ (get issue-block bond-info) (get maturity-blocks bond-info)))
      (accrued-interest (unwrap! (calculate-accrued-interest bond-id tx-sender) ERR-INVALID-AMOUNT))
      (face-value-total (* (get face-value bond-info) (get quantity holding)))
      (total-redemption (+ face-value-total accrued-interest))
    )
    (asserts! (>= stacks-block-height maturity-block) ERR-BOND-NOT-MATURED)
    (asserts! (not (get redeemed holding)) ERR-BOND-ALREADY-REDEEMED)
    (asserts! (> (get quantity holding) u0) ERR-INSUFFICIENT-BALANCE)

    ;; Transfer STX to holder
    (try! (as-contract (stx-transfer? total-redemption tx-sender tx-sender)))

    ;; Mark as redeemed
    (map-set bond-holdings
      { holder: tx-sender, bond-id: bond-id }
      (merge holding { redeemed: true })
    )

    ;; Update contract balance
    (var-set contract-balance (- (var-get contract-balance) total-redemption))

    (ok total-redemption)
  )
)

;; =================
;; READ-ONLY FUNCTIONS
;; =================

;; Get bond information
(define-read-only (get-bond-info (bond-id uint))
  (map-get? bonds { bond-id: bond-id })
)

;; Get bond metadata
(define-read-only (get-bond-metadata (bond-id uint))
  (map-get? bond-metadata { bond-id: bond-id })
)

;; Get holder's bond position
(define-read-only (get-bond-holding (holder principal) (bond-id uint))
  (map-get? bond-holdings { holder: holder, bond-id: bond-id })
)

;; Check if bond is matured
(define-read-only (is-bond-matured (bond-id uint))
  (match (map-get? bonds { bond-id: bond-id })
    bond-info
      (let ((maturity-block (+ (get issue-block bond-info) (get maturity-blocks bond-info))))
        (>= stacks-block-height maturity-block))
    false
  )
)

;; Get contract stats
(define-read-only (get-contract-stats)
  {
    total-bonds-issued: (var-get total-bonds-issued),
    next-bond-id: (var-get next-bond-id),
    contract-balance: (var-get contract-balance)
  }
)

;; Get bond value with interest
(define-read-only (get-bond-value (bond-id uint) (holder principal))
  (let
    (
      (bond-info (unwrap! (map-get? bonds { bond-id: bond-id }) ERR-BOND-NOT-FOUND))
      (holding (unwrap! (map-get? bond-holdings { holder: holder, bond-id: bond-id }) ERR-BOND-NOT-FOUND))
      (accrued-interest (unwrap! (calculate-accrued-interest bond-id holder) ERR-INVALID-AMOUNT))
      (face-value-total (* (get face-value bond-info) (get quantity holding)))
    )
    (ok (+ face-value-total accrued-interest))
  )
)