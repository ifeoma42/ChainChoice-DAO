;; ChainChoice DAO - Quadratic Voting Contract
;; Error Codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u101))
(define-constant ERR-INVALID-VOTE-AMOUNT (err u102))
(define-constant ERR-PROPOSAL-EXPIRED (err u103))
(define-constant ERR-INSUFFICIENT-BALANCE (err u104))
(define-constant ERR-ALREADY-VOTED (err u105))

;; Data Maps
(define-map proposals
    {proposal-id: uint}
    {
        creator: principal,
        title: (string-ascii 50),
        description: (string-ascii 500),
        start-block: uint,
        end-block: uint,
        yes-votes: uint,
        no-votes: uint,
        status: (string-ascii 10)
    }
)

(define-map user-votes
    {user: principal, proposal-id: uint}
    {
        vote-amount: uint,
        vote-direction: bool  ;; true for yes, false for no
    }
)

(define-map user-balances
    principal
    uint
)

;; Variables
(define-data-var proposal-count uint u0)
(define-data-var token-name (string-ascii 32) "ChainChoice")
(define-data-var token-symbol (string-ascii 10) "CHC")

;; Read-only functions
(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals {proposal-id: proposal-id})
)

(define-read-only (get-user-vote (user principal) (proposal-id uint))
    (map-get? user-votes {user: user, proposal-id: proposal-id})
)

(define-read-only (get-balance (user principal))
    (default-to u0 (map-get? user-balances user))
)

(define-read-only (calculate-quadratic-votes (amount uint))
    (let ((square-root (sqrti amount)))
        square-root
    )
)

;; Public functions
(define-public (create-proposal (title (string-ascii 50)) (description (string-ascii 500)) (duration uint))
    (let
        (
            (proposal-id (var-get proposal-count))
            (start-block block-height)
            (end-block (+ block-height duration))
        )
        (asserts! (> duration u0) ERR-INVALID-VOTE-AMOUNT)
        (map-set proposals
            {proposal-id: proposal-id}
            {
                creator: tx-sender,
                title: title,
                description: description,
                start-block: start-block,
                end-block: end-block,
                yes-votes: u0,
                no-votes: u0,
                status: "active"
            }
        )
        (var-set proposal-count (+ proposal-id u1))
        (ok proposal-id)
    )
)

(define-public (vote (proposal-id uint) (amount uint) (vote-direction bool))
    (let
        (
            (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (user-balance (get-balance tx-sender))
            (quadratic-votes (calculate-quadratic-votes amount))
            (previous-vote (get-user-vote tx-sender proposal-id))
        )
        (asserts! (>= user-balance amount) ERR-INSUFFICIENT-BALANCE)
        (asserts! (is-none previous-vote) ERR-ALREADY-VOTED)
        (asserts! (<= block-height (get end-block proposal)) ERR-PROPOSAL-EXPIRED)
        
        ;; Update vote counts
        (map-set proposals
            {proposal-id: proposal-id}
            (merge proposal
                {
                    yes-votes: (if vote-direction
                        (+ (get yes-votes proposal) quadratic-votes)
                        (get yes-votes proposal)
                    ),
                    no-votes: (if (not vote-direction)
                        (+ (get no-votes proposal) quadratic-votes)
                        (get no-votes proposal)
                    )
                }
            )
        )
        
        ;; Record user vote
        (map-set user-votes
            {user: tx-sender, proposal-id: proposal-id}
            {
                vote-amount: amount,
                vote-direction: vote-direction
            }
        )
        
        ;; Update user balance
        (map-set user-balances
            tx-sender
            (- user-balance amount)
        )
        
        (ok true)
    )
)

(define-public (close-proposal (proposal-id uint))
    (let
        (
            (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
        )
        (asserts! (>= block-height (get end-block proposal)) ERR-PROPOSAL-EXPIRED)
        (asserts! (is-eq (get creator proposal) tx-sender) ERR-NOT-AUTHORIZED)
        
        (map-set proposals
            {proposal-id: proposal-id}
            (merge proposal
                {
                    status: (if (> (get yes-votes proposal) (get no-votes proposal))
                        "passed"
                        "failed"
                    )
                }
            )
        )
        (ok true)
    )
)

;; Initialize contract
(define-public (initialize-contract)
    (begin
        (var-set proposal-count u0)
        (ok true)
    )
)