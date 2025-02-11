/*
------------------------------
SQL Project - Elist Analysis
------------------------------
*/

-- 1) What are the quarterly trends for order count, sales, and AOV for Macbooks sold in North America across all years? 
    -- Tables: orders, customers, geo_lookup
    -- Columns: quarters per year, COUNT(order id), SUM(usd_price) & AVG(usd_price)
    -- Filter: WHERE product_name LIKE '%macbook%' AND region = 'NA'

    SELECT 
      DATE_TRUNC(o.purchase_ts, QUARTER) AS quarter, 
      COUNT(o.id) AS order_count, 
      ROUND(SUM(o.usd_price),2) AS sales,
      ROUND(AVG(usd_price),2) AS AOV
    FROM core.orders o
    LEFT JOIN core.customers c
      ON o.customer_id = c.id
    LEFT JOIN core.geo_lookup g
      ON c.country_code = g.country
    WHERE LOWER(o.product_name) LIKE '%macbook%'
    AND g.region = 'NA'
    GROUP BY 1
    ORDER BY 1 DESC;

    --What is the average quarterly order count and total sales for Macbooks sold in North America? 
    --Use CTE to take AVG metrics

    WITH quarterly_metric AS (
      SELECT 
        DATE_TRUNC(o.purchase_ts, QUARTER) AS purchase_quarter,
        COUNT(DISTINCT o.id) AS order_count,
        SUM(o.usd_price) AS total_sales
      FROM core.orders o
      LEFT JOIN core.customers c
        ON c.id = o.customer_id
      LEFT JOIN core.geo_lookup g
        ON c.country_code = g.country
      WHERE g.region = 'NA' 
      AND LOWER(o.product_name) LIKE '%macbook%'
      GROUP BY 1
      ORDER BY 1 DESC
    )
    
    SELECT 
      ROUND(AVG(order_count),2) AS avg_order_count,
      ROUND(AVG(total_sales),2) AS avg_total_sales
    FROM quarterly_metric;


     ------In North America, MacBook sales averaged 98 units per quarter, with average quarterly revenue of $155,362.-------


