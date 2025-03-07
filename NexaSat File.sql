--creating a table in the schema
CREATE TABLE "Nexa_sat".nexasat(
	Customer_id VARCHAR(50),
	Gender VARCHAR(10),
	Partner VARCHAR(3),
	Dependents VARCHAR(3),
	Senior_Citizen INT,
	Call_Duration FLOAT,
	Data_Usage FLOAT,
	Plan_Type VARCHAR(20),
	Plan_Level VARCHAR(20),
	Monthly_Bill_Amount FLOAT,
	Tenure_Months INT,
	Multiple_Lines VARCHAR(3),
	Tech_Support VARCHAR(3),Churn INT);
--confirm current schema
SELECT current_schema();

--set path for queries 
SET search_path TO "Nexa_sat";
SELECT *
FROM nexasat;

--data cleaning, searching for duplicates
SELECT Customer_id,Gender,Partner,Dependents,Senior_Citizen,Call_Duration ,Data_Usage,
Plan_Type,Plan_Level,Monthly_Bill_Amount,Tenure_Months,Multiple_Lines,Tech_Support,Churn
FROM nexasat
GROUP BY Customer_id,Gender,Partner,Dependents,Senior_Citizen,Call_Duration ,Data_Usage,
Plan_Type,Plan_Level,Monthly_Bill_Amount,Tenure_Months,Multiple_Lines,Tech_Support,Churn
HAVING COUNT(*) >1; --this filters out rolls that are duplicate
--It returned no rolls that means we dont have duplicates on this data set

--Checking for NULL values for all columns
SELECT *
FROM nexasat
WHERE Customer_id IS NULL
OR Gender IS NULL
OR Partner IS NULL
OR Dependents IS NULL
OR Senior_Citizen IS NULL
OR Call_Duration IS NULL
OR Data_Usage IS NULL
OR Plan_Type IS NULL
OR Plan_Level IS NULL
OR Monthly_Bill_Amount IS NULL
OR Tenure_Months IS NULL
OR Multiple_Lines IS NULL
OR Tech_Support IS NULL
OR Churn IS NULL;
--It returned no rolls that means we dont have NULL Vaues on this data set

--Let's perform some exploratory Data Analysis (EDA)
--Total Users
SELECT COUNT (Customer_id) AS current_users
FROM nexasat
WHERE Churn = 0; --count all customer id as current_user, where churn(people that have deactivated) is 0

--Total users by plan level
SELECT Plan_Level, COUNT (Customer_id) AS total_users
FROM nexasat
GROUP BY 1; --count plan level column, Count customer id as total users,from the table nexaset and group by 1 
--which is the first column PLAN LEVEL we typed

--Total revenue
SELECT ROUND (SUM(Monthly_Bill_Amount)::NUMERIC),2) AS revenue
FROM nexasat;

--Revenue by plan level
SELECT Plan_Level, ROUND(SUM(Monthly_Bill_Amount)::NUMERIC),2 AS revenue
FROM nexasat
GROUP BY 1
ORDER BY 2;

--Churn count by
SELECT Plan_Level,
Plan_Type,
COUNT (*) AS total_customers,
SUM(Churn) AS churn_count
FROM nexasat
GROUP BY 1,2
ORDER BY 1;

--Average tenure by plan level
SELECT Plan_Level, ROUND(AVG(Tenure_Months),2) AS avg_tenure
FROM nexasat
GROUP BY 1;


--MARKETING SEGMENTS
--create table containing existing users only(those that have not churned)
CREATE TABLE existing_users AS
SELECT *
FROM nexasat
WHERE Churn = 0;

--calculate Average Revenue Per User(ARPU)
SELECT ROUND(AVG(Monthly_bill_amount::INT),2) AS ARPU
FROM existing_users;

--Calculate Customer life time value(CLV)
--we will first add a new column which we will call CLV Using the alter table syntax and update it too
ALTER TABLE existing_users
ADD COLUMN CLV FLOAT;

UPDATE existing_users
SET CLV = Monthly_bill_amount * Tenure_months;

--let's view our new column
SELECT Customer_id,CLV
FROM existing_users;

--creat a clv score column and update it
ALTER TABLE existing_users
ADD COLUMN CLV_Score NUMERIC(10,2);

UPDATE existing_users
SET CLV = Monthly_bill_amount * Tenure_months;

--Calculating clv score based on certain percentage
--Monthly bill amount=40%, Tenure = 30%, Call duration = 10%,  Data usage = 10%, Premiunm user =10%

UPDATE existing_users
SET CLV_score = 
              (0.4 * Monthly_bill_amount) +
              (0.3 * Tenure_months) +
              (0.1 * Call_Duration) +
              (0.1 * Data_usage) +
              (0.1  * CASE WHEN Plan_Level = 'Premium' THEN 1 ELSE 0
	          END);
--let's view our new clv score column

SELECT Customer_id,CLV_score
FROM existing_users;

--group users in segments based on their CLV score
--create a new column called CLV segments

ALTER TABLE existing_users
ADD COLUMN CLV_Segment VARCHAR;

