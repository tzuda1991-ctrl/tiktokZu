# Shortzz — Railway + GitHub Actions Monorepo

Cleaned and structured repository for deploying the **Shortzz** Laravel backend on **Railway** and building Android APKs via **GitHub Actions**.

## Structure

- `backend/` — Laravel 10 API & Admin Panel (with `Dockerfile`, `docker-entrypoint.sh`, `railway.json`, Railway HTTPS proxy fixes)
- `flutter_app/` — Flutter mobile client (`--dart-define` support for `BASE_URL` and `API_KEY`)
- `shortzz_database.sql` — MySQL schema & initial seed data
- `.github/workflows/build-apk.yml` — Automated Android Release APK build workflow

## 1. Deploy Backend on Railway

1. Create a Railway project from this GitHub repository.
2. In service **Settings → Root Directory**, set `/backend`.
3. Add a **MySQL** database service in the same Railway project.
4. Set environment variables on the backend service:
   - `APP_NAME=Shortzz`
   - `APP_ENV=production`
   - `APP_DEBUG=false`
   - `APP_KEY=base64:...`
   - `APP_URL=https://YOUR-SERVICE.up.railway.app`
   - `APP_API_KEY=your_secret_api_key`
   - `DB_CONNECTION=mysql`
   - `DB_HOST=${{MySQL.MYSQLHOST}}`
   - `DB_PORT=${{MySQL.MYSQLPORT}}`
   - `DB_DATABASE=${{MySQL.MYSQLDATABASE}}`
   - `DB_USERNAME=${{MySQL.MYSQLUSER}}`
   - `DB_PASSWORD=${{MySQL.MYSQLPASSWORD}}`
   - `FILES_STORAGE_LOCATION=PUBLIC` *(or `AWSS3` / `DOSPACE`)*
   - `FILESYSTEM_DRIVER=public`
   - `NOTIFICATION_TOPIC=shortzz`
   - `GOOGLE_CREDENTIALS_JSON=<paste Firebase service account JSON>`
5. If using `FILES_STORAGE_LOCATION=PUBLIC`, attach a **Railway Volume** mounted at `/var/www/html/storage/app/public`.
6. Import `shortzz_database.sql` into Railway MySQL using its public connection URL.

## 2. Build APK via GitHub Actions

1. In GitHub **Settings → Secrets and variables → Actions**:
   - Add Variable `BASE_URL` = `https://YOUR-SERVICE.up.railway.app/` (trailing slash required)
   - Add Secret `API_KEY` = same value as `APP_API_KEY`
   - *(Optional)* Add Secret `GOOGLE_SERVICES_JSON_BASE64` = base64 of your `google-services.json`
2. Open the **Actions** tab → **Build Shortzz Release APK** → **Run workflow** (or push to `flutter_app/**`).
3. Download the built APK from **Artifacts → shortzz-release-apk**.
