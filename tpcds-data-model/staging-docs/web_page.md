# staging.web_page — Individual Web Pages

**Rows:** 200 | **Source:** `raw.web_page`

Individual pages within a web site. Referenced by `web_sales` and `web_returns`
via `*_web_page_sk`. Useful for analysing which product pages generate the most orders.

## Columns

| Column | Type | Description |
|--------|------|-------------|
| `wp_web_page_sk` | INTEGER | Surrogate key. Referenced as `ws_web_page_sk`, `wr_web_page_sk`. |
| `wp_web_page_id` | CHAR(16) | Natural key. |
| `wp_rec_start_date` | DATE | SCD Type 2 effective start date. |
| `wp_rec_end_date` | DATE | SCD Type 2 end date. NULL = active. |
| `wp_creation_date_sk` | INTEGER | FK → `date_dim`. Date the page was created. |
| `wp_access_date_sk` | INTEGER | FK → `date_dim`. Date the page was last accessed. |
| `wp_autogen_flag` | CHAR(1) | `Y` = auto-generated page, `N` = manually created. |
| `wp_customer_sk` | INTEGER | FK → `customer`. Customer who owns/manages this page (e.g. a seller). |
| `wp_url` | VARCHAR | Page URL. |
| `wp_type` | CHAR(50) | Page type (e.g. `review`, `welcome`, `dynamic`). |
| `wp_char_count` | INTEGER | Total character count of the page content. |
| `wp_link_count` | INTEGER | Number of outbound links. |
| `wp_image_count` | INTEGER | Number of images on the page. |
| `wp_max_ad_count` | INTEGER | Maximum number of ads displayed. |

## Sample Query
```sql
-- Revenue by page type
SELECT wp.wp_type, SUM(ws_net_paid) AS revenue
FROM staging.web_sales ws
JOIN staging.web_page wp ON ws.ws_web_page_sk = wp.wp_web_page_sk
GROUP BY wp.wp_type
ORDER BY revenue DESC;
```
