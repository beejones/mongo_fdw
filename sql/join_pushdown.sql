\set MONGO_HOST			`echo \'"$MONGO_HOST"\'`
\set MONGO_PORT			`echo \'"$MONGO_PORT"\'`
\set MONGO_USER_NAME	`echo \'"$MONGO_USER_NAME"\'`
\set MONGO_PASS			`echo \'"$MONGO_PWD"\'`

-- Before running this file User must create database mongo_fdw_regress on
-- MongoDB with all permission for 'edb' user with 'edb' password and ran
-- mongodb_init.sh file to load collections.

\c contrib_regression
CREATE EXTENSION IF NOT EXISTS mongo_fdw;
CREATE SERVER mongo_server FOREIGN DATA WRAPPER mongo_fdw
  OPTIONS (address :MONGO_HOST, port :MONGO_PORT);
CREATE USER MAPPING FOR public SERVER mongo_server;

CREATE SERVER mongo_server1 FOREIGN DATA WRAPPER mongo_fdw
  OPTIONS (address :MONGO_HOST, port :MONGO_PORT);
CREATE USER MAPPING FOR public SERVER mongo_server1;

-- Create foreign tables.
CREATE FOREIGN TABLE f_test_tbl1 (_id NAME, c1 INTEGER, c2 TEXT, c3 CHAR(9), c4 INTEGER, c5 pg_catalog.Date, c6 DECIMAL, c7 INTEGER, c8 INTEGER)
  SERVER mongo_server OPTIONS (database 'mongo_fdw_regress', collection 'test_tbl1');
CREATE FOREIGN TABLE f_test_tbl2 (_id NAME, c1 INTEGER, c2 TEXT, c3 TEXT)
  SERVER mongo_server OPTIONS (database 'mongo_fdw_regress', collection 'test_tbl2');
CREATE FOREIGN TABLE f_test_tbl3 (_id NAME, c1 INTEGER, c2 TEXT, c3 TEXT)
  SERVER mongo_server1 OPTIONS (database 'mongo_fdw_regress', collection 'test_tbl2');
CREATE FOREIGN TABLE test_text ( __doc text)
  SERVER mongo_server OPTIONS (database 'mongo_fdw_regress', collection 'warehouse');
CREATE FOREIGN TABLE test_varchar ( __doc varchar)
  SERVER mongo_server OPTIONS (database 'mongo_fdw_regress', collection 'warehouse');
CREATE FOREIGN TABLE f_test_tbl4 (_id NAME, c1 INTEGER, c2 TEXT, c3 CHAR(9), c4 INTEGER, c5 pg_catalog.Date, c6 DECIMAL, c7 INTEGER, c8 INTEGER)
  SERVER mongo_server1 OPTIONS (database 'mongo_fdw_regress', collection 'test_tbl1');

INSERT INTO f_test_tbl1 VALUES (0, 1500, 'EMP15', 'FINANCE', 1300, '2000-12-25', 950.0, 400, 60);
INSERT INTO f_test_tbl1 VALUES (0, 1600, 'EMP16', 'ADMIN', 600);
INSERT INTO f_test_tbl2 VALUES (0, 50, 'TESTING', 'NASHIK');
INSERT INTO f_test_tbl2 VALUES (0);


-- Create local table.
CREATE TABLE l_test_tbl1 AS
  SELECT c1, c2, c3, c4, c5, c6, c7, c8 FROM f_test_tbl1;

