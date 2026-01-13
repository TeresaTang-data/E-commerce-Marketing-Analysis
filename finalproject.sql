/# 1. Show the volume growth of the business. Pull data from overall session and order volume trended by quarter.

SELECT YEAR(w.created_at) AS yr,
       QUARTER(w.created_at) AS qr,
	   COUNT(DISTINCT w.website_session_id) AS overall_sessions,
	   COUNT(DISTINCT o.order_id) AS overall_orders
FROM website_sessions w
LEFT JOIN orders o
USING(website_session_id)
GROUP BY 1,2
ORDER BY 1,2

/# 2. Efficiency improvements: session-to-order conversion rate, revenue per order, revenue per session for quarterly figures.

SELECT YEAR(w.created_at),
               QUARTER(w.created_at),
               ROUND(COUNT(DISTINCT o.order_id)/COUNT(DISTINCT w.website_session_id),2)  AS conversion_rate,
			   ROUND(SUM(price_usd)/COUNT(DISTINCT o.order_id),2) AS revenue_per_order,
			   ROUND(SUM(price_usd)/COUNT(DISTINCT w.website_session_id),2) AS revenue_per_session
FROM website_sessions w
LEFT JOIN orders o
USING(website_session_id)
GROUP BY 1,2
ORDER BY 1,2

/# 3.Channel analysis: quarterly view of orders from different channels(brand, non-brand, search engine, etc.)

SELECT YEAR(w.created_at), QUARTER(w.created_at),        
    COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' AND utm_campaign = 'nonbrand' THEN o.order_id ELSE NULL END) AS gsearch_nonbrand_orders, 
    COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' AND utm_campaign = 'nonbrand' THEN o.order_id ELSE NULL END) AS bsearch_nonbrand_orders, 
    COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN o.order_id ELSE NULL END) AS brand_search_orders,
    COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN o.order_id ELSE NULL END) AS organic_search_orders,
    COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NULL THEN o.order_id ELSE NULL END) AS direct_type_in_orders    
FROM website_sessions w
LEFT JOIN orders o
USING(website_session_id)
GROUP BY 1,2
ORDER BY 1,2

/# 4. Overall Session-to-order conversion rate for each channel. Note any periods of great improvements and optimizations.
SELECT YEAR(website_sessions.created_at), QUARTER(website_sessions.created_at),
    COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' AND utm_campaign = 'nonbrand' THEN orders.order_id ELSE NULL END)
		/COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' AND utm_campaign = 'nonbrand' THEN website_sessions.website_session_id ELSE NULL END) AS gsearch_nonbrand_conv_rt, 
    COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' AND utm_campaign = 'nonbrand' THEN orders.order_id ELSE NULL END) 
		/COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' AND utm_campaign = 'nonbrand' THEN website_sessions.website_session_id ELSE NULL END) AS bsearch_nonbrand_conv_rt, 
    COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN orders.order_id ELSE NULL END) 
		/COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN website_sessions.website_session_id ELSE NULL END) AS brand_search_conv_rt,
    COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN orders.order_id ELSE NULL END) 
		/COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN website_sessions.website_session_id ELSE NULL END) AS organic_search_conv_rt,
    COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NULL THEN orders.order_id ELSE NULL END) 
		/COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NULL THEN website_sessions.website_session_id ELSE NULL END) AS direct_type_in_conv_rt
FROM website_sessions 
LEFT JOIN orders
USING(website_session_id)
GROUP BY 1,2
ORDER BY 1,2

/# 5. Monthly trends of revenue and margin analysis by product, along with total sales and revenue. Note any trends due to seasonality.
SELECT YEAR(created_at), MONTH(created_at),
               SUM(price_usd) AS revenue,
               SUM(price_usd) - SUM(cogs_usd) AS margin,
               SUM(CASE WHEN product_id = 1 THEN price_usd ELSE NULL END) AS revenue_1,
               SUM(CASE WHEN product_id = 1 THEN price_usd - cogs_usd ELSE NULL END) AS margin_1
FROM order_items
GROUP BY 1,2
ORDER BY 1,2

/# 6. Impact of introducing a new product. Pull monthly sessions from the /product page to investigate % of sessions clicking through another page has changed over time, and how conversion from placing a product to placing an order has improved

CREATE TEMPORARY TABLE product_pageview
SELECT website_session_id, website_pageview_id, created_at AS saw_product_page_at
FROM website_pageviews
WHERE pageview_url = '/product';

SELECT YEAR(saw_product_page_at), MONTH(saw_product_page_at),
               COUNT(DISTINCT p.website_session_id) AS sessions_to_product_page, 
               COUNT(DISTINCT w.website_session_id) AS clicked_to_next_page, 
               COUNT(DISTINCT w.website_session_id)/COUNT(DISTINCT p.website_session_id) AS clickthrough_rt,
                COUNT(DISTINCT orders.order_id) AS orders,
                COUNT(DISTINCT orders.order_id)/COUNT(DISTINCT p.website_session_id) AS products_to_order_rt
FROM product_pageview p
    LEFT JOIN website_pageviews w
ON p.website_session_id = w.website_session_id
AND w.website_pageview_id > p.website_pageview_id 
    LEFT JOIN orders
ON orders.website_session_id = p.website_session_id
GROUP BY 1,2

/# 7. Cross-sell analysis: Made 4th product a primary product(lower price). Investigate how well each product cross-sell with each other?

CREATE TEMPORARY TABLE AS primary_product
SELECT order_id, primary_product_id, created_as AS order_as
FROM orders
WHERE created_at > ‘2014-12-05’;

SELECT primary_product_id,
              COUNT(DISTINCT order_id) AS total_orders,
              COUNT(DISTINCT CASE WHEN cross_sell_product_id = 1 THEN order_id ELSE NULL END) AS xsold_p1,
COUNT(DISTINCT CASE WHEN cross_sell_product_id = 2 THEN order_id ELSE NULL END) AS xsold_p2,
COUNT(DISTINCT CASE WHEN cross_sell_product_id = 3 THEN order_id ELSE NULL END) AS xsold_p3,
COUNT(DISTINCT CASE WHEN cross_sell_product_id = 4 THEN order_id ELSE NULL END) AS xsold_p4,
COUNT(DISTINCT CASE WHEN cross_sell_product_id = 1 THEN order_id ELSE NULL END)/COUNT(DISTINCT order_id) AS p1_xsell_rt,
COUNT(DISTINCT CASE WHEN cross_sell_product_id = 2 THEN order_id ELSE NULL END)/COUNT(DISTINCT order_id) AS p2_xsell_rt,
COUNT(DISTINCT CASE WHEN cross_sell_product_id = 3 THEN order_id ELSE NULL END)/COUNT(DISTINCT order_id) AS p3_xsell_rt,
COUNT(DISTINCT CASE WHEN cross_sell_product_id = 4 THEN order_id ELSE NULL END)/COUNT(DISTINCT order_id) AS p4_xsell_rt
FROM(            
SELECT primary_product.*, order_items.product_id AS cross_sell_product_id
FROM primary product
LEFT JOIN order_items 
ON order_items.order_id =  primary product.order_id
AND order_items.is_primary_item = 0)




