DROP TABLE IF EXISTS src.streaming_event_raw
;

CREATE TABLE src.streaming_event_raw
(
  ingest_ts           TIMESTAMP NOT NULL,
  payload             JSON,
  attributes          JSON,
  publish_time        TIMESTAMP,
  message_id          STRING,
  subscription_name   STRING
)
PARTITION BY DATE(ingest_ts)
OPTIONS (
  partition_expiration_days = 7,
  description = "Raw streaming events from Pub/Sub. Immutable source of truth."
)
;

DROP VIEW IF EXISTS stg.streaming_event_raw
;

CREATE VIEW stg.streaming_event_raw AS
SELECT
  ingest_ts,
  JSON_VALUE(payload, '$.core.event_name')              AS event_name,
  JSON_VALUE(payload, '$.core.event_id')                AS event_id,
  JSON_VALUE(payload, '$.core.pageview_id')             AS pageview_id,
  JSON_VALUE(payload, '$.core.page_name')               AS page_name,
  JSON_VALUE(payload, '$.core.page_urlpath')            AS page_urlpath,
  JSON_VALUE(payload, '$.core.previous_page')           AS previous_page,
  JSON_VALUE(payload, '$.core.previous_page_urlpath')   AS previous_page_urlpath,
  TIMESTAMP_MILLIS(
    SAFE_CAST(JSON_VALUE(payload, '$.core.event_timestamp') AS INT64)
  )                                                     AS event_datetime,
  JSON_VALUE(payload, '$.user.user_id')                 AS user_id,
  JSON_VALUE(payload, '$.user.session_id')              AS session_id,
  JSON_VALUE(payload, '$.application.source_name')      AS source_name,
  JSON_VALUE(payload, '$.application.os_name')          AS os_name,
  JSON_VALUE(payload, '$.application.os_version')       AS os_version,
  JSON_VALUE(payload, '$.application.os_timezone')      AS os_timezone,
  JSON_VALUE(payload, '$.application.device_class')     AS device_class,
  JSON_VALUE(payload, '$.application.device_family')    AS device_family,
  JSON_VALUE(payload, '$.application.app_version')      AS app_version,
  JSON_VALUE(payload, '$.application.device_id')        AS device_id,
  JSON_VALUE(payload, '$.network.ip_address')           AS ip_address,
  JSON_VALUE(payload, '$.network.network_isp')          AS network_isp,
  JSON_VALUE(payload, '$.network.country')              AS country,
  JSON_VALUE(payload, '$.network.city')                 AS city,
  JSON_VALUE(payload, '$.network.zipcode')              AS zipcode,
  SAFE_CAST(JSON_VALUE(payload, '$.network.latitude') AS FLOAT64)   AS latitude,
  SAFE_CAST(JSON_VALUE(payload, '$.network.longitude') AS FLOAT64)  AS longitude,
  JSON_VALUE(payload, '$.marketing.utm_raw')            AS utm_raw,
  payload                                                AS raw_payload,
  attributes,
  publish_time,
  message_id,
  subscription_name
FROM src.streaming_event_raw
WHERE ingest_ts >= TIMESTAMP_TRUNC(CURRENT_TIMESTAMP(), DAY)
;

CREATE TABLE IF NOT EXISTS stg.streaming_event
(
  event_date      DATE,
  ingest_ts       TIMESTAMP,
  event_datetime  TIMESTAMP,
  event_name      STRING,
  event_id        STRING,
  pageview_id     STRING,
  page_name       STRING,
  page_urlpath    STRING,
  user_id         STRING,
  session_id      STRING,
  source_name     STRING,
  os_name         STRING,
  os_version      STRING,
  device_class    STRING,
  device_family   STRING,
  app_version     STRING,
  device_id       STRING,
  country         STRING,
  city            STRING,
  latitude        FLOAT64,
  longitude       FLOAT64,
  utm_raw         STRING,
  original_json   STRING
)
PARTITION BY event_date
OPTIONS (
  description = "Validated and transformed events. Populated via Airflow batch."
)
;

CREATE TABLE IF NOT EXISTS rej.streaming_event_rej
(
  event_date        DATE,
  ingest_ts         TIMESTAMP,
  reject_reason     STRING,
  original_json     STRING,
  attributes        JSON,
  publish_time      TIMESTAMP,
  message_id        STRING,
  subscription_name STRING
)
PARTITION BY event_date
OPTIONS (
  description = "Rejected events from Pub/Sub DLQ and Airflow validation."
)
;

DROP VIEW IF EXISTS dw.streaming_event
;

CREATE VIEW dw.streaming_event AS
SELECT
  event_date,
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
  original_json
FROM stg.streaming_event

UNION ALL

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
