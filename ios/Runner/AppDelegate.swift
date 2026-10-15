import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    DownloadBackground.shared.reconnect()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
    if identifier == DownloadBackground.identifier {
      DownloadBackground.shared.completionHandler = completionHandler
      DownloadBackground.shared.reconnect()
    } else {
      super.application(application, handleEventsForBackgroundURLSession: identifier, completionHandler: completionHandler)
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(name: "inkora/download_background", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    let policy = FlutterMethodChannel(name: "inkora/reader_network_policy", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    policy.setMethodCallHandler { call, result in
      if call.method == "current" { result(DownloadBackground.shared.networkPolicy()) }
      else { result(FlutterMethodNotImplemented) }
    }
    channel.setMethodCallHandler { call, result in DownloadBackground.shared.handle(call, result: result) }
  }
}
