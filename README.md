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
