(define-non-fungible-token livestock-nft uint)

(define-data-var next-livestock-id uint u1)
(define-data-var contract-owner principal tx-sender)
(define-data-var insurance-pool uint u0)

(define-map livestock-registry
  uint
  {
    owner: principal,
    species: (string-ascii 50),
    breed: (string-ascii 50),
    birth-date: uint,
    ear-tag-id: (string-ascii 20),
    biometric-hash: (buff 32),
    current-health-status: (string-ascii 20),
    market-value: uint,
    insurance-amount: uint,
    created-at: uint
  }
)

(define-map health-records
  {livestock-id: uint, record-id: uint}
  {
    veterinarian: principal,
    record-type: (string-ascii 30),
    description: (string-ascii 200),
    vaccination-name: (optional (string-ascii 100)),
    treatment-date: uint,
    next-checkup: (optional uint),
    severity: uint,
    verified: bool
  }
)

(define-map veterinarians
  principal
  {
    licensed: bool,
    license-number: (string-ascii 50),
    specialization: (string-ascii 100),
    reputation-score: uint
  }
)

(define-map marketplace-listings
  uint
  {
    seller: principal,
    price: uint,
    currency: (string-ascii 10),
    listing-date: uint,
    active: bool,
    verified-health: bool
  }
)

(define-map insurance-claims
  uint
  {
    claimant: principal,
    claim-type: (string-ascii 30),
    amount: uint,
    status: (string-ascii 20),
    filed-date: uint,
    veterinarian-verify: (optional principal)
  }
)

(define-map livestock-record-count uint uint)

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-NOT-OWNER (err u104))
(define-constant ERR-NOT-VETERINARIAN (err u105))
(define-constant ERR-INSUFFICIENT-FUNDS (err u106))
(define-constant ERR-INVALID-STATUS (err u107))
(define-constant ERR-CLAIM-EXISTS (err u108))

