--========================================================================
-- Customer Report
--========================================================================

CREATE VIEW gold.report_customers AS
WITH base_query AS (
/*
------------------------------------------------------
1) Base Query: Retrieve core columns from tables
------------------------------------------------------
*/
SELECT 
f.order_number,
f.product_key,
f.order_date,
f.sales_amount,
f.quantity,
c.customer_key,
c.customer_number,
CONCAT(c.first_name, ' ',c.last_name) as customer_name,
DATEDIFF(year, c.birthdate,GETDATE()) as age
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON c.customer_key = f.customer_key
WHERE order_date IS NOT NULL
)

, customer_aggregation AS(
/*
--------------------------------------------------------------------
2) Customer Aggregations: Summarize key metric at the customer level
--------------------------------------------------------------------
*/
SELECT 
customer_key,
customer_number,
customer_name,
age,
COUNT(DISTINCT order_number) as total_orders,
SUM(sales_amount)as total_sales,
SUM(quantity) as total_quantity,
COUNT(DISTINCT product_key) as total_products,
MAX(order_date) as last_order_date,
DATEDIFF(month,MIN(order_date),MAX(order_date)) as lifespan
FROM base_query
GROUP BY 
customer_key,
customer_number,
customer_name,
age)

SELECT 
customer_key,
customer_number,
customer_name,
age,
CASE WHEN age <20  THEN 'Under 20'
		 WHEN age BETWEEN 20 AND 29 THEN '20-29'
		  WHEN age BETWEEN 30 AND 39 THEN '30-39'
		   WHEN age BETWEEN 40 AND 49 THEN '40-49'
		 ELSE '50 and above'
		 END age_group,
CASE WHEN lifespan >=12 AND total_sales > 5000 THEN 'VIP'
		 WHEN lifespan >=12 AND total_sales <=5000 THEN 'Regular'
		 ELSE 'New Customer'
		 END customer_segments,
total_orders,
total_sales,
total_quantity,
total_products,
last_order_date,
-- KPI (1): Recency
DATEDIFF(month,last_order_date, GETDATE()) as recency,
lifespan,
-- KPI (2): average order value (AVO)
CASE WHEN total_orders = 0 THEN 0
	ELSE total_sales /total_orders  
END as avg_order_value,

-- KPI(3): Average monthly spend
CASE WHEN lifespan = 0 THEN total_sales
ELSE total_sales / lifespan 
END as avg_monthly_spend
FROM customer_aggregation
