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

# 1. ENABLE APIS
echo "Enabling APIs..."
gcloud services enable \
  pubsub.googleapis.com \
  bigquery.googleapis.com \
  --project="$PROJECT_ID" --quiet

# 2. IAM - BIGQUERY PERMISSIONS
echo "Granting BigQuery permissions to Pub/Sub Service Agent..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${PUBSUB_SA}" \
  --role="roles/bigquery.dataEditor" --quiet

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${PUBSUB_SA}" \
  --role="roles/bigquery.metadataViewer" --quiet

# 3. IAM - DLQ PERMISSIONS (CRITICAL)
echo "Granting DLQ permissions to Pub/Sub Service Agent..."

# Role to Publish to the DLQ Topic
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${PUBSUB_SA}" \
  --role="roles/pubsub.publisher" --quiet

# Role to Acknowledge/Forward from the Main Subscription
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${PUBSUB_SA}" \
  --role="roles/pubsub.subscriber" --quiet

# 4. TOPIC CREATION
echo "Creating topics..."
gcloud pubsub topics create "$DLQ_TOPIC" --project="$PROJECT_ID" --quiet || true
gcloud pubsub topics create "$MAIN_TOPIC" --project="$PROJECT_ID" --quiet || true

# 5. SUBSCRIPTION CREATION
echo "Creating subscriptions..."

# DLQ Debug Subscription
gcloud pubsub subscriptions create "$DLQ_DEBUG_SUB" \
  --topic="$DLQ_TOPIC" \
  --project="$PROJECT_ID" \
  --ack-deadline=600 \
  --expiration-period=never --quiet || true

# Main BigQuery Subscription
gcloud pubsub subscriptions create "$MAIN_SUB" \
  --project="$PROJECT_ID" \
  --topic="$MAIN_TOPIC" \
  --bigquery-table="$PROJECT_ID:$SRC_DATASET.$SRC_TABLE" \
  --write-metadata \
  --drop-unknown-fields \
  --dead-letter-topic="$DLQ_TOPIC" \
  --max-delivery-attempts=5 \
  --ack-deadline=600 \
  --message-retention-duration=6h \
  --expiration-period=never --quiet || true