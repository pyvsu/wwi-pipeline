-- =====================================================
-- 03_bridge_stock_item_group.sql : load dw.bridge_stock_item_group
-- One row per item-category link. Run AFTER dim_stock_item.
-- Never add category totals together: categories overlap.
-- =====================================================

BEGIN TRANSACTION;

DELETE FROM dw.bridge_stock_item_group;

INSERT INTO dw.bridge_stock_item_group (
    stock_item_key, stock_group_id, stock_group_name
)
SELECT
    d.stock_item_key,
    g.stock_group_id,
    g.stock_group_name
FROM oltp.stock_item_stock_groups AS link
JOIN dw.dim_stock_item AS d
  ON d.stock_item_id = link.stock_item_id
JOIN oltp.stock_groups AS g
  ON g.stock_group_id = link.stock_group_id;

COMMIT;
