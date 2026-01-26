;; StackPay Payment Processor (Iteration: Balance + Withdrawals)

(use-trait invoice-trait .architecturexx.invoice-trait)
(use-trait sip-010-trait 'ST1NXBK3K5YYMD6FD41MVNP3JS1GABZ8TRVX023PT.sip-010-trait-ft-standard.sip-010-trait)

;; constants
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_INVALID_TOKEN (err u401))
(define-constant ERR_PAYMENT_FAILED (err u402))
(define-constant ERR_INVALID_AMOUNT (err u405))
(define-constant ERR_INVALID_INPUT (err u407))
(define-constant ERR_INACTIVE_SUBSCRIPTION (err u410))
(define-constant ERR_TOO_EARLY (err u411))
(define-constant ERR_MAX_PAYMENTS_EXCEEDED (err u412))
(define-constant ERR_INSUFFICIENT_BALANCE (err u413))

(define-constant CURRENCY_STX "STX")
(define-constant CURRENCY_SBTC "sBTC")
(define-constant CURRENCY_USDC "USDC")

;; data-vars
(define-data-var platform-fee-bps uint u100) ;; in basis points (100 = 1%)

;; data-maps
(define-map balances
    {
        merchant: principal,
        currency: (string-ascii 10),
    }
    { amount: uint }
)

(define-map supported-tokens
    { currency: (string-ascii 10) }
    {
        token-contract: (optional principal),
        is-active: bool,
    }
)

(map-set supported-tokens { currency: CURRENCY_STX } {
    token-contract: none,
    is-active: true,
})
(map-set supported-tokens { currency: CURRENCY_SBTC } {
    token-contract: (some 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token),
    is-active: true,
})
(map-set supported-tokens { currency: CURRENCY_USDC } {
    token-contract: (some 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.usdcx),
    is-active: true,
})

;; private functions
(define-private (credit-balance
        (merchant principal)
        (currency (string-ascii 10))
        (amt uint)
    )
    (let ((cur (default-to { amount: u0 }
            (map-get? balances {
                merchant: merchant,
                currency: currency,
            })
        )))
        (map-set balances {
            merchant: merchant,
            currency: currency,
        } { amount: (+ (get amount cur) amt) }
        )
    )
)

(define-private (debit-balance
        (merchant principal)
        (currency (string-ascii 10))
        (amt uint)
    )
    (let ((cur (unwrap!
            (map-get? balances {
                merchant: merchant,
                currency: currency,
            })
            ERR_INSUFFICIENT_BALANCE
        )))
        (asserts! (>= (get amount cur) amt) ERR_INSUFFICIENT_BALANCE)
        (map-set balances {
            merchant: merchant,
            currency: currency,
        } { amount: (- (get amount cur) amt) }
        )
        (ok true)
    )
)

;; public functions

(define-public (process-stx-payment
        (invoice-id (string-ascii 85))
        (amount uint)
        (tx-id (buff 32))
    )
    (let (
            (payer tx-sender)
            (inv (unwrap! (contract-call? .architecturexx get-invoice invoice-id)
                ERR_PAYMENT_FAILED
            ))
            (merchant (get merchant inv))
        )
        (asserts! (is-eq (get currency inv) CURRENCY_STX) ERR_INVALID_INPUT)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (is-eq amount (get amount inv)) ERR_INVALID_AMOUNT)
        ;; funds deposited to contract, not merchant
        (as-contract? ((with-stx amount))
            (try! (stx-transfer? amount payer contract-caller))
        )

        (credit-balance merchant CURRENCY_STX amount)
        (try! (contract-call? .architecturexx process-payment invoice-id payer amount
            tx-id
        ))
        (ok true)
    )
)

(define-public (process-sip-010-payment
        (invoice-id (string-ascii 85))
        (amount uint)
        (tx-id (buff 32))
        (token <sip-010-trait>)
    )
    (let (
            (payer tx-sender)
            (inv (unwrap! (contract-call? .architecturexx get-invoice invoice-id)
                ERR_PAYMENT_FAILED
            ))
            (currency (get currency inv))
            (merchant (get merchant inv))
            ;; dynamic lookup based on invoice currency
            (info (unwrap! (map-get? supported-tokens { currency: currency })
                ERR_INVALID_TOKEN
            ))
            (reg (unwrap! (get token-contract info) ERR_INVALID_TOKEN))
        )
        ;; ensure invoice currency matches the token we looked up
        (asserts! (or
            (is-eq currency CURRENCY_SBTC)
            (is-eq currency CURRENCY_USDC)
        ) ERR_INVALID_INPUT)

        ;; ensure the passed token trait matches our registry
        (asserts! (is-eq reg (contract-of token)) ERR_INVALID_TOKEN)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (is-eq amount (get amount inv)) ERR_INVALID_AMOUNT)

        ;; transfer to contract
        (as-contract? ((with-ft token amount))
            (try! (contract-call? token transfer amount payer contract-caller none))
        )

        (credit-balance merchant currency amount)
        (try! (contract-call? .architecturexx process-payment invoice-id payer amount
            tx-id
        ))
        (ok true)
    )
)

(define-public (withdraw
        (currency (string-ascii 10))
        (amount uint)
        (token <sip-010-trait>)
    )
    (let (
            (bal (unwrap!
                (map-get? balances {
                    merchant: tx-sender,
                    currency: currency,
                })
                ERR_INSUFFICIENT_BALANCE
            ))
            (fee-bps (var-get platform-fee-bps))
            (fee (/ (* amount fee-bps) u10000))
            (payout (- amount fee))
        )
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (>= (get amount bal) amount) ERR_INSUFFICIENT_BALANCE)
        (try! (debit-balance tx-sender currency amount))
        (if (is-eq currency CURRENCY_STX)
            (as-contract? ((with-stx payout))
                (try! (stx-transfer? payout contract-caller tx-sender))
            )
            (let (
                    (info (unwrap!
                        (map-get? supported-tokens { currency: CURRENCY_SBTC })
                        ERR_INVALID_TOKEN
                    ))
                    (reg (unwrap! (get token-contract info) ERR_INVALID_TOKEN))
                )
                (asserts! (is-eq reg (contract-of token)) ERR_INVALID_TOKEN)
                (as-contract? ((with-ft token payout))
                    (try! (contract-call? token transfer payout contract-caller tx-sender none))
                )

            )
        )
        (ok {
            withdrawn: payout,
            fee: fee,
        })
    )
)

;; read-only

(define-read-only (get-balance
        (merchant principal)
        (currency (string-ascii 10))
    )
    (map-get? balances {
        merchant: merchant,
        currency: currency,
    })
)
