CREATE DATABASE IF NOT EXISTS fleet;

CREATE EXTERNAL TABLE fleet.telemetry (
  vehicle_id string, ts bigint, lat double, lon double, speed_kmh double,
  battery_pct double, ingest_ts bigint, zone string, speeding boolean,
  processed_ts bigint, e2e_ms bigint
)
PARTITIONED BY (dt string, hour string)
STORED AS PARQUET
LOCATION 's3://fleet-lake-2493a265/curated/telemetry/'
TBLPROPERTIES (
  'projection.enabled'='true',
  'projection.dt.type'='date', 'projection.dt.range'='2026-10-01,NOW',
  'projection.dt.format'='yyyy-MM-dd',
  'projection.hour.type'='integer', 'projection.hour.range'='0,23', 'projection.hour.digits'='2',
  'storage.location.template'='s3://fleet-lake-2493a265/curated/telemetry/dt=${dt}/hour=${hour}'
);

-- dedupe view (at-least-once delivery)
CREATE VIEW fleet.telemetry_dedup AS
SELECT * FROM (SELECT *, row_number() OVER (PARTITION BY vehicle_id, ts ORDER BY processed_ts) rn
               FROM fleet.telemetry) WHERE rn = 1;

-- latency percentiles
SELECT approx_percentile(e2e_ms, 0.5) p50, approx_percentile(e2e_ms, 0.95) p95, count(*) n
FROM fleet.telemetry_dedup WHERE dt = '2026-10-27';

-- speeding hot-spots
SELECT zone, count_if(speeding) speeding_events FROM fleet.telemetry_dedup
WHERE dt = '2026-10-27' GROUP BY zone ORDER BY 2 DESC LIMIT 10;