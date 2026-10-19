DROP DATABASE IF EXISTS ecommerce_churn;
CREATE DATABASE ecommerce_churn;
USE ecommerce_churn;

CREATE TABLE customers_raw (
    customer_id            INT AUTO_INCREMENT PRIMARY KEY,
    tenure                 INT,            
    warehouse_to_home      INT,            
    devices_registered     INT,            
    preferred_order_cat    VARCHAR(50),    
    satisfaction_score     INT,            
    marital_status         VARCHAR(20),
    num_addresses          INT,           
    complain               TINYINT,        
    days_since_last_order  INT,
    cashback_amount        DECIMAL(10,2),
    churn                  TINYINT         
);

LOAD DATA LOCAL INFILE 'C:/Users/gamin/Downloads/Projects/ecommerce-churn-sql/data/data_ecommerce_customer_churn.csv'
INTO TABLE customers_raw
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(@tenure, @wh, @dev, preferred_order_cat, satisfaction_score, marital_status,
 num_addresses, complain, @dslo, cashback_amount, churn)
SET
    tenure                = CAST(CAST(NULLIF(TRIM(@tenure),'') AS DECIMAL(10,1)) AS SIGNED),
    warehouse_to_home     = CAST(CAST(NULLIF(TRIM(@wh),'') AS DECIMAL(10,1)) AS SIGNED),
    devices_registered    = CAST(@dev AS SIGNED),
    days_since_last_order = CAST(CAST(NULLIF(TRIM(@dslo), '') AS DECIMAL(10,1)) AS SIGNED);

SHOW VARIABLES LIKE 'local_infile';
SET GLOBAL local_infile = 1;

-- should display 3,941 rows
SELECT * FROM customers_raw;
