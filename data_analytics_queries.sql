WITH latest_decimals AS (
    SELECT 
        mint,
        FIRST_VALUE(decimal) OVER (PARTITION BY mint ORDER BY block_timestamp DESC) AS decimal
    FROM solana.defi.fact_token_mint_actions
    WHERE decimal IS NOT NULL
),

token_decimals AS (
    SELECT DISTINCT 
        mint,
        CASE 
            WHEN decimal BETWEEN 0 AND 18 THEN decimal
            ELSE 6
        END AS decimal
    FROM latest_decimals

    UNION ALL

    -- Default well-known token decimals as fallback
    SELECT 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v', 6  -- USDC
    UNION ALL SELECT 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB', 6  -- USDT
    UNION ALL SELECT 'So11111111111111111111111111111111111111112', 9  -- SOL
    UNION ALL SELECT 'mSoLzYCxHdYgdzU16g5QSh3i5K3z3KZK7ytfqcJm7So', 9  -- mSOL
    UNION ALL SELECT '7dHbWXmci3dT8UFYWYZweBLXgycu7Y3iL6trKn1Y7ARj', 6  -- stUSDC
),

lending_actions AS (
    SELECT 
        fdi.block_timestamp,
        fdi.tx_id,
        fdi.event_type,
        TRY_PARSE_JSON(fdi.decoded_instruction:args):amount::number AS raw_amount,
        fdi.decoded_instruction:accounts[0]:pubkey AS account_pubkey,
        fdi.decoded_instruction:accounts[1]:pubkey AS mint_address,
        COALESCE(td.decimal, 6) AS token_decimals
    FROM solana.core.fact_decoded_instructions fdi
    LEFT JOIN token_decimals td
        ON td.mint = fdi.decoded_instruction:accounts[1]:pubkey
    WHERE fdi.program_id = 'MFv2hWf31Z9kbCa1snEPYctwafyhdvnV7FZnsebVacA'
      AND fdi.event_type IN (
          'lendingAccountBorrow',
          'lendingAccountRepay',
          'lendingAccountDeposit',
          'lendingAccountWithdraw'
      )
),

daily_metrics AS (
    SELECT 
        DATE_TRUNC('day', block_timestamp) AS date,
        
        -- Volume metrics
        SUM(CASE WHEN event_type = 'lendingAccountBorrow' THEN raw_amount / POWER(10, token_decimals) ELSE 0 END) AS daily_borrow_volume,
        SUM(CASE WHEN event_type = 'lendingAccountRepay' THEN raw_amount / POWER(10, token_decimals) ELSE 0 END) AS daily_repay_volume,
        SUM(CASE WHEN event_type = 'lendingAccountDeposit' THEN raw_amount / POWER(10, token_decimals) ELSE 0 END) AS daily_deposit_volume,
        SUM(CASE WHEN event_type = 'lendingAccountWithdraw' THEN -raw_amount / POWER(10, token_decimals) ELSE 0 END) AS daily_withdraw_volume,
        
        -- Protocol fees (assuming 0.1% on borrow volume as it is dynamic and depends on market value and banks)
        SUM(CASE WHEN event_type = 'lendingAccountBorrow' THEN ABS(raw_amount / POWER(10, token_decimals)) * 0.001 ELSE 0 END) AS daily_protocol_fees,
        
        -- Transaction activity
        COUNT(DISTINCT CASE WHEN event_type = 'lendingAccountBorrow' THEN tx_id END) AS borrow_tx_count,
        COUNT(DISTINCT CASE WHEN event_type = 'lendingAccountDeposit' THEN tx_id END) AS deposit_tx_count
    FROM lending_actions
    GROUP BY 1
),

cumulative_metrics AS (
    SELECT 
        date,
        daily_borrow_volume,
        daily_repay_volume,
        daily_deposit_volume,
        daily_withdraw_volume,
        daily_protocol_fees,
        
        -- Cumulative logic
        ABS(SUM(daily_borrow_volume - daily_repay_volume) OVER (ORDER BY date)) AS outstanding_borrows,
        ABS(SUM(daily_deposit_volume + daily_withdraw_volume) OVER (ORDER BY date)) AS total_value_locked,
        SUM(daily_protocol_fees) OVER (ORDER BY date) AS cumulative_fees,
        
        -- Revenue assumption
        daily_protocol_fees AS daily_revenue,
        SUM(daily_protocol_fees) OVER (ORDER BY date) AS cumulative_revenue,
        
        borrow_tx_count,
        deposit_tx_count
    FROM daily_metrics
)

SELECT 
    date,

    -- TVL
    total_value_locked,

    -- Borrow metrics
    daily_borrow_volume,
    daily_repay_volume,
    outstanding_borrows,

    -- Deposit metrics
    daily_deposit_volume,
    ABS(daily_withdraw_volume) AS daily_withdraw_volume,
    total_value_locked AS outstanding_deposits,

    -- Protocol revenue
    daily_protocol_fees,
    cumulative_fees,
    daily_revenue,
    cumulative_revenue,

    -- Activity
    borrow_tx_count,
    deposit_tx_count

FROM cumulative_metrics
WHERE date >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY date DESC;
