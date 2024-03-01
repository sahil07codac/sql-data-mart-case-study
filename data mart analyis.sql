select * from weekly_sales;

--EXEC sp_help weekly_sales;
--- data cleasing 

select
	week_date,
	datepart(wk,week_date)as weeknumber,
	datepart(mm,week_date)as monthnumber,
	datepart(yy,week_date)as calenderyear,
	region,platform,
	case 
	when segment='null' then 'unknown'
	else segment
	end as segment,
	case 
	when segment like 'C%' then 'Couples'
	when segment like 'F%' then 'families'
	else 'unknown'
	end as demographic,
	case 
	when segment like '%1' then 'Young Adults'
	when segment like '%2' then 'Middle Aged'
	when segment like '%3' or segment like '%4' then 'Retirees'
	else 'unkown'
	end as age_band,
	transactions,sales, customer_type,
	round(sales/transactions,2)as avgtransaction
into clean_weekly_sales 
from weekly_sales

select * from clean_weekly_sales;

---1.What day of the week is used for each week_date value?
select DISTINCT DATENAME(w,week_date)AS DAY_OFWEEK  from clean_weekly_sales;

--2.What range of week numbers are missing from the dataset?
WITH WeekNumberss AS (
    SELECT 1 AS WeekNumbers
    UNION ALL
    SELECT WeekNumbers + 1
    FROM WeekNumberss
    WHERE WeekNumbers < 52
)

SELECT WeekNumbers
FROM WeekNumberss
WHERE WeekNumbers NOT IN (
    SELECT DISTINCT WeekNumber
    FROM clean_weekly_sales
)



--3.How many total transactions were there for each year in the dataset?
select calenderyear, count(transactions)as totaltransaction
from clean_weekly_sales
group by calenderyear
order by calenderyear ;


--4.What is the total sales for each region for each month?
select distinct monthnumber,region,sum(cast(sales as bigint)) as totalsales
from clean_weekly_sales
group by region,monthnumber
order by monthnumber

--5.What is the total count of transactions for each platform?
select platform,count(transactions) as countoftransaction
from clean_weekly_sales
group by platform

--6.What is the percentage of sales for Retail vs Shopify for each month?

select monthnumber,
sum( case when platform='Retail' then cast(sales as bigint) else 0 end) as retailsales,
sum( case when platform='Shopify' then cast(sales as bigint) else 0 end) as retailsales,
sum(cast(sales as bigint))as totalsales,
100*SUM(CASE WHEN Platform = 'Retail' THEN cast(sales as bigint) ELSE 0 END) / sum(cast(sales as bigint))  AS RetailPercentage,
100*SUM(CASE WHEN Platform = 'Shopify' THEN cast(sales as bigint) ELSE 0 END) / sum(cast(sales as bigint))  AS ShopifyPercentage
from clean_weekly_sales
group by  monthnumber
order by monthnumber;


----or---

select monthnumber,calenderyear,round((shopify_sales)*100/total_sales,2) as
shofipy_percentage,
round((retail_sales)*100/total_sales,2) as retail_percentage
from
(select monthnumber,calenderyear,sum(cast(sales as bigint)) as total_sales,
sum(case when platform = 'shopify' then cast(sales as bigint) end) as 'shopify_sales',
sum(case when platform = 'retail' then cast(sales as bigint) end) as 'retail_sales'
from clean_weekly_sales
group by monthnumber,calenderyear)
clean_weekly_sales

---7.What is the percentage of sales by demographic for each year in the dataset?
select calenderyear,demographic,sum(cast(sales as bigint)) as total_sales,round(sum(cast(sales as bigint))*100/sum(sum(cast(sales as bigint))) over(partition by calenderyear),2)as percentageofsales
from clean_weekly_sales
group  by calenderyear,demographic


