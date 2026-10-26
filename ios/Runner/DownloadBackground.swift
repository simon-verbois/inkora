import Foundation
import Network
import Security
import Flutter
import UIKit

/// Metadata contains no headers. URLSession persists authenticated requests in
/// its system-owned background session; Basic credentials are origin-scoped
/// Keychain items and never explicit redirectable headers.
final class DownloadBackground: NSObject, URLSessionDownloadDelegate {
  static let shared = DownloadBackground()
  static let identifier = "dev.inkora.downloads.v1"
  private let monitor = NWPathMonitor()
  var completionHandler: (() -> Void)?
  private let metadataURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/background-transfers.json")
  private var entries: [String: [String: Any]] = [:]
  private lazy var session: URLSession = {
    let configuration = URLSessionConfiguration.background(withIdentifier: Self.identifier)
    configuration.sessionSendsLaunchEvents = true
    configuration.isDiscretionary = true
    configuration.httpMaximumConnectionsPerHost = 1
    configuration.urlCredentialStorage = nil
    configuration.httpCookieStorage = nil
    configuration.httpShouldSetCookies = false
    configuration.timeoutIntervalForResource = 7 * 24 * 60 * 60
    return URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
  }()
  private override init() {
    super.init()
    monitor.start(queue: DispatchQueue(label: "dev.inkora.network-policy"))
    if let data = try? Data(contentsOf: metadataURL),
       let saved = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] { entries = saved }
  }
  func networkPolicy() -> [String: Bool] {
    let path = monitor.currentPath
    var constrained = false
    if #available(iOS 13.0, *) { constrained = path.isConstrained }
    return ["metered": path.status != .satisfied || path.isExpensive, "dataSaver": constrained]
  }
  func reconnect() { _ = session }
  private func save() throws {
    try FileManager.default.createDirectory(at: metadataURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try JSONSerialization.data(withJSONObject: entries)
    try data.write(to: metadataURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
  }
  private let credentialService = "dev.inkora.background.basic.v1"
  private func credentialQuery(_ account: String) -> [String: Any] {
    return [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: credentialService, kSecAttrAccount as String: account]
  }
  private func storeCredential(_ account: String, basic: String) throws {
    guard let encoded = basic.split(separator: " ").last, let data = Data(base64Encoded: String(encoded)),
          let text = String(data: data, encoding: .utf8), text.contains(":") else { throw NSError(domain: "InkoraTransfer", code: 3) }
    var query = credentialQuery(account)
    let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    if status == errSecItemNotFound {
      query[kSecValueData as String] = data
      query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else { throw NSError(domain: "InkoraTransfer", code: 4) }
    } else if status != errSecSuccess { throw NSError(domain: "InkoraTransfer", code: 4) }
  }
  private func readCredential(_ account: String) -> (String, String)? {
    var query = credentialQuery(account)
    query[kSecReturnData as String] = true
    var value: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &value) == errSecSuccess, let data = value as? Data,
          let text = String(data: data, encoding: .utf8), let delimiter = text.firstIndex(of: ":") else { return nil }
    return (String(text[..<delimiter]), String(text[text.index(after: delimiter)...]))
  }
  private func discardCredentialIfUnused(_ account: String) {
    if !entries.values.contains(where: { ($0["account"] as? String) == account }) {
      SecItemDelete(credentialQuery(account) as CFDictionary)
    }
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "foreground":
      guard UIApplication.shared.applicationState == .active else { result(nil); return }
      session.getAllTasks { tasks in
        tasks.forEach { $0.cancel() }
        DispatchQueue.main.async { result(nil) }
      }
    case "enqueue":
      guard let arguments = call.arguments as? [String: Any], let tasks = arguments["tasks"] as? [[String: Any]], let headers = arguments["headers"] as? [String: String], let wifiOnly = arguments["wifiOnly"] as? Bool else {
        result(FlutterError(code: "invalid_task", message: "Invalid background task.", details: nil)); return
      }
      // Background URLSession follows redirects without consulting its redirect
      // delegate. Never attach API-key/custom Authorization headers to these
      // tasks: Basic auth is supplied only to the original scheme/host/port.
      guard headers.count == 1, let basic = headers["Authorization"], basic.hasPrefix("Basic ") else {
        result(FlutterError(code: "credential_mode", message: "This authentication mode uses foreground downloads on iOS.", details: nil)); return
      }
      do {
        for task in tasks {
          guard let id = task["id"] as? String, id.range(of: "^[a-f0-9]{64}-[0-9]+$", options: .regularExpression) != nil,
                let address = task["url"] as? String, let url = URL(string: address),
                (url.scheme == "http" || url.scheme == "https"), url.host != nil, url.user == nil,
                let path = task["path"] as? String,
                URL(fileURLWithPath: path).standardizedFileURL.path.hasPrefix(NSHomeDirectory() + "/Library/Application Support/"),
                let budget = task["maximumBytes"] as? Int, budget > 0, budget <= 512 * 1024 * 1024 else {
            throw NSError(domain: "InkoraTransfer", code: 1)
          }
          if entries[id] != nil { continue }
          var metadata = task
          metadata.removeValue(forKey: "url")
          guard let account = task["account"] as? String else { throw NSError(domain: "InkoraTransfer", code: 5) }
          try storeCredential(account, basic: basic)
          metadata["originHost"] = url.host
          metadata["originScheme"] = url.scheme
          metadata["originPort"] = url.port ?? (url.scheme == "https" ? 443 : 80)
          metadata["originalURL"] = url.absoluteString
          metadata["state"] = "queued"
          entries[id] = metadata
          // Persist identity before giving the task to the system.
          try save()
          var request = URLRequest(url: url)
          request.httpShouldHandleCookies = false
          request.allowsCellularAccess = !wifiOnly
          if #available(iOS 13.0, *) { request.allowsExpensiveNetworkAccess = !wifiOnly; request.allowsConstrainedNetworkAccess = false }
          let download = session.downloadTask(with: request)
          download.taskDescription = id
          download.resume()
        }
        result(nil)
      } catch { result(FlutterError(code: "background_transfer", message: "Native transfer unavailable.", details: nil)) }
    case "accounts": result(Array(Set(entries.values.compactMap { $0["account"] as? String })))
    case "excludeFromBackup":
      do {
        guard let paths = call.arguments as? [String] else { throw NSError(domain: "InkoraTransfer", code: 6) }
        for path in paths {
          var url = URL(fileURLWithPath: path).standardizedFileURL
          guard url.path.hasPrefix(NSHomeDirectory() + "/Library/Application Support/") else { throw NSError(domain: "InkoraTransfer", code: 7) }
          try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
          var values = URLResourceValues(); values.isExcludedFromBackup = true
          try url.setResourceValues(values)
        }
        result(nil)
      } catch { result(FlutterError(code: "backup_exclusion", message: "Unable to configure download storage.", details: nil)) }
    case "results":
      result(entries.values.filter { ($0["state"] as? String) == "complete" || ($0["state"] as? String) == "failed" }.map { $0 })
    case "acknowledge":
      if let id = call.arguments as? String {
        let account = entries[id]?["account"] as? String
        entries.removeValue(forKey: id)
        if let account = account { discardCredentialIfUnused(account) }
        try? save()
      }
      result(nil)
    case "cancelAccount":
      guard let account = call.arguments as? String else { result(nil); return }
      let ids = Set(entries.filter { ($0.value["account"] as? String) == account }.map { $0.key })
      session.getAllTasks { tasks in
        tasks.filter { ids.contains($0.taskDescription ?? "") }.forEach { $0.cancel() }
        DispatchQueue.main.async {
          for id in ids {
            if let path = self.entries[id]?["path"] as? String { try? FileManager.default.removeItem(atPath: path) }
            self.entries.removeValue(forKey: id)
          }
          self.discardCredentialIfUnused(account)
          try? self.save()
          result(nil)
        }
      }
    case "status": result(["count": entries.count])
    default: result(FlutterMethodNotImplemented)
    }
  }
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
    guard let id = downloadTask.taskDescription, let entry = entries[id], let budget = entry["maximumBytes"] as? Int else { downloadTask.cancel(); return }
    if totalBytesWritten > budget || totalBytesExpectedToWrite > budget { entries[id]?["state"] = "failed"; try? save(); downloadTask.cancel() }
  }
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    guard let id = downloadTask.taskDescription, let entry = entries[id], let path = entry["path"] as? String, let budget = entry["maximumBytes"] as? Int,
          let response = downloadTask.response as? HTTPURLResponse else { return }
    do {
      let length = (try FileManager.default.attributesOfItem(atPath: location.path)[.size] as? NSNumber)?.intValue ?? 0
      guard response.statusCode == 200, response.url?.absoluteString == entry["originalURL"] as? String, length > 0, length <= budget, entry["state"] as? String != "failed" else { throw NSError(domain: "InkoraTransfer", code: 2) }
      let destination = URL(fileURLWithPath: path)
      try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
      if FileManager.default.fileExists(atPath: path) { try FileManager.default.removeItem(at: destination) }
      try FileManager.default.moveItem(at: location, to: destination)
      try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: path)
      entries[id]?["byteLength"] = length
      entries[id]?["mediaType"] = response.mimeType ?? ""
      entries[id]?["state"] = "complete"
      try save()
    } catch { entries[id]?["state"] = "failed"; try? save() }
  }
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard let id = task.taskDescription, entries[id] != nil, entries[id]?["state"] as? String != "complete" else { return }
    if error != nil { entries[id]?["state"] = "failed"; try? save() }
  }
  func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
      completionHandler(.performDefaultHandling, nil); return
    }
    guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic,
          challenge.previousFailureCount == 0, let id = task.taskDescription, let entry = entries[id],
          let account = entry["account"] as? String,
          challenge.protectionSpace.protocol == (entry["originScheme"] as? String ?? "https"),
          challenge.protectionSpace.host == entry["originHost"] as? String,
          challenge.protectionSpace.port == entry["originPort"] as? Int,
          let credential = readCredential(account) else { completionHandler(.cancelAuthenticationChallenge, nil); return }
    completionHandler(.useCredential, URLCredential(user: credential.0, password: credential.1, persistence: .none))
  }
  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    let handler = completionHandler
    completionHandler = nil
    handler?()
  }
}
