WITH latest_pool_metadata AS (
    -- Get the most recent ticker for each pool
    SELECT DISTINCT ON (pool_id) 
        pool_id, 
        ticker_name
    FROM off_chain_pool_data
    ORDER BY pool_id, id DESC
),
active_delegations AS (
    -- Map every active stake address to its current pool
    SELECT DISTINCT ON (d.addr_id)
        d.addr_id,
        d.pool_hash_id
    FROM delegation d
    WHERE NOT EXISTS (
        SELECT 1 FROM stake_deregistration sdr
        WHERE sdr.addr_id = d.addr_id
        AND sdr.tx_id > d.tx_id
    )
    ORDER BY d.addr_id, d.tx_id DESC
),
drep_delegations AS (
    -- Map every active stake address to its current DRep choice
    SELECT DISTINCT ON (dv.addr_id)
        dv.addr_id,
        dh.view AS drep_view
    FROM delegation_vote dv
    LEFT JOIN drep_hash dh ON dv.drep_hash_id = dh.id
    ORDER BY dv.addr_id, dv.tx_id DESC, dv.cert_index DESC
)
SELECT 
    ph.view AS pool_id,
    COALESCE(lpm.ticker_name, 'No Ticker') AS ticker,
    COUNT(ad.addr_id) AS total_delegator_count,
    -- Break down counts into columns
    COUNT(ad.addr_id) FILTER (WHERE dd.drep_view IS NULL) AS no_drep_delegated,
    COUNT(ad.addr_id) FILTER (WHERE dd.drep_view = 'drep_always_abstain') AS always_abstain,
    COUNT(ad.addr_id) FILTER (WHERE dd.drep_view = 'drep_always_no_confidence') AS always_no_confidence,
    COUNT(ad.addr_id) FILTER (WHERE dd.drep_view NOT IN ('drep_always_abstain', 'drep_always_no_confidence')) AS other_drep
FROM active_delegations ad
JOIN pool_hash ph ON ad.pool_hash_id = ph.id
LEFT JOIN latest_pool_metadata lpm ON ph.id = lpm.pool_id
LEFT JOIN drep_delegations dd ON ad.addr_id = dd.addr_id
-- Filter out retired pools to keep the list relevant
WHERE NOT EXISTS (
    SELECT 1 FROM pool_retire pr 
    WHERE pr.hash_id = ph.id 
    AND pr.retiring_epoch <= (SELECT max(no) FROM epoch)
)
GROUP BY ph.view, lpm.ticker_name
ORDER BY total_delegator_count DESC;
