gcloud run deploy wevibe-backend19 \
  --source . \
  --update-env-vars DATABASE_URL="postgresql://postgres:WeVibe_Group19@34.45.92.51:5432/postgres" \
  --set-cloudsql-instances="appyyo-417016:us-central1:wevibe-postqre" \
  --update-env-vars AUTH_PROVIDER_MODE="firebase" \
  --session-affinity \
  --timeout=3600 \
  --region us-central1 \
  --allow-unauthenticated
