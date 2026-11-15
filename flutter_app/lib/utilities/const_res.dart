const String baseURL = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://YOUR-BACKEND.up.railway.app/',
);
const String apiURL = '${baseURL}api/';
const String apiKey = String.fromEnvironment(
  'API_KEY',
  defaultValue: 'retry123',
);

// If you change this topic you also change backend .env file
String notificationTopic = const String.fromEnvironment(
  'NOTIFICATION_TOPIC',
  defaultValue: 'shortzz',
);

String revenueCatAndroidApiKey = const String.fromEnvironment(
  'RC_ANDROID_KEY',
  defaultValue: '______',
); // revenueCat android api
String revenueCatAppleApiKey = const String.fromEnvironment(
  'RC_APPLE_KEY',
  defaultValue: '________',
); // revenueCat apple api