-- Push down LEFT OUTER JOIN.
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d LEFT OUTER JOIN f_test_tbl1 e ON d.c1 = e.c8 ORDER BY 1, 3;
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d LEFT OUTER JOIN f_test_tbl1 e ON d.c1 = e.c8 ORDER BY 1, 3;
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl1 e LEFT OUTER JOIN f_test_tbl2 d ON d.c1 = e.c8 ORDER BY 1, 3;
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl1 e LEFT OUTER JOIN f_test_tbl2 d ON e.c8 = d.c1 ORDER BY 1, 3;
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d LEFT OUTER JOIN f_test_tbl1 e ON (d.c1 = e.c8 AND e.c4 > d.c1 OR e.c2 < d.c3) ORDER BY 1, 3 OFFSET 50;
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d LEFT OUTER JOIN f_test_tbl1 e ON (d.c1 = e.c8 AND e.c4 > d.c1 OR e.c2 < d.c3) ORDER BY 1, 3 OFFSET 50;
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d LEFT OUTER JOIN f_test_tbl1 e ON (d.c1 = e.c8 AND e.c4 > d.c1 AND e.c2 < d.c3) ORDER BY 1, 3;
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d LEFT OUTER JOIN f_test_tbl1 e ON (d.c1 = e.c8 AND e.c4 > d.c1 AND e.c2 < d.c3) ORDER BY 1, 3;
-- Column comparing with 'Constant' pushed down.
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d LEFT OUTER JOIN f_test_tbl1 e ON d.c1 = 20 ORDER BY 1, 3;
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d LEFT OUTER JOIN f_test_tbl1 e ON d.c1 = 20 ORDER BY 1, 3;

-- Push down RIGHT OUTER JOIN.
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d RIGHT OUTER JOIN f_test_tbl1 e ON d.c1 = e.c8 ORDER BY 1, 3;
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d RIGHT OUTER JOIN f_test_tbl1 e ON d.c1 = e.c8 ORDER BY 1, 3;
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl1 e RIGHT OUTER JOIN f_test_tbl2 d ON e.c8 = d.c1 ORDER BY 1, 3;
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl1 e RIGHT OUTER JOIN f_test_tbl2 d ON e.c8 = d.c1 ORDER BY 1, 3;
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d RIGHT OUTER JOIN f_test_tbl1 e ON (d.c1 = e.c8 OR e.c4 > d.c1 OR e.c2 < d.c3) ORDER BY 1, 3 OFFSET 60;
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d RIGHT OUTER JOIN f_test_tbl1 e ON (d.c1 = e.c8 OR e.c4 > d.c1 OR e.c2 < d.c3) ORDER BY 1, 3 OFFSET 60;
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d LEFT OUTER JOIN f_test_tbl1 e ON ((d.c1 = e.c8 OR e.c4 > d.c1) AND e.c2 < d.c3) ORDER BY 1, 3 OFFSET 60;
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d LEFT OUTER JOIN f_test_tbl1 e ON ((d.c1 = e.c8 OR e.c4 > d.c1) OR e.c2 < d.c3) ORDER BY 1, 3 OFFSET 60;
-- Column comparing with 'Constant' pushed down.
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d RIGHT OUTER JOIN f_test_tbl1 e ON d.c1 = 20 ORDER BY 1, 3;
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d RIGHT OUTER JOIN f_test_tbl1 e ON (d.c1 = 20 AND e.c2 = 'EMP1')  ORDER BY 1, 3;

-- Push INNER JOIN.
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d INNER JOIN f_test_tbl1 e ON d.c1 = e.c8 ORDER BY 1, 3;
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d INNER JOIN f_test_tbl1 e ON d.c1 = e.c8 ORDER BY 1, 3;
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d INNER JOIN f_test_tbl1 e ON ((d.c1 = e.c8 OR e.c4 > d.c1) AND e.c2 < d.c3) ORDER BY 1, 3 OFFSET 60;
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d INNER JOIN f_test_tbl1 e ON ((d.c1 = e.c8 OR e.c4 > d.c1) OR e.c2 < d.c3) ORDER BY 1, 3 OFFSET 60;
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d INNER JOIN f_test_tbl1 e ON (d.c1 = e.c8 OR e.c2 < d.c3) ORDER BY 1, 3 OFFSET 60;
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d INNER JOIN f_test_tbl1 e ON (d.c1 = e.c8 OR e.c2 < d.c3) ORDER BY 1, 3 OFFSET 60;

