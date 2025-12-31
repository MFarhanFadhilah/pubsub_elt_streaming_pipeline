curl -X POST \
  -H "Authorization: Bearer test123" \
  -H "Content-Type: application/json" \
  -d @unit_test/sample_req.json \
  https://us-central1-personal-project-dev-482704.cloudfunctions.net/streaming_gateway
