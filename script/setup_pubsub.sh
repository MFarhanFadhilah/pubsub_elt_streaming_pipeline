#!/bin/bash
set -euo pipefail

# INPUT
PROJECT_ID=$1
PROJECT_NUMBER=$2

if [ -z "${PROJECT_ID:-}" ] || [ -z "${PROJECT_NUMBER:-}" ]; then
  echo "Usage: ./setup_pubsub.sh <PROJECT_ID> <PROJECT_NUMBER>"
  exit 1
fi

# CONFIGURATION
SRC_DATASET=src
SRC_TABLE=streaming_event_raw
MAIN_TOPIC=streming_event
MAIN_SUB=streming_event_bq_sub
DLQ_TOPIC=streming_event_dl
DLQ_DEBUG_SUB=streming_event_dl_debug_sub
PUBSUB_SA="service-${PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com"

# HEADER
echo "===================================================="
echo " PROJECT        : $PROJECT_ID"
echo " MAIN TOPIC     : $MAIN_TOPIC"
echo " MAIN SUB       : $MAIN_SUB"
echo " MAIN TABLE     : $SRC_DATASET.$SRC_TABLE"
echo " DLQ TOPIC      : $DLQ_TOPIC"
echo " DLQ DEBUG SUB  : $DLQ_DEBUG_SUB"
echo "===================================================="

# ENABLE REQUIRED APIS
echo "Enabling required APIs..."
gcloud services enable \
  pubsub.googleapis.com \
  bigquery.googleapis.com \
  --project="$PROJECT_ID" \
  --quiet

sleep 20

# IAM — PUBSUB → BIGQUERY
echo "Granting BigQuery permissions to Pub/Sub service agent..."

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${PUBSUB_SA}" \
  --role="roles/bigquery.dataEditor" \
  --quiet

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${PUBSUB_SA}" \
  --role="roles/bigquery.metadataViewer" \
  --quiet

# CLEANUP
gcloud pubsub subscriptions delete "$MAIN_SUB" \
  --project="$PROJECT_ID" --quiet || true

gcloud pubsub subscriptions delete "$DLQ_DEBUG_SUB" \
  --project="$PROJECT_ID" --quiet || true

gcloud pubsub topics delete "$MAIN_TOPIC" \
  --project="$PROJECT_ID" --quiet || true

gcloud pubsub topics delete "$DLQ_TOPIC" \
  --project="$PROJECT_ID" --quiet || true

# CREATE TOPICS
gcloud pubsub topics create "$MAIN_TOPIC" \
  --project="$PROJECT_ID" \
  --labels=component=streaming,type=main

gcloud pubsub topics create "$DLQ_TOPIC" \
  --project="$PROJECT_ID" \
  --labels=component=streaming,type=dlq

# CREATE MAIN BIGQUERY SUBSCRIPTION
gcloud pubsub subscriptions create "$MAIN_SUB" \
  --project="$PROJECT_ID" \
  --topic="$MAIN_TOPIC" \
  --bigquery-table="$PROJECT_ID:$SRC_DATASET.$SRC_TABLE" \
  --use-table-schema \
  --write-metadata \
  --ack-deadline=600 \
  --message-retention-duration=6h \
  --dead-letter-topic="$DLQ_TOPIC" \
  --max-delivery-attempts=5 \
  --expiration-period=never

gcloud pubsub subscriptions create "$DLQ_DEBUG_SUB" \
  --project="$PROJECT_ID" \
  --topic="$DLQ_TOPIC" \
  --ack-deadline=600 \
  --message-retention-duration=7d \
  --expiration-period=never