-- Column comparing with 'Constant' pushed down.
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d INNER JOIN f_test_tbl1 e ON (d.c1 = e.c8 AND d.c1 = 20 OR e.c2 = 'EMP1') ORDER BY 1, 3;
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d INNER JOIN f_test_tbl1 e ON (d.c1 = e.c8 AND d.c1 = 20 OR e.c2 = 'EMP1')  ORDER BY 1, 3;
-- INNER JOIN with WHERE clause.  Should execute where condition separately
-- (NOT added into join clauses) on remote side.
EXPLAIN (COSTS OFF)
SELECT d.c1, e.c1
  FROM f_test_tbl1 d JOIN f_test_tbl2 e ON (d.c8 = e.c1) WHERE d.c1 = 100 ORDER BY e.c3, d.c1;
SELECT d.c1, e.c1
  FROM f_test_tbl1 d JOIN f_test_tbl2 e ON (d.c8 = e.c1) WHERE d.c1 = 100 ORDER BY e.c3, d.c1;
-- INNER JOIN in which join clause is not pushable but WHERE condition is
-- pushable with join clause 'TRUE'.
EXPLAIN (COSTS OFF)
SELECT d.c1, e.c1
  FROM f_test_tbl1 d JOIN f_test_tbl2 e ON (abs(d.c8) = e.c1) WHERE d.c1 = 100 ORDER BY e.c3, d.c1;
SELECT d.c1, e.c1
  FROM f_test_tbl1 d JOIN f_test_tbl2 e ON (abs(d.c8) = e.c1) WHERE d.c1 = 100 ORDER BY e.c3, d.c1;

-- Local-Foreign table joins.
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d LEFT OUTER JOIN l_test_tbl1 e ON d.c1 = e.c8 ORDER BY 1, 3;
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d LEFT OUTER JOIN l_test_tbl1 e ON d.c1 = e.c8 ORDER BY 1, 3;

-- JOIN in sub-query, should be pushed down.
EXPLAIN (COSTS OFF)
SELECT l.c1, l.c6, l.c8
  FROM l_test_tbl1 l
    WHERE l.c1 IN (SELECT f1.c1 FROM f_test_tbl1 f1 LEFT JOIN f_test_tbl2 f2 ON (f1.c8 = f2.c1)) ORDER BY 1, 3;
SELECT l.c1, l.c6, l.c8
  FROM l_test_tbl1 l
    WHERE l.c1 IN (SELECT f1.c1 FROM f_test_tbl1 f1 LEFT JOIN f_test_tbl2 f2 ON (f1.c8 = f2.c1)) ORDER BY 1, 3;
SET enable_hashjoin TO OFF;
SET enable_nestloop TO OFF;
EXPLAIN (COSTS OFF)
SELECT l.c1, l.c6, l.c8
  FROM l_test_tbl1 l
    WHERE l.c1 = (SELECT f1.c1 FROM f_test_tbl1 f1 LEFT JOIN f_test_tbl2 f2 ON (f1.c8 = f2.c1) LIMIT 1) ORDER BY 1, 3;
SELECT l.c1, l.c6, l.c8
  FROM l_test_tbl1 l
    WHERE l.c1 = (SELECT f1.c1 FROM f_test_tbl1 f1 LEFT JOIN f_test_tbl2 f2 ON (f1.c8 = f2.c1) LIMIT 1) ORDER BY 1, 3;
EXPLAIN (COSTS OFF)
SELECT l.c1, l.c6, l.c8
  FROM l_test_tbl1 l
    WHERE l.c1 = (SELECT f1.c1 FROM f_test_tbl1 f1 INNER JOIN f_test_tbl2 f2 ON (f1.c8 = f2.c1) LIMIT 1) ORDER BY 1, 3;
SELECT l.c1, l.c6, l.c8
  FROM l_test_tbl1 l
    WHERE l.c1 = (SELECT f1.c1 FROM f_test_tbl1 f1 INNER JOIN f_test_tbl2 f2 ON (f1.c8 = f2.c1) LIMIT 1) ORDER BY 1, 3;
