import { useMemo, useState } from 'react';
import {
  Check,
  Copy,
  Database,
  FolderGit2,
  KeyRound,
  RefreshCw,
  Server,
  Smartphone,
} from 'lucide-react';

type SectionId = 'overview' | 'railway' | 'actions';

interface RepoArtifact {
  path: string;
  target: 'Railway' | 'GitHub Actions' | 'Database' | 'Repo';
  purpose: string;
  state: 'Configured' | 'Needs User Secrets';
}

const REPO_ARTIFACTS: RepoArtifact[] = [
  {
    path: 'backend/Dockerfile',
    target: 'Railway',
    purpose: 'PHP 8.2 Apache container with GD, Zip, PDO MySQL, and 256 MB upload limits',
    state: 'Configured',
  },
  {
    path: 'backend/docker-entrypoint.sh',
    target: 'Railway',
    purpose: 'Binds Railway $PORT, links storage, clears config cache, writes googleCredentials.json',
    state: 'Configured',
  },
  {
    path: 'backend/railway.json',
    target: 'Railway',
    purpose: 'Forces Dockerfile builder and failure restart policy',
    state: 'Configured',
  },
  {
    path: 'backend/app/Http/Middleware/TrustProxies.php',
    target: 'Railway',
    purpose: 'Trusts Railway reverse proxy headers (*)',
    state: 'Configured',
  },
  {
    path: 'backend/app/Providers/AppServiceProvider.php',
    target: 'Railway',
    purpose: 'Forces HTTPS scheme in production',
    state: 'Configured',
  },
  {
    path: 'backend/app/Http/Middleware/CheckHeader.php',
    target: 'Railway',
    purpose: 'Reads APP_API_KEY via config(app.api_key) with retry123 fallback',
    state: 'Configured',
  },
  {
    path: '.github/workflows/build-apk.yml',
    target: 'GitHub Actions',
    purpose: 'Java 17 + Flutter stable release APK build and artifact upload',
    state: 'Configured',
  },
  {
    path: 'flutter_app/lib/utilities/const_res.dart',
    target: 'GitHub Actions',
    purpose: 'Supports --dart-define BASE_URL, API_KEY, and RevenueCat keys',
    state: 'Needs User Secrets',
  },
  {
    path: 'shortzz_database.sql',
    target: 'Database',
    purpose: 'MySQL schema and initial seed data ready for Railway MySQL import',
    state: 'Needs User Secrets',
  },
  {
    path: 'flutter_app/android/app/google-services.json',
    target: 'GitHub Actions',
    purpose: 'Override via GOOGLE_SERVICES_JSON_BASE64 secret or replace directly',
    state: 'Needs User Secrets',
  },
];

function generateLaravelKey(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  let binary = '';
  for (let i = 0; i < bytes.length; i += 1) {
    binary += String.fromCharCode(bytes[i]);
  }
  return `base64:${btoa(binary)}`;
}

function generateApiKey(): string {
  const bytes = new Uint8Array(18);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
}

