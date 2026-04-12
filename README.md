# SoloIVA

Web application for **Spanish freelancers** (*autónomos*) who need a lightweight way to record **issued and received invoices**, track **VAT (IVA)** by line, and see a **quarterly summary aligned with Modelo 303** (Spain’s periodic VAT return). Data is **per user**; there is no multi-tenant billing layer—just your own invoice ledger and reports.

---

## What it does

- **Invoices** — Each invoice has a type (*emitida* / *recibida*), header fields (number, date, issuer NIF/name, etc.), and **multiple VAT lines** (rate + taxable base; IVA quota is derived).
- **Import from files** — Upload a **PDF** or a **photo/scan** (JPEG, PNG, WebP). The app tries to extract structured invoice data using **Google Gemini** and **Groq** (with a **text heuristic fallback** for PDFs only). You can import from the **new invoice form** (immediate JSON response) or from the **review** page (background job, one file at a time per UX).
- **Pending review** — Imports can create invoices in a **pending** state; you **confirm** or edit them before they count in accounting totals.
- **Modelo 303 view** — For a chosen **calendar year and quarter**, the app aggregates **confirmed** invoice lines into totals useful for filling **Modelo 303** (issued vs received, by IVA rate). This is a **helper report**, not filed directly with the tax agency.
- **Authentication** — **Devise**; each user only sees their own invoices and uploads.
- **Google Drive (optional)** — After OAuth, **received** invoices that are **confirmed** (or created already confirmed) enqueue a job that uploads to Drive under **`Facturas / Recibidas / YYYY / MM`** by default (both folder names are editable). If the invoice came from the **async review upload**, the **original file** (PDF or image) is uploaded; otherwise a **generated summary PDF** is used.

---

## User-facing flows (short)

| Flow | Where | Behaviour |
| --- | --- | --- |
| Manual invoice | `Invoices` CRUD | Standard Rails forms; nested lines. |
| Quick import (single file) | New/edit invoice — drop zone | `POST` upload → JSON with one or more extracted invoices → form prefill or bulk save. |
| Batch import | Review page — drop zone | Each accepted file → `PdfUpload` + `ProcessPdfUploadJob` → Turbo Streams refresh queue and pending cards. |
| Confirm pending | Review | Moves invoice from `pending` to `confirmed` (included in Modelo 303 and list filters). |

Unsupported image formats (e.g. **HEIC** from some phones) are rejected with a clear message; users should export as **JPEG** or **PNG**.

---

## Technical architecture

- **Framework** — Ruby on Rails **8.1**, **Hotwire** (Turbo + Stimulus), **importmap** (no Node bundler for JS).
- **Database** — **PostgreSQL** with multiple DB configs: **primary** (app), **queue** (Solid Queue), **cable** (Solid Cable). Run `bin/rails db:prepare` (or `db:setup`) so all databases exist.
- **Background jobs** — **Solid Queue** (`config/queue.yml`). PDF/image import jobs use a dedicated **`pdf_import`** queue with **limited concurrency** to avoid hammering external APIs. In **development**, Puma can run Solid Queue in **async** mode (see `config/puma.rb`).
- **Real-time UI** — **Action Cable** + **Turbo Streams** for upload rows and pending-invoice panels on the review page.
- **Domain / structure** — Use cases under `app/use_cases/`, PDF/vision clients under `app/infrastructure/pdf/`, small value objects under `app/domain/` (e.g. `Modelo303Report`, `QuarterCalculator`, `PdfExtractionResult`).
- **Document parsing** — `ParseInvoiceDocument` branches on `InvoiceFileKind`: **PDF** → text extraction (`pdf-reader`) → Gemini → Groq → heuristics; **image** → **vision-only** (Gemini then Groq), no text heuristics on raw bytes.

---

## Requirements

- Ruby **3.3+** (see `.ruby-version` if present)
- **PostgreSQL** (9.5+)
- Bundler

---

## Getting started

```bash
bundle install
bin/rails db:prepare   # creates primary, queue, and cable DBs where configured
bin/rails server
```

Open the app, sign up or sign in, then use **Dashboard**, **Invoices**, **Review**, and **Reports → Modelo 303** as needed.

### Tests and lint

```bash
bundle exec rspec
bundle exec rubocop
```

---

## Configuration: AI keys

Invoice extraction uses **Google Gemini** (Generative Language API) and **Groq** (OpenAI-compatible chat; **multimodal** for images).

Add keys to **encrypted credentials**:

```bash
bin/rails credentials:edit
```

| Credential | Purpose |
| --- | --- |
| `gemini_api_key` | [Google AI Studio](https://aistudio.google.com/apikey) |
| `groq_api_key` | [Groq Console](https://console.groq.com/keys) |

**Optional:** set `GROQ_API_KEY` in the environment for local dev; it is used when `groq_api_key` is missing from credentials.

Without keys, PDF text extraction may still run, but **LLM steps are skipped** and results depend on **heuristics** (PDFs with poor or no text will often yield nothing). **Images** require vision APIs.

---

## Configuration: Google Drive backup (received invoices)

1. In [Google Cloud Console](https://console.cloud.google.com/), create or pick a project, enable the **Google Drive API**, and create **OAuth 2.0 Client ID** credentials of type **Web application**.
2. Add an **Authorized redirect URI** that matches your app exactly, e.g.  
   `http://localhost:3000/google_drive_settings/callback` (development) and your production URL in deploy.
3. Put the client id and secret in credentials (or use env vars):

```yaml
# bin/rails credentials:edit
google_oauth:
  client_id: "....apps.googleusercontent.com"
  client_secret: "...."
```

Alternatively set `GOOGLE_OAUTH_CLIENT_ID` and `GOOGLE_OAUTH_CLIENT_SECRET` in the environment.

4. Sign in to the app → **Google Drive** in the nav → **Conectar con Google** and approve access (scope: **drive.file** — only files this app creates).

**Original vs summary:** Invoices created by `ProcessPdfUploadJob` store a **copy** of the uploaded file on the invoice (`source_file_data` / `source_filename`), so the original is still available for Drive after you click **Quitar** on the upload row (which deletes the `PdfUpload`). The Drive job prefers that copy, then the live `PdfUpload`, then a **summary PDF**. Manually entered or form-only imports without a stored source get the summary only. Jobs run on the **`default`** Solid Queue worker.

In **development**, `config.action_controller.default_url_options` is set to `localhost:3000` so the OAuth callback URL matches Google Cloud. In **production**, set `APP_HOST` (and optionally `APP_PROTOCOL`) if full URLs must be generated outside a request (see `config/environments/production.rb`).

---

## Production notes

- Set `SOLO_IVA_DATABASE_PASSWORD` (and any other `database.yml` env vars) for the **primary** DB; configure **cache**, **queue**, and **cable** databases as in `config/database.yml`.
- Run Solid Queue workers in production (e.g. `bin/jobs` or your process manager) so `pdf_import` and `default` jobs execute.
- The repo includes **Kamal** and **Thruster** in the Gemfile for container-style deploys; adjust to your hosting.

---

## Project name

**SoloIVA** — *solo* (alone/simple) + **IVA** (VAT in Spanish). The product copy and tax concepts are Spain-specific; code and docs stay in **English** by convention.
