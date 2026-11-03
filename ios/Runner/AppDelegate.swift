import CFNetwork
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerVpnChannel(with: engineBridge.pluginRegistry)
  }

  /// connectivity_plus no informa de VPN en iOS, así que se consulta aquí.
  private func registerVpnChannel(with registry: FlutterPluginRegistry) {
    guard let messenger = registry.registrar(forPlugin: "VpnDetector")?.messenger() else { return }
    let channel = FlutterMethodChannel(name: "control_input_output/vpn", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      if call.method == "isVpnActive" {
        result(AppDelegate.isVpnActive())
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Hay VPN cuando el sistema expone una interfaz de túnel entre las conexiones activas.
  private static func isVpnActive() -> Bool {
    guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
      let scoped = settings["__SCOPED__"] as? [String: Any]
    else { return false }
    let tunnelPrefixes = ["tap", "tun", "ppp", "ipsec", "utun"]
    return scoped.keys.contains { key in tunnelPrefixes.contains { key.hasPrefix($0) } }
  }
}
