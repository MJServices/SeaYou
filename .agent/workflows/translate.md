---
description: How to synchronize localization files using Google Translate
---

This workflow automates the translation of missing keys in your localization files (`fr.json`, `de.json`, `es.json`) based on `en.json`.

### Prerequisites

1.  **Google Cloud API Key**: Follow these steps to get your key:
    - Go to the [Google Cloud Console](https://console.cloud.google.com/).
    - **Create a Project**: Click the project dropdown at the top and select "New Project". Give it a name like "SeaYou-Translation".
    - **Enable the API**: In the Search bar at the top, type "Cloud Translation API" and click it. Then click the **Enable** button.
    - **Create Credentials**:
      - Go to **APIs & Services > Credentials** in the left sidebar.
      - Click **+ CREATE CREDENTIALS** at the top and select **API key**.
      - A popup will show your API key. Copy it!
    - **(Optional) Restrict Key**: For security, click "Edit" on the new key and under "API restrictions", select "Restrict key" and choose "Cloud Translation API" from the list. Save it.

2.  **Add API Key to .env**:
    Add the following line to your `e:/seayou_app/.env` file:
    ```
    GOOGLE_TRANSLATE_API_KEY=your_actual_api_key_here
    ```

### Running the Translation Sync

// turbo

1. Run the following command in your terminal:
   ```powershell
   dart scripts/translate_sync.dart
   ```

### How it works

- It uses `assets/i18n/en.json` as the source of truth.
- It scans for keys that exist in `en.json` but are missing or empty in target files.
- It translates missing values while preserving placeholders like `{count}` or `{{name}}`.
- It sorts the resulting JSON files alphabetically by key for better readability.
