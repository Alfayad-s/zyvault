/// True on the APK that registers the payment-alert listener.
/// The basic APK is built with `--dart-define=UPI_ALERTS=false`.
const upiAlertsBuild = bool.fromEnvironment('UPI_ALERTS', defaultValue: true);
