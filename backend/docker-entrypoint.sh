#!/usr/bin/env bash
set -e

export LOG_CHANNEL="${LOG_CHANNEL:-stderr}"

if [ -z "${APP_KEY:-}" ]; then
  echo "[Shortzz] ERROR: APP_KEY is missing in Railway Variables!" >&2
fi
if [ -z "${DB_HOST:-}" ] && [ -z "${DATABASE_URL:-}" ] && [ -z "${MYSQL_URL:-}" ]; then
  echo "[Shortzz] ERROR: DB_HOST / DATABASE_URL is missing in Railway Variables!" >&2
fi

PORT="${PORT:-8080}"
sed -i "s/Listen 80/Listen ${PORT}/g" /etc/apache2/ports.conf
sed -i "s/<VirtualHost \*:80>/<VirtualHost *:${PORT}>/g" /etc/apache2/sites-available/000-default.conf

if [ -n "${GOOGLE_CREDENTIALS_JSON:-}" ]; then
  printf '%s' "${GOOGLE_CREDENTIALS_JSON}" > /var/www/html/googleCredentials.json
elif [ ! -s /var/www/html/googleCredentials.json ]; then
  printf '{"type":"service_account","project_id":"shortzz-new"}' > /var/www/html/googleCredentials.json
fi

mkdir -p /var/www/html/storage/app/public/uploads \
  /var/www/html/storage/framework/cache \
  /var/www/html/storage/framework/sessions \
  /var/www/html/storage/framework/views \
  /var/www/html/storage/logs \
  /var/www/html/bootstrap/cache

# Extract bundled language CSVs into storage/app/public/uploads/
if [ -f /var/www/html/app_languages.zip ]; then
  unzip -oq /var/www/html/app_languages.zip -d /var/www/html/storage/app/public/uploads/ || true
fi

chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

# Auto-import shortzz_database.sql and ensure default languages exist
if [ -f /var/www/html/database/shortzz_database.sql ]; then
  php -r '
    $url = getenv("DATABASE_URL") ?: getenv("MYSQL_URL");
    if ($url) {
        $p = parse_url($url);
        $host = $p["host"] ?? "";
        $port = $p["port"] ?? 3306;
        $db   = ltrim($p["path"] ?? "", "/");
        $user = $p["user"] ?? "";
        $pass = $p["pass"] ?? "";
    } else {
        $host = getenv("DB_HOST") ?: getenv("MYSQLHOST");
        $port = getenv("DB_PORT") ?: (getenv("MYSQLPORT") ?: 3306);
        $db   = getenv("DB_DATABASE") ?: getenv("MYSQLDATABASE");
        $user = getenv("DB_USERNAME") ?: getenv("MYSQLUSER");
        $pass = getenv("DB_PASSWORD") ?: getenv("MYSQLPASSWORD");
    }
    if (!$host || !$db || !$user) {
        fwrite(STDERR, "[Shortzz] Skipping auto SQL check: DB credentials incomplete.\n");
        exit(0);
    }
    for ($i = 0; $i < 10; $i++) {
        try {
            $pdo = new PDO("mysql:host={$host};port={$port};dbname={$db};charset=utf8mb4", $user, $pass, [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_TIMEOUT => 5,
            ]);
            $exists = $pdo->query("SHOW TABLES LIKE \"tbl_settings\"")->fetchColumn();
            if (!$exists) {
                fwrite(STDOUT, "[Shortzz] Empty database detected. Importing database/shortzz_database.sql...\n");
                $cmd = sprintf(
                    "MYSQL_PWD=%s mysql --skip-ssl -h %s -P %s -u %s %s < /var/www/html/database/shortzz_database.sql",
                    escapeshellarg($pass),
                    escapeshellarg($host),
                    escapeshellarg((string)$port),
                    escapeshellarg($user),
                    escapeshellarg($db)
                );
                passthru($cmd, $ret);
                if ($ret !== 0) {
                    fwrite(STDERR, "[Shortzz] Auto SQL import failed with exit code {$ret}.\n");
                } else {
                    fwrite(STDOUT, "[Shortzz] Database schema imported successfully!\n");
                }
            }

            // Ensure default languages exist in `languages` table so the Flutter app passes the splash screen
            $langCount = (int) $pdo->query("SELECT COUNT(*) FROM `languages`")->fetchColumn();
            if ($langCount === 0) {
                fwrite(STDOUT, "[Shortzz] Seeding default languages (English & Hindi) into `languages` table...\n");
                $stmt = $pdo->prepare("INSERT INTO `languages` (`code`, `title`, `localized_title`, `csv_file`, `status`, `is_default`) VALUES (?, ?, ?, ?, ?, ?)");
                $stmt->execute(["en", "English", "English", "uploads/English.csv", 1, 1]);
                $stmt->execute(["hi", "Hindi", "हिन्दी", "uploads/Hindi.csv", 1, 0]);
                fwrite(STDOUT, "[Shortzz] Default languages seeded!\n");
            }
            exit(0);
        } catch (Throwable $e) {
            fwrite(STDERR, "[Shortzz] Waiting for MySQL ({$host}:{$port}): " . $e->getMessage() . "\n");
            sleep(2);
        }
    }
  ' || true
fi

php artisan storage:link || true
php artisan config:clear || true
php artisan route:clear || true
php artisan view:clear || true

rm -f /etc/apache2/mods-enabled/mpm_event.* /etc/apache2/mods-enabled/mpm_worker.* || true
a2enmod mpm_prefork >/dev/null 2>&1 || true

exec apache2-foreground
