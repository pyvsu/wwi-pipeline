## After batch 1 (initial load)

| dim_customer rows | current rows | fact_order rows | fact_sale rows |
|---|---|---|---|
| 664 | 664 | 231412 | 228265 |

Customers 1-8, all versions:

| customer_key | customer_id | category | buying_group | effective_from | effective_to | is_current |
|---|---|---|---|---|---|---|
| 1 | 1 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |
| 2 | 2 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |
| 3 | 3 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |
| 4 | 4 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |
| 5 | 5 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |
| 6 | 6 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |
| 7 | 7 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |
| 8 | 8 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |

fact_sale lines per customer version (customers 1-4):

| customer_id | customer_key | category | effective_from | sale_lines | amount_incl_tax |
|---|---|---|---|---|---|
| 1 | 1 | Novelty Shop | 1900-01-01 | 406 | 351298.08 |
| 2 | 2 | Novelty Shop | 1900-01-01 | 361 | 263403.06 |
| 3 | 3 | Novelty Shop | 1900-01-01 | 437 | 353580.24 |
| 4 | 4 | Novelty Shop | 1900-01-01 | 316 | 343935.50 |

## After batch 2 (changes effective 2015-01-01)

| dim_customer rows | current rows | fact_order rows | fact_sale rows |
|---|---|---|---|
| 668 | 664 | 231412 | 228265 |

Customers 1-8, all versions:

| customer_key | customer_id | category | buying_group | effective_from | effective_to | is_current |
|---|---|---|---|---|---|---|
| 1 | 1 | Novelty Shop | Tailspin Toys | 1900-01-01 | 2014-12-31 | False |
| 664 | 1 | Supermarket | Tailspin Toys | 2015-01-01 | 9999-12-31 | True |
| 2 | 2 | Novelty Shop | Tailspin Toys | 1900-01-01 | 2014-12-31 | False |
| 665 | 2 | Computer Store | Tailspin Toys | 2015-01-01 | 9999-12-31 | True |
| 3 | 3 | Novelty Shop | Tailspin Toys | 1900-01-01 | 2014-12-31 | False |
| 666 | 3 | Gift Store | Tailspin Toys | 2015-01-01 | 9999-12-31 | True |
| 4 | 4 | Novelty Shop | Tailspin Toys | 1900-01-01 | 2014-12-31 | False |
| 667 | 4 | Novelty Shop | Wingtip Toys | 2015-01-01 | 9999-12-31 | True |
| 5 | 5 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |
| 6 | 6 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |
| 7 | 7 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |
| 8 | 8 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |

fact_sale lines per customer version (customers 1-4):

| customer_id | customer_key | category | effective_from | sale_lines | amount_incl_tax |
|---|---|---|---|---|---|
| 1 | 1 | Novelty Shop | 1900-01-01 | 238 | 207302.59 |
| 1 | 664 | Supermarket | 2015-01-01 | 168 | 143995.49 |
| 2 | 2 | Novelty Shop | 1900-01-01 | 188 | 138701.57 |
| 2 | 665 | Computer Store | 2015-01-01 | 173 | 124701.49 |
| 3 | 3 | Novelty Shop | 1900-01-01 | 272 | 227868.43 |
| 3 | 666 | Gift Store | 2015-01-01 | 165 | 125711.81 |
| 4 | 4 | Novelty Shop | 1900-01-01 | 188 | 207737.17 |
| 4 | 667 | Novelty Shop | 2015-01-01 | 128 | 136198.33 |

## After batch 2 re-run (no change expected)

| dim_customer rows | current rows | fact_order rows | fact_sale rows |
|---|---|---|---|
| 668 | 664 | 231412 | 228265 |

Customers 1-8, all versions:

| customer_key | customer_id | category | buying_group | effective_from | effective_to | is_current |
|---|---|---|---|---|---|---|
| 1 | 1 | Novelty Shop | Tailspin Toys | 1900-01-01 | 2014-12-31 | False |
| 664 | 1 | Supermarket | Tailspin Toys | 2015-01-01 | 9999-12-31 | True |
| 2 | 2 | Novelty Shop | Tailspin Toys | 1900-01-01 | 2014-12-31 | False |
| 665 | 2 | Computer Store | Tailspin Toys | 2015-01-01 | 9999-12-31 | True |
| 3 | 3 | Novelty Shop | Tailspin Toys | 1900-01-01 | 2014-12-31 | False |
| 666 | 3 | Gift Store | Tailspin Toys | 2015-01-01 | 9999-12-31 | True |
| 4 | 4 | Novelty Shop | Tailspin Toys | 1900-01-01 | 2014-12-31 | False |
| 667 | 4 | Novelty Shop | Wingtip Toys | 2015-01-01 | 9999-12-31 | True |
| 5 | 5 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |
| 6 | 6 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |
| 7 | 7 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |
| 8 | 8 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |

fact_sale lines per customer version (customers 1-4):

| customer_id | customer_key | category | effective_from | sale_lines | amount_incl_tax |
|---|---|---|---|---|---|
| 1 | 1 | Novelty Shop | 1900-01-01 | 238 | 207302.59 |
| 1 | 664 | Supermarket | 2015-01-01 | 168 | 143995.49 |
| 2 | 2 | Novelty Shop | 1900-01-01 | 188 | 138701.57 |
| 2 | 665 | Computer Store | 2015-01-01 | 173 | 124701.49 |
| 3 | 3 | Novelty Shop | 1900-01-01 | 272 | 227868.43 |
| 3 | 666 | Gift Store | 2015-01-01 | 165 | 125711.81 |
| 4 | 4 | Novelty Shop | 1900-01-01 | 188 | 207737.17 |
| 4 | 667 | Novelty Shop | 2015-01-01 | 128 | 136198.33 |