---8.Which age_band and demographic values contribute the most to Retail sales?
select * from clean_weekly_sales;
select age_band,demographic,sum(case when platform = 'retail' then cast(sales as bigint) end) as 'retail_sales'
from clean_weekly_sales
group by  age_band,demographic 
order by 'retail_sales' desc

---9.Can we use the avg_transaction column to find the average transaction size for each year for Retail vs Shopify? If not - how would you calculate it instead?
select calenderyear,platform,avg(avgtransaction) as avgtransaction 
from clean_weekly_sales
group by calenderyear,platform
----or

select calenderyear,platform,sum(cast(sales as bigint))/count(*)  as avgtransaction 
from clean_weekly_sales
group by calenderyear,platform


---10.What are the total sales and total transactions for each region in the dataset?
select region,sum(cast(sales as bigint)) as total_sales,sum(transactions)as total_transactions from
clean_weekly_sales
group by region

---11.Analyze the sales performance for different segments (C1, C2, C3, F1, F2).
select segment,sum(cast(sales as bigint))
from clean_weekly_sales
where segment!='unknown'
group by segment

---12.Which platform has the highest average transaction value
select platform,round(avg(transactions),2) as 
avg_transaction 
from clean_weekly_sales
group by platform 
order by avg_transaction  desc;

--13.How many total transactions were there for each year in the dataset?
select calenderyear,sum(transactions)as totaltranction
from clean_weekly_sales
group by calenderyear

--14.What is the total sales for the 4 weeks before and after 2020-06-15? What is the growth or reduction rate in actual values and percentage of sales?

select week_date ,weeknumber , sum(cast(sales as bigint))as totalsale
from clean_weekly_sales
where  week_date between DATEADD(wk,-4,'2020-06-15') and DATEADD(wk,4,'2020-06-15')
group by week_date ,weeknumber ;
---or 
WITH SalesSummary AS (
    SELECT 
        WeekNumber,
        SUM(CASE WHEN week_date < '2020-06-15' THEN Sales ELSE 0 END) AS SalesBefore,
        SUM(CASE WHEN week_date > '2020-06-15' THEN Sales  ELSE 0 END) AS SalesAfter,
		sum(cast(sales as bigint))as totalsale
    FROM 
       clean_weekly_sales
    WHERE 
        week_date BETWEEN DATEADD(WEEK, -4, '2020-06-15') AND DATEADD(WEEK, 4, '2020-06-15')
    GROUP BY 
      WeekNumber
)
SELECT 
    SUM(cast(SalesBefore as bigint)) AS TotalSalesBefore,
    SUM(cast(SalesAfter as bigint)) AS TotalSalesAfter,
  SUM(cast(SalesAfter as bigint))-SUM(cast(SalesBefore as bigint)) as actualsale,
    ((SUM(cast(SalesAfter as bigint)) - SUM(cast(SalesBefore as bigint))) *100/ NULLIF(SUM(cast(SalesBefore as bigint)), 0)) AS PercentageChange
FROM 
    SalesSummary;

---15.What about the entire 12 weeks before and after?
WITH SalesSummary AS (
    SELECT 
        WeekNumber,
        SUM(CASE WHEN week_date < '2020-06-15' THEN Sales ELSE 0 END) AS SalesBefore,
        SUM(CASE WHEN week_date > '2020-06-15' THEN Sales  ELSE 0 END) AS SalesAfter
    FROM 
       clean_weekly_sales
    WHERE 
        week_date BETWEEN DATEADD(WEEK, -12, '2020-06-15') AND DATEADD(WEEK, 12, '2020-06-15')
    GROUP BY 
      WeekNumber
)
SELECT 
    SUM(cast(SalesBefore as bigint)) AS TotalSalesBefore,
    SUM(cast(SalesAfter as bigint)) AS TotalSalesAfter,
   SUM(cast(SalesAfter as bigint))-SUM(cast(SalesBefore as bigint)) as actualsale,
    ((SUM(cast(SalesAfter as bigint)) - SUM(cast(SalesBefore as bigint))) *100/ NULLIF(SUM(cast(SalesBefore as bigint)), 0)) AS PercentageChange
