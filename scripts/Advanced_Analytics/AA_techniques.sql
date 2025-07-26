--ADVANCED ANALYTICS
-- (1). Change Over Time (Trends) 
-- # Aggregate a [Measure] By a [Date Dimension]

SELECT 
YEAR(order_date) as order_year,
SUM(sales_amount) as total_sales,
--Calcualte total # of customers each year
COUNT(DISTINCT	customer_key) as total_customers,
--Summarize total # quantities sold 
SUM(quantity) as total_quantity
From gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY YEAR(order_date)


--(2). Cumulative Analysis

--Calculate the total sales per month 
--And the running total of sales over time 

SELECT
order_date,
total_sales,
--Window function
SUM(total_sales) OVER (ORDER BY order_date) AS running_total_sales, 
SUM(avg_price) OVER (ORDER BY order_date) AS _moving_average_price
FROM

(
SELECT 
DATETRUNC(MONTH,order_date) as order_date,
SUM(sales_amount) as total_sales,
AVG(price) as avg_price
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH,order_date)
--ORDER BY DATETRUNC(month,order_date)

) t

--(3). Performance Analysis 
-- Comparing [current value] >? [target value]
--Helps us to measure success and compare our performance 
--Find the difference [current measure] - [target measure]


/*
Analyze the yearly performance of products by comparing their sales to 
both the average sales performnce of the product and the previous year's sales
*/

WITH yearly_product_sales AS (
SELECT 
YEAR(f.order_date) as order_year,
p.product_name,
SUM(f.sales_amount) as current_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_product p
ON p.product_key = f.product_key
WHERE f.order_date IS NOT NULL
GROUP BY YEAR(f.order_date), p.product_name
)

SELECT 
order_year,
product_name,
current_sales,
--find average sales per product
AVG(current_sales) OVER (PARTITION BY product_name) as avg_sales,
--find the difference current sales- avg sales
current_sales - AVG(current_sales) OVER (PARTITION BY product_name) as diff_avg,
CASE  WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name)  > 0 THEN 'Above average'
	  WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name)  <0 THEN 'Below average'
	  ELSE 'Average'
	END avg_change,
	--get previous years sales value
LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) as prev_yr_sales,
-- find the difference of current sales -prev yr sales
current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) as diff_prev_yr,
--conditions
CASE  WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year)  > 0 THEN 'Increase'
	  WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year)  <0 THEN 'Decrease'
	  ELSE 'No change'
	END prev_yr_change
FROM yearly_product_sales
ORDER BY product_name, order_year

--(4). Part-to-whole Analysis 
-- analyze how 1 part performs compared to all 
-- allows us to understand which category has the greatest impact on the business 

--Task 1: Which category contributes the most to overall sales 
WITH category_sales AS( 
	SELECT 
	category,
	SUM(sales_amount) as total_sales
	FROM gold.fact_sales f
	LEFT JOIN gold.dim_product p
	ON p.product_key = f.product_key
	GROUP BY category
	)
SELECT 
category,
total_sales,
SUM(total_sales) OVER() overall_sales,
CONCAT(ROUND((CAST(total_sales AS FLOAT) / SUM(total_sales) OVER() ) *100,2), '%') AS percentage_of_total
from category_sales
order by total_sales desc


--(5). DATA SEGMENTATION

--Task: segment products into cost ranges and count how many products fall into each segment 

--We have 2 measures: Costs, and Total #Products
WITH product_segments as(
SELECT 
product_key,
product_name,
cost,
-- Segment cost into categories
CASE WHEN	cost <100 THEN 'Below 100'
	 WHEN cost BETWEEN 100 AND 500 THEN '100-500'
	 WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
	 ELSE 'Above 1000'
	 End as cost_range
FROM gold.dim_product
)
SELECT 
cost_range,
COUNT(product_key) as total_products
FROM product_segments
GROUP BY cost_range
ORDER BY total_products DESC

/*
TASK 2
	-Group customers into 3 segments based on their spending behaviour (Segments) Based on [months] [sales] [customers]
		--VIP: at least 12 months of history and spending more than $5,000
		--REGULAR: at least 12 months of history but spending $5,000 or less
		--NEW: lifespan less than 12 months
	-Find the total # of customers by each group (Final Aggregation)

	*Measures in this case: 
*/
-- CTE for finding the lifespan of each customer
WITH customer_spending AS (
SELECT 
c.customer_key,
SUM(f.sales_amount) as total_spending,
--find the lifespan of each customer
-- the first order and last order dates for each customer 
MIN(order_date) first_order,
MAX(order_date) last_order,
-- find out the lifespan of customer between their first order and last order
DATEDIFF(month,MIN(order_date),MAX(order_date)) as lifespan
from gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON c.customer_key = f.customer_key
GROUP BY c.customer_key
)

SELECT 
customer_segments,
COUNT(customer_key) as total_customers
FROM(
	--Subquerey for segmenting customers
	SELECT 
	customer_key,
	-- Start building the segments
	CASE WHEN lifespan >=12 AND total_spending > 5000 THEN 'VIP'
		 WHEN lifespan >=12 AND total_spending <=5000 THEN 'Regular'
		 ELSE 'New Customer'
		 END customer_segments
	 
	FROM customer_spending) t
GROUP BY customer_segments
ORDER BY total_customers DESC
