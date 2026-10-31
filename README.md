# OFP Printing quote application

This repository contains the Rails quote-request app and the local Shopify theme in `shopify-theme/`. The quote flow validates and persists project-specific details, generates a private reference, and queues an OFP notification and Shopify Draft Order creation. The public confirmation page displays only the reference.

The app is **not deployed or connected to the live storefront yet**. The production database, Redis service, mail provider, Shopify app, app proxy, and theme have not been configured or verified.

## Current runtime

- Ruby `~> 3.4.0` (the inspected environment runs Ruby 3.4.8).
- Rails `~> 8.1.0` (the lockfile resolves Rails 8.1.3.1).
- PostgreSQL in production; SQLite remains in development and tests.
- Puma serves web requests. Sidekiq runs notification and Shopify jobs using Redis.
- Rails asset compilation is run during the release build; proxied pages load those assets from the Rails host.

## Production host: Render

Use one Render region for the Rails web service, Sidekiq worker, PostgreSQL, and Key Value (Redis-compatible) service. PostgreSQL persists quote data; Key Value provides a shared production rate-limit/form-token cache and Sidekiq queue. The repository includes a `Procfile` with the web and worker commands.

1. Create a managed Render PostgreSQL database and a paid/persistent Key Value instance. Keep them in the same region and workspace; use their **internal** connection URLs.
2. Create two Render services from this repository and branch:
   - Web build command: `bundle install && bundle exec rails assets:precompile`
   - Web start command: `bundle exec puma -C config/puma.rb`
   - Health check path: `/up`
   - Worker start command: `bundle exec sidekiq -C config/sidekiq.yml`
3. Configure the environment variables listed below on **both** services, including identical database, Redis, Rails secret, Shopify, and SMTP values. Render's database/Key Value connection URLs can be shared service references.
4. Configure a stable HTTPS service hostname, put its hostname (without scheme) in `APP_HOST`, and set the service's public static-file serving variable. The production Rails configuration requires HTTPS and serves precompiled assets from that hostname.
5. Before routing storefront traffic, run `bundle exec rails db:migrate` against the production database, deploy the worker, and verify `https://APP_HOST/up` returns HTTP 200.
6. Configure a verified sender and SMTP credentials with your email provider. Verify delivery to `info@ofpprinting.com` using an approved test request before launch.
7. Enable the database backup/PITR option available for the selected plan, choose a retention period, and test a restore to a separate database before launch.

### Production environment variables

Set secrets in Render's environment/secrets UI, never in the repository, theme, or browser code.

| Variable | Purpose / example |
|---|---|
| `RAILS_ENV` | `production` |
| `SECRET_KEY_BASE` | Generate with `bin/rails secret` and store as a secret; this app has no encrypted credentials file |
| `DATABASE_URL` | Render PostgreSQL internal connection URL |
| `REDIS_URL` | Render Key Value internal connection URL |
| `RAILS_SERVE_STATIC_FILES` | `true` |
| `APP_HOST` | Rails service hostname only, e.g. `ofp-quote-service.onrender.com` |
| `SHOPIFY_STORE_DOMAIN` | Expected permanent store domain, e.g. `your-store.myshopify.com` |
| `SHOPIFY_APP_PROXY_PATH_PREFIX` | `/apps/ofp-quotes` (must match the Shopify app proxy URL) |
| `SHOPIFY_STOREFRONT_ORIGINS` | Comma-separated exact storefront origins, e.g. `https://www.ofpprinting.com` |
| `SHOPIFY_API_KEY` | Server-side app client ID |
| `SHOPIFY_API_SECRET` | Secret app client secret; used for proxy HMAC and token exchange |
| `SHOPIFY_ADMIN_API_VERSION` | `2026-10` (pinned, supported version) |
| `OFP_MAIL_FROM` | Verified sender address for OFP notification mail |
| `SMTP_ADDRESS` | SMTP host from your provider |
| `SMTP_PORT` | Usually `587` |
| `SMTP_USERNAME` | SMTP credential |
| `SMTP_PASSWORD` | Secret SMTP credential |
| `SMTP_DOMAIN` | SMTP HELO domain, usually `ofpprinting.com` |
| `SMTP_AUTHENTICATION` | Provider-required method, normally `plain` |

The app obtains and caches a Shopify Admin API access token on the server using Shopify's client-credentials grant; tokens expire after 24 hours and the cache refreshes them before expiry. That grant is only suitable when the app and store are in the same Shopify organization. If they are not, stop before launch: the app needs an installed-app OAuth/token-exchange flow instead.

### Release, health, backup, and rollback

- Build/release: `bundle install`, `bundle exec rails assets:precompile`, then `bundle exec rails db:migrate`; deploy the web service and worker from the same commit.
- Health: `GET /up` checks that the Rails process is serving requests. Separately monitor PostgreSQL, Redis/Sidekiq queue depth, failed jobs, SMTP delivery, and the Shopify integration statuses.
- Backups: use managed PostgreSQL backups/PITR and test restores. Do not treat the Rails container filesystem or SQLite as persistent production storage.
- Rollback: redeploy the last known-good web **and worker** release together. Keep migrations additive and backward-compatible across that rollback. If a data migration cannot be rolled back safely, restore a verified database backup to a separate database and follow the provider's recovery procedure; do not delete quote records to roll back code.
- Integration recovery: inspect Sidekiq failures and the quote's stored integration status. After correcting the cause and confirming no active/scheduled retry remains, enqueue pending or failed integrations with `bin/rails quotes:retry_integrations[OFP-REFERENCE]`. Draft-order retries first search Shopify for the request's unique tag and reuse a found order.

