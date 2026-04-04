gcloud run deploy wevibe-backend19 \
  --source . \
  --set-cloudsql-instances="appyyo-417016:us-central1:wevibe-postqre" \
 --update-env-vars DATABASE_URL="postgresql://postgres:WeVibe_Group19@34.45.92.51:5432/postgres",AUTH_PROVIDER_MODE="firebase",FIREBASE_PROJECT_ID="wevibe-dev",UPSTASH_REDIS_URL="rediss://default:AZtFAAIncDExYjc0MjIyY2E3M2U0NDk1OWZiMzc1NTQ5ZDhmNWNkNXAxMzk3NDk@normal-flamingo-39749.upstash.io:6379" \
  --remove-env-vars GOOGLE_APPLICATION_CREDENTIALS \
  --session-affinity \
  --timeout=3600 \
  --region us-central1 \
  --allow-unauthenticated