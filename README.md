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