RESET enable_hashjoin;
RESET enable_nestloop;

-- Execute JOIN through PREPARE statement.
PREPARE pre_stmt_left_join AS
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d LEFT OUTER JOIN f_test_tbl1 e ON (d.c1 = e.c8 OR e.c4 > d.c1) ORDER BY 1, 3 OFFSET 70;
EXPLAIN (COSTS OFF)
EXECUTE pre_stmt_left_join;
EXECUTE pre_stmt_left_join;
PREPARE pre_stmt_inner_join AS
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d INNER JOIN f_test_tbl1 e ON (d.c1 = e.c8 OR e.c4 > d.c1) ORDER BY 1, 3 OFFSET 70;
EXPLAIN (COSTS OFF)
EXECUTE pre_stmt_inner_join;
EXECUTE pre_stmt_inner_join;

-- join + WHERE clause push-down.
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d LEFT OUTER JOIN f_test_tbl1 e ON d.c1 = e.c8 WHERE d.c1 = 10 ORDER BY 1, 3;
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d LEFT OUTER JOIN f_test_tbl1 e ON d.c1 = e.c8 WHERE d.c1 = 10 ORDER BY 1, 3;
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d RIGHT OUTER JOIN f_test_tbl1 e ON d.c1 = e.c8 WHERE e.c8 = 10 ORDER BY 1, 3;
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d RIGHT OUTER JOIN f_test_tbl1 e ON d.c1 = e.c8 WHERE e.c8 = 10 ORDER BY 1, 3;
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d INNER JOIN f_test_tbl1 e ON d.c1 = e.c8 WHERE d.c2 = 'SALES' ORDER BY 1, 3;
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d INNER JOIN f_test_tbl1 e ON d.c1 = e.c8 WHERE d.c2 = 'SALES' ORDER BY 1, 3;
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d INNER JOIN f_test_tbl1 e ON d.c1 = e.c8 WHERE e.c2 = 'EMP2' ORDER BY 1, 3;
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d INNER JOIN f_test_tbl1 e ON d.c1 = e.c8 WHERE e.c2 = 'EMP2' ORDER BY 1, 3;
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d INNER JOIN f_test_tbl1 e ON (d.c1 = e.c8 AND d.c1 = 20 OR e.c2 = 'EMP1') WHERE d.c1 = 10 OR e.c8 = 30 ORDER BY 1, 3;
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d INNER JOIN f_test_tbl1 e ON (d.c1 = e.c8 AND d.c1 = 20 OR e.c2 = 'EMP1') WHERE d.c1 = 10 OR e.c8 = 30 ORDER BY 1, 3;
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, e.c1, e.c2, d.c6, d.c8
  FROM f_test_tbl1 d LEFT JOIN f_test_tbl2 e ON (e.c1 = d.c8 AND (e.c1 = 20 OR d.c2 = 'EMP1')) WHERE e.c1 = 20 AND d.c8 = 20 ORDER BY 1, 3;
SELECT d.c1, d.c2, e.c1, e.c2, d.c6, d.c8
  FROM f_test_tbl1 d LEFT JOIN f_test_tbl2 e ON (e.c1 = d.c8 AND (e.c1 = 20 OR d.c2 = 'EMP1')) WHERE e.c1 = 20 AND d.c8 = 20 ORDER BY 1, 3;
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, d.c5, e.c1, e.c2
  FROM f_test_tbl1 d LEFT JOIN f_test_tbl2 e ON (e.c1 = d.c8 AND (d.c5 = '02-22-1981' OR d.c5 = '12-17-1980')) ORDER BY 1, 3;
SELECT d.c1, d.c2, d.c5, e.c1, e.c2
  FROM f_test_tbl1 d LEFT JOIN f_test_tbl2 e ON (e.c1 = d.c8 AND (d.c5 = '02-22-1981' OR d.c5 = '12-17-1980')) ORDER BY 1, 3;
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, d.c5, e.c1, e.c2
  FROM f_test_tbl1 d LEFT JOIN f_test_tbl2 e ON (e.c1 = d.c8) WHERE d.c5 = '02-22-1981' ORDER BY 1;
