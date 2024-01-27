-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its
-- business in the APAC region.
SELECT
       DISTINCT  market 
FROM gdb023.dim_customer
WHERE customer = 'Atliq Exclusive' AND region = 'APAC';

-- 2. What is the percentage of unique product increase in 2021 vs. 2020? 
-- The final output contains these fields,
-- unique_products_2020
-- unique_products_2021
-- percentage_chg
WITH unique_products AS(
SELECT 
       COUNT(DISTINCT(CASE WHEN fiscal_year = 2020 THEN product_code END)) AS unique_products_2020,
       COUNT(DISTINCT(CASE WHEN fiscal_year = 2021 THEN product_code END)) AS unique_products_2021
       FROM gdb023.fact_sales_monthly 
)
SELECT 
        unique_products_2020,
        unique_products_2021,
        CONCAT(ROUND((unique_products_2021 - unique_products_2020)*100/unique_products_2020,2), '%') AS percentage_chg
FROM unique_products;

-- 3. Provide a report with all the unique product counts for each segment and
-- sort them in descending order of product counts. The final output contains 2 fields,
-- segment
-- product_count
SELECT 
      segment,
      COUNT(*) AS product_count
FROM gdb023.dim_product
GROUP BY segment;

-- 4. Follow-up: Which segment had the most increase in unique products in
-- 2021 vs 2020? The final output contains these fields,
-- segment
-- product_count_2020
-- product_count_2021
-- difference
WITH unique_products AS(
SELECT 
       p.segment,
       COUNT(DISTINCT(CASE WHEN s.fiscal_year = 2020 THEN s.product_code END)) AS product_count_2020,
       COUNT(DISTINCT(CASE WHEN s.fiscal_year = 2021 THEN s.product_code END)) AS product_count_2021
       FROM gdb023.fact_sales_monthly s JOIN gdb023.dim_product p
       ON s.product_code = p.product_code
       GROUP BY p.segment
)
SELECT 
      segment,
      product_count_2020,
      product_count_2021,
      (product_count_2021 - product_count_2020) AS difference
FROM unique_products
ORDER BY difference DESC;

-- 5. Get the products that have the highest and lowest manufacturing costs.
-- The final output should contain these fields,
-- product_code
-- product
-- manufacturing_cost

SELECT 
       p.product_code,
       p.product,
       CONCAT('$',ROUND(manufacturing_cost,2)) AS manufacturing_cost
FROM gdb023.fact_manufacturing_cost m JOIN gdb023.dim_product p 
ON m.product_code = p.product_code
WHERE manufacturing_cost = (SELECT MAX(manufacturing_cost) FROM gdb023.fact_manufacturing_cost) 
OR manufacturing_cost = (SELECT MIN(manufacturing_cost) FROM gdb023.fact_manufacturing_cost)
ORDER BY manufacturing_cost DESC;


-- 6. Generate a report which contains the top 5 customers who received an
-- average high pre_invoice_discount_pct for the fiscal year 2021 and in the
-- Indian market. The final output contains these fields,
-- customer_code
-- customer
-- average_discount_percentage
SELECT 
       pid.customer_code,
       c.customer,
       CONCAT(ROUND(AVG(pid.pre_invoice_discount_pct)*100, 2),'%') AS average_discount_percentage
FROM gdb023.dim_customer c JOIN gdb023.fact_pre_invoice_deductions pid
ON c.customer_code = pid.customer_code
WHERE c.market = 'India' AND pid.fiscal_year = 2021
GROUP BY pid.customer_code, c.customer
ORDER BY AVG(pid.pre_invoice_discount_pct) DESC
LIMIT 5;

-- 7. Get the complete report of the Gross sales amount for the customer “Atliq
-- Exclusive” for each month. This analysis helps to get an idea of low and
-- high-performing months and take strategic decisions.
-- The final report contains these columns:
-- Month
-- Year
-- Gross sales Amount
SELECT 
      MONTHNAME(s.date) AS `month`,
      YEAR(s.date) AS `year`,
      CONCAT('$', ROUND(SUM((s.sold_quantity * g.gross_price)/1000000),2),  'M') AS gross_sales_amount
FROM gdb023.dim_customer c JOIN gdb023.fact_sales_monthly s
ON c.customer_code = s.customer_code
JOIN gdb023.fact_gross_price g
ON s.product_code = g.product_code AND s.fiscal_year = g.fiscal_year
WHERE c.customer = 'Atliq Exclusive'
GROUP BY `month`, `year`
ORDER BY `year`;

-- 8. In which quarter of 2020, got the maximum total_sold_quantity? The final
-- output contains these fields sorted by the total_sold_quantity,
-- Quarter
-- total_sold_quantity
SELECT
       CASE 
            WHEN MONTH(date) IN (9,10,11) THEN 'Q1'
            WHEN MONTH(date) IN (12,1,2) THEN 'Q2'
            WHEN MONTH(date) IN (3,4,5) THEN 'Q3'
            ELSE 'Q4'
       END AS Quarter,
       SUM(sold_quantity) AS total_sold_quantity
FROM gdb023.fact_sales_monthly
WHERE fiscal_year = 2020
GROUP BY Quarter
ORDER BY total_sold_quantity DESC;

-- 9. Which channel helped to bring more gross sales in the fiscal year 2021
-- and the percentage of contribution? The final output contains these fields,
-- channel
-- gross_sales_mln
-- percentage
WITH gross_sales AS(
SELECT c.channel,
	    ROUND(SUM((s.sold_quantity * g.gross_price)/1000000),2) AS gross_sales_mln
FROM gdb023.dim_customer c JOIN gdb023.fact_sales_monthly s
ON c.customer_code = s.customer_code
JOIN gdb023.fact_gross_price g
ON s.product_code = g.product_code AND s.fiscal_year = g.fiscal_year
WHERE s.fiscal_year = 2021
GROUP BY c.channel
)
SELECT 
       channel,
       CONCAT('$',gross_sales_mln, 'M') AS gross_sales_mln,
       CONCAT(ROUND((gross_sales_mln * 100) / (SELECT SUM(gross_sales_mln) FROM gross_sales), 2), '%') AS percentage
FROM gross_sales
ORDER BY percentage DESC;

-- 10. Get the Top 3 products in each division that have a high
-- total_sold_quantity in the fiscal_year 2021? The final output contains these fields,
-- division
-- product_code
-- product
-- total_sold_quantity
-- rank_order
WITH total_sold_quantity AS(
SELECT  p.division,
        p.product_code,
        p.product,
	    SUM(s.sold_quantity) AS total_sold_quantity
FROM gdb023.dim_product p JOIN gdb023.fact_sales_monthly s
ON p.product_code = s.product_code
WHERE s.fiscal_year = 2021
GROUP BY p.division, p.product_code, p.product
ORDER BY total_sold_quantity DESC
),
top_products_per_division AS (
SELECT 
       division,
       product_code,
       product,
       total_sold_quantity,
	   DENSE_RANK() OVER(PARTITION BY division ORDER BY total_sold_quantity DESC) AS rnk
FROM total_sold_quantity
)
SELECT * FROM top_products_per_division WHERE rnk<=3;
