;; Automated Dollar-Cost Averaging System Smart Contract
;; Written in Clarinet for Stacks blockchain

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_STRATEGY_NOT_FOUND (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_INVALID_FREQUENCY (err u103))
(define-constant ERR_INVALID_AMOUNT (err u104))
(define-constant ERR_STRATEGY_PAUSED (err u105))
(define-constant ERR_STRATEGY_ACTIVE (err u106))
(define-constant ERR_EXECUTION_TOO_EARLY (err u107))
(define-constant ERR_TOKEN_NOT_SUPPORTED (err u108))
(define-constant ERR_PRICE_FEED_ERROR (err u109))
(define-constant ERR_SLIPPAGE_TOO_HIGH (err u110))

;; Token trait for SIP-010 compliance
(define-trait sip-010-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

;; Data structures
(define-map dca-strategies
  { strategy-id: uint }
  {
    owner: principal,
    token-in: principal,         ;; Token to sell (e.g., STX)
    token-out: principal,        ;; Token to buy (e.g., USDC)
    amount-per-execution: uint,  ;; Amount to invest each time
    frequency: uint,             ;; Frequency in blocks
    last-execution: uint,        ;; Last execution block
    total-invested: uint,        ;; Total amount invested
    total-purchased: uint,       ;; Total tokens purchased
    executions-count: uint,      ;; Number of executions
    is-active: bool,             ;; Strategy status
    max-slippage: uint,          ;; Max slippage in basis points (100 = 1%)
    created-at: uint,            ;; Creation block
    next-execution: uint         ;; Next scheduled execution
  }
)

(define-map user-balances
  { user: principal, token: principal }
  { balance: uint }
)

(define-map supported-tokens
  { token: principal }
  {
    is-supported: bool,
    decimals: uint,
    price-feed: (optional principal)  ;; Oracle contract for price feeds
  }
)

(define-map token-pairs
  { token-in: principal, token-out: principal }
  {
    is-active: bool,
    dex-contract: principal,    ;; DEX contract for swapping
    fee-rate: uint              ;; Fee rate in basis points
  }
)

(define-map price-feeds
  { token: principal }
  {
    price: uint,               ;; Price in micro-units
    last-update: uint,         ;; Last update block
    oracle: principal          ;; Oracle provider
  }
)

;; Data variables
(define-data-var next-strategy-id uint u1)
(define-data-var platform-fee-rate uint u50)    ;; 0.5% platform fee
(define-data-var min-execution-amount uint u1000000)  ;; Minimum 1 STX
(define-data-var max-slippage-allowed uint u1000)     ;; 10% max slippage
(define-data-var contract-paused bool false)

;; Helper function to get current block height
(define-read-only (get-block-height)
  stacks-block-height
)

;; Read-only functions
(define-read-only (get-strategy (strategy-id uint))
  (map-get? dca-strategies { strategy-id: strategy-id })
)

(define-read-only (get-user-balance (user principal) (token principal))
  (default-to 
    { balance: u0 }
    (map-get? user-balances { user: user, token: token })
  )
)

(define-read-only (get-supported-token (token principal))
  (map-get? supported-tokens { token: token })
)

(define-read-only (get-token-pair (token-in principal) (token-out principal))
  (map-get? token-pairs { token-in: token-in, token-out: token-out })
)

(define-read-only (get-price-feed (token principal))
  (map-get? price-feeds { token: token })
)

(define-read-only (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-rate)) u10000)
)

(define-read-only (is-execution-due (strategy-id uint))
  (match (get-strategy strategy-id)
    strategy (>= (get-block-height) (get next-execution strategy))
    false
  )
)

(define-read-only (calculate-average-price (strategy-id uint))
  (match (get-strategy strategy-id)
    strategy 
      (if (> (get total-purchased strategy) u0)
        (/ (get total-invested strategy) (get total-purchased strategy))
        u0)
    u0
  )
)

(define-read-only (get-strategy-performance (strategy-id uint))
  (match (get-strategy strategy-id)
    strategy
      (let
        (
          (avg-price (calculate-average-price strategy-id))
          (current-price (get-token-price (get token-out strategy)))
        )
        (match current-price
          price 
            (if (> avg-price u0)
              {
                average-price: avg-price,
                current-price: price,
                pnl-percentage: (if (>= price avg-price)
                  (/ (* (- price avg-price) u10000) avg-price)
                  (- u0 (/ (* (- avg-price price) u10000) avg-price))
                ),
                total-value: (* (get total-purchased strategy) price)
              }
              {
                average-price: u0,
                current-price: price,
                pnl-percentage: u0,
                total-value: u0
              })
          {
            average-price: u0,
            current-price: u0,
            pnl-percentage: u0,
            total-value: u0
          }
        )
      )
    {
      average-price: u0,
      current-price: u0,
      pnl-percentage: u0,
      total-value: u0
    }
  )
)

;; Private functions
(define-private (get-token-price (token principal))
  (match (get-price-feed token)
    feed (some (get price feed))
    none
  )
)

