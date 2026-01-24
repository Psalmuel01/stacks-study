;; Comprehensive Voting / Governance Contract for Clarity 4 ;;

;; Error codes
(define-constant ERR_NOT_OWNER u100)
(define-constant ERR_PROPOSAL_EXISTS u101)
(define-constant ERR_PROPOSAL_NOT_FOUND u102)
(define-constant ERR_VOTE_CLOSED u103)
(define-constant ERR_ALREADY_VOTED u104)
(define-constant ERR_INVALID_VOTE u105)

;; Owner of the contract
(define-data-var owner principal tx-sender)

;; Proposal structure: id => { description, votes-up, votes-down, end-timestamp }
(define-map proposals
  { id: uint }
  {
    description: (string-ascii 280),
    votes-up: uint,
    votes-down: uint,
    end: uint
  })

;; Track votes by user: {proposal-id, voter} => {support: bool}
(define-map votes
  { proposal-id: uint, voter: principal }
  { support: bool })

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ADMIN FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Create a new proposal
(define-public (create-proposal (id uint) (description (string-ascii 280)) (duration uint))
  (begin
    (asserts! (is-none (map-get? proposals { id: id })) (err ERR_PROPOSAL_EXISTS))

    (let ((end (+ stacks-block-height duration)))
      (map-set proposals
        { id: id }
        {
          description: description,
          votes-up: u0,
          votes-down: u0,
          end: end
        })

      (print { event: "proposal-created", id: id, description: description, end: end })

      (ok id))))

;; Cast or modify a vote
(define-public (vote (proposal-id uint) (support bool))
  (let ((prop (unwrap! (map-get? proposals { id: proposal-id }) (err ERR_PROPOSAL_NOT_FOUND))))
    (asserts! (< stacks-block-height (get end prop)) (err ERR_VOTE_CLOSED))

    (let ((prev (map-get? votes { proposal-id: proposal-id, voter: tx-sender })))
      (match prev
        prev-vote
        ;; vote already exists, changing it
        (let ((was-yes (get support prev-vote)))
          (if (is-eq was-yes support)
            ;; same choice, no change needed
            (ok proposal-id)
            ;; flip vote
            (begin
              (map-set proposals { id: proposal-id }
                (merge prop {
                  votes-up:   (if support (+ (get votes-up prop) u1)   (- (get votes-up prop)   u1)),
                  votes-down: (if support (- (get votes-down prop) u1) (+ (get votes-down prop) u1))
                }))
              (map-set votes
                { proposal-id: proposal-id, voter: tx-sender }
                { support: support })
              (print { event: "vote-changed", proposal-id: proposal-id, voter: tx-sender, support: support })
              (ok proposal-id))))

        ;; first vote
        (begin
          (map-set proposals { id: proposal-id }
            (merge prop {
              votes-up:   (if support (+ (get votes-up prop) u1)   (get votes-up prop)),
              votes-down: (if support (get votes-down prop)        (+ (get votes-down prop) u1))
            }))
          (map-set votes
            { proposal-id: proposal-id, voter: tx-sender }
            { support: support })
          (print { event: "vote-cast", proposal-id: proposal-id, voter: tx-sender, support: support })
          (ok proposal-id))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; READ-ONLY FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-read-only (get-proposal (id uint))
  (map-get? proposals { id: id }))

(define-read-only (get-vote (id uint) (voter principal))
  (map-get? votes { proposal-id: id, voter: voter }))

(define-read-only (get-result (id uint))
  (let ((p (map-get? proposals { id: id })))
    (match p
      prop (if (>= stacks-block-height (get end prop))
               (ok (if (> (get votes-up prop) (get votes-down prop))
                       "YES"
                       (if (< (get votes-up prop) (get votes-down prop))
                           "NO"
                           "TIE")))
               (err ERR_VOTE_CLOSED))
      (err ERR_PROPOSAL_NOT_FOUND))))