UPDATE existing_users
SET CLV_segment = 
                CASE WHEN Clv_score > (SELECT percentile_cont(0.85)
 	                                   WITHIN GROUP(ORDER BY Clv_score)
	                                   FROM existing_users) THEN 'High Value Customer'
	                   WHEN Clv_score > (SELECT percentile_cont(0.50)
 	                                   WITHIN GROUP(ORDER BY Clv_score)
	                                   FROM existing_users) THEN 'Moderate Value Customer'
	                    WHEN Clv_score > (SELECT percentile_cont(0.25)
 	                                   WITHIN GROUP(ORDER BY Clv_score)
	                                   FROM existing_users) THEN 'Low Value Customer'
	                     ELSE 'Churn Risk'
	                     END; --When a customer's CLV score fall within a certain percentage, identify them
                             --as either high level, moderate,low else risk to churn

--let's view our new clv segment column

SELECT Customer_id,clv,clv_score,CLV_segment
FROM existing_users;

--Analyzing segments
--Average bill and tenure per segment
SELECT clv_segment,
	ROUND(AVG(Monthly_bill_amount::INT),2) AS Avg_monthly_charges,
    ROUND(AVG(tenure_months::INT),2) AS Avg_tenure
FROM existing_users
GROUP BY 1;

--tech support and multiple lines percent
SELECT clv_segment,
ROUND(Avg(CASE WHEN tech_support = 'Yes' THEN 1 ELSE 0 END),2) AS tech_support_percentage,
ROUND(Avg(CASE WHEN multiple_lines = 'Yes' THEN 1 ELSE 0 END),2) AS multiple_lines_percent
FROM existing_users
GROUP BY clv_segment;

--Revenue per segment
SELECT clv_segment,COUNT (customer_id),
CAST(SUM(monthly_bill_amount * tenure_months)AS NUMERIC(10,2)) AS Total_revenue
FROM existing_users
GROUP BY clv_segment;



--CROSS SELLING AND UP-SELLING
--Cross-selling tech support to senior citizens
SELECT customer_id
FROM existing_users
WHERE senior_citizen = 1 --senior citizen
AND dependents = 'No' --no children or tech-savvy helpers
AND tech_support = 'No' --do not have this service
AND (clv_segment = 'Churn Risk' OR clv_segment = 'low value Customer');

--cross-selling multiple lines for partners and dependents
SELECT customer_id
FROM existing_users
WHERE multiple_lines = 'No' 
AND(dependents = 'Yes' OR partner = 'Yes')
AND plan_level = 'Basic';

--Up-selling strategy; premium discount for basic users with churn risk
SELECT customer_id
FROM existing_users 
WHERE clv_segment = 'churn_risk'
AND plan_level = 'Basic';

--up selling; basic to premium for longer lock in period and higher ARPU
SELECT plan_level,ROUND(Avg(monthly_bill_amount::INT),2), ROUND(avg(tenure_months::INT),2)
FROM existing_users
WHERE  clv_segment = 'High Value Customer'
OR Clv_segment = 'Moderate Value Customer'
GROUP BY 1;

SELECT *
FROM existing_users;

--select customers
SELECT customer_id, monthly_bill_amount
FROM existing_users
WHERE plan_level = 'Basic'
AND (clv_segment = 'High Value Customer' OR clv_segment = 'Moderate Value Customers')
AND monthly_bill_amount > 150;


--CREATE STORED PROCEDURES
--snr citizen who wil be offered tech support
CREATE FUNCTION tech_support_snr_citizen()
RETURNS TABLE (Customer_id VARCHAR(50))
AS $$
BEGIN
RETURN QUERY
SELECT eu.customer_id
FROM existing_users AS eu
WHERE eu.senior_citizen = 1 --senior citizen
AND eu.dependents = 'No' --no children or tech-savvy helpers
AND eu.tech_support = 'No' --do not have this service
AND (eu.clv_segment = 'Churn Risk' OR eu.clv_segment = 'low value Customer');
END;
$$ LANGUAGE plpgsql;

--CHURN RISK DISCOUNT
CREATE FUNCTION churn_risk_discount()
RETURNS TABLE (Customer_id VARCHAR(50))
AS $$
BEGIN
RETURN QUERY
    SELECT eu.customer_id
    FROM existing_users eu
    WHERE eu.clv_segment = 'churn_risk'
    AND eu. plan_level = 'Basic';
END;
$$ LANGUAGE plpgsql;

--high usage customers who will be offered premium discount
CREATE FUNCTION high_usage_basic()
RETURNS TABLE (customer_id VARCHAR(50))
AS $$
BEGIN
    RETURN QUERY
    SELECT eu.customer_id
    FROM existing_users eu
    WHERE eu. plan_level = 'Basic'
    AND (eu.clv_segment = 'High Value Customer' OR clv_segment = 'Moderate Value Customers')
    AND eu.monthly_bill_amount > 150;
END;
$$ LANGUAGE plpgsql;

--USING PROCEDURES
--Curn risk discount
SELECT *
FROM churn_risk_discount();

--high basic usage
SELECT *
FROM high_usage_basic();


