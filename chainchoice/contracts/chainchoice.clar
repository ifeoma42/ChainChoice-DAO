;; ChainChoice DAO - Quadratic Voting Contract with Emergency Veto
;; Error Codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u101))
(define-constant ERR-INVALID-VOTE-AMOUNT (err u102))
(define-constant ERR-PROPOSAL-EXPIRED (err u103))
(define-constant ERR-INSUFFICIENT-BALANCE (err u104))
(define-constant ERR-ALREADY-VOTED (err u105))
(define-constant ERR-NOT-COUNCIL-MEMBER (err u106))
(define-constant ERR-PROPOSAL-VETOED (err u107))
(define-constant ERR-INSUFFICIENT-VETO-POWER (err u108))
(define-constant ERR-ALREADY-VETOED (err u109))
(define-constant ERR-INVALID-TITLE (err u110))
(define-constant ERR-INVALID-DESCRIPTION (err u111))
(define-constant ERR-INVALID-SUPPLY (err u112))
(define-constant ERR-ZERO-ADDRESS (err u113))

;; Constants
(define-constant VETO_THRESHOLD u750) ;; 75% of total supply needed for community veto
(define-constant COUNCIL_VETO_THRESHOLD u2) ;; Number of council members needed for veto
(define-constant MAX_TITLE_LENGTH u50)
(define-constant MAX_DESCRIPTION_LENGTH u500)
(define-constant CONTRACT_OWNER tx-sender)

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
        status: (string-ascii 10),
        veto-count: uint,
        is-vetoed: bool
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

(define-map council-members
    principal
    bool
)

(define-map veto-votes
    {user: principal, proposal-id: uint}
    bool
)

;; Variables
(define-data-var proposal-count uint u0)
(define-data-var token-name (string-ascii 32) "ChainChoice")
(define-data-var token-symbol (string-ascii 10) "CHC")
(define-data-var total-supply uint u0)
(define-data-var contract-initialized bool false)

;; Private functions
(define-private (is-valid-title (title (string-ascii 50)))
    (and
        (not (is-eq title ""))
        (<= (len title) MAX_TITLE_LENGTH)
    )
)

(define-private (is-valid-description (description (string-ascii 500)))
    (and
        (not (is-eq description ""))
        (<= (len description) MAX_DESCRIPTION_LENGTH)
    )
)

(define-private (is-valid-principal (address principal))
    (not (is-eq address (as-contract tx-sender)))
)

(define-private (check-is-owner)
    (ok (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR-NOT-AUTHORIZED))
)

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

(define-read-only (is-council-member (user principal))
    (default-to false (map-get? council-members user))
)

(define-read-only (calculate-quadratic-votes (amount uint))
    (let ((square-root (sqrti amount)))
        square-root
    )
)

(define-read-only (get-veto-vote (user principal) (proposal-id uint))
    (default-to false (map-get? veto-votes {user: user, proposal-id: proposal-id}))
)

;; Public functions
(define-public (create-proposal (title (string-ascii 50)) (description (string-ascii 500)) (duration uint))
    (let
        (
            (proposal-id (var-get proposal-count))
            (start-block block-height)
            (end-block (+ block-height duration))
        )
        (asserts! (is-valid-title title) ERR-INVALID-TITLE)
        (asserts! (is-valid-description description) ERR-INVALID-DESCRIPTION)
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
                status: "active",
                veto-count: u0,
                is-vetoed: false
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
        (asserts! (not (get is-vetoed proposal)) ERR-PROPOSAL-VETOED)
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

(define-public (council-veto (proposal-id uint))
    (let
        (
            (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (current-veto-count (get veto-count proposal))
        )
        (asserts! (is-council-member tx-sender) ERR-NOT-COUNCIL-MEMBER)
        (asserts! (not (get-veto-vote tx-sender proposal-id)) ERR-ALREADY-VETOED)
        (asserts! (not (get is-vetoed proposal)) ERR-PROPOSAL-VETOED)
        
        ;; Record council member's veto
        (map-set veto-votes
            {user: tx-sender, proposal-id: proposal-id}
            true
        )
        
        ;; Update veto count and check if threshold is met
        (let ((new-veto-count (+ current-veto-count u1)))
            (map-set proposals
                {proposal-id: proposal-id}
                (merge proposal
                    {
                        veto-count: new-veto-count,
                        is-vetoed: (>= new-veto-count COUNCIL_VETO_THRESHOLD),
                        status: (if (>= new-veto-count COUNCIL_VETO_THRESHOLD)
                            "vetoed"
                            (get status proposal)
                        )
                    }
                )
            )
            (ok true)
        )
    )
)

(define-public (community-veto (proposal-id uint))
    (let
        (
            (proposal (unwrap! (get-proposal proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (user-balance (get-balance tx-sender))
        )
        (asserts! (not (get-veto-vote tx-sender proposal-id)) ERR-ALREADY-VETOED)
        (asserts! (not (get is-vetoed proposal)) ERR-PROPOSAL-VETOED)
        (asserts! (>= user-balance (/ (* (var-get total-supply) VETO_THRESHOLD) u1000)) ERR-INSUFFICIENT-VETO-POWER)
        
        ;; Record community veto
        (map-set veto-votes
            {user: tx-sender, proposal-id: proposal-id}
            true
        )
        
        ;; Automatically veto if threshold met
        (map-set proposals
            {proposal-id: proposal-id}
            (merge proposal
                {
                    is-vetoed: true,
                    status: "vetoed"
                }
            )
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
        (asserts! (not (get is-vetoed proposal)) ERR-PROPOSAL-VETOED)
        
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

(define-public (add-council-member (member principal))
    (begin
        (try! (check-is-owner))
        (asserts! (is-valid-principal member) ERR-ZERO-ADDRESS)
        (map-set council-members member true)
        (ok true)
    )
)

(define-public (remove-council-member (member principal))
    (begin
        (try! (check-is-owner))
        (asserts! (is-valid-principal member) ERR-ZERO-ADDRESS)
        (map-set council-members member false)
        (ok true)
    )
)

;; Initialize contract
(define-public (initialize-contract (initial-council-member principal) (initial-supply uint))
    (begin
        (asserts! (not (var-get contract-initialized)) ERR-NOT-AUTHORIZED)
        (asserts! (> initial-supply u0) ERR-INVALID-SUPPLY)
        (asserts! (is-valid-principal initial-council-member) ERR-ZERO-ADDRESS)
        
        (var-set contract-initialized true)
        (var-set proposal-count u0)
        (var-set total-supply initial-supply)
        (map-set council-members initial-council-member true)
        (map-set user-balances initial-council-member initial-supply)
        (ok true)
    )
)