FROM 
    SalesSummary;


	----
---How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?
	WITH SalesComparison AS (
    SELECT 
        YEAR(week_date) AS OrderYear,
        SUM(CASE WHEN week_date BETWEEN DATEADD(YEAR, -2, '2020-06-15') AND DATEADD(YEAR, -1, '2020-06-15') THEN cast(sales as bigint) ELSE 0 END) AS SalesBefore2020,
        SUM(CASE WHEN week_date BETWEEN '2020-06-15' AND DATEADD(YEAR, -1, '2020-06-15') THEN cast(sales as bigint) ELSE 0 END) AS SalesAfter2020,
        SUM(CASE WHEN week_date BETWEEN DATEADD(YEAR, -3, '2020-06-15') AND DATEADD(YEAR, -2, '2020-06-15') THEN cast(sales as bigint) ELSE 0 END) AS SalesBefore2019,
        SUM(CASE WHEN week_date BETWEEN DATEADD(YEAR, -2, '2020-06-15') AND DATEADD(YEAR, -1, '2020-06-15') THEN cast(sales as bigint) ELSE 0 END) AS SalesAfter2019,
        SUM(CASE WHEN week_date BETWEEN DATEADD(YEAR, -4, '2020-06-15') AND DATEADD(YEAR, -3, '2020-06-15') THEN cast(sales as bigint) ELSE 0 END) AS SalesBefore2018,
        SUM(CASE WHEN week_date BETWEEN DATEADD(YEAR, -3, '2020-06-15') AND DATEADD(YEAR, -2, '2020-06-15') THEN cast(sales as bigint) ELSE 0 END) AS SalesAfter2018
    FROM 
        clean_weekly_sales
    GROUP BY 
        YEAR(week_date)
)

SELECT 
    OrderYear,
    SalesBefore2020,
    SalesAfter2020,
    SalesBefore2019,
    SalesAfter2019,
    SalesBefore2020 - SalesBefore2019 AS SalesDifferenceBefore2020,
    SalesAfter2020 - SalesAfter2019 AS SalesDifferenceAfter2020,
    ((SalesAfter2020 - SalesAfter2019) - (SalesBefore2020 - SalesBefore2019)) AS SalesGrowthDifference
FROM 
    SalesComparison;

---
WITH SalesComparison AS (
    SELECT 
        region,
        platform,
        age_band,
        demographic,
        customer_type,
        SUM(CASE WHEN week_date BETWEEN DATEADD(WEEK, -12, '2020-06-15') AND '2020-06-15' THEN cast(sales as bigint) ELSE 0 END) AS SalesBefore2020,
        SUM(CASE WHEN week_date BETWEEN '2020-06-15' AND DATEADD(WEEK, 12, '2020-06-15') THEN cast(sales as bigint) ELSE 0 END) AS SalesAfter2020,
        SUM(CASE WHEN week_date BETWEEN DATEADD(YEAR, -2, '2020-06-15') AND DATEADD(YEAR, -1, '2020-06-15') THEN cast(sales as bigint) ELSE 0 END) AS SalesBefore2019,
        SUM(CASE WHEN week_date BETWEEN DATEADD(YEAR, -1, '2020-06-15') AND '2020-06-15' THEN cast(sales as bigint) ELSE 0 END) AS SalesAfter2019
    FROM 
        clean_weekly_sales
    WHERE
        YEAR(week_date) IN (2019, 2020)
    GROUP BY 
        region,
        platform,
        age_band,
        demographic,
        customer_type
)

SELECT 
    region,
    platform,
    age_band,
    demographic,
    customer_type,
    (SalesAfter2020 - SalesAfter2019) - (SalesBefore2020 - SalesBefore2019) AS SalesImpact
FROM 
    SalesComparison
ORDER BY 
    SalesImpact DESC