SELECT d.c1, d.c2, d.c5, e.c1, e.c2
  FROM f_test_tbl1 d LEFT JOIN f_test_tbl2 e ON (e.c1 = d.c8) WHERE d.c5 = '02-22-1981' ORDER BY 1;
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d LEFT JOIN f_test_tbl1 e ON (d.c1 = e.c8 AND d.c1 = 20 OR e.c2 = 'EMP1') WHERE d.c1 = 10 OR e.c8 = 30 ORDER BY 1, 3;
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d LEFT JOIN f_test_tbl1 e ON (d.c1 = e.c8 AND d.c1 = 20 OR e.c2 = 'EMP1') WHERE d.c1 = 10 OR e.c8 = 30 ORDER BY 1, 3;

-- Natural join, should push-down.
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, d.c5, e.c1, e.c2
  FROM f_test_tbl1 d NATURAL JOIN f_test_tbl1 e WHERE e.c1 > d.c8 ORDER BY 1;
SELECT d.c1, d.c2, d.c5, e.c1, e.c2
  FROM f_test_tbl1 d NATURAL JOIN f_test_tbl1 e WHERE e.c1 > d.c8 ORDER BY 1;
-- Self join, should push-down.
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, d.c5, e.c1, e.c2
  FROM f_test_tbl1 d INNER JOIN f_test_tbl1 e ON e.c8 = d.c8 ORDER BY 1 OFFSET 65;
SELECT d.c1, d.c2, d.c5, e.c1, e.c2
  FROM f_test_tbl1 d INNER JOIN f_test_tbl1 e ON e.c8 = d.c8 ORDER BY 1 OFFSET 65;

-- Join in CTE.
-- Explain plan difference between v11 (or pre) and later.
EXPLAIN (COSTS false, VERBOSE)
WITH t (c1_1, c1_3, c2_1) AS (
  SELECT d.c1, d.c3, e.c1
    FROM f_test_tbl1 d JOIN f_test_tbl2 e ON (d.c8 = e.c1)
) SELECT c1_1, c2_1 FROM t ORDER BY c1_3, c1_1;
WITH t (c1_1, c1_3, c2_1) AS (
  SELECT d.c1, d.c3, e.c1
    FROM f_test_tbl1 d JOIN f_test_tbl2 e ON (d.c8 = e.c1)
) SELECT c1_1, c2_1 FROM t ORDER BY c1_3, c1_1;

-- This won't push-down because WHERE only pushes operator expression.
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, d.c5, e.c1, e.c2
  FROM f_test_tbl2 e LEFT JOIN f_test_tbl1 d ON (e.c1 = d.c8) WHERE d.c5 = '02-22-1981' OR d.c5 = '12-17-1980' ORDER BY 1;
SELECT d.c1, d.c2, d.c5, e.c1, e.c2
  FROM f_test_tbl2 e LEFT JOIN f_test_tbl1 d ON (e.c1 = d.c8) WHERE d.c5 = '02-22-1981' OR d.c5 = '12-17-1980' ORDER BY 1;

