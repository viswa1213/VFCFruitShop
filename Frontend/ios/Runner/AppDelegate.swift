import Flutter
import UIKit

#if canImport(GoogleMaps)
  import GoogleMaps
#endif

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Provide Google Maps API key from Info.plist if present (avoids hardcoding secrets)
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
      !apiKey.isEmpty
    {
      #if canImport(GoogleMaps)
        GMSServices.provideAPIKey(apiKey)
      #endif
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
