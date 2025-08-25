AppConfig appConfig = AppConfig(version: 38, codeName: '2.0.13');

class AppConfig {
  int version;
  String codeName;
  // Update checks will query the GitHub Releases API for the latest release by default.
  // You can override this at runtime by setting the environment variable ARE_UPDATE_URI
  // (useful to point to a simple hosted `latest.json` manifest).
  Uri updateUri = Uri.parse(const String.fromEnvironment(
    'ARE_UPDATE_URI',
    defaultValue:
        'https://api.github.com/repos/iragoudapatil077-commits/are_music/releases/latest',
  ).toString());

  // Note: to override at build time in CI use flutter build with --dart-define:
  // flutter build windows --release --dart-define=ARE_UPDATE_URI="https://raw.githubusercontent.com/<user>/<repo>/main/latest.json"

  AppConfig({required this.version, required this.codeName});
}
