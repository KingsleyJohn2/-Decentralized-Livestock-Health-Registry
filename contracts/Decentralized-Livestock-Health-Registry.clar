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
    created-at: uint,
    retired: bool
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

(define-map seller-profiles
  principal
  {
    total-sales: uint,
    total-ratings: uint,
    rating-sum: uint,
    reputation-score: uint,
    first-sale-date: (optional uint)
  }
)

(define-map seller-ratings
  {rater: principal, seller: principal, livestock-id: uint}
  {
    rating: uint,
    comment: (string-ascii 200),
    rated-date: uint
  }
)

(define-map veterinarian-ratings
  {rater: principal, veterinarian: principal, livestock-id: uint}
  {
    rating: uint,
    comment: (string-ascii 200),
    rated-date: uint
  }
)
(define-map breeding-records
  uint
  {
    sire-id: (optional uint),
    dam-id: (optional uint),
    breeding-date: uint,
    breeder: principal
  }
)

(define-map lease-agreements
  uint
  {
    lessee: principal,
    lease-start: uint,
    lease-end: uint,
    daily-rate: uint,
    total-paid: uint,
    active: bool
  }
)

(define-map purchase-history
  uint
  {
    buyer: principal,
    seller: principal,
    purchase-date: uint,
    price: uint,
    rated-seller: bool,
    rated-veterinarian: bool
  }
)

(define-map livestock-transport-records
  {livestock-id: uint, transport-id: uint}
  {
    transporter: principal,
    destination: (string-ascii 100),
    transport-date: uint,
    purpose: (string-ascii 50),
    verified: bool
  }
)

(define-map livestock-transport-count uint uint)

(define-map mortality-records
  uint
  {
    reported-by: principal,
    cause: (string-ascii 100),
    reported-date: uint,
    verified: bool,
    verified-by: (optional principal)
  }
)

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-NOT-OWNER (err u104))
(define-constant ERR-NOT-VETERINARIAN (err u105))
(define-constant ERR-INSUFFICIENT-FUNDS (err u106))
(define-constant ERR-INVALID-STATUS (err u107))
(define-constant ERR-CLAIM-EXISTS (err u108))
(define-constant ERR-ALREADY-RATED (err u109))
(define-constant ERR-INVALID-RATING (err u110))
(define-constant ERR-NO-PURCHASE-RECORD (err u111))
(define-constant ERR-ALREADY-DECEASED (err u112))

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
      created-at: stacks-block-height,
      retired: false
    })
    
    (map-set livestock-record-count livestock-id u0)
    (var-set next-livestock-id (+ livestock-id u1))
    (ok livestock-id)
  )
)

