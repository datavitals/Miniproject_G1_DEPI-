USE task;
GO

---------------------------------------------------
-- حذف الجداول القديمة لو موجودة
---------------------------------------------------
DROP TABLE IF EXISTS fact_sales;
DROP TABLE IF EXISTS dim_dates;
DROP TABLE IF EXISTS dim_regions;
DROP TABLE IF EXISTS dim_products;
DROP TABLE IF EXISTS dim_customers;

---------------------------------------------------
-- إنشاء الجداول من جديد
---------------------------------------------------

-- جدول العملاء
CREATE TABLE dim_customers (
    CustomerID VARCHAR(200) PRIMARY KEY,
    CustomerName VARCHAR(MAX),
    Segment VARCHAR(MAX)
);

-- جدول المنتجات (ProductID بطول محدد بدل MAX)
CREATE TABLE dim_products (
    ProductID VARCHAR(500) PRIMARY KEY,
    Category VARCHAR(MAX),
    SubCategory VARCHAR(MAX),
    ProductName VARCHAR(MAX)
);

-- جدول المناطق
CREATE TABLE dim_regions (
    RegionID INT IDENTITY(1,1) PRIMARY KEY,
    City VARCHAR(MAX),
    State VARCHAR(MAX),
    Region VARCHAR(MAX)
);

-- جدول التواريخ
CREATE TABLE dim_dates (
    DateID INT IDENTITY(1,1) PRIMARY KEY,
    OrderDate DATE,
    ShipDate DATE
);

-- جدول الحقائق
CREATE TABLE fact_sales (
    SalesID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID VARCHAR(200),
    CustomerID VARCHAR(200),
    ProductID VARCHAR(500),
    RegionID INT,
    DateID INT,
    Sales DECIMAL(10,2),
    Quantity INT,
    Profit DECIMAL(10,2),
    FOREIGN KEY (CustomerID) REFERENCES dim_customers(CustomerID),
    FOREIGN KEY (ProductID) REFERENCES dim_products(ProductID),
    FOREIGN KEY (RegionID) REFERENCES dim_regions(RegionID),
    FOREIGN KEY (DateID) REFERENCES dim_dates(DateID)
);

---------------------------------------------------
-- نقل البيانات
---------------------------------------------------

-- العملاء
INSERT INTO dim_customers (CustomerID, CustomerName, Segment)
SELECT DISTINCT Customer_ID, Customer_Name, Segment
FROM [dbo].[Sample - Superstore];

-- المنتجات (مفتاح فريد بدمج ID + Name)
INSERT INTO dim_products (ProductID, Category, SubCategory, ProductName)
SELECT DISTINCT 
    CAST(Product_ID AS VARCHAR(500)) + '_' + Product_Name AS ProductID,
    Category,
    Sub_Category,
    Product_Name
FROM [dbo].[Sample - Superstore];

-- المناطق
INSERT INTO dim_regions (City, State, Region)
SELECT DISTINCT City, State, Region
FROM [dbo].[Sample - Superstore];

-- التواريخ
INSERT INTO dim_dates (OrderDate, ShipDate)
SELECT DISTINCT Order_Date, Ship_Date
FROM [dbo].[Sample - Superstore];

-- جدول الحقائق
INSERT INTO fact_sales (OrderID, CustomerID, ProductID, RegionID, DateID, Sales, Quantity, Profit)
SELECT 
    s.Order_ID,
    s.Customer_ID,
    CAST(s.Product_ID AS VARCHAR(500)) + '_' + s.Product_Name,
    r.RegionID,
    d.DateID,
    s.Sales,
    s.Quantity,
    s.Profit
FROM [dbo].[Sample - Superstore] s
JOIN dim_customers c ON c.CustomerID = s.Customer_ID
JOIN dim_products p ON p.ProductID = CAST(s.Product_ID AS VARCHAR(500)) + '_' + s.Product_Name
JOIN dim_regions r ON r.City = s.City AND r.State = s.State
JOIN dim_dates d ON d.OrderDate = s.Order_Date AND d.ShipDate = s.Ship_Date;

