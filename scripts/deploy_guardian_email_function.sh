#!/usr/bin/env bash
set -euo pipefail

PROJECT_REF="${SUPABASE_PROJECT_REF:-zwjdxizbakfhklpjoalt}"
APP_PUBLIC_URL="${APP_PUBLIC_URL:-https://futboltalent.pro}"
RESEND_FROM_EMAIL="${RESEND_FROM_EMAIL:-FutbolTalent <onboarding@futboltalent.pro>}"

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "Missing SUPABASE_ACCESS_TOKEN. Create one in Supabase Dashboard > Account > Access Tokens." >&2
  exit 1
fi

if [[ -z "${RESEND_API_KEY:-}" ]]; then
  echo "Missing RESEND_API_KEY. Create one in Resend and export it before deploy." >&2
  exit 1
fi

npx supabase secrets set \
  "RESEND_API_KEY=${RESEND_API_KEY}" \
  "RESEND_FROM_EMAIL=${RESEND_FROM_EMAIL}" \
  "APP_PUBLIC_URL=${APP_PUBLIC_URL}" \
  --project-ref "${PROJECT_REF}"

npx supabase functions deploy send-guardian-validation-email \
  --project-ref "${PROJECT_REF}"

echo "Guardian validation email function deployed to ${PROJECT_REF}."
