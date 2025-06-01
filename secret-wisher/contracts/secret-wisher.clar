;; title: secret-wisher
;; version: 1.0.0
;; summary: a simple wish system to post and manage wishes
;; description: a contract that allows anyone to make wishes and update them, with getter functions to view wishes and their owners

;; traits
;;

;; token definitions
;;

;; constants
(define-constant ERR-WISH-NOT-FOUND (err u404))
(define-constant ERR-EMPTY-WISH (err u400))
;;

;; data vars
(define-data-var wish-counter uint u0)
;;

;; data maps
(define-map wishes
    uint
    {
        wish: (string-utf8 500),
        owner: principal,
        created-at: uint,
        updated-at: uint,
    }
)

(define-map user-wishes
    principal
    (list
        100
        uint
    )
)
;;

;; public functions

;; Function to make a new wish
(define-public (make-wish (wish-text (string-utf8 500)))
  (let 
    (
      (wish-id (+ (var-get wish-counter) u1))
      (caller tx-sender)
      (current-block block-height)
    )
    (asserts! (> (len wish-text) u0) ERR-EMPTY-WISH)
    
    ;; Store the wish
    (map-set wishes wish-id {
      wish: wish-text,
      owner: caller,
      created-at: current-block,
      updated-at: current-block
    })
    
    ;; Update user's wish list
    (let ((current-wishes (default-to (list) (map-get? user-wishes caller))))
      (map-set user-wishes caller (unwrap-panic (as-max-len? (append current-wishes wish-id) u100)))
    )
    
    ;; Increment counter
    (var-set wish-counter wish-id)
    
    (ok wish-id)
  )
)

;; Function to update an existing wish (anyone can update any wish)
(define-public (update-wish (wish-id uint) (new-wish-text (string-utf8 500)))
  (let 
    (
      (existing-wish (unwrap! (map-get? wishes wish-id) ERR-WISH-NOT-FOUND))
      (current-block block-height)
    )
    (asserts! (> (len new-wish-text) u0) ERR-EMPTY-WISH)
    
    ;; Update the wish with new text and timestamp
    (map-set wishes wish-id {
      wish: new-wish-text,
      owner: (get owner existing-wish),
      created-at: (get created-at existing-wish),
      updated-at: current-block
    })
    
    (ok true)
  )
)
;; 

;; read only functions

;; Get a specific wish by ID
(define-read-only (get-wish (wish-id uint))
  (map-get? wishes wish-id)
)

;; Get the owner of a specific wish
(define-read-only (get-wish-owner (wish-id uint))
  (match (map-get? wishes wish-id)
    wish-data (some (get owner wish-data))
    none
  )
)

;; Get all wish IDs created by a specific user
(define-read-only (get-user-wishes (user principal))
  (default-to (list) (map-get? user-wishes user))
)

;; Get the total number of wishes
(define-read-only (get-total-wishes)
  (var-get wish-counter)
)

;; Get wish text only
(define-read-only (get-wish-text (wish-id uint))
  (match (map-get? wishes wish-id)
    wish-data (some (get wish wish-data))
    none
  )
)

;; Check if a wish exists
(define-read-only (wish-exists (wish-id uint))
  (is-some (map-get? wishes wish-id))
)

;; Get wish creation and update timestamps
(define-read-only (get-wish-timestamps (wish-id uint))
  (match (map-get? wishes wish-id)
    wish-data (some {
      created-at: (get created-at wish-data),
      updated-at: (get updated-at wish-data)
    })
    none
  )
)
;; 

;; private functions
;;