---------------------------------------------------
-- التحقق من النتائج
---------------------------------------------------
SELECT COUNT(*) AS Customers FROM dim_customers;
SELECT COUNT(*) AS Products FROM dim_products;
SELECT COUNT(*) AS Regions FROM dim_regions;
SELECT COUNT(*) AS Dates FROM dim_dates;
SELECT COUNT(*) AS FactSales FROM fact_sales;


-- حذف التكرار من جدول العملاء
DELETE FROM dim_customers
WHERE CustomerID IN (
    SELECT CustomerID
    FROM dim_customers
    GROUP BY CustomerID
    HAVING COUNT(*) > 1
);

-- حذف التكرار من جدول المنتجات
DELETE FROM dim_products
WHERE ProductID IN (
    SELECT ProductID
    FROM dim_products
    GROUP BY ProductID
    HAVING COUNT(*) > 1
);


-- حذف الصفوف اللي فيها قيم ناقصة في الأعمدة الأساسية
DELETE FROM dim_customers
WHERE CustomerID IS NULL OR CustomerName IS NULL;

DELETE FROM dim_products
WHERE ProductID IS NULL OR ProductName IS NULL;

DELETE FROM fact_sales
WHERE Sales IS NULL OR Quantity IS NULL OR Profit IS NULL;



-- تحويل أسماء المنتجات والعملاء لحروف صغيرة لتوحيد الشكل
UPDATE dim_products
SET ProductName = LOWER(ProductName);

UPDATE dim_customers
SET CustomerName = LOWER(CustomerName);

SELECT COUNT(*) AS CleanCustomers FROM dim_customers;
SELECT COUNT(*) AS CleanProducts FROM dim_products;
SELECT COUNT(*) AS CleanFactSales FROM fact_sales;




---------------------------------------------------
-- 1️⃣ إزالة القيم السالبة أو غير المنطقية
---------------------------------------------------
-- حذف الصفوف اللي فيها مبيعات أو أرباح سالبة
DELETE FROM fact_sales
WHERE Sales < 0 OR Profit < 0 OR Quantity <= 0;

---------------------------------------------------
-- 2️⃣ معالجة القيم الشاذة (Outliers)
---------------------------------------------------
-- حذف الصفوف اللي فيها مبيعات أو أرباح أعلى من المتوسط بـ 3 انحراف معياري
DELETE FROM fact_sales
WHERE Sales > (
    SELECT AVG(Sales) + 3 * STDEV(Sales) FROM fact_sales
)
OR Profit > (
    SELECT AVG(Profit) + 3 * STDEV(Profit) FROM fact_sales
);

---------------------------------------------------
-- 3️⃣ توحيد النصوص في الجداول البُعدية
---------------------------------------------------
-- إزالة المسافات الزائدة وتحويل النصوص لحروف صغيرة
UPDATE dim_customers
SET CustomerName = LOWER(LTRIM(RTRIM(CustomerName))),
    Segment = LOWER(LTRIM(RTRIM(Segment)));

UPDATE dim_products
SET ProductName = LOWER(LTRIM(RTRIM(ProductName))),
    Category = LOWER(LTRIM(RTRIM(Category))),
    SubCategory = LOWER(LTRIM(RTRIM(SubCategory)));

UPDATE dim_regions
SET City = LOWER(LTRIM(RTRIM(City))),
    State = LOWER(LTRIM(RTRIM(State))),
    Region = LOWER(LTRIM(RTRIM(Region)));

---------------------------------------------------
-- 4️⃣ التحقق بعد التنظيف المتقدم
---------------------------------------------------
SELECT COUNT(*) AS CleanFactSales_AfterAdvanced FROM fact_sales;
SELECT COUNT(*) AS CleanProducts_AfterAdvanced FROM dim_products;
SELECT COUNT(*) AS CleanCustomers_AfterAdvanced FROM dim_customers;
SELECT COUNT(*) AS CleanRegions_AfterAdvanced FROM dim_regions;



