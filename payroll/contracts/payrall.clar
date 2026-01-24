(define-constant ERR-NOT-EMPLOYER u200)
(define-constant ERR-INSUFFICIENT-BALANCE u201)

(define-map employers
  principal
  (string-ascii 256)
)

(define-map streams
  uint
  principal
)

(define-data-var stream-counter uint u0)
(define-constant USDCX 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.usdcx)
(define-constant SALARY 'ST1H7G0B7BBM991P2KA77R0XHDRNYCWH8H92TT4QN.salary)
;; --- employer management ---

(define-public (register-employer (metadata (string-ascii 256)))
  (begin
    (map-set employers tx-sender metadata)
    (ok true)
  )
)

(define-read-only (is-employer (who principal))
  (is-some (map-get? employers who))
)

;; --- stream creation ---

(define-public (create-stream
  (employee principal)
  (total-amount uint)
  (start uint)
  (end uint)
)
  (begin
    (asserts! (is-employer tx-sender) ERR-NOT-EMPLOYER)

    ;; ensure employer has enough USDCx
    (let ((balance
            (unwrap-panic
              (contract-call? USDCX
                get-balance
                tx-sender))))
      (asserts! (>= balance total-amount) ERR-INSUFFICIENT-BALANCE)
    )

    (let (
          (id (+ (var-get stream-counter) u1))
         )
      (var-set stream-counter id)

      ;; deploy new stream contract
      (let (
            (stream
            (unwrap-panic
              (contract-call?
                SALARY
                initialize
                tx-sender
                employee
                USDCX
                total-amount
                start
                end))
           ))
        (map-set streams id stream)
        (ok id)
      )
    )
  )
)

(define-read-only (get-stream (id uint))
  (map-get? streams id)
)