-- 2) For products purchased in 2022 on the website or products purchased on mobile in any year, which region has the average highest time to deliver? 
    -- Use tables order_status, orders, customers & geo_lookup
    -- Return the region with the highest AVG(delivery_ts - ship_ts)
    -- Filter for orders in 2022 on the website OR orders placed on mobile (all years)


    SELECT 
      g.region, 
      ROUND(AVG(DATE_DIFF(os.delivery_ts, os.purchase_ts, DAY)),2) AS days_to_delivery
    FROM core.orders o
    LEFT JOIN core.order_status os
      ON o.id = os.order_id
    LEFT JOIN core.customers c
      ON o.customer_id = c.id
    LEFT JOIN `core.geo_lookup` g
      ON g.country = c.country_code
    WHERE (EXTRACT(YEAR FROM o.purchase_ts) = 2022 AND o.purchase_platform = 'website')
    OR (o.purchase_platform = 'mobile app')
    GROUP BY 1
    ORDER BY 2 DESC
    LIMIT 1;

   -----EMEA region shows the highest average delivery time of 7.54 days for orders that were either placed on the website in 2022 or through mobile devices across all years.-----
    
    --For products is website purchases made in 2022 or Samsung purchases made in 2021, expressing time to deliver in weeks instead of days.


    SELECT 
      g.region, 
      ROUND(AVG(DATE_DIFF(os.delivery_ts, os.purchase_ts, WEEK)),2) AS weeks_to_delivery
    FROM core.orders o
    LEFT JOIN core.order_status os
      ON o.id = os.order_id
    LEFT JOIN core.customers c
      ON o.customer_id = c.id
    LEFT JOIN `core.geo_lookup` g
      ON g.country = c.country_code
    WHERE (EXTRACT(YEAR FROM o.purchase_ts) = 2022 AND o.purchase_platform = 'website')
    OR (EXTRACT(YEAR FROM o.purchase_ts) = 2021 AND LOWER(o.product_name) LIKE '%samsung%')
    GROUP BY 1
    ORDER BY 2 DESC;
    
   -------LATAM region shows the highest average delivery time of 1.08 weeks for orders that were either placed on the website in 2022 or Samsung products purchased in 2021.--------------

    -- 3) What was the refund rate and refund count for each product overall? 
        -- Clean product name
        -- create a “helper column” using a case when statement to code 1 for refunds, 0 if not a refund
        -- Find the refund rate per product_name (use AVG for rates)
        -- Use the order_status & orders tables
    
    SELECT CASE WHEN o.product_name = '27in"" 4k gaming monitor' THEN '27in 4K gaming monitor' ELSE o.product_name END AS product_name,
      ROUND(AVG(CASE WHEN os.refund_ts IS NOT NULL THEN 1 ELSE 0 END)*100,2) AS refund_rate, 
      SUM(CASE WHEN os.refund_ts IS NOT NULL THEN 1 ELSE 0 END) AS refund_count
    FROM core.orders o
    LEFT JOIN core.order_status os
      ON o.id = os.order_id
    GROUP BY 1
    ORDER BY 2 DESC;

   -------Among all products, ThinkPad Laptop shows the highest refund rate at 11.73%, while Apple AirPods Headphones recorded the highest absolute number of refunds with 2,636 units returned.--------------


    --What was the refund rate and refund count for each product per year?
    
    SELECT EXTRACT(YEAR FROM o.purchase_ts) AS year,
      CASE WHEN o.product_name = '27in"" 4k gaming monitor' THEN '27in 4K gaming monitor' ELSE o.product_name END AS product_name,
      ROUND(AVG(CASE WHEN os.refund_ts IS NOT NULL THEN 1 ELSE 0 END),2) AS refund_rate, 
      SUM(CASE WHEN os.refund_ts IS NOT NULL THEN 1 ELSE 0 END) AS refund_count
    FROM core.orders o
    LEFT JOIN core.order_status os
      ON o.id = os.order_id
    GROUP BY 1,2
    ORDER BY 3 DESC;



    
   -- 4) Within each region, what is the most popular product?
    -- Join all tables to return region and count of order (total orders of each product = most popular)
    -- Rank the products by count in each region and return the top selling product
    
    WITH sales_by_product AS(
      SELECT 
        g.region AS region, 
        CASE WHEN o.product_name = '27in"" 4k gaming monitor' THEN '27in 4K gaming monitor' ELSE o.product_name END AS product_name, 
        COUNT(DISTINCT o.id) AS order_count,
        RANK() OVER(PARTITION BY g.region ORDER BY COUNT(DISTINCT o.id) DESC) as rnk
      FROM core.geo_lookup g
      LEFT JOIN core.customers c
      ON g.country = c.country_code
      LEFT JOIN core.orders o
      ON o.customer_id = c.id 
      GROUP BY 1,2
    )
    
    SELECT 
      region, 
      product_name, 
      order_count
    FROM sales_by_product
    WHERE rnk = 1;


    -------Apple AirPods Headphones ranks as the best-selling product across all regions.  -------




   -- 5) How does the time to make a purchase differ between loyalty customers vs. non-loyalty customers? 
    -- Use orders & customers tables
    -- Calculate the avg days to purchase

    SELECT 
      c.loyalty_program,
      ROUND(AVG(DATE_DIFF(o.purchase_ts, c.created_on, DAY)),1) AS days_to_purchase
    FROM core.orders o
    LEFT JOIN core.customers c
      ON o.customer_id = c.id
    GROUP BY 1;
  -------Analysis of customer purchasing behavior shows that loyalty program members make their first purchase within 49.3 days of account creation, 
  -------while non-members take an average of 70.5 days - indicating that loyalty program members engage with purchases 30% faster.


    --split the time to purchase per loyalty program, per purchase platform. Return the number of records to benchmark the severity of nulls.
    
    SELECT 
      c.loyalty_program, 
      o.purchase_platform,
      ROUND(AVG(DATE_DIFF(o.purchase_ts, c.created_on, DAY)),1) AS days_to_purchase,
      COUNT(*) AS row_count
    FROM core.orders o
    LEFT JOIN core.customers c
      ON o.customer_id = c.id
    GROUP BY 1,2
    ORDER BY 1 DESC;

--Analysis of purchase patterns by platform shows distinct differences between loyalty program members and non-members. 
--Loyalty program members complete purchases faster through the mobile app compared to the website. 
--For non-members, website purchases take notably longer, averaging 73.9 days from account creation - significantly higher than other platforms.











