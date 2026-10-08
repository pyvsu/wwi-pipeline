# SCD2 demo, Stage 1 (dim_customer)

### BEFORE: after batch 1

rows=664  current=664  max_key=663

| key | id | category | buying group | from | to | current |
|---|---|---|---|---|---|---|
| 1 | 1 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |
| 2 | 2 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |
| 3 | 3 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |
| 4 | 4 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |
| 5 | 5 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |
| 6 | 6 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |
| 7 | 7 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |
| 8 | 8 | Novelty Shop | Tailspin Toys | 1900-01-01 | 9999-12-31 | True |

### AFTER: batch 2 (effective 2015-01-01)

rows=668  current=664  max_key=667

| key | id | category | buying group | from | to | current |
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

### AFTER: batch 2 run a second time (must be identical)

rows=668  current=664  max_key=667

| key | id | category | buying group | from | to | current |
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
