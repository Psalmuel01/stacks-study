;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Comprehensive Voting / Governance Contract for Clarity 4 ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
  ((id uint))
  ((description (string-ascii 280))
   (votes-up uint)
   (votes-down uint)
   (end uint)))

;; Track votes by user: ((proposal-id, voter) => voted bool, support bool)
(define-map votes
  ((proposal-id uint) (voter principal))
  ((voted bool) (support bool)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ADMIN FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Create a new proposal
(define-public (create-proposal (id uint) (description (string-utf8 256)) (duration uint))
    (begin
      ;; Ensure proposal does not exist
      (asserts! (is-none (map-get? proposals {id: id})) (err ERR_PROPOSAL_EXISTS))

      ;; Compute end time
      (let ((end (+ stacks-block-time duration)))
        (begin
          ;; Store proposal in map
          (map-set proposals {id: id}
            {description: description, votes-up: u0, votes-down: u0, end: end})

          ;; Emit Chainhook event
          (print {event: "proposal-created", id: id, description: description, end: end})

          ;; Return proposal id
          (ok id)
        )
      )
    )
  )
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; VOTING FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Cast or modify a vote
(define-public (vote id uint support bool)
  (let ((p (map-get? proposals {id: id})))
    (match p
      p
      (begin
        ;; Ensure proposal still active
        (asserts! (< (stacks-block-time) (get end p)) (err ERR_VOTE_CLOSED))

        ;; Check if voter already voted
        (let ((existing-vote (map-get? votes {proposal-id: id, voter: tx-sender})))
          (if existing-vote
              ;; Modify existing vote
              (begin
                (map-set votes {proposal-id: id, voter: tx-sender}
                         {voted: true, support: support})

                ;; Update proposal tallies
                (let ((delta-up (if support u1 u0))
                      (delta-down (if support u0 u1))
                      (old-up (get votes-up p))
                      (old-down (get votes-down p)))
                  (map-set proposals {id: id}
                           {description: (get description p),
                            votes-up: (+ old-up delta-up),
                            votes-down: (+ old-down delta-down),
                            end: (get end p)}))
                (print {event: "vote-modified", proposal-id: id, voter: tx-sender, support: support})
                (ok id))
              ;; First-time vote
              (begin
                (map-set votes {proposal-id: id, voter: tx-sender} {voted: true, support: support})

                ;; Update proposal tallies
                (map-set proposals {id: id}
                         {description: (get description p),
                          votes-up: (+ (get votes-up p) (if support u1 u0)),
                          votes-down: (+ (get votes-down p) (if support u0 u1)),
                          end: (get end p)})

                (print {event: "vote-cast", proposal-id: id, voter: tx-sender, support: support})
                (ok id)))))
      (err ERR_PROPOSAL_NOT_FOUND))
  )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; READ-ONLY FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Get proposal info
(define-read-only (get-proposal id uint)
  (map-get? proposals {id: id}))

;; Get vote info for a user
(define-read-only (get-vote id uint voter principal)
  (map-get? votes {proposal-id: id, voter: voter}))

;; Get winning choice (after proposal ends)
(define-read-only (get-result id uint)
  (let ((p (map-get? proposals {id: id})))
    (match p
      p
      (if (>= (stacks-block-time) (get end p))
          (ok (if (> (get votes-up p) (get votes-down p)) "YES" "NO"))
          (err ERR_VOTE_CLOSED))
      (err ERR_PROPOSAL_NOT_FOUND)
    )
  )
)