(define-private (update-user-balance (user principal) (token principal) (amount uint) (is-deposit bool))
  (let
    (
      (current-balance (get balance (get-user-balance user token)))
    )
    (if is-deposit
      ;; For deposits, just add the amount
      (let
        (
          (new-balance (+ current-balance amount))
        )
        (map-set user-balances
          { user: user, token: token }
          { balance: new-balance }
        )
        (ok new-balance)
      )
      ;; For withdrawals, check if sufficient balance exists
      (if (>= current-balance amount)
        (let
          (
            (new-balance (- current-balance amount))
          )
          (map-set user-balances
            { user: user, token: token }
            { balance: new-balance }
          )
          (ok new-balance)
        )
        ERR_INSUFFICIENT_BALANCE
      )
    )
  )
)

(define-private (execute-swap 
  (token-in principal) 
  (token-out principal) 
  (amount-in uint)
  (min-amount-out uint))
  ;; This is a simplified swap function
  ;; In a real implementation, this would interact with a DEX
  (let
    (
      (pair (unwrap! (get-token-pair token-in token-out) ERR_TOKEN_NOT_SUPPORTED))
      (price-in (unwrap! (get-token-price token-in) ERR_PRICE_FEED_ERROR))
      (price-out (unwrap! (get-token-price token-out) ERR_PRICE_FEED_ERROR))
      (expected-out (/ (* amount-in price-in) price-out))
      (fee-amount (/ (* expected-out (get fee-rate pair)) u10000))
      (amount-out (- expected-out fee-amount))
    )
    (asserts! (>= amount-out min-amount-out) ERR_SLIPPAGE_TOO_HIGH)
    (ok amount-out)
  )
)

;; Public functions

;; Deposit tokens to user balance
(define-public (deposit-tokens (token <sip-010-trait>) (amount uint))
  (let
    (
      (token-address (contract-of token))
    )
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Transfer tokens from user to contract
    (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
    
    ;; Update user balance
    (try! (update-user-balance tx-sender token-address amount true))
    
    (ok amount)
  )
)

;; Withdraw tokens from user balance
(define-public (withdraw-tokens (token <sip-010-trait>) (amount uint))
  (let
    (
      (token-address (contract-of token))
      (user-balance (get balance (get-user-balance tx-sender token-address)))
    )
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= user-balance amount) ERR_INSUFFICIENT_BALANCE)
    
    ;; Transfer tokens from contract to user
    (try! (as-contract (contract-call? token transfer amount tx-sender tx-sender none)))
    
    ;; Update user balance
    (try! (update-user-balance tx-sender token-address amount false))
    
    (ok amount)
  )
)

;; Create a new DCA strategy
(define-public (create-dca-strategy
  (token-in principal)
  (token-out principal)
  (amount-per-execution uint)
  (frequency uint)
  (max-slippage uint))
  (let
    (
      (strategy-id (var-get next-strategy-id))
      (user-balance (get balance (get-user-balance tx-sender token-in)))
      (current-block (get-block-height))
    )
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (>= amount-per-execution (var-get min-execution-amount)) ERR_INVALID_AMOUNT)
    (asserts! (> frequency u0) ERR_INVALID_FREQUENCY)
    (asserts! (<= max-slippage (var-get max-slippage-allowed)) ERR_SLIPPAGE_TOO_HIGH)
    (asserts! (>= user-balance amount-per-execution) ERR_INSUFFICIENT_BALANCE)
    (asserts! (is-some (get-supported-token token-in)) ERR_TOKEN_NOT_SUPPORTED)
    (asserts! (is-some (get-supported-token token-out)) ERR_TOKEN_NOT_SUPPORTED)
    (asserts! (is-some (get-token-pair token-in token-out)) ERR_TOKEN_NOT_SUPPORTED)
    
    (map-set dca-strategies
      { strategy-id: strategy-id }
      {
        owner: tx-sender,
        token-in: token-in,
        token-out: token-out,
        amount-per-execution: amount-per-execution,
        frequency: frequency,
        last-execution: u0,
        total-invested: u0,
        total-purchased: u0,
        executions-count: u0,
        is-active: true,
        max-slippage: max-slippage,
        created-at: current-block,
        next-execution: (+ current-block frequency)
      }
    )
    
    (var-set next-strategy-id (+ strategy-id u1))
    (ok strategy-id)
  )
)

