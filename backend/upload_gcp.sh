gcloud run deploy wevibe-backend19 \
  --source . \
  --set-cloudsql-instances="<gcp-project-id>:<region>:<cloud-sql-instance>" \
 --update-env-vars DATABASE_URL="$DATABASE_URL",AUTH_PROVIDER_MODE="firebase",FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID",UPSTASH_REDIS_URL="$UPSTASH_REDIS_URL" \
  --remove-env-vars GOOGLE_APPLICATION_CREDENTIALS \
  --session-affinity \
  --timeout=3600 \
  --region us-central1 \
  --allow-unauthenticated
