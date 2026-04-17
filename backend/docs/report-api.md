# Report API Documentation

This document describes the reporting functionality for the WeVibe app backend.

## Overview

Users can report other users they are matched with for various inappropriate behaviors. The reporting system helps maintain a safe community by allowing users to flag problematic behavior.

## Database Schema

The `user_reports` table stores all reports with the following fields:
- `id`: UUID primary key
- `reporter_user_id`: User who submitted the report
- `reported_user_id`: User being reported
- `match_id`: Optional reference to the match where the incident occurred
- `reason`: Reason for the report (see valid reasons below)
- `details`: Optional additional details
- `created_at`: Timestamp when the report was submitted

## API Endpoints

### POST /api/v1/reports
Submit a report for a user.

**Authentication:** Required (Firebase Auth)

**Request Body:**
```json
{
  "reportedUserId": "string (required)",
  "reason": "string (required)",
  "details": "string (optional)",
  "matchId": "string (optional)"
}
```

**Valid Reasons:**
- `inappropriate_content`
- `harassment`
- `spam`
- `fake_profile`
- `underage`
- `scam`
- `hate_speech`
- `violence`
- `other`

**Response:**
```json
{
  "success": true,
  "message": "Report submitted successfully"
}
```

**Error Codes:**
- `INVALID_REPORTED_USER_ID`: reportedUserId is missing or invalid
- `INVALID_REPORT_REASON`: reason is missing or invalid
- `INVALID_REPORT_DETAILS`: details is not a string
- `INVALID_MATCH_ID`: matchId is not a string
- `SELF_REPORT_NOT_ALLOWED`: Users cannot report themselves
- `REPORTED_USER_NOT_FOUND`: The reported user does not exist
- `DUPLICATE_REPORT`: User has already reported this match

### GET /api/v1/reports
Get all reports submitted by the authenticated user.

**Authentication:** Required (Firebase Auth)

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "reporter_user_id": "uuid",
      "reported_user_id": "uuid",
      "match_id": "uuid",
      "reason": "string",
      "details": "string",
      "created_at": "timestamp",
      "users_user_reports_reported": {
        "id": "uuid",
        "email": "string"
      },
      "matches": { ... }
    }
  ]
}
```

### GET /api/v1/reports/user/:userId
Get all reports for a specific user (admin endpoint).

**Authentication:** Required (Firebase Auth)

**Parameters:**
- `userId`: UUID of the user to get reports for

**Response:** Same as GET /api/v1/reports

### GET /api/v1/reports/count/:userId
Get the count of reports for a specific user.

**Authentication:** Required (Firebase Auth)

**Parameters:**
- `userId`: UUID of the user to get report count for

**Response:**
```json
{
  "success": true,
  "data": {
    "count": 5
  }
}
```

### GET /api/v1/reports/all
Get all reports in the system (admin endpoint).

**Authentication:** Required (Firebase Auth)

**Response:** Same as GET /api/v1/reports

## Business Logic

1. **Self-Reporting Prevention:** Users cannot report themselves
2. **Duplicate Prevention:** Users cannot report the same match multiple times
3. **Validation:** All reports are validated for required fields and valid reasons
4. **User Existence:** Both reporter and reported users must exist
5. **Optional Match Context:** Reports can be submitted with or without a specific match context

## Future Enhancements

- Admin dashboard for reviewing reports
- Automated actions based on report patterns (e.g., auto-ban for multiple reports)
- Report status tracking (pending, reviewed, resolved)
- Appeal system for reported users
- Report categories and severity levels