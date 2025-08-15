CREATE TABLE sales
(
    sale_id INT PRIMARY KEY,
    sale_date DATE,
    product_id INT,
    customer_id INT,
    total FLOAT,
    rating INT,
    CONSTRAINT fk_products FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT fk_customers FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- END of SCHEMAS
SELECT * FROM city;
SELECT * FROM products;
SELECT * FROM customers;
SELECT * FROM sales;




-- **REPORT AND DATA ANALYSIS** 
-- Q1. Coffee Consumers Count
-- How many people in each city are estimated to consume coffee , given that 25% of the population does?
SELECT city_name,population*0.25 AS coffee_consumers 
FROM city;

-- Q2. Total Revenue from Coffee Sales
-- What is the total revenue generated from coffee sales across all cities in the last quarter of 2023?
SELECT sum(total) as total_revenue
From sales 
where EXTRACT(YEAR FROM sale_date)=2023 and EXTRACT(QUARTER FROM sale_date)=4;

-- Q3. Sales Count for Each Product
-- How many units of each coffee product have been sold?
SELECT p.product_name,count(s.sale_id) as total_sold from products as p
left join sales as s
on p.product_id=s.product_id
group by p.product_name
ORDER BY 2 DESC;

-- Q4. Average Sales Amount per City
-- What is the average sales amount per customer in each city?
SELECT c.city_name,ROUND(SUM(total)/count(distinct s.customer_id),2) as average_sale
from sales as s
join customers as cu
on s.customer_id=cu.customer_id
join city as c
on c.city_id=cu.city_id
group by c.city_name
order by 2 DESC;

-- Q5. City Population and Coffee Consumers
-- Provide a list of cities along with their populations and estimated coffee consumers.
SELECT city_name, population , population*0.25 as estimated_coffee_consumers 
from city
order by estimated_coffee_consumers DESC;

-- Q6. Top Selling Products by City
-- What are the top 3 selling products in each city based on sales volume?
WITH sales_per_product AS (
    SELECT 
        c.city_name,
        p.product_name,
        COUNT(s.sale_id) AS total_orders
    FROM sales AS s
    JOIN products AS p
        ON s.product_id = p.product_id
    JOIN customers AS cu
        ON cu.customer_id = s.customer_id
    JOIN city AS c
        ON c.city_id = cu.city_id
    GROUP BY c.city_name, p.product_name
)
SELECT city_name, product_name, total_orders
FROM (
    SELECT 
        city_name,
        product_name,
        total_orders,
        DENSE_RANK() OVER (
            PARTITION BY city_name 
            ORDER BY total_orders DESC
        ) AS rnk
    FROM sales_per_product
) ranked
WHERE rnk <= 3
ORDER BY city_name, total_orders DESC;

-- Q7. Customer Segmentation by City
-- How many unique customers are there in each city who have purchased coffee products?
select c.city_name, count(distinct s.customer_id) from sales as s 
join customers as cu
on s.customer_id=cu.customer_id
join city as c
on c.city_id=cu.city_id
where s.product_id<=14
group by c.city_name
order by 2 desc;

-- Q8. Average Sale vs Rent
-- Find each city and their average sale per customer and average rent per customer.
-- Average sales per customer and average rent per customer, by city
SELECT
  ci.city_name,
  ROUND(COALESCE(sc.sales_total, 0) / NULLIF(cc.customer_count, 0), 2) AS avg_sales_per_customer,
  ROUND(ci.estimated_rent / NULLIF(cc.customer_count, 0), 2)  AS avg_rent_per_customer
FROM city AS ci
LEFT JOIN (
  SELECT cu.city_id, COUNT(*) AS customer_count
  FROM customers AS cu
  GROUP BY cu.city_id
) AS cc
  ON cc.city_id = ci.city_id
LEFT JOIN (
  SELECT cu.city_id, SUM(s.total) AS sales_total
  FROM customers AS cu
  JOIN sales AS s
    ON s.customer_id = cu.customer_id
  GROUP BY cu.city_id
) AS sc
  ON sc.city_id = ci.city_id
ORDER BY avg_sales_per_customer desc;

-- Q9. Monthly Sales Growth
-- Sales growth rate: Calculate the percentage growth (or decline) in sales over different time periods (monthly).
WITH monthly_sales AS (
    SELECT
        ci.city_name,
        EXTRACT(MONTH FROM sale_date) AS month,
        EXTRACT(YEAR FROM sale_date) AS year,
        SUM(s.total) AS total_sale
    FROM sales AS s
    JOIN customers AS c
        ON c.customer_id = s.customer_id
    JOIN city AS ci
        ON ci.city_id = c.city_id
    GROUP BY 1, 2, 3
    ORDER BY 1, 3, 2
),
growth_ratio
as
(
SELECT 
      city_name,
      month,
      year,
      total_sale as cr_month_sale,
      LAG(total_sale,1) over(partition by city_name order by year,month) as last_month_sale
from monthly_sales      
)
select 
     city_name,
     month,
     year,
     cr_month_sale,
     last_month_sale,
     round((cr_month_sale - last_month_sale)/last_month_sale * 100,2) as growth_ratio
from growth_ratio
where last_month_sale is not null;   

-- Q10.Market Potential Analysis
-- Identify top 3 city based on highest sales, return city name, total sale,total rent,total customer,estimated coffee customer.
 
WITH city_table AS (
    SELECT
        ci.city_name,
        SUM(s.total) AS total_revenue,
        COUNT(DISTINCT s.customer_id) AS total_cx,
        ROUND(
            SUM(s.total)/
            COUNT(DISTINCT s.customer_id),
            2
        ) AS avg_sale_pr_cx
    FROM sales AS s
    JOIN customers AS c
        ON s.customer_id = c.customer_id
    JOIN city AS ci
        ON ci.city_id = c.city_id
    GROUP BY ci.city_name
    ORDER BY total_revenue DESC
),
city_rent AS (
    SELECT
        city_name,
        estimated_rent,
        population*0.25 as estimated_coffee_consumer
    FROM city
)
SELECT
    cr.city_name,
    ct.total_revenue,
    cr.estimated_rent as total_rent,
    ct.total_cx,
    cr.estimated_coffee_consumer,
    ct.avg_sale_pr_cx,
    ROUND(
        cr.estimated_rent / ct.total_cx,
        2
    ) AS avg_rent_per_c
    FROM city_rent AS cr
    JOIN city_table AS ct
    ON cr.city_name = ct.city_name
    order by total_revenue desc;
   