-- Nested joins(Don't push-down nested join)
SET enable_mergejoin TO OFF;
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, d.c5, e.c1, e.c2
  FROM f_test_tbl1 d LEFT JOIN f_test_tbl2 e ON (e.c1 = d.c8) LEFT JOIN f_test_tbl1 f ON (f.c8 = e.c1) ORDER BY d.c1 OFFSET 65 ;
SELECT d.c1, d.c2, d.c5, e.c1, e.c2
  FROM f_test_tbl1 d LEFT JOIN f_test_tbl2 e ON (e.c1 = d.c8) LEFT JOIN f_test_tbl1 f ON (f.c8 = e.c1) ORDER BY d.c1 OFFSET 65;
RESET enable_mergejoin;

-- Not supported expressions won't push-down(e.g. function expression, etc.)
EXPLAIN (COSTS OFF)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d LEFT OUTER JOIN f_test_tbl1 e ON (ABS(d.c1) = e.c8) ORDER BY 1, 3;
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d LEFT OUTER JOIN f_test_tbl1 e ON (ABS(d.c1) = e.c8) ORDER BY 1, 3;

-- Don't pushdown when whole row reference is involved.
EXPLAIN (COSTS OFF)
SELECT d, e
  FROM f_test_tbl1 d LEFT JOIN f_test_tbl2 e ON (e.c1 = d.c8) LEFT JOIN f_test_tbl1 f ON (f.c8 = e.c1) ORDER BY e.c1 OFFSET 65;

-- Don't pushdown when full document retrieval is involved.
EXPLAIN (COSTS OFF)
SELECT json_data.key AS key1, json_data.value AS value1
  FROM test_text, test_varchar, json_each_text(test_text.__doc::json) AS json_data WHERE key NOT IN ('_id') ORDER BY json_data.key COLLATE "C";
SELECT json_data.key AS key1, json_data.value AS value1
  FROM test_text, test_varchar, json_each_text(test_text.__doc::json) AS json_data WHERE key NOT IN ('_id') ORDER BY json_data.key COLLATE "C";

-- Join two tables from two different foreign servers.
EXPLAIN (COSTS OFF)
SELECT d.c1, e.c1
  FROM f_test_tbl2 d LEFT OUTER JOIN f_test_tbl3 e ON d.c1 = e.c1 ORDER BY 1;

-- SEMI JOIN, not pushed down
EXPLAIN (COSTS OFF)
SELECT d.c2
  FROM f_test_tbl1 d WHERE EXISTS (SELECT 1 FROM f_test_tbl2 e WHERE d.c8 = e.c1) ORDER BY d.c2 LIMIT 10;
SELECT d.c2
  FROM f_test_tbl1 d WHERE EXISTS (SELECT 1 FROM f_test_tbl2 e WHERE d.c8 = e.c1) ORDER BY d.c2 LIMIT 10;

-- ANTI JOIN, not pushed down
EXPLAIN (COSTS OFF)
SELECT d.c2
  FROM f_test_tbl1 d WHERE NOT EXISTS (SELECT 1 FROM f_test_tbl2 e WHERE d.c8 = e.c1) ORDER BY d.c2 LIMIT 10;
SELECT d.c2
  FROM f_test_tbl1 d WHERE NOT EXISTS (SELECT 1 FROM f_test_tbl2 e WHERE d.c8 = e.c1) ORDER BY d.c2 LIMIT 10;

-- FULL OUTER JOIN, should not pushdown.
EXPLAIN (COSTS OFF)
SELECT d.c1, e.c1
  FROM f_test_tbl1 d FULL JOIN f_test_tbl2 e ON (d.c8 = e.c1) ORDER BY d.c2 LIMIT 10;
SELECT d.c1, e.c1
  FROM f_test_tbl1 d FULL JOIN f_test_tbl2 e ON (d.c8 = e.c1) ORDER BY d.c2 LIMIT 10;

-- CROSS JOIN can be pushed down
EXPLAIN (COSTS OFF)
SELECT e.c1, d.c2
  FROM f_test_tbl1 d CROSS JOIN f_test_tbl2 e ORDER BY e.c1, d.c2 LIMIT 10;
SELECT e.c1, d.c2
  FROM f_test_tbl1 d CROSS JOIN f_test_tbl2 e ORDER BY e.c1, d.c2 LIMIT 10;

-- Test partition-wise join
SET enable_partitionwise_join TO on;

-- Create the partition table in plpgsql block as those are failing with
-- different error messages on back-branches.
-- All test cases related to partition-wise join gives an error on v96 as
-- partition syntax is not supported there.
DO
$$
BEGIN
  EXECUTE 'CREATE TABLE fprt1 (_id NAME, c1 INTEGER, c2 INTEGER, c3 TEXT) PARTITION BY RANGE(c1)';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'syntax error';
END;
$$
LANGUAGE plpgsql;
CREATE FOREIGN TABLE ftprt1_p1 PARTITION OF fprt1 FOR VALUES FROM (1) TO (4)
  SERVER mongo_server OPTIONS (database 'mongo_fdw_regress', collection 'test1');
CREATE FOREIGN TABLE ftprt1_p2 PARTITION OF fprt1 FOR VALUES FROM (5) TO (8)
  SERVER mongo_server OPTIONS (database 'mongo_fdw_regress', collection 'test2');

DO
$$
BEGIN
  EXECUTE 'CREATE TABLE fprt2 (_id NAME, c1 INTEGER, c2 INTEGER, c3 TEXT) PARTITION BY RANGE(c2)';
EXCEPTION WHEN syntax_error THEN
  RAISE NOTICE 'syntax error';
END;
$$
LANGUAGE plpgsql;
CREATE FOREIGN TABLE ftprt2_p1 PARTITION OF fprt2 FOR VALUES FROM (1) TO (4)
  SERVER mongo_server OPTIONS (database 'mongo_fdw_regress', collection 'test3');
CREATE FOREIGN TABLE ftprt2_p2 PARTITION OF fprt2 FOR VALUES FROM (5) TO (8)
  SERVER mongo_server OPTIONS (database 'mongo_fdw_regress', collection 'test4');

-- Inner join two tables
-- Different explain plan on v10 as partition-wise join is not supported there.
SET enable_mergejoin TO OFF;
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2
  FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.c1 = t2.c2) ORDER BY 1,2;
