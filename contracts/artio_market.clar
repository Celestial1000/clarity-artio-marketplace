;; Artio NFT Marketplace Contract
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant market-fee u25) ;; 2.5% fee
(define-constant err-owner-only (err u100))
(define-constant err-not-whitelisted (err u101))
(define-constant err-listing-not-found (err u102))
(define-constant err-wrong-price (err u103))
(define-constant err-not-owner (err u104))
(define-constant err-not-found (err u105))
(define-constant err-insufficient-funds (err u106))

;; Data Variables
(define-data-var marketplace-enabled bool true)
(define-data-var next-token-id uint u0)

;; NFT Definition
(define-non-fungible-token artio-nft uint)

;; Data Maps
(define-map artist-whitelist principal bool)
(define-map token-listings
    uint
    {price: uint, seller: principal, royalty: uint}
)
(define-map token-metadata
    uint
    {artist: principal, title: string-utf8, uri: (string-utf8 256)}
)

;; Initialize NFT
(define-public (initialize-nft)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (try! (nft-mint? artio-nft u0 contract-owner))
        (ok true)
    )
)

;; Whitelist Functions
(define-public (add-to-whitelist (artist principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set artist-whitelist artist true))
    )
)

;; Minting Function
(define-public (mint-artwork (title string-utf8) (uri (string-utf8 256)))
    (let
        (
            (artist tx-sender)
            (token-id (var-get next-token-id))
        )
        (asserts! (default-to false (map-get? artist-whitelist artist)) err-not-whitelisted)
        (try! (nft-mint? artio-nft token-id artist))
        (map-set token-metadata token-id {
            artist: artist,
            title: title,
            uri: uri
        })
        (var-set next-token-id (+ token-id u1))
        (ok token-id)
    )
)

;; Listing Functions
(define-public (list-nft (token-id uint) (price uint) (royalty uint))
    (let
        (
            (owner (unwrap! (nft-get-owner? artio-nft token-id) err-not-found))
        )
        (asserts! (is-eq tx-sender owner) err-not-owner)
        (map-set token-listings token-id {
            price: price,
            seller: tx-sender,
            royalty: royalty
        })
        (ok true)
    )
)

;; Purchase Function
(define-public (purchase-nft (token-id uint))
    (let
        (
            (listing (unwrap! (map-get? token-listings token-id) err-listing-not-found))
            (price (get price listing))
            (seller (get seller listing))
            (royalty (get royalty listing))
            (metadata (unwrap! (map-get? token-metadata token-id) err-not-found))
            (artist (get artist metadata))
            (market-cut (/ (* price market-fee) u1000))
            (royalty-amount (/ (* price royalty) u100))
            (seller-amount (- price (+ market-cut royalty-amount)))
        )
        (asserts! (>= (stx-get-balance tx-sender) price) err-insufficient-funds)
        ;; Process payments directly to respective parties
        (try! (stx-transfer? market-cut tx-sender contract-owner))
        (try! (stx-transfer? royalty-amount tx-sender artist))
        (try! (stx-transfer? seller-amount tx-sender seller))
        (try! (nft-transfer? artio-nft token-id seller tx-sender))
        (map-delete token-listings token-id)
        (ok true)
    )
)

;; Read Only Functions
(define-read-only (get-listing (token-id uint))
    (ok (map-get? token-listings token-id))
)

(define-read-only (get-token-metadata (token-id uint))
    (ok (map-get? token-metadata token-id))
)

(define-read-only (get-next-token-id)
    (ok (var-get next-token-id))
)

(define-read-only (is-whitelisted (artist principal))
    (ok (default-to false (map-get? artist-whitelist artist)))
)
