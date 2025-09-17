# Google Calendar Integration Setup Guide

This guide explains how to set up Google Calendar integration for your Bandmate app, allowing bands to sync their gigs to Google Calendar.

## Overview

The Google Calendar integration allows each band to:
- Sync their gigs to a shared Google Calendar
- Have band members subscribe to the calendar in their personal Google Calendar
- Automatically sync when gigs are created, updated, or deleted
- Include venue information and setlists in calendar events

## Setup Steps

### 1. Create a Google Cloud Project

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Note your project ID

### 2. Enable the Google Calendar API

1. In the Google Cloud Console, go to "APIs & Services" > "Library"
2. Search for "Google Calendar API"
3. Click on it and press "Enable"

### 3. Create a Service Account

1. Go to "APIs & Services" > "Credentials"
2. Click "Create Credentials" > "Service Account"
3. Fill in the service account details:
   - Name: `bandmate-calendar-service`
   - Description: `Service account for Bandmate Google Calendar integration`
4. Click "Create and Continue"
5. Skip the "Grant access" step for now
6. Click "Done"

### 4. Generate Service Account Key

1. In the Credentials page, find your service account
2. Click on the service account email
3. Go to the "Keys" tab
4. Click "Add Key" > "Create new key"
5. Choose "JSON" format
6. Download the JSON file

### 5. Configure Environment Variables

1. Copy the downloaded JSON file content
2. Add it to your `.env` file as `GOOGLE_SERVICE_ACCOUNT_JSON`
3. The value should be the entire JSON object as a single line

Example:
```bash
GOOGLE_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"your-project-id",...}
```

### 6. Share Calendars with Service Account

For each band that wants to use Google Calendar integration:

1. **Option A: Use a Personal Calendar**
   - Go to [Google Calendar](https://calendar.google.com)
   - Find your calendar in the left sidebar
   - Click the three dots next to it
   - Select "Settings and sharing"
   - Under "Share with specific people", add the service account email
   - Give it "Make changes to events" permission
   - Copy the Calendar ID (usually your email address)

2. **Option B: Create a Shared Calendar**
   - In Google Calendar, click the "+" next to "Other calendars"
   - Select "Create new calendar"
   - Name it something like "Band Name - Gigs"
   - Click "Create calendar"
   - Go to "Settings and sharing" for the new calendar
   - Add the service account email with "Make changes to events" permission
   - Copy the Calendar ID from the "Integrate calendar" section

### 7. Configure Band Settings

1. In Bandmate, go to your band's edit page
2. Scroll down to "Google Calendar Integration"
3. Check "Enable Google Calendar Sync"
4. Enter the Calendar ID you copied in step 6
5. Click "Test Connection" to verify it works
6. Click "Save Calendar Settings"

## How It Works

### Automatic Sync
- When a gig is created, updated, or deleted, it automatically syncs to Google Calendar
- The sync happens in the background and won't slow down the app

### Event Details
Each gig becomes a Google Calendar event with:
- **Title**: Gig name
- **Date/Time**: Performance date and times
- **Location**: Venue name and address (if venue is set)
- **Description**: 
  - Band name
  - Venue details (name, location, phone)
  - Setlist (if songs are added to the gig)

### Band Member Access
- Band members can subscribe to the shared calendar in their personal Google Calendar
- They'll see all gigs automatically without needing to check the app
- Changes in the app are reflected in their calendar

## Troubleshooting

### "Connection failed" error
- Verify the Calendar ID is correct
- Ensure the service account has access to the calendar
- Check that the Google Calendar API is enabled
- Verify the service account JSON is properly formatted in `.env`

### "Permission denied" error
- Make sure the service account email is added to the calendar's sharing settings
- Ensure the service account has "Make changes to events" permission

### Events not syncing
- Check that Google Calendar sync is enabled for the band
- Verify the Calendar ID is correct
- Look at the server logs for error messages

### Service Account Email
The service account email looks like: `bandmate-calendar-service@your-project-id.iam.gserviceaccount.com`

## Security Notes

- The service account JSON contains sensitive credentials - keep it secure
- Never commit the `.env` file to version control
- The service account only has access to calendars you explicitly share with it
- Each band uses their own calendar - there's no cross-band data access

## Support

If you encounter issues:
1. Check the server logs for error messages
2. Verify all setup steps were completed correctly
3. Test the connection using the "Test Connection" button in band settings
4. Ensure the Google Calendar API is enabled and the service account has proper permissions

