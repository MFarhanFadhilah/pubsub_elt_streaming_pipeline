# Pub/Sub → BigQuery Streaming ELT (Without Dataflow)

A **lean, production-ready streaming ELT pipeline** on Google Cloud that ingests JSON events into BigQuery using **Cloud Functions (Go)**, **Pub/Sub native subscriptions**, and **BigQuery views**—without Dataflow.

This repository accompanies the Medium article:

> **When Dataflow Is Overkill: Building a Lean Pub/Sub → BigQuery Streaming ELT with Go**

---

## Why This Project Exists

Many Google Cloud streaming pipelines default to **Dataflow**, even when the workload is limited to straightforward JSON event ingestion. While Dataflow is powerful, it can be unnecessarily expensive and operationally heavy for ingestion-dominant use cases.

This project demonstrates a **simpler alternative**:

* No Dataflow
* No streaming workers
* No in-flight schema validation
* ELT instead of ETL
* BigQuery as the transformation engine

The result is a pipeline that is **cheaper, easier to operate, and easier to evolve**.

---

## Architecture Overview

```
Client / Mobile App
        ↓
Cloud Function (Go)
        ↓
Pub/Sub (Main Topic)
        ↓
BigQuery Native Subscription
        ↓
Raw Table (JSON, immutable)
        ↓
Staging View (Today’s data)
        ↓
DW View (Unified analytics interface)

Failures
   ↓
Dead Letter Topic (Pub/Sub only)
   ↓
Manual inspection / replay
```

Key design principles:

* **Durability first**: store raw events exactly once
* **Schema-on-read**: parse JSON in BigQuery views
* **Operational simplicity**: fewer moving parts than Dataflow
* **Cost efficiency**: pay for storage and queries, not streaming workers

---

## Repository Structure

```text
.
├── cloudbuild.yaml              # Cloud Build deployment for Cloud Function
├── main.go                      # Go Cloud Function (streaming gateway)
├── go.mod
├── go.sum
│
├── sql/
│   └── setup_bq.sql             # BigQuery raw table + views
│
├── script/
│   └── setup_pubsub.sh          # Pub/Sub topics & subscriptions (with DLQ)
│
├── unit_test/
│   └── sample_req.json          # Sample event payload
│
└── README.md
```

---

## Core Components

### 1. Streaming Gateway (Go + Cloud Functions Gen 2)

* Authenticates incoming requests
* Publishes events to Pub/Sub
* Performs **no validation or transformation**
* Keeps latency and failure surface minimal

**Why Go?**

* Fast cold starts
* Predictable performance
* Simple concurrency model

---

### 2. Pub/Sub → BigQuery (Native Subscription)

The pipeline uses **native Pub/Sub BigQuery subscriptions**, which provide:

* Exactly-once delivery
* Automatic scaling
* No Dataflow jobs
* No worker management

Messages are written directly into a BigQuery raw table.

---

### 3. Raw Layer (BigQuery)

The raw table stores:

* The full JSON payload
* Pub/Sub metadata
* Ingestion timestamp

It is:

* Immutable
* Partitioned
* Short-retention (7 days)
* Designed for replay and auditability

---

### 4. Staging & DW Views (ELT)

* **Staging view** parses JSON using `JSON_VALUE` and `SAFE_CAST`
* Only scans today’s partition for performance
* **DW view** provides a unified interface for consumers

No intermediate tables are required for real-time access.

---

### 5. Dead Letter Handling (Without Overengineering)

Failed messages are routed to a **Pub/Sub Dead Letter Topic**.

Design choice:

* No automatic BigQuery sink for DLQ
* No forced schema contracts
* Manual pull subscription for inspection and replay

This keeps failure handling flexible and low-cost.

---

## Setup Instructions

### Prerequisites

* Google Cloud project
* `gcloud` and `bq` CLI installed
* Cloud Functions Gen 2 enabled
* Permissions to manage Pub/Sub and BigQuery

---

### 1. Initialize BigQuery

```bash
bq query --use_legacy_sql=false < sql/setup_bq.sql
```

This creates:

* Raw streaming table
* Staging view
* DW view

---

### 2. Set Up Pub/Sub

```bash
chmod +x script/setup_pubsub.sh
./script/setup_pubsub.sh <PROJECT_ID> <PROJECT_NUMBER>
```

This creates:

* Main Pub/Sub topic
* BigQuery subscription
* Dead letter topic
* Debug pull subscription for DLQ

---

### 3. Deploy the Cloud Function

```bash
gcloud builds submit
```

Deployment uses **Cloud Build** and the configuration in `cloudbuild.yaml`.

---

### 4. Send a Test Event

```bash
curl -X POST \
  -H "Authorization: Bearer test123" \
  -H "Content-Type: application/json" \
  -d @unit_test/sample_req.json \
  https://<REGION>-<PROJECT_ID>.cloudfunctions.net/streaming_gateway
```

---

### 5. Verify Ingestion

```sql
SELECT *
FROM src.streaming_event_raw
ORDER BY ingest_ts DESC
LIMIT 10;
```

```sql
SELECT *
FROM stg.streaming_event_raw
LIMIT 10;
```

---

## When to Use This Pattern

### Good Fit

* Event tracking
* Mobile analytics
* Application telemetry
* JSON-heavy ingestion workloads
* Cost-sensitive streaming pipelines

### Not a Good Fit

* Stateful streaming joins
* Complex event-time windowing
* Real-time aggregations with sub-second SLAs

For those cases, Dataflow is still the right tool.

---

## Key Takeaways

* Dataflow should be a **deliberate choice**, not a default
* ELT simplifies streaming architectures
* BigQuery is powerful enough to handle transformation
* Removing components often improves reliability

---

## Related Article

📖 **Medium**:
*When Dataflow Is Overkill: Building a Lean Pub/Sub → BigQuery Streaming ELT with Go*

---

## License

MIT — use freely, adapt responsibly.

---
