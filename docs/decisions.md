# Architecture Decision Records

This document summarizes the current design. Confirm each implementation detail against the Terraform and Lambda code before presenting it as a verified feature.

## 1. AWS IoT Core for MQTT ingress

**Decision:** Use AWS IoT Core as the managed MQTT endpoint.

**Why:** It provides a managed MQTT entry point and certificate-based client authentication without operating a broker for the cloud deployment.

**Trade-off:** Device certificates and IoT policies must be managed carefully. A single simulator certificate is a demonstration shortcut, not a production device-identity strategy.

## 2. SQS between IoT Core and Lambda

**Decision:** Buffer telemetry in SQS before processing it with Lambda.

**Why:** The queue decouples ingestion from processing and absorbs short traffic spikes.

**Trade-off:** Delivery is at least once, so consumers must tolerate duplicates. Ordering is not guaranteed with a standard queue. Messages can be retried and eventually sent to a DLQ according to the configured redrive policy.

## 3. Lambda for event processing

**Decision:** Process queued messages with a Lambda consumer.

**Why:** It avoids managing long-running worker servers and scales with event-source processing.

**Trade-off:** Batch failure behavior, timeout, visibility timeout, concurrency, and retry policy need to be configured consistently. Partial-batch retry support should only be claimed if it is enabled in the event-source mapping and implemented in the handler.

## 4. DynamoDB for current vehicle state

**Decision:** Store the latest known state per vehicle in DynamoDB.

**Why:** A key-value access pattern is a natural fit for retrieving a vehicle's most recent state.

**Trade-off:** Capacity mode and write conditions affect cost and correctness. Conditional writes should be documented only if the code actually prevents older events from overwriting newer state.

## 5. S3 and Parquet for analytics data

**Decision:** Keep analytical telemetry in S3 in Parquet format and query it using Athena.

**Why:** Parquet is columnar and can reduce scan volume when queries read only selected columns. S3 separates durable data storage from query compute.

**Trade-off:** Partition layout and file sizes matter. Excessive small files can hurt query performance, and the output schema must stay aligned with the Athena table definition.

## 6. Athena partition projection

**Decision:** Use partition projection for date/hour partitions instead of relying on a crawler.

**Why:** Athena can derive partition locations from configured rules, reducing partition metadata maintenance.

**Trade-off:** The projection range, format, and S3 location template must match the actual object paths. Incorrect settings can result in empty query results.

## 7. Terraform for infrastructure

**Decision:** Define infrastructure in Terraform.

**Why:** Infrastructure changes can be reviewed, repeated, and validated through code.

**Trade-off:** Terraform state and variable files may contain sensitive values. Keep them out of Git and protect any remote state backend if one is added.

## 8. CloudWatch and SNS for operations

**Decision:** Use logs, metrics, alarms, and email notifications to observe failures and queue backlog.

**Why:** The system needs operational signals in addition to successful message ingestion.

**Trade-off:** Alarm thresholds need to reflect expected traffic. Email subscriptions may require confirmation, and missing or sparse metrics need careful interpretation.

## Potential future decisions

- Per-device certificates and certificate rotation.
- Idempotency keys or conditional writes for duplicate/out-of-order events.
- Compaction and table formats such as Apache Iceberg if analytical data volume warrants them.
- Kinesis or another replayable stream if replay and retention requirements justify the extra complexity.
