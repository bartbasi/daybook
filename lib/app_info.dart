// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

/// The app's name. A rename only changes this line (and store listings).
const appName = 'Daybook';

/// Must match `version:` in pubspec.yaml (a test checks this).
const appVersion = '1.0.0';

const sourceUrl = 'https://github.com/bartbasi/daybook';
const feedbackEmail = 'bartbasi@gmail.com';

/// Sent with every Open Food Facts request, as their API terms ask.
/// Identifies the app only, never the user.
String offUserAgent(String version) => '$appName/$version ($feedbackEmail)';
