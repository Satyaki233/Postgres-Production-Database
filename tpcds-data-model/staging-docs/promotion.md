# staging.promotion — Marketing Promotions

**Rows:** 500 | **Source:** `raw.promotion`

Promotion records with full 19-column TPC-DS spec. The marts layer promotes
a 15-column version as `marts.dim_promotion`. Use staging when you need
`p_start_date_sk`, `p_end_date_sk`, `p_item_sk`, or `p_channel_details`.

## Columns

| Column | Type | Description |
|--------|------|-------------|
| `p_promo_sk` | INTEGER | Surrogate key. Referenced as `ss_promo_sk`, `ws_promo_sk`, `cs_promo_sk`. |
| `p_promo_id` | CHAR(16) | Natural key. |
| `p_start_date_sk` | INTEGER | FK → `date_dim`. Promotion start date. **Not in marts.** |
| `p_end_date_sk` | INTEGER | FK → `date_dim`. Promotion end date. **Not in marts.** |
| `p_item_sk` | INTEGER | FK → `item`. Item this promotion was tied to. **Not in marts.** |
| `p_cost` | NUMERIC | Total cost of running this promotion. |
| `p_response_target` | INTEGER | Target response rate (1 = all customers). |
| `p_promo_name` | CHAR(50) | Promotion name. |
| `p_channel_dmail` | CHAR(1) | `Y` = direct mail channel. |
| `p_channel_email` | CHAR(1) | `Y` = email channel. |
| `p_channel_catalog` | CHAR(1) | `Y` = catalog channel. |
| `p_channel_tv` | CHAR(1) | `Y` = TV channel. |
| `p_channel_radio` | CHAR(1) | `Y` = radio channel. |
| `p_channel_press` | CHAR(1) | `Y` = press / print channel. |
| `p_channel_event` | CHAR(1) | `Y` = in-store event channel. |
| `p_channel_demo` | CHAR(1) | `Y` = product demo channel. |
| `p_channel_details` | VARCHAR | Free-text notes on channel usage. **Not in marts.** |
| `p_purpose` | CHAR(15) | Business goal: `Unknown`, `Cross-Sell`, `Retention`, `Awareness`. |
| `p_discount_active` | CHAR(1) | `Y` = price discount was active. |

## Notes
- Use staging to check if a promotion was active on a specific date: join `p_start_date_sk` and `p_end_date_sk` to `date_dim`.
- `p_item_sk` links a promotion to the specific item it was designed for — not all promotions are item-specific.