(define-public (register-veterinarian (license-number (string-ascii 50)) (specialization (string-ascii 100)))
  (let ((caller tx-sender))
    (asserts! (is-eq caller (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (ok (map-set veterinarians caller {
      licensed: true,
      license-number: license-number,
      specialization: specialization,
      reputation-score: u100
    }))
  )
)

(define-public (register-livestock 
  (species (string-ascii 50))
  (breed (string-ascii 50))
  (birth-date uint)
  (ear-tag-id (string-ascii 20))
  (biometric-hash (buff 32))
  (market-value uint)
  (insurance-amount uint)
)
  (let (
    (livestock-id (var-get next-livestock-id))
    (caller tx-sender)
  )
    (asserts! (> market-value u0) ERR-INVALID-AMOUNT)
    (asserts! (<= insurance-amount market-value) ERR-INVALID-AMOUNT)
    
    (try! (nft-mint? livestock-nft livestock-id caller))
    
    (map-set livestock-registry livestock-id {
      owner: caller,
      species: species,
      breed: breed,
      birth-date: birth-date,
      ear-tag-id: ear-tag-id,
      biometric-hash: biometric-hash,
      current-health-status: "healthy",
      market-value: market-value,
      insurance-amount: insurance-amount,
      created-at: stacks-block-height
    })
    
    (map-set livestock-record-count livestock-id u0)
    (var-set next-livestock-id (+ livestock-id u1))
    (ok livestock-id)
  )
)

(define-public (add-health-record
  (livestock-id uint)
  (record-type (string-ascii 30))
  (description (string-ascii 200))
  (vaccination-name (optional (string-ascii 100)))
  (next-checkup (optional uint))
  (severity uint)
)
  (let (
    (caller tx-sender)
    (vet-info (map-get? veterinarians caller))
    (livestock-info (map-get? livestock-registry livestock-id))
    (current-record-count (default-to u0 (map-get? livestock-record-count livestock-id)))
  )
    (asserts! (is-some vet-info) ERR-NOT-VETERINARIAN)
    (asserts! (get licensed (unwrap-panic vet-info)) ERR-NOT-VETERINARIAN)
    (asserts! (is-some livestock-info) ERR-NOT-FOUND)
    (asserts! (<= severity u10) ERR-INVALID-AMOUNT)
    
    (map-set health-records 
      {livestock-id: livestock-id, record-id: current-record-count}
      {
        veterinarian: caller,
        record-type: record-type,
        description: description,
        vaccination-name: vaccination-name,
        treatment-date: stacks-block-height,
        next-checkup: next-checkup,
        severity: severity,
        verified: true
      }
    )
    
    (map-set livestock-record-count livestock-id (+ current-record-count u1))
    
    (if (> severity u7)
      (map-set livestock-registry livestock-id 
        (merge (unwrap-panic livestock-info) {current-health-status: "critical"}))
      (if (> severity u4)
        (map-set livestock-registry livestock-id 
          (merge (unwrap-panic livestock-info) {current-health-status: "moderate"}))
        (map-set livestock-registry livestock-id 
          (merge (unwrap-panic livestock-info) {current-health-status: "healthy"}))
      )
    )
    
    (ok current-record-count)
  )
)

(define-public (list-for-sale (livestock-id uint) (price uint) (currency (string-ascii 10)))
  (let (
    (caller tx-sender)
    (livestock-info (map-get? livestock-registry livestock-id))
    (owner (nft-get-owner? livestock-nft livestock-id))
  )
    (asserts! (is-some livestock-info) ERR-NOT-FOUND)
    (asserts! (is-eq (some caller) owner) ERR-NOT-OWNER)
    (asserts! (> price u0) ERR-INVALID-AMOUNT)
    
    (let ((health-status (get current-health-status (unwrap-panic livestock-info))))
      (ok (map-set marketplace-listings livestock-id {
        seller: caller,
        price: price,
        currency: currency,
        listing-date: stacks-block-height,
        active: true,
        verified-health: (is-eq health-status "healthy")
      }))
    )
  )
)

(define-public (purchase-livestock (livestock-id uint))
  (let (
    (caller tx-sender)
    (listing (map-get? marketplace-listings livestock-id))
    (livestock-info (map-get? livestock-registry livestock-id))
  )
    (asserts! (is-some listing) ERR-NOT-FOUND)
    (asserts! (is-some livestock-info) ERR-NOT-FOUND)
    (asserts! (get active (unwrap-panic listing)) ERR-INVALID-STATUS)
    
    (let (
      (seller (get seller (unwrap-panic listing)))
      (price (get price (unwrap-panic listing)))
    )
      (asserts! (not (is-eq caller seller)) ERR-NOT-AUTHORIZED)
      (try! (stx-transfer? price caller seller))
      (try! (nft-transfer? livestock-nft livestock-id seller caller))
      
      (map-set livestock-registry livestock-id 
        (merge (unwrap-panic livestock-info) {owner: caller}))
      
      (map-set marketplace-listings livestock-id 
        (merge (unwrap-panic listing) {active: false}))
      
      (ok true)
    )
  )
)

(define-public (file-insurance-claim (livestock-id uint) (claim-type (string-ascii 30)) (amount uint))
  (let (
    (caller tx-sender)
    (livestock-info (map-get? livestock-registry livestock-id))
    (owner (nft-get-owner? livestock-nft livestock-id))
    (existing-claim (map-get? insurance-claims livestock-id))
  )
    (asserts! (is-some livestock-info) ERR-NOT-FOUND)
    (asserts! (is-eq (some caller) owner) ERR-NOT-OWNER)
    (asserts! (is-none existing-claim) ERR-CLAIM-EXISTS)
    (asserts! (<= amount (get insurance-amount (unwrap-panic livestock-info))) ERR-INVALID-AMOUNT)
    
    (ok (map-set insurance-claims livestock-id {
      claimant: caller,
      claim-type: claim-type,
      amount: amount,
      status: "pending",
      filed-date: stacks-block-height,
      veterinarian-verify: none
    }))
  )
)

(define-public (verify-insurance-claim (livestock-id uint) (approve bool))
  (let (
    (caller tx-sender)
    (vet-info (map-get? veterinarians caller))
    (claim-info (map-get? insurance-claims livestock-id))
  )
    (asserts! (is-some vet-info) ERR-NOT-VETERINARIAN)
    (asserts! (get licensed (unwrap-panic vet-info)) ERR-NOT-VETERINARIAN)
    (asserts! (is-some claim-info) ERR-NOT-FOUND)
    
    (let ((claim (unwrap-panic claim-info)))
      (if approve
        (begin
          (map-set insurance-claims livestock-id 
            (merge claim {
              status: "approved",
              veterinarian-verify: (some caller)
            }))
          (var-set insurance-pool (- (var-get insurance-pool) (get amount claim)))
          (try! (stx-transfer? (get amount claim) (as-contract tx-sender) (get claimant claim)))
          (ok true)
        )
        (begin
          (map-set insurance-claims livestock-id 
            (merge claim {
              status: "rejected",
              veterinarian-verify: (some caller)
            }))
          (ok false)
        )
      )
    )
  )
)

(define-public (contribute-to-insurance-pool (amount uint))
  (let ((caller tx-sender))
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (try! (stx-transfer? amount caller (as-contract tx-sender)))
    (var-set insurance-pool (+ (var-get insurance-pool) amount))
    (ok true)
  )
)

(define-read-only (get-livestock-info (livestock-id uint))
  (map-get? livestock-registry livestock-id)
)

(define-read-only (get-health-record (livestock-id uint) (record-id uint))
  (map-get? health-records {livestock-id: livestock-id, record-id: record-id})
)

(define-read-only (get-veterinarian-info (veterinarian principal))
  (map-get? veterinarians veterinarian)
)

(define-read-only (get-marketplace-listing (livestock-id uint))
  (map-get? marketplace-listings livestock-id)
)

(define-read-only (get-insurance-claim (livestock-id uint))
  (map-get? insurance-claims livestock-id)
)

(define-read-only (get-livestock-record-count (livestock-id uint))
  (default-to u0 (map-get? livestock-record-count livestock-id))
)

(define-read-only (get-insurance-pool-balance)
  (var-get insurance-pool)
)

(define-read-only (get-next-livestock-id)
  (var-get next-livestock-id)
)

(define-read-only (get-livestock-owner (livestock-id uint))
  (nft-get-owner? livestock-nft livestock-id)
)
