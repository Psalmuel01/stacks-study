;; (define-constant ERR-NOT-AUTHORIZED u100)
;; (define-constant ERR-STREAM-PAUSED u101)
;; (define-constant ERR-NOTHING-TO-WITHDRAW u102)

;; ;; USDCX token contract
;; (define-constant USDCX 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.usdcx)

;; ;; immutable stream params
;; (define-data-var employer principal tx-sender)
;; (define-data-var employee principal tx-sender)

;; (define-data-var total-amount uint u0)
;; (define-data-var withdrawn uint u0)
;; (define-data-var start-block uint u0)
;; (define-data-var end-block uint u0)
;; (define-data-var paused bool false)

;; ;; ---------------- helpers ----------------

;; (define-read-only (earned)
;;   (let (
;;         (now stacks-block-height)
;;         (start (var-get start-block))
;;         (end (var-get end-block))
;;        )
;;     (if (<= now start)
;;         u0
;;         (let (
;;               (elapsed (if (< (- now start) (- end start)) (- now start) (- end start)))
;;               (rate (/ (var-get total-amount) (- end start)))
;;              )
;;           (* elapsed rate)
;;         )
;;     )
;;   )
;; )

;; (define-read-only (withdrawable)
;;   (let (
;;         (e (earned))
;;         (w (var-get withdrawn))
;;        )
;;     (if (<= e w) u0 (- e w))
;;   )
;; )

;; ;; ---------------- public ----------------

;; (define-public (withdraw-earned)
;;   (begin
;;     (asserts! (not (var-get paused)) ERR-STREAM-PAUSED)

;;     (let ((amount (withdrawable)))
;;       (asserts! (> amount u0) ERR-NOTHING-TO-WITHDRAW)

;;       (try!
;;         (contract-call? USDCX transfer amount tx-sender (var-get employee) none)
;;       )

;;       (var-set withdrawn (+ (var-get withdrawn) amount))
;;       (ok amount)
;;     )
;;   )
;; )

;; (define-public (pause)
;;   (begin
;;     (asserts! (is-eq tx-sender (var-get employer)) ERR-NOT-AUTHORIZED)
;;     (var-set paused true)
;;     (ok true)
;;   )
;; )

;; (define-public (resume)
;;   (begin
;;     (asserts! (is-eq tx-sender (var-get employer)) ERR-NOT-AUTHORIZED)
;;     (var-set paused false)
;;     (ok true)
;;   )
;; )