;; Execute DCA strategy
(define-public (execute-dca-strategy (strategy-id uint))
  (let
    (
      (strategy (unwrap! (get-strategy strategy-id) ERR_STRATEGY_NOT_FOUND))
      (owner (get owner strategy))
      (token-in (get token-in strategy))
      (token-out (get token-out strategy))
      (amount (get amount-per-execution strategy))
      (user-balance (get balance (get-user-balance owner token-in)))
      (current-block (get-block-height))
    )
    (asserts! (not (var-get contract-paused)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active strategy) ERR_STRATEGY_PAUSED)
    (asserts! (>= current-block (get next-execution strategy)) ERR_EXECUTION_TOO_EARLY)
    (asserts! (>= user-balance amount) ERR_INSUFFICIENT_BALANCE)
    
    ;; Calculate minimum amount out based on slippage tolerance
    (let
      (
        (price-in (unwrap! (get-token-price token-in) ERR_PRICE_FEED_ERROR))
        (price-out (unwrap! (get-token-price token-out) ERR_PRICE_FEED_ERROR))
        (expected-out (/ (* amount price-in) price-out))
        (min-amount-out (- expected-out (/ (* expected-out (get max-slippage strategy)) u10000)))
        (platform-fee (calculate-platform-fee amount))
        (net-amount (- amount platform-fee))
      )
      
      ;; Execute the swap
      (let
        (
          (amount-out (try! (execute-swap token-in token-out net-amount min-amount-out)))
        )
        
        ;; Update user balances
        (try! (update-user-balance owner token-in amount false))
        (try! (update-user-balance owner token-out amount-out true))
        
        ;; Update strategy
        (map-set dca-strategies
          { strategy-id: strategy-id }
          (merge strategy {
            last-execution: current-block,
            total-invested: (+ (get total-invested strategy) net-amount),
            total-purchased: (+ (get total-purchased strategy) amount-out),
            executions-count: (+ (get executions-count strategy) u1),
            next-execution: (+ current-block (get frequency strategy))
          })
        )
        
        ;; Transfer platform fee to contract owner
        (try! (update-user-balance CONTRACT_OWNER token-in platform-fee true))
        
        (ok {
          amount-invested: net-amount,
          amount-purchased: amount-out,
          execution-price: (/ net-amount amount-out)
        })
      )
    )
  )
)

;; Pause/unpause DCA strategy
(define-public (toggle-strategy-status (strategy-id uint))
  (let
    (
      (strategy (unwrap! (get-strategy strategy-id) ERR_STRATEGY_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner strategy)) ERR_NOT_AUTHORIZED)
    
    (map-set dca-strategies
      { strategy-id: strategy-id }
      (merge strategy { is-active: (not (get is-active strategy)) })
    )
    
    (ok (not (get is-active strategy)))
  )
)

;; Update DCA strategy parameters
(define-public (update-strategy
  (strategy-id uint)
  (new-amount uint)
  (new-frequency uint)
  (new-max-slippage uint))
  (let
    (
      (strategy (unwrap! (get-strategy strategy-id) ERR_STRATEGY_NOT_FOUND))
      (current-block (get-block-height))
    )
    (asserts! (is-eq tx-sender (get owner strategy)) ERR_NOT_AUTHORIZED)
    (asserts! (not (get is-active strategy)) ERR_STRATEGY_ACTIVE)
    (asserts! (>= new-amount (var-get min-execution-amount)) ERR_INVALID_AMOUNT)
    (asserts! (> new-frequency u0) ERR_INVALID_FREQUENCY)
    (asserts! (<= new-max-slippage (var-get max-slippage-allowed)) ERR_SLIPPAGE_TOO_HIGH)
    
    (map-set dca-strategies
      { strategy-id: strategy-id }
      (merge strategy {
        amount-per-execution: new-amount,
        frequency: new-frequency,
        max-slippage: new-max-slippage,
        next-execution: (+ current-block new-frequency)
      })
    )
    
    (ok true)
  )
)

;; Cancel DCA strategy and refund remaining balance
(define-public (cancel-strategy (strategy-id uint))
  (let
    (
      (strategy (unwrap! (get-strategy strategy-id) ERR_STRATEGY_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner strategy)) ERR_NOT_AUTHORIZED)
    
    ;; Mark strategy as inactive
    (map-set dca-strategies
      { strategy-id: strategy-id }
      (merge strategy { is-active: false })
    )
    
    (ok true)
  )
)

;; Admin functions

;; Add supported token
(define-public (add-supported-token 
  (token principal) 
  (decimals uint) 
  (price-feed (optional principal)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    (map-set supported-tokens
      { token: token }
      {
        is-supported: true,
        decimals: decimals,
        price-feed: price-feed
      }
    )
    
    (ok true)
  )
)

;; Add token pair for trading
(define-public (add-token-pair
  (token-in principal)
  (token-out principal)
  (dex-contract principal)
  (fee-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    (map-set token-pairs
      { token-in: token-in, token-out: token-out }
      {
        is-active: true,
        dex-contract: dex-contract,
        fee-rate: fee-rate
      }
    )
    
    (ok true)
  )
)

;; Update price feed
(define-public (update-price-feed
  (token principal)
  (price uint)
  (oracle principal))
  (let
    (
      (current-block (get-block-height))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    (map-set price-feeds
      { token: token }
      {
        price: price,
        last-update: current-block,
        oracle: oracle
      }
    )
    
    (ok true)
  )
)

;; Set platform fee rate
(define-public (set-platform-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-rate u500) (err u111)) ;; Max 5%
    
    (var-set platform-fee-rate new-rate)
    (ok true)
  )
)

;; Emergency pause/unpause contract
(define-public (toggle-contract-pause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    (var-set contract-paused (not (var-get contract-paused)))
    (ok (var-get contract-paused))
  )
)

;; Batch execute multiple strategies (for automation)
(define-public (batch-execute-strategies (strategy-ids (list 20 uint)))
  (let
    (
      (results (map execute-dca-strategy strategy-ids))
    )
    (ok results)
  )
)