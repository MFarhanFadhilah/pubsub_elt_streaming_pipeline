package streaming_gateway

import (
	"context"
	"encoding/json"
	"net/http"
	"os"
	"strings"
	"time"

	"cloud.google.com/go/pubsub"
)

var (
	projectID = os.Getenv("PROJECT_ID")
	apiKey    = os.Getenv("API_KEY")
	topicName = os.Getenv("TOPIC_NAME")

	pubsubClient *pubsub.Client
)

func init() {
	ctx := context.Background()
	client, err := pubsub.NewClient(ctx, projectID)
	if err != nil {
		panic(err)
	}
	pubsubClient = client
}

type RequestBody struct {
	Data []map[string]interface{} `json:"data"`
}

func Handler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}

	token := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
	if token != apiKey {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var body RequestBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	ctx := r.Context()
	topic := pubsubClient.Topic(topicName)

	for _, event := range body.Data {
		msg := map[string]interface{}{
			"ingested_at": time.Now().UTC().Format(time.RFC3339),
			"payload":     event,
		}

		b, _ := json.Marshal(msg)
		topic.Publish(ctx, &pubsub.Message{Data: b})
	}

	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"ok"}`))
}
