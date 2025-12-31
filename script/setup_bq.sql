-- 1. RAW LAYER (The Landing Zone)
DROP TABLE IF EXISTS src.streaming_event_raw;
CREATE TABLE src.streaming_event_raw
(
  data                JSON,          -- The Pub/Sub message body (payload)
  attributes          JSON,          -- Message attributes
  subscription_name   STRING,        -- Metadata: Name of the subscription
  message_id          STRING,        -- Metadata: Unique ID
  publish_time        TIMESTAMP,     -- Metadata: When it was published
  ingest_ts           TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(ingest_ts)
OPTIONS (
  partition_expiration_days = 7,
  description = "Raw streaming events. Message body is in the 'data' column."
);

-- 2. STAGING VIEW (The Parser)
DROP VIEW IF EXISTS stg.streaming_event_raw;
CREATE VIEW stg.streaming_event_raw AS
SELECT
  ingest_ts,
  JSON_VALUE(data, '$.core.event_name')              AS event_name,
  JSON_VALUE(data, '$.core.event_id')                AS event_id,
  JSON_VALUE(data, '$.core.pageview_id')             AS pageview_id,
  JSON_VALUE(data, '$.core.page_name')               AS page_name,
  JSON_VALUE(data, '$.core.page_urlpath')            AS page_urlpath,
  JSON_VALUE(data, '$.core.previous_page')           AS previous_page,
  JSON_VALUE(data, '$.core.previous_page_urlpath')   AS previous_page_urlpath,
  TIMESTAMP_MILLIS(
    SAFE_CAST(JSON_VALUE(data, '$.core.event_timestamp') AS INT64)
  )                                                  AS event_datetime,
  JSON_VALUE(data, '$.user.user_id')                 AS user_id,
  JSON_VALUE(data, '$.user.session_id')              AS session_id,
  JSON_VALUE(data, '$.application.source_name')      AS source_name,
  JSON_VALUE(data, '$.application.os_name')          AS os_name,
  JSON_VALUE(data, '$.application.os_version')       AS os_version,
  JSON_VALUE(data, '$.application.os_timezone')      AS os_timezone,
  JSON_VALUE(data, '$.application.device_class')     AS device_class,
  JSON_VALUE(data, '$.application.device_family')    AS device_family,
  JSON_VALUE(data, '$.application.app_version')      AS app_version,
  JSON_VALUE(data, '$.application.device_id')        AS device_id,
  JSON_VALUE(data, '$.network.ip_address')           AS ip_address,
  JSON_VALUE(data, '$.network.network_isp')          AS network_isp,
  JSON_VALUE(data, '$.network.country')              AS country,
  JSON_VALUE(data, '$.network.city')                 AS city,
  JSON_VALUE(data, '$.network.zipcode')              AS zipcode,
  SAFE_CAST(JSON_VALUE(data, '$.network.latitude') AS FLOAT64)   AS latitude,
  SAFE_CAST(JSON_VALUE(data, '$.network.longitude') AS FLOAT64)  AS longitude,
  JSON_VALUE(data, '$.marketing.utm_raw')            AS utm_raw,
  data                                               AS raw_payload,
  attributes,
  publish_time,
  message_id,
  subscription_name
FROM src.streaming_event_raw
WHERE ingest_ts >= TIMESTAMP_TRUNC(CURRENT_TIMESTAMP(), DAY);

-- 3. DW LAYER (The Final Union)
DROP VIEW IF EXISTS dw.streaming_event;
CREATE VIEW dw.streaming_event AS
SELECT
  DATE(event_datetime)            AS event_date,
  ingest_ts,
  event_datetime,
  event_name,
  event_id,
  pageview_id,
  page_name,
  page_urlpath,
  user_id,
  session_id,
  source_name,
  os_name,
  os_version,
  device_class,
  device_family,
  app_version,
  device_id,
  country,
  city,
  latitude,
  longitude,
  utm_raw,
  TO_JSON_STRING(raw_payload)     AS original_json
FROM stg.streaming_event_raw;