SELECT t1.c1, t2.c2
  FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.c1 = t2.c2) ORDER BY 1,2;

-- Inner join three tables
-- Different explain plan on v10 as partition-wise join is not supported there.
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2, t3.c2
  FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.c1 = t2.c2) INNER JOIN fprt1 t3 ON (t3.c1 = t2.c2) ORDER BY 1,2;
SELECT t1.c1, t2.c2, t3.c2
  FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.c1 = t2.c2) INNER JOIN fprt1 t3 ON (t3.c1 = t2.c2) ORDER BY 1,2;
RESET enable_mergejoin;

-- Join with lateral reference
-- Different explain plan on v10 as partition-wise join is not supported there.
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t1.c2
  FROM fprt1 t1, LATERAL (SELECT t2.c1, t2.c2 FROM fprt2 t2
  WHERE t1.c1 = t2.c2 AND t1.c2 = t2.c1) q WHERE t1.c1 % 2 = 0 ORDER BY 1,2;
SELECT t1.c1, t1.c2
  FROM fprt1 t1, LATERAL (SELECT t2.c1, t2.c2 FROM fprt2 t2
  WHERE t1.c1 = t2.c2 AND t1.c2 = t2.c1) q WHERE t1.c1 % 2 = 0 ORDER BY 1,2;

-- With PHVs, partitionwise join selected but no join pushdown
-- Table alias in foreign scan is different for v12, v11 and v10.
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t1.phv, t2.c2, t2.phv
  FROM (SELECT 't1_phv' phv, * FROM fprt1 WHERE c1 % 2 = 0) t1 LEFT JOIN
    (SELECT 't2_phv' phv, * FROM fprt2 WHERE c2 % 2 = 0) t2 ON (t1.c1 = t2.c2)
  ORDER BY t1.c1, t2.c2;
SELECT t1.c1, t1.phv, t2.c2, t2.phv
  FROM (SELECT 't1_phv' phv, * FROM fprt1 WHERE c1 % 2 = 0) t1 LEFT JOIN
    (SELECT 't2_phv' phv, * FROM fprt2 WHERE c2 % 2 = 0) t2 ON (t1.c1 = t2.c2)
  ORDER BY t1.c1, t2.c2;
RESET enable_partitionwise_join;

