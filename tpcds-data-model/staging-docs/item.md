# staging.item — Product Catalogue

**Rows:** 102,000 | **Source:** `raw.item`

The full product catalogue with all 22 TPC-DS columns. The marts layer
promotes a simplified 18-column version as `marts.dim_item`. Use staging
when you need `i_item_desc`, `i_formulation`, or `i_manager_id`.

## Columns

| Column | Type | Description |
|--------|------|-------------|
| `i_item_sk` | INTEGER | Surrogate key. Referenced in all sales, returns, and inventory tables. |
| `i_item_id` | TEXT | Natural key. 16-char source system ID. Same across SCD Type 2 versions. |
| `i_rec_start_date` | DATE | SCD Type 2 effective start date. |
| `i_rec_end_date` | DATE | SCD Type 2 end date. NULL = currently active version. |
| `i_item_desc` | TEXT | Long-form product description. **Not in marts.** |
| `i_current_price` | NUMERIC | Retail price for this version of the item. |
| `i_wholesale_cost` | NUMERIC | Retailer's cost price. |
| `i_brand_id` | INTEGER | Numeric brand identifier. |
| `i_brand` | TEXT | Brand name. |
| `i_class_id` | INTEGER | Numeric class identifier. |
| `i_class` | TEXT | Product class within the category. |
| `i_category_id` | INTEGER | Numeric category identifier. |
| `i_category` | TEXT | Top-level product category. |
| `i_manufact_id` | INTEGER | Numeric manufacturer identifier. |
| `i_manufact` | TEXT | Manufacturer name. |
| `i_size` | TEXT | Size label. |
| `i_formulation` | TEXT | Product formulation or composition. **Not in marts.** |
| `i_color` | TEXT | Colour description. |
| `i_units` | TEXT | Unit of measure. |
| `i_container` | TEXT | Packaging type. |
| `i_manager_id` | INTEGER | ID of the category manager responsible for this item. **Not in marts.** |
| `i_product_name` | TEXT | Full product name. |

## Notes
- `i_item_desc` and `i_formulation` are long text fields not included in marts — query staging when you need full descriptions.
- `i_manager_id` can be used to group items by their category manager.
- SCD Type 2: the same `i_item_id` can have multiple rows with different prices — `i_item_sk` uniquely identifies each version.