(define-public (retire-livestock (livestock-id uint))
  (let (
    (caller tx-sender)
    (livestock-info (map-get? livestock-registry livestock-id))
    (owner (nft-get-owner? livestock-nft livestock-id))
  )
    (asserts! (is-some livestock-info) ERR-NOT-FOUND)
    (asserts! (is-eq (some caller) owner) ERR-NOT-OWNER)
    (asserts! (not (get retired (unwrap-panic livestock-info))) ERR-INVALID-STATUS)
    (ok (map-set livestock-registry livestock-id
      (merge (unwrap-panic livestock-info) {retired: true})))
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
    (asserts! (not (get retired (unwrap-panic livestock-info))) ERR-INVALID-STATUS)
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
    (asserts! (not (get retired (unwrap-panic livestock-info))) ERR-INVALID-STATUS)
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
      
      (map-set purchase-history livestock-id {
        buyer: caller,
        seller: seller,
        purchase-date: stacks-block-height,
        price: price,
        rated-seller: false,
        rated-veterinarian: false
      })
      
      (let ((seller-profile (default-to 
        {total-sales: u0, total-ratings: u0, rating-sum: u0, reputation-score: u0, first-sale-date: none}
        (map-get? seller-profiles seller))))
        (map-set seller-profiles seller (merge seller-profile {
          total-sales: (+ (get total-sales seller-profile) u1),
          first-sale-date: (if (is-none (get first-sale-date seller-profile))
            (some stacks-block-height)
            (get first-sale-date seller-profile))
        }))
      )
      
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

(define-public (rate-seller (livestock-id uint) (rating uint) (comment (string-ascii 200)))
  (let (
    (caller tx-sender)
    (purchase-record (map-get? purchase-history livestock-id))
    (rating-key {rater: caller, seller: (get seller (unwrap! purchase-record ERR-NO-PURCHASE-RECORD)), livestock-id: livestock-id})
  )
    (asserts! (is-some purchase-record) ERR-NO-PURCHASE-RECORD)
    (asserts! (is-eq caller (get buyer (unwrap-panic purchase-record))) ERR-NOT-AUTHORIZED)
    (asserts! (not (get rated-seller (unwrap-panic purchase-record))) ERR-ALREADY-RATED)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-RATING)
    (asserts! (is-none (map-get? seller-ratings rating-key)) ERR-ALREADY-RATED)
    
    (let ((seller (get seller (unwrap-panic purchase-record))))
      (map-set seller-ratings rating-key {
        rating: rating,
        comment: comment,
        rated-date: stacks-block-height
      })
      
      (map-set purchase-history livestock-id 
        (merge (unwrap-panic purchase-record) {rated-seller: true}))
      
      (let ((seller-profile (default-to 
        {total-sales: u0, total-ratings: u0, rating-sum: u0, reputation-score: u0, first-sale-date: none}
        (map-get? seller-profiles seller))))
        (let ((new-total-ratings (+ (get total-ratings seller-profile) u1))
              (new-rating-sum (+ (get rating-sum seller-profile) rating)))
          (map-set seller-profiles seller (merge seller-profile {
            total-ratings: new-total-ratings,
            rating-sum: new-rating-sum,
            reputation-score: (/ (* new-rating-sum u100) new-total-ratings)
          }))
        )
      )
      
      (ok true)
    )
  )
)

(define-public (rate-veterinarian (livestock-id uint) (veterinarian principal) (rating uint) (comment (string-ascii 200)))
  (let (
    (caller tx-sender)
    (purchase-record (map-get? purchase-history livestock-id))
    (rating-key {rater: caller, veterinarian: veterinarian, livestock-id: livestock-id})
    (vet-info (map-get? veterinarians veterinarian))
  )
    (asserts! (is-some purchase-record) ERR-NO-PURCHASE-RECORD)
    (asserts! (is-eq caller (get buyer (unwrap-panic purchase-record))) ERR-NOT-AUTHORIZED)
    (asserts! (not (get rated-veterinarian (unwrap-panic purchase-record))) ERR-ALREADY-RATED)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-RATING)
    (asserts! (is-none (map-get? veterinarian-ratings rating-key)) ERR-ALREADY-RATED)
    (asserts! (is-some vet-info) ERR-NOT-VETERINARIAN)
    
    (map-set veterinarian-ratings rating-key {
      rating: rating,
      comment: comment,
      rated-date: stacks-block-height
    })
    
    (map-set purchase-history livestock-id 
      (merge (unwrap-panic purchase-record) {rated-veterinarian: true}))
    
    (let ((current-vet-info (unwrap-panic vet-info)))
      (map-set veterinarians veterinarian (merge current-vet-info {
        reputation-score: (+ (get reputation-score current-vet-info) 
          (if (>= rating u4) u2 (if (>= rating u3) u0 (- u0 u1))))
      }))
    )
    
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

(define-read-only (get-seller-profile (seller principal))
  (map-get? seller-profiles seller)
)

(define-read-only (get-seller-rating (rater principal) (seller principal) (livestock-id uint))
  (map-get? seller-ratings {rater: rater, seller: seller, livestock-id: livestock-id})
)

(define-read-only (get-veterinarian-rating (rater principal) (veterinarian principal) (livestock-id uint))
  (map-get? veterinarian-ratings {rater: rater, veterinarian: veterinarian, livestock-id: livestock-id})
)

(define-read-only (get-purchase-history (livestock-id uint))
  (map-get? purchase-history livestock-id)
)

(define-read-only (get-seller-reputation-score (seller principal))
  (let ((profile (map-get? seller-profiles seller)))
    (if (is-some profile)
      (some (get reputation-score (unwrap-panic profile)))
      none
    )
  )
)

(define-read-only (get-livestock-retired-status (livestock-id uint))
  (let ((livestock-info (map-get? livestock-registry livestock-id)))
    (if (is-some livestock-info)
      (some (get retired (unwrap-panic livestock-info)))
      none
    )
  )
)

(define-read-only (get-breeding-record (livestock-id uint))
  (map-get? breeding-records livestock-id)
)

(define-public (record-breeding
  (livestock-id uint)
  (sire-id (optional uint))
  (dam-id (optional uint))
)
  (let (
    (caller tx-sender)
    (livestock-info (map-get? livestock-registry livestock-id))
    (sire-info (if (is-some sire-id) (map-get? livestock-registry (unwrap-panic sire-id)) none))
    (dam-info (if (is-some dam-id) (map-get? livestock-registry (unwrap-panic dam-id)) none))
  )
    (asserts! (is-some livestock-info) ERR-NOT-FOUND)
    (asserts! (is-eq caller (get owner (unwrap-panic livestock-info))) ERR-NOT-OWNER)
    (asserts! (not (get retired (unwrap-panic livestock-info))) ERR-INVALID-STATUS)
    (if (is-some sire-id)
      (asserts! (is-some sire-info) ERR-NOT-FOUND)
      true
    )
    (if (is-some dam-id)
      (asserts! (is-some dam-info) ERR-NOT-FOUND)
      true
    )
    (ok (map-set breeding-records livestock-id {
      sire-id: sire-id,
      dam-id: dam-id,
      breeding-date: stacks-block-height,
      breeder: caller
    }))
  )
)

(define-read-only (get-veterinarian-reputation-score (veterinarian principal))
  (let ((vet-info (map-get? veterinarians veterinarian)))
    (if (is-some vet-info)
      (some (get reputation-score (unwrap-panic vet-info)))
      none
    )
  )
)

(define-public (lease-livestock (livestock-id uint) (lease-end uint) (daily-rate uint))
  (let (
    (caller tx-sender)
    (livestock-info (map-get? livestock-registry livestock-id))
    (owner (nft-get-owner? livestock-nft livestock-id))
    (lease-duration (- lease-end stacks-block-height))
    (total-cost (* daily-rate lease-duration))
  )
    (asserts! (is-some livestock-info) ERR-NOT-FOUND)
    (asserts! (is-eq (some caller) owner) ERR-NOT-OWNER)
    (asserts! (not (get retired (unwrap-panic livestock-info))) ERR-INVALID-STATUS)
    (asserts! (> lease-end stacks-block-height) ERR-INVALID-AMOUNT)
    (asserts! (> daily-rate u0) ERR-INVALID-AMOUNT)
    (asserts! (is-none (map-get? lease-agreements livestock-id)) ERR-ALREADY-EXISTS)
    (ok (map-set lease-agreements livestock-id {
      lessee: caller,
      lease-start: stacks-block-height,
      lease-end: lease-end,
      daily-rate: daily-rate,
      total-paid: u0,
      active: true
    }))
  )
)

(define-public (rent-livestock (livestock-id uint) (rental-days uint))
  (let (
    (caller tx-sender)
    (lease-info (map-get? lease-agreements livestock-id))
    (livestock-info (map-get? livestock-registry livestock-id))
    (lease (unwrap! lease-info ERR-NOT-FOUND))
    (rental-cost (* (get daily-rate lease) rental-days))
  )
    (asserts! (is-some livestock-info) ERR-NOT-FOUND)
    (asserts! (get active lease) ERR-INVALID-STATUS)
    (asserts! (<= (+ stacks-block-height rental-days) (get lease-end lease)) ERR-INVALID-AMOUNT)
    (try! (stx-transfer? rental-cost caller (get lessee lease)))
    (map-set lease-agreements livestock-id
      (merge lease {total-paid: (+ (get total-paid lease) rental-cost)}))
    (ok true)
  )
)

(define-public (end-lease (livestock-id uint))
  (let (
    (caller tx-sender)
    (lease-info (map-get? lease-agreements livestock-id))
    (livestock-info (map-get? livestock-registry livestock-id))
    (owner (nft-get-owner? livestock-nft livestock-id))
  )
    (asserts! (is-some livestock-info) ERR-NOT-FOUND)
    (asserts! (is-eq (some caller) owner) ERR-NOT-OWNER)
    (asserts! (is-some lease-info) ERR-NOT-FOUND)
    (asserts! (get active (unwrap-panic lease-info)) ERR-INVALID-STATUS)
    (ok (map-set lease-agreements livestock-id
      (merge (unwrap-panic lease-info) {active: false})))
  )
)

(define-read-only (get-lease-agreement (livestock-id uint))
  (map-get? lease-agreements livestock-id)
)

(define-public (record-transport
  (livestock-id uint)
  (destination (string-ascii 100))
  (purpose (string-ascii 50))
)
  (let (
    (caller tx-sender)
    (livestock-info (map-get? livestock-registry livestock-id))
    (owner (nft-get-owner? livestock-nft livestock-id))
    (current-transport-count (default-to u0 (map-get? livestock-transport-count livestock-id)))
  )
    (asserts! (is-some livestock-info) ERR-NOT-FOUND)
    (asserts! (is-eq (some caller) owner) ERR-NOT-OWNER)
    (asserts! (not (get retired (unwrap-panic livestock-info))) ERR-INVALID-STATUS)

    (map-set livestock-transport-records
      {livestock-id: livestock-id, transport-id: current-transport-count}
      {
        transporter: caller,
        destination: destination,
        transport-date: stacks-block-height,
        purpose: purpose,
        verified: false
      }
    )

    (map-set livestock-transport-count livestock-id (+ current-transport-count u1))
    (ok current-transport-count)
  )
)

(define-public (verify-transport (livestock-id uint) (transport-id uint))
  (let (
    (caller tx-sender)
    (vet-info (map-get? veterinarians caller))
    (transport-key {livestock-id: livestock-id, transport-id: transport-id})
    (transport-info (map-get? livestock-transport-records transport-key))
  )
    (asserts! (is-some vet-info) ERR-NOT-VETERINARIAN)
    (asserts! (get licensed (unwrap-panic vet-info)) ERR-NOT-VETERINARIAN)
    (asserts! (is-some transport-info) ERR-NOT-FOUND)

    (map-set livestock-transport-records transport-key
      (merge (unwrap-panic transport-info) {verified: true}))
    (ok true)
  )
)

(define-read-only (get-transport-record (livestock-id uint) (transport-id uint))
  (map-get? livestock-transport-records {livestock-id: livestock-id, transport-id: transport-id})
)

(define-read-only (get-transport-count (livestock-id uint))
  (default-to u0 (map-get? livestock-transport-count livestock-id))
)

(define-public (report-mortality (livestock-id uint) (cause (string-ascii 100)))
  (let (
    (caller tx-sender)
    (livestock-info (map-get? livestock-registry livestock-id))
    (owner (nft-get-owner? livestock-nft livestock-id))
    (existing-mortality (map-get? mortality-records livestock-id))
  )
    (asserts! (is-some livestock-info) ERR-NOT-FOUND)
    (asserts! (is-eq (some caller) owner) ERR-NOT-OWNER)
    (asserts! (not (get retired (unwrap-panic livestock-info))) ERR-INVALID-STATUS)
    (asserts! (is-none existing-mortality) ERR-ALREADY-DECEASED)
    (ok (map-set mortality-records livestock-id {
      reported-by: caller,
      cause: cause,
      reported-date: stacks-block-height,
      verified: false,
      verified-by: none
    }))
  )
)

(define-public (verify-mortality (livestock-id uint))
  (let (
    (caller tx-sender)
    (vet-info (map-get? veterinarians caller))
    (mortality-info (map-get? mortality-records livestock-id))
  )
    (asserts! (is-some vet-info) ERR-NOT-VETERINARIAN)
    (asserts! (get licensed (unwrap-panic vet-info)) ERR-NOT-VETERINARIAN)
    (asserts! (is-some mortality-info) ERR-NOT-FOUND)
    (ok (map-set mortality-records livestock-id
      (merge (unwrap-panic mortality-info) {
        verified: true,
        verified-by: (some caller)
      })))
  )
)

(define-read-only (get-mortality-record (livestock-id uint))
  (map-get? mortality-records livestock-id)
)

(define-map emergency-alerts
  uint
  {
    livestock-id: uint,
    alert-type: (string-ascii 30),
    description: (string-ascii 200),
    severity: uint,
    reported-by: principal,
    reported-at: uint,
    resolved: bool,
    resolved-by: (optional principal),
    resolved-at: (optional uint)
  }
)

(define-map emergency-alert-count uint uint)

(define-constant ERR-EMERGENCY-ALERT-EXISTS (err u113))
(define-constant ERR-ALERT-NOT-FOUND (err u114))
(define-constant ERR-ALERT-ALREADY-RESOLVED (err u115))

(define-public (report-emergency-alert
  (livestock-id uint)
  (alert-type (string-ascii 30))
  (description (string-ascii 200))
  (severity uint)
)
  (let (
    (caller tx-sender)
    (livestock-info (map-get? livestock-registry livestock-id))
    (current-alert-count (default-to u0 (map-get? emergency-alert-count livestock-id)))
  )
    (asserts! (is-some livestock-info) ERR-NOT-FOUND)
    (asserts! (not (get retired (unwrap-panic livestock-info))) ERR-INVALID-STATUS)
    (asserts! (<= severity u10) ERR-INVALID-AMOUNT)
    (asserts! (> severity u0) ERR-INVALID-AMOUNT)

    (map-set emergency-alerts current-alert-count {
      livestock-id: livestock-id,
      alert-type: alert-type,
      description: description,
      severity: severity,
      reported-by: caller,
      reported-at: stacks-block-height,
      resolved: false,
      resolved-by: none,
      resolved-at: none
    })

    (map-set emergency-alert-count livestock-id (+ current-alert-count u1))
    (ok current-alert-count)
  )
)

(define-public (resolve-emergency-alert (livestock-id uint) (alert-id uint))
  (let (
    (caller tx-sender)
    (vet-info (map-get? veterinarians caller))
    (alert-info (map-get? emergency-alerts alert-id))
  )
    (asserts! (is-some vet-info) ERR-NOT-VETERINARIAN)
    (asserts! (get licensed (unwrap-panic vet-info)) ERR-NOT-VETERINARIAN)
    (asserts! (is-some alert-info) ERR-ALERT-NOT-FOUND)
    (asserts! (is-eq livestock-id (get livestock-id (unwrap-panic alert-info))) ERR-NOT-FOUND)
    (asserts! (not (get resolved (unwrap-panic alert-info))) ERR-ALERT-ALREADY-RESOLVED)

    (map-set emergency-alerts alert-id
      (merge (unwrap-panic alert-info) {
        resolved: true,
        resolved-by: (some caller),
        resolved-at: (some stacks-block-height)
      })
    )
    (ok true)
  )
)

(define-read-only (get-emergency-alert (alert-id uint))
  (map-get? emergency-alerts alert-id)
)

(define-read-only (get-emergency-alert-count (livestock-id uint))
  (default-to u0 (map-get? emergency-alert-count livestock-id))
)

(define-map genetic-test-records
  {livestock-id: uint, test-id: uint}
  {
    veterinarian: principal,
    test-type: (string-ascii 50),
    result: (string-ascii 200),
    test-date: uint,
    verified: bool
  }
)

(define-map genetic-test-count uint uint)

(define-public (record-genetic-test
  (livestock-id uint)
  (test-type (string-ascii 50))
  (result (string-ascii 200))
)
  (let (
    (caller tx-sender)
    (vet-info (map-get? veterinarians caller))
    (livestock-info (map-get? livestock-registry livestock-id))
    (current-test-count (default-to u0 (map-get? genetic-test-count livestock-id)))
  )
    (asserts! (is-some vet-info) ERR-NOT-VETERINARIAN)
    (asserts! (get licensed (unwrap-panic vet-info)) ERR-NOT-VETERINARIAN)
    (asserts! (is-some livestock-info) ERR-NOT-FOUND)
    (asserts! (not (get retired (unwrap-panic livestock-info))) ERR-INVALID-STATUS)

    (map-set genetic-test-records
      {livestock-id: livestock-id, test-id: current-test-count}
      {
        veterinarian: caller,
        test-type: test-type,
        result: result,
        test-date: stacks-block-height,
        verified: true
      }
    )

    (map-set genetic-test-count livestock-id (+ current-test-count u1))

    (ok current-test-count)
  )
)

(define-read-only (get-genetic-test-record (livestock-id uint) (test-id uint))
  (map-get? genetic-test-records {livestock-id: livestock-id, test-id: test-id})
)

(define-read-only (get-genetic-test-count (livestock-id uint))
  (default-to u0 (map-get? genetic-test-count livestock-id))
)