-- FDW-445: Support enable_join_pushdown option at server level and table level.
-- Check only boolean values are accepted.
ALTER SERVER mongo_server OPTIONS (ADD enable_join_pushdown 'abc11');

-- Test the option at server level.
ALTER SERVER mongo_server OPTIONS (ADD enable_join_pushdown 'false');
EXPLAIN (COSTS FALSE, VERBOSE)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d JOIN f_test_tbl1 e ON d.c1 = e.c8 ORDER BY 1, 3;
ALTER SERVER mongo_server OPTIONS (SET enable_join_pushdown 'true');
EXPLAIN (COSTS FALSE, VERBOSE)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d JOIN f_test_tbl1 e ON d.c1 = e.c8 ORDER BY 1, 3;

-- Test the option with outer rel.
ALTER FOREIGN TABLE f_test_tbl2 OPTIONS (ADD enable_join_pushdown 'false');
EXPLAIN (COSTS FALSE, VERBOSE)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d JOIN f_test_tbl1 e ON d.c1 = e.c8 ORDER BY 1, 3;

ALTER FOREIGN TABLE f_test_tbl2 OPTIONS (SET enable_join_pushdown 'true');
EXPLAIN (COSTS FALSE, VERBOSE)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d JOIN f_test_tbl1 e ON d.c1 = e.c8 ORDER BY 1, 3;

-- Test the option with inner rel.
ALTER FOREIGN TABLE f_test_tbl1 OPTIONS (ADD enable_join_pushdown 'false');
EXPLAIN (COSTS FALSE, VERBOSE)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d JOIN f_test_tbl1 e ON d.c1 = e.c8 ORDER BY 1, 3;

ALTER FOREIGN TABLE f_test_tbl1 OPTIONS (SET enable_join_pushdown 'true');
EXPLAIN (COSTS FALSE, VERBOSE)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d JOIN f_test_tbl1 e ON d.c1 = e.c8 ORDER BY 1, 3;

-- Test that setting option at table level does not affect the setting at
-- server level.
ALTER FOREIGN TABLE f_test_tbl1 OPTIONS (SET enable_join_pushdown 'false');
ALTER FOREIGN TABLE f_test_tbl2 OPTIONS (SET enable_join_pushdown 'false');
EXPLAIN (COSTS FALSE, VERBOSE)
SELECT d.c1, d.c2, e.c1, e.c2, e.c6, e.c8
  FROM f_test_tbl2 d JOIN f_test_tbl1 e ON d.c1 = e.c8 ORDER BY 1, 3;

EXPLAIN (COSTS FALSE, VERBOSE)
SELECT t1.c1, t2.c2
  FROM f_test_tbl3 t1 JOIN f_test_tbl4 t2 ON (t1.c1 = t2.c8) ORDER BY 1, 2;

DELETE FROM f_test_tbl1 WHERE c8 IS NULL;
DELETE FROM f_test_tbl1 WHERE c8 = 60;
DELETE FROM f_test_tbl2 WHERE c1 IS NULL;
DELETE FROM f_test_tbl2 WHERE c1 = 50;
DROP FOREIGN TABLE f_test_tbl1;
DROP FOREIGN TABLE f_test_tbl2;
DROP FOREIGN TABLE f_test_tbl3;
DROP FOREIGN TABLE f_test_tbl4;
DROP FOREIGN TABLE test_text;
DROP FOREIGN TABLE test_varchar;
DROP TABLE l_test_tbl1;
DROP FOREIGN TABLE  ftprt1_p1;
DROP FOREIGN TABLE  ftprt1_p2;
DROP FOREIGN TABLE  ftprt2_p1;
DROP FOREIGN TABLE  ftprt2_p2;
DROP TABLE IF EXISTS fprt1;
DROP TABLE IF EXISTS fprt2;
DROP USER MAPPING FOR public SERVER mongo_server1;
DROP SERVER mongo_server1;
DROP USER MAPPING FOR public SERVER mongo_server;
DROP SERVER mongo_server;
DROP EXTENSION mongo_fdw;
