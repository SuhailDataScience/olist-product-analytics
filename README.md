# Olist orders, delivery and repeat customers

I wanted to know where an online marketplace loses orders and customers, and whether anything in the data explains it. This project uses the public Olist Brazilian e-commerce dataset. The analysis is in MySQL, and the results feed a three-page Power BI dashboard.

The questions, in order: how many orders make it from purchase to delivery, how long delivery takes, how many customers ever buy a second time, and whether a slow first delivery or a bad first review has anything to do with that.

Dataset: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce/data

The dataset itself is not included in this repository and keeps its own licence. The code here is under the MIT licence.

## Scope

I kept orders placed between 1 January 2017 and 31 August 2018, which is 99,092 orders. The few orders outside that range are too sparse to say anything about.

Tables used: orders, customers, order items, products and reviews. I used MySQL 8 (the queries rely on CTEs and window functions) and Power BI Desktop.

## How the data was filtered and defined

Most of the analysis uses what I call valid orders. Of the 99,092 orders in the window, 96,211 have the status delivered. I kept 95,498 of them. The other 713 (0.74%) have timestamps that contradict each other, for example an order approved before it was placed, or delivered before it reached the carrier. The order funnel and the status breakdown use all 99,092. Everything else (delivery time, reviews, retention, revenue) uses the 95,498.

A few definitions that matter for the numbers:

- A customer is a `customer_unique_id`. The plain `customer_id` changes with every order, so using it makes every order look like a new customer.
- Revenue is the sum of item price. Freight is left out. The currency is Brazilian reais (R$).
- A customer "came back" if they placed an order at a later time than their first. Orders placed at the same moment do not count. 781 customers placed several orders at the same moment, which probably means one checkout split into separate orders, but I could not confirm that from the data.
- Where an order has more than one review, the view `v_reviews_clean` keeps the latest one.
- Return within 90 days is only measured for customers whose first order was before 1 June 2018, so everyone had a full 90 days. That leaves 74,772 customers in 17 monthly cohorts.
- When a customer's first purchase contained several orders, I used the longest delivery time and the lowest review score among them.

## What I found

### Orders and delivery

97.09% of orders placed reached delivery (96,204 of 99,092). The status field gives a slightly different count, 2,881 orders that are not marked delivered, and the difference is delivered orders with missing timestamps. Most of those 2,881 are 1,097 orders stuck at "shipped", 602 marked unavailable and 580 canceled. I cannot tell whether the shipped ones were lost or simply never updated. They are spread across the whole period and not bunched at the end, so they are not just orders that were still in progress when the data was taken.

Delivery takes 12.5 days on average from purchase. Roughly half a day is approval, 2.7 days is waiting for the carrier to collect, and 9.3 days is the carrier getting it to the customer. About 71% of orders arrive within two weeks, and 12% (11,500 orders) take more than 21 days.

By month, delivery sat at 11 to 12 days for most of 2017, rose to 14 to 17 days between November 2017 and March 2018 (16 to 25% of orders over 21 days), and was back at 11.5 days by April 2018. The June to August 2018 figures (9.2, 9.0 and 7.7 days) look too good. Orders that were still undelivered when the data ended are not in those averages.

Review scores fall as delivery gets slower. The average score is 4.41 for orders delivered within a week and 2.19 for orders that took more than 30 days. The share of 1 and 2 star reviews goes from 7.5% to 64.9%. The decline is gentle up to three weeks and steep after that.

### Customers

Repeat purchases are rare. 2.99% of the 92,422 customers placed more than one order, and 2.14% (1,980) bought again at a later time. In any single month after the first, under 1% of a cohort ordered again.

Of the 1,980 who came back, 30% did so within a month, 55% within 90 days and 24% after more than 180 days. That last share is understated, because recent customers have not had time to come back yet.

Among customers with a full 90 days, 1.29% returned within that time (966 of 74,772). By cohort it ranges from 0.84% to 1.80% with no clear trend.

Customers whose first order took more than 30 days returned within 90 days at a rate of 0.83%, compared with 1.50% for those who received it within a week. Customers who gave their first order 1 or 2 stars returned at 1.02%, against 1.36% for 4 or 5 stars. Both gaps point the same way, and both are small. If the whole delivery gap were caused by slow delivery, closing it would bring back about 60 more customers out of 74,772. Return rates are low whatever the first experience was, and nothing I looked at explains why.

