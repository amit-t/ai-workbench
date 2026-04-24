---
layout: default
title: Steering, GitHub App setup
parent: Steering
permalink: /steering/setup/
---

# Steering, drift-digest GitHub App setup

The weekly drift digest (`M2`) runs as a GitHub Action in this template repo. It queries the org for every stamped workbench (repos tagged with the `ai-workbench` GitHub topic), reads each repo's `steering.local/` tree, and posts a digest issue back to this template repo.

The action needs org-wide read-only access to repos matching the `ai-workbench` topic. A GitHub App installation token is the cleanest way to provide that.

## One-time setup (done by a GitHub org owner)

1. **Create a GitHub App.**
   - Org Settings → Developer settings → GitHub Apps → New GitHub App.
   - Name: `ai-workbench-drift-digest`.
   - Homepage URL: this template repo's URL.
   - Webhook: disabled (the action triggers on cron, not on webhook).
   - **Repository permissions:**
     - Contents: **Read-only**.
     - Metadata: **Read-only** (required, default).
     - Issues: **Read and write** (only for the template repo, where the digest issue is posted).
   - **Organization permissions:** none needed.
   - Where can this GitHub App be installed? **Only on this account.**
   - Create the app.

2. **Install the App on the org.**
   - After creation, click "Install App" in the app's settings sidebar.
   - Choose the org (e.g. `Invenco-Cloud-Systems-ICS`).
   - **Repository access:** "Only select repositories" → include this template repo (for issue write) and every `wb-*` repo matching the `ai-workbench` topic (for content read).
   - If you prefer one-shot setup: "All repositories" is acceptable since all permissions are read-only except on this template's issues.
   - Confirm install.

3. **Generate a private key for the App.**
   - In the App settings → General → Private keys → Generate a private key. A `.pem` file downloads.
   - This file is the secret credential. Do not commit it.

4. **Add secrets to this template repo.**
   - Repo → Settings → Secrets and variables → Actions → New repository secret.
   - `AI_WORKBENCH_APP_ID`: the App ID (numeric, visible on the App settings page).
   - `AI_WORKBENCH_APP_PRIVATE_KEY`: the full contents of the `.pem` file (paste verbatim, including the BEGIN/END lines).

5. **Verify.**
   - Workflow file: `.github/workflows/drift-digest.yml`.
   - Trigger a manual run: `gh workflow run "steering drift digest" -R <org>/ai-workbench`.
   - Confirm a new issue titled `steering drift digest, week of <date>` appears with the expected content. It will be empty if no stamped wb has non-empty `steering.local/`.

## Ongoing expectations

- `init.wb` must tag every stamped workbench with the `ai-workbench` GitHub topic. Without the topic, the drift digest cannot see the repo. (The devkit-side change to `init.wb` is tracked as a follow-up.)
- If the template repo moves to a different org, re-install the App in the new org. The App is reusable; secrets must be re-added to the new template repo.
- Rotate the private key on the App's usual rotation cadence. Replace `AI_WORKBENCH_APP_PRIVATE_KEY` when rotating.

## Troubleshooting

- **"gh api returned 401"**, token invalid or expired. Re-run the `actions/create-github-app-token` step manually or regenerate the App's private key.
- **"No repos found"**, either the topic has not been applied to any wb, or the App is not installed on those repos. Check the App's installation repo list.
- **"Rate limited"**, unlikely for weekly runs, but if the org has > 500 wbs, batch the content-fetch calls or reduce the per-wb scan to metadata only.