export default function App() {
  const [activeTab, setActiveTab] = useState<SectionId>('overview');
  const [filterTarget, setFilterTarget] = useState<string>('All');
  const [railwayDomain, setRailwayDomain] = useState<string>('https://tiktokzu-backend.up.railway.app');
  const [appKey, setAppKey] = useState<string>(() => generateLaravelKey());
  const [apiKey, setApiKey] = useState<string>(() => generateApiKey());
  const [storageMode, setStorageMode] = useState<'PUBLIC' | 'AWSS3' | 'DOSPACE'>('PUBLIC');
  const [mysqlUrl, setMysqlUrl] = useState<string>('mysql://root:PASSWORD@HOST:PORT/railway');
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const normalizedUrl = useMemo(() => {
    const trimmed = railwayDomain.trim().replace(/\/+$/, '');
    return trimmed || 'https://your-service.up.railway.app';
  }, [railwayDomain]);

  const railwayEnvText = useMemo(() => {
    const lines = [
      'APP_NAME=Shortzz',
      'APP_ENV=production',
      'APP_DEBUG=false',
      `APP_KEY=${appKey}`,
      `APP_URL=${normalizedUrl}`,
      `APP_API_KEY=${apiKey}`,
      'NOTIFICATION_TOPIC=shortzz',
      'DB_CONNECTION=mysql',
      'DB_HOST=${{MySQL.MYSQLHOST}}',
      'DB_PORT=${{MySQL.MYSQLPORT}}',
      'DB_DATABASE=${{MySQL.MYSQLDATABASE}}',
      'DB_USERNAME=${{MySQL.MYSQLUSER}}',
      'DB_PASSWORD=${{MySQL.MYSQLPASSWORD}}',
      `FILES_STORAGE_LOCATION=${storageMode}`,
      'FILESYSTEM_DRIVER=public',
      'GOOGLE_CREDENTIALS_JSON=<paste-firebase-service-account-json>',
    ];

    if (storageMode === 'AWSS3') {
      lines.push(
        'AWS_ACCESS_KEY_ID=',
        'AWS_SECRET_ACCESS_KEY=',
        'AWS_DEFAULT_REGION=ap-south-1',
        'AWS_BUCKET=',
        'ITEM_BASE_URL='
      );
    } else if (storageMode === 'DOSPACE') {
      lines.push(
        'DO_SPACE_ACCESS_KEY_ID=',
        'DO_SPACE_SECRET_ACCESS_KEY=',
        'DO_SPACE_REGION=blr1',
        'DO_SPACE_BUCKET=',
        'DO_SPACE_ENDPOINT=https://blr1.digitaloceanspaces.com',
        'DO_SPACE_URL='
      );
    }

    return lines.join('\n');
  }, [appKey, apiKey, normalizedUrl, storageMode]);

  const mysqlImportCommand = useMemo(() => {
    const match = mysqlUrl.match(/^mysql:\/\/([^:]+):([^@]+)@([^:]+):(\d+)\/(.+)$/);
    if (!match) {
      return 'mysql -h <MYSQLHOST> -P <MYSQLPORT> -u root -p<MYSQLPASSWORD> railway < shortzz_database.sql';
    }
    const [, user, pass, host, port, db] = match;
    return `mysql -h ${host} -P ${port} -u ${user} -p${pass} ${db} < shortzz_database.sql`;
  }, [mysqlUrl]);

  const flutterBuildCommand = useMemo(() => {
    return `flutter build apk --release --dart-define=BASE_URL=${normalizedUrl}/ --dart-define=API_KEY=${apiKey}`;
  }, [normalizedUrl, apiKey]);

  const filteredArtifacts = useMemo(() => {
    if (filterTarget === 'All') return REPO_ARTIFACTS;
    return REPO_ARTIFACTS.filter((item) => item.target === filterTarget);
  }, [filterTarget]);

  const copyValue = async (id: string, value: string) => {
    await navigator.clipboard.writeText(value);
    setCopiedId(id);
    window.setTimeout(() => {
      setCopiedId((prev) => (prev === id ? null : prev));
    }, 1800);
  };

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900">
      <header className="border-b border-slate-200 bg-white">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-8 px-6 py-4">
          <a
            href="#top"
            className="text-lg font-bold tracking-tight text-slate-900 whitespace-nowrap shrink-0"
          >
            Shortzz Deploy Hub
          </a>

          <nav className="hidden md:flex items-center gap-6 text-sm font-medium text-slate-600">
            <button
              type="button"
              onClick={() => setActiveTab('overview')}
              className={`whitespace-nowrap shrink-0 cursor-pointer transition-colors ${
                activeTab === 'overview' ? 'text-slate-900 underline underline-offset-8' : 'hover:text-slate-900'
              }`}
            >
              Repo Files
            </button>
            <button
              type="button"
              onClick={() => setActiveTab('railway')}
              className={`whitespace-nowrap shrink-0 cursor-pointer transition-colors ${
                activeTab === 'railway' ? 'text-slate-900 underline underline-offset-8' : 'hover:text-slate-900'
              }`}
            >
              Railway Setup
            </button>
            <button
              type="button"
              onClick={() => setActiveTab('actions')}
              className={`whitespace-nowrap shrink-0 cursor-pointer transition-colors ${
                activeTab === 'actions' ? 'text-slate-900 underline underline-offset-8' : 'hover:text-slate-900'
              }`}
            >
              APK Actions
            </button>
          </nav>

          <button
            type="button"
            onClick={() => copyValue('header-env', railwayEnvText)}
            className="inline-flex items-center gap-2 rounded-lg bg-slate-900 px-4 py-2 text-xs font-semibold text-white transition-colors hover:bg-slate-800 whitespace-nowrap shrink-0 cursor-pointer"
          >
            {copiedId === 'header-env' ? <Check className="h-3.5 w-3.5" /> : <Copy className="h-3.5 w-3.5" />}
            <span>{copiedId === 'header-env' ? 'Copied Env' : 'Copy Railway Env'}</span>
          </button>
        </div>
      </header>

      <main className="mx-auto max-w-6xl px-6 py-8">
        <div className="mb-8 flex flex-col gap-4 border-b border-slate-200 pb-6 md:flex-row md:items-end md:justify-between">
          <div className="max-w-2xl">
            <p className="text-xs font-medium text-slate-500">
              tzuda1991-ctrl/tiktokZu · Laravel 10 Backend · Flutter 3.41+ Client
            </p>
            <h1 className="mt-1 text-2xl font-bold tracking-tight text-slate-900 sm:text-3xl">
              Repository prepared for Railway and GitHub Actions
            </h1>
            <p className="mt-2 text-sm leading-relaxed text-slate-600">
              Duplicate nested archives and build caches are removed. Use the tabs below to inspect modified files,
              generate production Railway variables, and configure automated Android APK builds.
            </p>
          </div>

          <div className="flex items-center gap-1 rounded-lg bg-slate-200/70 p-1 md:hidden">
            <button
              type="button"
              onClick={() => setActiveTab('overview')}
              className={`rounded-md px-3 py-1.5 text-xs font-medium whitespace-nowrap shrink-0 cursor-pointer ${
                activeTab === 'overview' ? 'bg-white text-slate-900' : 'text-slate-600'
              }`}
            >
              Repo Files
            </button>
            <button
              type="button"
              onClick={() => setActiveTab('railway')}
              className={`rounded-md px-3 py-1.5 text-xs font-medium whitespace-nowrap shrink-0 cursor-pointer ${
                activeTab === 'railway' ? 'bg-white text-slate-900' : 'text-slate-600'
              }`}
            >
              Railway
            </button>
            <button
              type="button"
              onClick={() => setActiveTab('actions')}
              className={`rounded-md px-3 py-1.5 text-xs font-medium whitespace-nowrap shrink-0 cursor-pointer ${
                activeTab === 'actions' ? 'bg-white text-slate-900' : 'text-slate-600'
              }`}
            >
              APK Build
            </button>
          </div>
        </div>

        {activeTab === 'overview' && (
          <section className="space-y-6">
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
              <div className="rounded-lg border border-slate-200 bg-white p-5">
                <div className="flex items-center gap-2 text-xs font-medium text-slate-500">
                  <Server className="h-4 w-4 text-slate-700" />
                  <span>Backend Target</span>
                </div>
                <p className="mt-2 text-lg font-semibold text-slate-900">/backend</p>
                <p className="mt-1 text-xs text-slate-600">
                  PHP 8.2 Apache Docker build · Railway Root Directory
                </p>
              </div>

              <div className="rounded-lg border border-slate-200 bg-white p-5">
                <div className="flex items-center gap-2 text-xs font-medium text-slate-500">
                  <Smartphone className="h-4 w-4 text-slate-700" />
                  <span>Android Workflow</span>
                </div>
                <p className="mt-2 text-lg font-semibold text-slate-900">/flutter_app</p>
                <p className="mt-1 text-xs text-slate-600">
                  GitHub Actions · Java 17 · Flutter stable
                </p>
              </div>

              <div className="rounded-lg border border-slate-200 bg-white p-5">
                <div className="flex items-center gap-2 text-xs font-medium text-slate-500">
                  <Database className="h-4 w-4 text-slate-700" />
                  <span>Database Dump</span>
                </div>
                <p className="mt-2 text-lg font-semibold text-slate-900 tabular-nums">225 KB SQL</p>
                <p className="mt-1 text-xs text-slate-600">
                  shortzz_database.sql ready at repository root
                </p>
              </div>
            </div>

            <div className="rounded-lg border border-slate-200 bg-white">
              <div className="flex flex-col gap-3 border-b border-slate-200 px-5 py-4 sm:flex-row sm:items-center sm:justify-between">
                <div className="flex items-center gap-2">
                  <FolderGit2 className="h-4 w-4 text-slate-700" />
                  <h2 className="text-sm font-semibold text-slate-900">Repository Configuration Matrix</h2>
                </div>

                <div className="flex items-center gap-1 rounded-lg bg-slate-100 p-1">
                  {['All', 'Railway', 'GitHub Actions', 'Database'].map((target) => (
                    <button
                      key={target}
                      type="button"
                      onClick={() => setFilterTarget(target)}
                      className={`rounded-md px-3 py-1 text-xs font-medium transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                        filterTarget === target
                          ? 'bg-white text-slate-900 shadow-xs'
                          : 'text-slate-600 hover:text-slate-900'
                      }`}
                    >
                      {target}
                    </button>
                  ))}
                </div>
              </div>

              <div className="overflow-x-auto">
                <table className="w-full border-collapse text-left text-sm">
                  <thead>
                    <tr className="border-b border-slate-200 text-xs font-medium text-slate-500">
                      <th className="px-5 py-3">File Path</th>
                      <th className="px-5 py-3">Target</th>
                      <th className="px-5 py-3">Purpose</th>
                      <th className="px-5 py-3 text-right">Status</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {filteredArtifacts.map((row) => (
                      <tr key={row.path} className="hover:bg-slate-50/80">
                        <td className="px-5 py-3 font-mono text-xs text-slate-900 whitespace-nowrap">
                          {row.path}
                        </td>
                        <td className="px-5 py-3 text-xs text-slate-600 whitespace-nowrap">{row.target}</td>
                        <td className="px-5 py-3 text-xs text-slate-600">{row.purpose}</td>
                        <td className="px-5 py-3 text-right text-xs font-medium whitespace-nowrap">
                          <span
                            className={
                              row.state === 'Configured' ? 'text-emerald-700' : 'text-amber-700'
                            }
                          >
                            {row.state}
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </section>
        )}

        {activeTab === 'railway' && (
          <section className="grid grid-cols-1 gap-6 lg:grid-cols-12">
            <div className="space-y-5 rounded-lg border border-slate-200 bg-white p-6 lg:col-span-5">
              <div>
                <h2 className="text-base font-semibold text-slate-900">Railway Service Parameters</h2>
                <p className="mt-1 text-xs text-slate-600">
                  Set Root Directory to <code className="text-slate-900">/backend</code> and paste the generated
                  variables in Railway.
                </p>
              </div>

              <div>
                <label htmlFor="railway-domain" className="block text-xs font-medium text-slate-700">
                  Railway Public Domain
                </label>
                <input
                  id="railway-domain"
                  type="url"
                  value={railwayDomain}
                  onChange={(e) => setRailwayDomain(e.target.value)}
                  placeholder="https://your-service.up.railway.app"
                  className="mt-1.5 w-full rounded-lg border border-slate-300 px-3 py-2 font-mono text-xs text-slate-900 focus:border-slate-900 focus:outline-none"
                />
              </div>

              <div>
                <div className="flex items-center justify-between">
                  <label htmlFor="app-key" className="block text-xs font-medium text-slate-700">
                    Laravel APP_KEY
                  </label>
                  <button
                    type="button"
                    onClick={() => setAppKey(generateLaravelKey())}
                    className="inline-flex items-center gap-1 text-xs font-medium text-blue-700 hover:text-blue-800 cursor-pointer"
                  >
                    <RefreshCw className="h-3 w-3" />
                    <span>Regenerate</span>
                  </button>
                </div>
                <input
                  id="app-key"
                  type="text"
                  value={appKey}
                  onChange={(e) => setAppKey(e.target.value)}
                  className="mt-1.5 w-full rounded-lg border border-slate-300 px-3 py-2 font-mono text-xs text-slate-900 focus:border-slate-900 focus:outline-none"
                />
              </div>

              <div>
                <div className="flex items-center justify-between">
                  <label htmlFor="api-key" className="block text-xs font-medium text-slate-700">
                    APP_API_KEY (Shared with Flutter)
                  </label>
                  <button
                    type="button"
                    onClick={() => setApiKey(generateApiKey())}
                    className="inline-flex items-center gap-1 text-xs font-medium text-blue-700 hover:text-blue-800 cursor-pointer"
                  >
                    <KeyRound className="h-3 w-3" />
                    <span>New Key</span>
                  </button>
                </div>
                <input
                  id="api-key"
                  type="text"
                  value={apiKey}
                  onChange={(e) => setApiKey(e.target.value)}
                  className="mt-1.5 w-full rounded-lg border border-slate-300 px-3 py-2 font-mono text-xs text-slate-900 focus:border-slate-900 focus:outline-none"
                />
              </div>

              <div>
                <span className="block text-xs font-medium text-slate-700">Media Storage Location</span>
                <div className="mt-1.5 grid grid-cols-3 gap-2">
                  {(['PUBLIC', 'AWSS3', 'DOSPACE'] as const).map((mode) => (
                    <button
                      key={mode}
                      type="button"
                      onClick={() => setStorageMode(mode)}
                      className={`rounded-lg border px-3 py-2 text-xs font-medium transition-colors cursor-pointer ${
                        storageMode === mode
                          ? 'border-slate-900 bg-slate-900 text-white'
                          : 'border-slate-200 bg-white text-slate-700 hover:bg-slate-50'
                      }`}
                    >
                      {mode}
                    </button>
                  ))}
                </div>
                {storageMode === 'PUBLIC' && (
                  <p className="mt-2 text-xs text-amber-700">
                    Attach a Railway Volume at /var/www/html/storage/app/public so uploaded reels survive redeploys.
                  </p>
                )}
              </div>

              <div>
                <label htmlFor="mysql-url" className="block text-xs font-medium text-slate-700">
                  Railway MySQL Public URL (for SQL import)
                </label>
                <input
                  id="mysql-url"
                  type="text"
                  value={mysqlUrl}
                  onChange={(e) => setMysqlUrl(e.target.value)}
                  className="mt-1.5 w-full rounded-lg border border-slate-300 px-3 py-2 font-mono text-xs text-slate-900 focus:border-slate-900 focus:outline-none"
                />
              </div>
            </div>

            <div className="space-y-5 lg:col-span-7">
              <div className="rounded-lg border border-slate-200 bg-white p-6">
                <div className="flex items-center justify-between gap-4">
                  <h3 className="text-sm font-semibold text-slate-900">Railway Raw Environment Variables</h3>
                  <button
                    type="button"
                    onClick={() => copyValue('railway-env', railwayEnvText)}
                    className="inline-flex items-center gap-1.5 rounded-lg border border-slate-200 px-3 py-1.5 text-xs font-medium text-slate-700 hover:bg-slate-50 whitespace-nowrap shrink-0 cursor-pointer"
                  >
                    {copiedId === 'railway-env' ? <Check className="h-3.5 w-3.5" /> : <Copy className="h-3.5 w-3.5" />}
                    <span>{copiedId === 'railway-env' ? 'Copied' : 'Copy Block'}</span>
                  </button>
                </div>
                <pre className="mt-3 overflow-x-auto rounded-lg bg-slate-950 p-4 font-mono text-xs leading-relaxed text-slate-100">
                  {railwayEnvText}
                </pre>
              </div>

              <div className="rounded-lg border border-slate-200 bg-white p-6">
                <div className="flex items-center justify-between gap-4">
                  <h3 className="text-sm font-semibold text-slate-900">Database Import Command</h3>
                  <button
                    type="button"
                    onClick={() => copyValue('mysql-cmd', mysqlImportCommand)}
                    className="inline-flex items-center gap-1.5 rounded-lg border border-slate-200 px-3 py-1.5 text-xs font-medium text-slate-700 hover:bg-slate-50 whitespace-nowrap shrink-0 cursor-pointer"
                  >
                    {copiedId === 'mysql-cmd' ? <Check className="h-3.5 w-3.5" /> : <Copy className="h-3.5 w-3.5" />}
                    <span>{copiedId === 'mysql-cmd' ? 'Copied' : 'Copy Command'}</span>
                  </button>
                </div>
                <pre className="mt-3 overflow-x-auto rounded-lg bg-slate-950 p-4 font-mono text-xs text-slate-100">
                  {mysqlImportCommand}
                </pre>
              </div>
            </div>
          </section>
        )}

        {activeTab === 'actions' && (
          <section className="grid grid-cols-1 gap-6 lg:grid-cols-12">
            <div className="space-y-4 rounded-lg border border-slate-200 bg-white p-6 lg:col-span-6">
              <h2 className="text-base font-semibold text-slate-900">GitHub Secrets &amp; Variables</h2>
              <p className="text-xs leading-relaxed text-slate-600">
                Add these in <span className="font-medium text-slate-900">tzuda1991-ctrl/tiktokZu</span> under
                Settings → Secrets and variables → Actions before running the APK workflow.
              </p>

              <div className="overflow-x-auto rounded-lg border border-slate-200">
                <table className="w-full border-collapse text-left text-xs">
                  <thead>
                    <tr className="border-b border-slate-200 bg-slate-50 text-slate-500">
                      <th className="px-4 py-2.5 font-medium">Name</th>
                      <th className="px-4 py-2.5 font-medium">Type</th>
                      <th className="px-4 py-2.5 font-medium">Value</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    <tr>
                      <td className="px-4 py-2.5 font-mono text-slate-900">BASE_URL</td>
                      <td className="px-4 py-2.5 text-slate-600">Variable</td>
                      <td className="px-4 py-2.5 font-mono text-slate-700">{normalizedUrl}/</td>
                    </tr>
                    <tr>
                      <td className="px-4 py-2.5 font-mono text-slate-900">API_KEY</td>
                      <td className="px-4 py-2.5 text-slate-600">Secret</td>
                      <td className="px-4 py-2.5 font-mono text-slate-700">{apiKey}</td>
                    </tr>
                    <tr>
                      <td className="px-4 py-2.5 font-mono text-slate-900">GOOGLE_SERVICES_JSON_BASE64</td>
                      <td className="px-4 py-2.5 text-slate-600">Secret (Optional)</td>
                      <td className="px-4 py-2.5 text-slate-600">Base64 of Firebase google-services.json</td>
                    </tr>
                    <tr>
                      <td className="px-4 py-2.5 font-mono text-slate-900">ANDROID_KEYSTORE_BASE64</td>
                      <td className="px-4 py-2.5 text-slate-600">Secret (Optional)</td>
                      <td className="px-4 py-2.5 text-slate-600">Release .jks keystore for Play Store</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>

            <div className="space-y-4 rounded-lg border border-slate-200 bg-white p-6 lg:col-span-6">
              <div className="flex items-center justify-between gap-4">
                <h2 className="text-base font-semibold text-slate-900">Generated Build Command</h2>
                <button
                  type="button"
                  onClick={() => copyValue('flutter-cmd', flutterBuildCommand)}
                  className="inline-flex items-center gap-1.5 rounded-lg border border-slate-200 px-3 py-1.5 text-xs font-medium text-slate-700 hover:bg-slate-50 whitespace-nowrap shrink-0 cursor-pointer"
                >
                  {copiedId === 'flutter-cmd' ? <Check className="h-3.5 w-3.5" /> : <Copy className="h-3.5 w-3.5" />}
                  <span>{copiedId === 'flutter-cmd' ? 'Copied' : 'Copy'}</span>
                </button>
              </div>
              <p className="text-xs leading-relaxed text-slate-600">
                The workflow runs this command inside <code className="text-slate-900">flutter_app/</code> and uploads
                the release APK as an artifact retained for 30 days.
              </p>
              <pre className="overflow-x-auto rounded-lg bg-slate-950 p-4 font-mono text-xs leading-relaxed text-slate-100">
                {flutterBuildCommand}
              </pre>
            </div>
          </section>
        )}
      </main>
    </div>
  );
}