### Revenue

Revenue came to R$13.09 million on the 95,498 orders, an average of R$137.11 per order. It grew through 2017, peaked in November 2017 at R$987k, and has stayed between R$725k and R$987k a month since, with order volume following the same pattern.

São Paulo accounts for 38.3% of revenue, and São Paulo, Rio de Janeiro and Minas Gerais together for 63.4%. The five biggest categories (health_beauty, watches_gifts, bed_bath_table, sports_leisure and computers_accessories) make up 39.9%, and 18 of the 72 categories reach about 81%.

Returning customers are 2.14% of customers and 4.10% of revenue. Each brought in about R$271, against R$139 for a one-time customer. They earn more because they order more (about 2.15 orders each, against 1.01), not because their orders are bigger: their average order is R$126 against R$138.

## Limits

- Everything here shows things moving together. None of it shows that one thing caused another.
- Recent customers and recent months are incomplete. The latest cohorts have had little time to come back, and the latest delivery averages leave out undelivered orders.
- Some groups are small. January 2017 has 747 orders, several states have only a few dozen customers, and the 527 customers who left no review on their first order include only 4 who returned. I did not read anything into those.
- Revenue is item price only. Customer counts by state add up to 92,458, not 92,422, because 36 customers have orders under two states.
- In the category table an order with items from two categories is counted in both, so order counts there do not add up to 95,498. Revenue does.
- This is one marketplace over 20 months, so I would not generalise from it.

## Checks

The totals agree across queries: 95,498 valid orders, 92,422 customers and R$13,093,865.52 in revenue appear in every table that should contain them. The 12.5-day delivery average equals the sum of the three stage averages (0.49 + 2.70 + 9.31 days). My first repeat-customer figure, from the data audit with looser filters, was 3.00% (2,801 customers), and it took a separate query to see that the difference to 2.14% comes mostly from orders placed at the same moment.

## Repository

- `olist-product-analytics-sql/`: the five SQL files
  - `01_data_audit.sql`: checks on the raw tables, and the cleaned reviews view.
  - `02_funnel.sql`: order funnel, status breakdown, time spent in each stage, delivery time distribution and the monthly trend.
  - `03_cohort_retention.sql`: cohorts, retention by month, repeat customers, time to a second purchase and 90-day returns.
  - `04_revenue.sql`: revenue by month, by customer type, by category and by state.
  - `05_drop_off_drivers.sql`: delivery time against reviews, and first delivery and first review against returning.
- `Csv-Dashboard/`: the query results as CSV files, which the dashboard reads.
- `olist_dashboard.pbix`: the Power BI dashboard.

## Running it

1. Load the Olist CSVs into a MySQL database. I used a local one called `e_commerce_store`, with tables named `orders`, `customers`, `orders_items`, `product` and `order_reviews`. If yours are named differently, change the names in the queries.
2. Run `01_data_audit.sql` first, since it creates the `v_reviews_clean` view that file 05 uses.
3. Run the other files in order. Each query has a comment saying what it answers.
4. The dashboard reads the CSVs in `Csv-Dashboard/`. If you open it from a different folder, update the data source path under Transform data, then Data source settings.

## Dashboard

Three pages, built in Power BI from the query results. Orange marks something that looks like a problem: slow deliveries, low scores, canceled or unavailable orders, and the funnel stage with the biggest drop.

1. Orders and delivery: the funnel, non-delivered orders by status, where the 12.5 days go, delivery time distribution, monthly delivery time and low scores by delivery time.
2. Customers and retention: a cohort heatmap, days to a second purchase, 90-day returns by cohort, and by first delivery time and first review.
3. Revenue: monthly revenue, top categories, top states, and returning customers' share of customers against their share of revenue.

Orders and delivery:

<img width="682" height="383" alt="Orders and delivery page of the dashboard" src="https://github.com/user-attachments/assets/172aeeff-39c6-48b6-bf29-49101f74f215" />

Customers and retention:

<img width="673" height="379" alt="Customers and retention page of the dashboard" src="https://github.com/user-attachments/assets/f4c92b86-bfab-438e-be0f-8b317506d8f5" />

Revenue:

<img width="671" height="377" alt="Revenue page of the dashboard" src="https://github.com/user-attachments/assets/33508801-7800-4747-b736-f668de629bf8" />
