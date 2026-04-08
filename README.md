# SoloIVA

A simple invoice management app for Spanish freelancers (*autónomos*). Track issued and received invoices, calculate VAT (IVA), and generate quarterly tax reports (Modelo 303).

## Features

- **Invoice management** — create, edit, and delete issued and received invoices with multiple VAT lines
- **PDF import** — drag and drop a PDF invoice to auto-fill fields via AI parsing
- **Modelo 303** — automatic quarterly VAT report based on your invoices
- **Authentication** — secure per-user data via Devise

## Tech stack

- Ruby on Rails 8
- SQLite
- Tailwind CSS (via CDN)
- Devise for authentication

## Getting started

```bash
bundle install
rails db:setup
rails server
```

## AI keys (PDF invoice import)

Parsing uploaded PDFs tries **Google Gemini** first, then **Groq** if Gemini returns no invoices, then heuristics on the extracted text.

Add both keys to encrypted credentials:

```bash
bin/rails credentials:edit
```

| Key | Purpose |
| --- | --- |
| `gemini_api_key` | [Google AI Studio](https://aistudio.google.com/apikey) — Generative Language API |
| `groq_api_key` | [Groq Console](https://console.groq.com/keys) — OpenAI-compatible chat API |

For local development you can also set `GROQ_API_KEY` in the environment; if present, it is used when credentials do not define `groq_api_key` (or the credentials method is missing).