## Shopify app proxy

The theme's quote links use `/apps/ofp-quotes`. Shopify's current app-proxy configuration supports the `apps` prefix and a subpath of `ofp-quotes`; its target is the Rails endpoint `/shopify/proxy`. The app proxy is configured on a Shopify app, not by theme code alone.

1. In Shopify's Dev Dashboard, create/configure an app owned by the **same Shopify organization as the OFP store**. Set its app URL to the deployed HTTPS Rails host.
2. Add only the required Admin API scopes to the app version: `write_app_proxy` (proxy configuration), `read_draft_orders` (look up a request's unique order tag before retry), and `write_draft_orders` (create the unpriced Draft Order). Release the version and install/update the app on the OFP store, approving those scopes.
   The installing store user must also have permission to manage Draft Orders.
3. Configure the app proxy:
   - Prefix: `apps`
   - Subpath: `ofp-quotes`
   - Proxy URL/target: `https://APP_HOST/shopify/proxy`
4. Set the app client ID and secret in Render's backend environment variables. Never put them, an Admin API token, or any secret in Liquid, JavaScript, the theme ZIP, or a storefront request body.
5. Keep `SHOPIFY_STORE_DOMAIN` set to the shop's permanent `.myshopify.com` domain, and `SHOPIFY_APP_PROXY_PATH_PREFIX=/apps/ofp-quotes`. If an administrator customizes the proxy path, update this variable and the local theme links together.
6. Install the updated local theme only after the backend and app proxy are configured. This repository change does not upload or publish a theme.
7. In a staging/test window, verify a signed GET, form submission, validation failure, confirmation, queued notification, and a test Draft Order. Do not perform the test with real email delivery or Shopify writes until you approve it.

The app verifies Shopify's documented query-string HMAC with the app secret, expected `shop`, configured `path_prefix`, and a five-minute timestamp window. App proxies strip cookies and `Set-Cookie`; the form therefore uses an expiring one-use token stored in shared Redis rather than a Rails cookie session. Rails CSRF verification is skipped only for the proxied quote-create action, after proxy authentication, with that one-use token required. It is not disabled globally. Quote submission remains rate-limited through shared Redis, and the existing honeypot remains active.

The proxy confirmation page returns only the high-entropy reference, never contact information or project details. Its links use Shopify's verified `path_prefix` so the proxy can be traversed without assuming the browser's URL is also the Rails URL. Rails assets load from the backend host and allow cross-origin reads only from the configured storefront origin(s).

Shopify can introduce additional signed query parameters. The verifier includes all query parameters except `signature` in the HMAC calculation, as Shopify documents. It does not rely on cookies or a logged-in customer ID.

## Pre-launch checklist

- [ ] Confirm the Shopify app and OFP store are in the same Shopify organization, or implement the required OAuth flow before launch.
- [ ] Set all production environment variables on both Render services; confirm secrets are stored only in Render.
- [ ] Verify PostgreSQL backups and a restore; verify Redis persistence and the Sidekiq worker is processing jobs.
- [ ] Run migrations and asset compilation; check `/up` and backend-host asset CORS from the storefront origin.
- [ ] Install the Shopify app with the required scopes and verify `/apps/ofp-quotes` forwards to the Rails app.
- [ ] Compare the three-step form and confirmation against the current Codespaces preview; verify project-specific questions, validation, consent, keyboard flow, and mobile layout.
- [ ] Test notification and Draft Order behavior using a non-production mail recipient/store or with your explicit approval. Confirm the Draft Order is tagged, unpriced, and linked to the quote reference.
- [ ] Check logs, integration statuses, Sidekiq retries, and the documented recovery command before switching live theme links.
- [ ] Update/publish the Shopify theme yourself only after all checks pass; this repository work has not changed the live theme.

## Data and integrations

Quote validation remains in `QuoteRequest`, including selected project details, required conditional answers, consent, phone preference, delivery method, and date ordering. Only permitted fields are persisted. Notification and Draft Order outcomes are recorded separately (`queued`, `processing`, `sent`/`created`, or `failed`) and failures are logged and surfaced on the reference-only confirmation page.

Draft Orders are unpriced intake placeholders and must be reviewed and priced by OFP before an invoice is sent. A unique quote tag and serialized per-request job reduce duplicate Draft Orders if a job is retried or a response is interrupted. No automated test makes a real network call or sends a real email.

## Local checks

```sh
bundle exec rails db:migrate
bin/rails test
```

Proxy verification tests use a test secret and generated HMAC values. Shopify and email calls in tests are mocked.

## Official Shopify references

- [App proxies and configuration](https://shopify.dev/docs/apps/build/online-store/app-proxies)
- [Authenticate app-proxy requests](https://shopify.dev/docs/apps/build/online-store/app-proxies/authenticate-app-proxies)
- [Client-credentials grant and 24-hour token expiry](https://shopify.dev/docs/apps/build/authentication-authorization/client-credentials-grant)
- [Draft Order creation](https://shopify.dev/docs/api/admin-graphql/2026-10/mutations/draftOrderCreate)
- [Admin API access scopes](https://shopify.dev/docs/api/usage/access-scopes)

## Official Render references

- [Deploy Rails 8](https://render.com/docs/deploy-rails-8)
- [Deploy Rails with Sidekiq](https://render.com/docs/deploy-rails-sidekiq)
- [Render PostgreSQL](https://render.com/docs/postgresql)
- [Render Key Value](https://render.com/docs/key-value)
