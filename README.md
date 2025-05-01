# Artemis-Analytics-Data-Analytics-Bounty

## Data Sources Used

- solana.core.fact_decoded_instructions: Base table for decoded on-chain instructions.
- solana.defi.fact_token_mint_actions: Used for extracting the most accurate token decimals.
- Custom logic to normalize decimals and handle known token mint addresses like USDC, USDT, and SOL.



## Instructions for Running the Query

- Open Flipside Crypto SQL Editor

- Select Solana as your blockchain.

- Paste the query and run it.

- Export results to CSV or visualize directly.



## Assumptions Made
- Fee Rate: Protocol fee assumed to be 0.1% of borrow volume; actual fee structure might vary.

- Token Decimals: Missing or null decimals are defaulted based on known tokens (e.g., USDC = 6).

- Outstanding Metrics: Calculated using cumulative differences between related actions.

## Explanation of each metric calculation

For Indepth calculation check https://docs.google.com/document/d/18KrAqZ4jK_w517-D2ftXMkTTQ46LokWmAKK6hOz1NeE/edit?usp=sharing

### Total Value Locked (TVL)

Definition: The net total value of assets currently deposited in the protocol.
Calculation:
Cumulative deposits minus withdrawals over time:

`TVL = ABS(SUM(daily_deposit_volume + daily_withdraw_volume))`

### Daily Borrow Volume

Definition: Total amount borrowed from the lending protocol each day.
Calculation:

`Sum of lendingAccountBorrow event amounts normalized by token decimals.`

### Daily Repay Volume

Definition: Total amount repaid to the protocol by borrowers each day.

Calculation:

`Sum of lendingAccountRepay event amounts normalized by token decimals.`

### Outstanding Borrows

Definition: The net cumulative amount currently borrowed (borrowed minus repaid).

Calculation:

`Outstanding Borrows = ABS(SUM(daily_borrow_volume - daily_repay_volume))`

### Outstanding Deposits

Definition: Total deposits minus withdrawals, representing net capital supplied to the protocol.

Calculation:

`Outstanding Deposits = TVL`

### Daily Deposit Volume

Definition: Amount deposited into the lending protocol daily.

Calculation:

`Sum of lendingAccountDeposit event values (normalized by token decimals).`

### Daily Withdraw Volume

Definition: Amount withdrawn from the protocol daily.

Calculation:

`Sum of lendingAccountWithdraw event values (normalized and treated as negative).`

### Protocol Fees & Revenue

Definition: The fees earned by the protocol from borrow transactions, representing revenue.

Assumption: A 0.1% fee is applied on all borrow volume.

Calculation:

```
Daily Protocol Fees = daily_borrow_volume * 0.001
Cumulative Revenue = SUM(daily_protocol_fees)
```

### Daily Borrow and Deposit Transactions

Definition: Count of unique transactions per day for borrowing and depositing.

Calculation:

```
borrow_tx_count = COUNT(DISTINCT tx_id) WHERE event_type = 'lendingAccountBorrow'
deposit_tx_count = COUNT(DISTINCT tx_id) WHERE event_type = 'lendingAccountDeposit'
```

### Daily Deposit and Repay Transactions
Definition: Count of unique deposit and repay transactions per day.
Usage: Reflects daily user activity and engagement.
Calculation:
Same as above, using lendingAccountRepay and lendingAccountDeposit events.
