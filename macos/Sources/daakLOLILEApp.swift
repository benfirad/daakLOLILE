import SwiftUI
import AppKit
import Foundation
@preconcurrency import CoreLocation
import UserNotifications

private struct RelayStatus: Decodable {
    struct Permissions: Decodable {
        let power: Bool?
        let memory: Bool?
    }

    struct Service: Decodable {
        let running: Bool
    }

    struct Port: Decodable {
        let listening: Bool
    }

    struct Consensus: Decodable {
        let found: Bool
        let running: Bool
    }

    struct Configuration: Decodable {
        let nickname: String
        let contactInfo: String?
        let nonExit: Bool
        let rateMbps: Int
        let burstMbps: Int
    }

    struct Traffic: Decodable {
        let read: Double
        let write: Double
        let total: Double
        let quota: Double
        let unlimited: Bool?
        let period: String?
    }

    struct Snowflake: Decodable {
        struct Traffic: Decodable {
            let inbound: Double
            let outbound: Double
            let total: Double
            let connections: Double
        }

        let running: Bool
        let capacity: Int
        let natType: String
        let traffic: Traffic
    }

    struct Support: Decodable {
        let total: Double
        let activeProjects: Int?
    }

    struct Volunteer: Decodable {
        struct Folding: Decodable {
            let installed: Bool
            let running: Bool
            let state: String
            let detail: String
            let completedWorkUnitsObserved: Int?
        }

        struct Boinc: Decodable {
            struct Project: Decodable {
                let name: String
                let url: String?
            }

            let installed: Bool
            let running: Bool
            let state: String
            let detail: String
            let projects: [Project]?
            let activeTasks: Int?
        }

        struct RipeAtlas: Decodable {
            let installed: Bool
            let running: Bool
            let registered: Bool
            let state: String
            let detail: String
        }

        let available: Bool?
        let folding: Folding
        let boinc: Boinc
        let ripeAtlas: RipeAtlas
    }

    struct PowerMode: Decodable {
        let available: Bool
        let controlMode: String
        let effectiveMode: String
        let nightStart: String
        let nightEnd: String
    }

    struct MemoryMaintenance: Decodable {
        struct Schedule: Decodable {
            let dailyAt: String
            let runsWithoutLogin: Bool
        }

        let available: Bool
        let decision: String
        let message: String
        let pressureDetected: Bool
        let updatedAt: String?
        let reclaimedBytes: Double?
        let schedule: Schedule
    }

    struct Hardware: Decodable {
        struct Power: Decodable {
            let wallEstimateWatts: Double?
            let wallEstimateLowWatts: Double?
            let wallEstimateHighWatts: Double?
            let todayKWh: Double?
            let monthKWh: Double?
        }

        struct Processor: Decodable {
            let loadPercent: Double?
            let temperatureC: Double?
            let powerWatts: Double?
            let powerSource: String?
        }

        struct Graphics: Decodable {
            let loadPercent: Double?
            let temperatureC: Double?
            let powerWatts: Double?
            let powerSource: String?
        }

        struct Memory: Decodable {
            let loadPercent: Double?
            let usedBytes: Double?
            let totalBytes: Double?
        }

        struct NetworkGroup: Decodable {
            struct Adapter: Decodable {
                let downloadBytesPerSecond: Double?
                let uploadBytesPerSecond: Double?
            }

            let ethernet: Adapter?
            let tailscale: Adapter?
        }

        let available: Bool
        let ageSeconds: Double?
        let power: Power?
        let cpu: Processor?
        let gpu: Graphics?
        let memory: Memory?
        let network: NetworkGroup?
    }

    struct Electricity: Decodable {
        struct Tariff: Decodable {
            let location: String
            let subscriberGroup: String
            let effectiveFrom: String
            let lowTierDailyKWh: Double
            let lowTierTryPerKWh: Double
            let highTierTryPerKWh: Double
            let skttAnnualKWh: Double
        }

        struct Impact: Decodable {
            let kWh: Double
            let lowTierTry: Double
            let highTierTry: Double
        }

        struct AnnualImpact: Decodable {
            let kWh: Double
            let lowTierTry: Double
            let highTierTry: Double
            let skttPercent: Double
        }

        struct ScheduleRecommendation: Decodable {
            let ecoStart: String
            let ecoEnd: String
            let basis: String
            let standardTariffSamePriceAllDay: Bool
            let snowflakeAlwaysOn: Bool
        }

        let available: Bool
        let tariff: Tariff
        let today: Impact
        let month: Impact
        let runRate30Days: Impact
        let runRateAnnual: AnnualImpact
        let scheduleRecommendation: ScheduleRecommendation?
    }

    let updatedAt: String
    let permissions: Permissions?
    let service: Service
    let port: Port
    let bootstrap: Int
    let consensus: Consensus
    let config: Configuration
    let traffic: Traffic
    let snowflake: Snowflake?
    let support: Support?
    let hardware: Hardware?
    let electricity: Electricity?
    let power: PowerMode?
    let memoryMaintenance: MemoryMaintenance?
    let volunteer: Volunteer?
}

private struct NodeStatus: Decodable {
    let schema: Int
    let state: String
    let updatedAt: TimeInterval
    let lastSuccessAt: TimeInterval
    let consecutiveFailures: Int
    let lastError: String?
    let provider: String?
    let accuracyMeters: Double?
}

private struct NodeLocation: Decodable, Equatable {
    let provider: String
    let latitude: Double
    let longitude: Double
    let accuracyMeters: Double
    let capturedAt: TimeInterval
}

private struct MYAL11Status: Decodable {
    struct Services: Decodable {
        let tailscale: Bool
        let ssh: Bool
        let screenSharing: Bool
        let stats: Bool?
        let keepingYouAwake: Bool
        let awaykeProcess: Bool
        let awaykeActive: Bool
        let caffeinateGuard: Bool
        let daakRemember: Bool?
        let daakRememberSync: Bool?
    }

    let updatedAt: String
    let name: String
    let model: String
    let tailscaleIp: String
    let powerSource: String
    let batteryPercent: Int
    let batteryMinutesRemaining: Int?
    let upsState: String?
    let upsMessage: String?
    let batteryCondition: String
    let batteryCycles: Int
    let diskFreeKb: Int64
    let memoryFreePercent: Int
    let loadAverage: String
    let uptime: String
    let dockerContainersRunning: Int
    let cpuUsagePercent: Double?
    let cpuTemperatureC: Double?
    let diskUsedPercent: Double?
    let services: Services
}

private struct TailnetStatus: Decodable {
    struct ExitNodeStatus: Decodable {
        let tailscaleIPs: [String]?

        enum CodingKeys: String, CodingKey {
            case tailscaleIPs = "TailscaleIPs"
        }
    }

    struct Peer: Decodable {
        let tailscaleIPs: [String]?
        let exitNodeOption: Bool?

        enum CodingKeys: String, CodingKey {
            case tailscaleIPs = "TailscaleIPs"
            case exitNodeOption = "ExitNodeOption"
        }
    }

    let exitNodeStatus: ExitNodeStatus?
    let peers: [String: Peer]

    enum CodingKeys: String, CodingKey {
        case exitNodeStatus = "ExitNodeStatus"
        case peers = "Peer"
    }
}

private struct CommandResult: Sendable {
    let exitCode: Int32
    let output: String
}

private enum LocalCommand {
    static func run(_ executable: String, _ arguments: [String]) async -> CommandResult {
        await Task.detached(priority: .utility) {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return CommandResult(
                    exitCode: process.terminationStatus,
                    output: String(decoding: data, as: UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                )
            } catch {
                return CommandResult(exitCode: 127, output: error.localizedDescription)
            }
        }.value
    }

    static func launch(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
    }
}

@MainActor
private final class MYAL11Monitor: ObservableObject {
    enum Route: String {
        case cable = "Kablo · otomatik"
        case thunderbolt = "Thunderbolt · otomatik"
        case tailscale = "Tailscale · otomatik"
        case offline = "Bağlantı yok"
    }

    @Published private(set) var status: MYAL11Status?
    @Published private(set) var route: Route = .offline
    @Published private(set) var lastError: String?
    @Published private(set) var actionMessage: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isRunningAction = false

    private let statusPath = NSHomeDirectory() + "/Library/Application Support/DAAK/Nodes/mya-l11/status.json"
    private let syncPath = NSHomeDirectory() + "/Library/Application Support/DAAK/daak-node-sync.zsh"
    private let routePath = NSHomeDirectory() + "/Library/Application Support/DAAK/mya-direct.zsh"
    private let syncLogPath = NSHomeDirectory() + "/Library/Logs/daak-node-sync.log"
    private var timer: Timer?
    private var lastUPSState: String?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        Task { await refresh() }
    }

    deinit { timer?.invalidate() }

    // A freshly copied status file is stronger evidence than a second socket probe.
    // macOS Local Network Privacy can reject a direct `nc` child process even while
    // the zsh/scp synchronizer is successfully talking to the same machine.
    var isOnline: Bool { isFresh && status?.services.ssh == true }
    var isFresh: Bool {
        guard let value = status?.updatedAt,
              let date = ISO8601DateFormatter().date(from: value) else { return false }
        return abs(date.timeIntervalSinceNow) < 180
    }

    var routeLabel: String { route.rawValue }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let syncResult = await LocalCommand.run("/bin/zsh", [syncPath])
        await refreshRoute(syncSucceeded: syncResult.exitCode == 0)
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: statusPath))
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            status = try decoder.decode(MYAL11Status.self, from: data)
            lastError = isFresh ? nil : "Son telemetri güncel değil."
            updateUPSNotification()
        } catch {
            status = nil
            lastError = "MYA-L11 telemetrisi okunamadı."
        }
    }

    private func refreshRoute(syncSucceeded: Bool) async {
        let result = await LocalCommand.run("/bin/zsh", [routePath, "status"])
        switch result.output.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "cable": route = .cable
        case "thunderbolt": route = .thunderbolt
        case "tailscale": route = .tailscale
        default: route = syncSucceeded ? routeFromLastSync() : .offline
        }
    }

    private func routeFromLastSync() -> Route {
        guard let log = try? String(contentsOfFile: syncLogPath, encoding: .utf8),
              let line = log.split(separator: "\n").last else { return .tailscale }
        if line.contains("route=mya-l11-direct") { return .cable }
        if line.contains("route=mya-l11-thunderbolt") { return .thunderbolt }
        return .tailscale
    }

    private var selectedSSHHost: String {
        switch route {
        case .cable: return "mya-l11-direct"
        case .thunderbolt: return "mya-l11-thunderbolt"
        case .tailscale, .offline: return "mya-l11-tail"
        }
    }

    private var wakeMac: String? {
        guard let raw = UserDefaults.standard.string(forKey: "myaL11WakeMac") else { return nil }
        let normalized = raw.lowercased().filter { $0.isHexDigit }
        return normalized.count == 12 ? normalized : nil
    }

    private func updateUPSNotification() {
        guard let status, let state = status.upsState else { return }
        defer { lastUPSState = state }
        guard lastUPSState != nil, lastUPSState != state else { return }

        if state == "battery" || state == "battery-low" {
            let content = UNMutableNotificationContent()
            content.title = state == "battery-low" ? "MYA-L11 yakında kapanabilir" : "MYA-L11 adaptörden ayrıldı"
            content.body = status.upsMessage ?? "Intel Mac pilde çalışıyor · pil %\(status.batteryPercent)"
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "app.daaknode.mya-l11-ups.\(state)",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    func openScreen() {
        try? LocalCommand.launch("/bin/zsh", [NSHomeDirectory() + "/Library/Application Support/DAAK/mya-direct.zsh", "screen"])
        actionMessage = "Ekran Paylaşımı en hızlı kullanılabilir hattan açılıyor."
    }

    func openDisk() {
        try? LocalCommand.launch("/bin/zsh", [NSHomeDirectory() + "/Library/Application Support/DAAK/mya-direct.zsh", "disk"])
    }

    func openSSH() {
        try? LocalCommand.launch("/usr/bin/open", ["ssh://mya-l11"])
    }

    func power(_ action: String) async {
        guard ["wake", "sleep", "restart", "shutdown"].contains(action), !isRunningAction else { return }
        isRunningAction = true
        defer { isRunningAction = false }

        if action == "wake" {
            guard let wakeMac else {
                actionMessage = "Wake-on-LAN MAC adresi bu Mac'te yapılandırılmamış."
                return
            }
            let result = await LocalCommand.run(
                "/usr/bin/python3",
                ["-c", "import socket,sys; m=bytes.fromhex(sys.argv[1]); p=b'\\xff'*6+m*16; s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.setsockopt(socket.SOL_SOCKET,socket.SO_BROADCAST,1); [s.sendto(p,(h,9)) for h in ('255.255.255.255','172.20.10.255')]", wakeMac]
            )
            actionMessage = result.exitCode == 0 ? "Uyandırma paketi yerel ağa gönderildi." : "Uyandırma paketi gönderilemedi."
            return
        }

        let result = await LocalCommand.run(
            "/usr/bin/ssh",
            ["-o", "BatchMode=yes", "-o", "ConnectTimeout=4", selectedSSHHost,
             "sudo -n /usr/local/sbin/daak-node-power \(action)"]
        )
        if result.exitCode == 0 {
            switch action {
            case "sleep": actionMessage = "MYA-L11 uykuya alındı."
            case "restart": actionMessage = "MYA-L11 yeniden başlatılıyor."
            default: actionMessage = "MYA-L11 kapatılıyor. Tekrar açmak fiziksel güç veya çalışan Wake-on-LAN gerektirebilir."
            }
        } else {
            actionMessage = "Güç komutu çalışmadı: \(result.output)"
        }
    }
}

@MainActor
private final class NodeMonitor: ObservableObject {
    @Published private(set) var status: NodeStatus?
    @Published private(set) var location: NodeLocation?
    @Published private(set) var lastError: String?
    @Published private(set) var actionMessage: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isSettingExitNode = false
    @Published private(set) var isPhoneExitNodeAvailable = false
    @Published private(set) var isUsingPhoneExitNode = false
    @Published var host: String

    private let hostKey = "daakNodeHost"
    private let sshPort = "8022"
    private let adbPort = "5555"
    private let tailscaleCLI = "/Applications/Tailscale.app/Contents/MacOS/Tailscale"
    private var timer: Timer?

    init() {
        host = UserDefaults.standard.string(forKey: hostKey) ?? ""
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        Task { await refresh() }
    }

    deinit {
        timer?.invalidate()
    }

    var isOnline: Bool { status != nil }
    var hasLocation: Bool { (status?.lastSuccessAt ?? 0) > 0 }

    var stateLabel: String {
        guard let status else { return "Bağlantı bekleniyor" }
        switch status.state {
        case "ready": return "Konum hazır"
        case "ready-last-gps": return "Son hassas GPS noktası korunuyor"
        case "ready-approximate": return "Yaklaşık konum hazır"
        case "acquiring-gps":
            return hasLocation ? "Yaklaşık konum hazır · GPS aranıyor" : "Hassas GPS aranıyor"
        case "waiting-for-gps": return hasLocation ? "Son konum hazır · GPS aranıyor" : "GPS sinyali bekleniyor"
        case "permission-required": return "Konum izni gerekli"
        default: return status.state.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }

    var lastLocationLabel: String {
        guard let timestamp = status?.lastSuccessAt, timestamp > 0 else {
            return "Henüz gerçek GPS koordinatı alınmadı"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: Date(timeIntervalSince1970: timestamp), relativeTo: Date())
    }

    func saveAndRefresh() async {
        host = Self.cleanedHost(host)
        UserDefaults.standard.set(host, forKey: hostKey)
        status = nil
        lastError = nil
        await refresh()
    }

    func refresh() async {
        await refreshCachedLocation()
        await refreshExitNodeState()
        guard Self.isSafeHost(host) else {
            status = nil
            lastError = "DAAK NODE Tailscale IP’si geçerli değil."
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }
        let result = await LocalCommand.run("/usr/bin/ssh", sshArguments(remoteCommand: ".local/bin/daak-find status"))
        guard result.exitCode == 0,
              let data = result.output.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(NodeStatus.self, from: data) else {
            status = nil
            lastError = "S9’a ulaşılamadı. Tailscale ve Termux SSH bağlantısını kontrol et."
            return
        }
        status = decoded
        lastError = nil
    }

    func setPhoneExitNode(enabled: Bool) async {
        guard Self.isSafeHost(host), !isSettingExitNode else { return }
        isSettingExitNode = true
        defer { isSettingExitNode = false }
        let arguments = enabled
            ? ["set", "--exit-node=\(host)", "--exit-node-allow-lan-access=true"]
            : ["set", "--exit-node="]
        let result = await LocalCommand.run(tailscaleCLI, arguments)
        await refreshExitNodeState()
        if result.exitCode == 0 {
            actionMessage = enabled
                ? "Mac interneti artık S9 üzerinden çıkıyor."
                : "Mac normal internet rotasına döndü."
        } else {
            actionMessage = "S9 çıkış rotası değiştirilemedi: \(result.output)"
        }
    }

    private func refreshExitNodeState() async {
        guard FileManager.default.isExecutableFile(atPath: tailscaleCLI) else {
            isPhoneExitNodeAvailable = false
            isUsingPhoneExitNode = false
            return
        }
        let result = await LocalCommand.run(tailscaleCLI, ["status", "--json"])
        guard result.exitCode == 0,
              let data = result.output.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(TailnetStatus.self, from: data) else {
            return
        }
        isPhoneExitNodeAvailable = decoded.peers.values.contains {
            $0.exitNodeOption == true && Self.addresses($0.tailscaleIPs, contain: host)
        }
        isUsingPhoneExitNode = Self.addresses(decoded.exitNodeStatus?.tailscaleIPs, contain: host)
    }

    private static func addresses(_ addresses: [String]?, contain host: String) -> Bool {
        (addresses ?? []).contains {
            $0.split(separator: "/", maxSplits: 1).first.map(String.init) == host
        }
    }

    private func refreshCachedLocation() async {
        let result = await LocalCommand.run(NSHomeDirectory() + "/.local/bin/daak-find", ["raw-cached"])
        guard result.exitCode == 0,
              let data = result.output.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(NodeLocation.self, from: data),
              (-90...90).contains(decoded.latitude),
              (-180...180).contains(decoded.longitude),
              decoded.accuracyMeters >= 0,
              decoded.accuracyMeters <= (decoded.provider == "gps" ? 500 : 2_000) else {
            return
        }
        location = decoded
    }

    func openFind() async {
        guard hasLocation else {
            actionMessage = "Harita için önce gerçek bir GPS koordinatı gerekiyor."
            return
        }
        let result = await LocalCommand.run(NSHomeDirectory() + "/.local/bin/daak-find", ["open"])
        actionMessage = result.exitCode == 0
            ? "DAAK NODE haritada açıldı."
            : "Konum açılamadı: \(result.output)"
    }

    func openLiveScreen() async {
        guard Self.isSafeHost(host) else { return }
        actionMessage = "S9 ekranına bağlanılıyor…"
        let serial = "\(host):\(adbPort)"
        let adb = await LocalCommand.run("/opt/homebrew/bin/adb", ["connect", serial])
        guard adb.exitCode == 0 else {
            actionMessage = "ADB bağlantısı kurulamadı: \(adb.output)"
            return
        }
        do {
            try LocalCommand.launch(
                "/opt/homebrew/bin/scrcpy",
                ["--serial", serial, "--no-audio", "--stay-awake", "--window-title", "DAAK NODE · Galaxy S9+"]
            )
            actionMessage = "Canlı ekran açıldı."
        } catch {
            actionMessage = "Canlı ekran açılamadı: \(error.localizedDescription)"
        }
    }

    func openSSH() {
        guard Self.isSafeHost(host), let url = URL(string: "ssh://\(host):\(sshPort)") else { return }
        NSWorkspace.shared.open(url)
        actionMessage = "S9 terminali açılıyor."
    }

    private func sshArguments(remoteCommand: String) -> [String] {
        [
            "-p", sshPort,
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=4",
            "-o", "ConnectionAttempts=1",
            "-o", "ServerAliveInterval=10",
            "-o", "StrictHostKeyChecking=yes",
            host,
            remoteCommand
        ]
    }

    private static func cleanedHost(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "ssh://", with: "", options: [.caseInsensitive, .anchored])
            .split(separator: ":", maxSplits: 1)
            .first
            .map(String.init) ?? ""
    }

    private static func isSafeHost(_ value: String) -> Bool {
        let pattern = #"^[A-Za-z0-9](?:[A-Za-z0-9.-]{0,251}[A-Za-z0-9])?$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}

@MainActor
private final class SeparationMonitor: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var distanceMeters: Double?
    @Published private(set) var statusLabel = "Ayrılma uyarısı hazırlanıyor"

    private let manager = CLLocationManager()
    private let alertDistance = 750.0
    private let reunionDistance = 400.0
    private var phoneLocation: NodeLocation?
    private var macLocation: CLLocation?
    private var consecutiveAwaySamples = 0
    private var hasAlerted = false
    private var notificationResolved = false
    private var notificationAllowed = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
        manager.activityType = .other
        manager.pausesLocationUpdatesAutomatically = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            Task { @MainActor in
                guard let self else { return }
                self.notificationResolved = true
                self.notificationAllowed = granted
                UserDefaults.standard.set(granted, forKey: "daakSeparationNotificationAllowed")
                if !granted {
                    self.statusLabel = "Ayrılma uyarısı için bildirim izni gerekli"
                }
            }
        }
        manager.requestWhenInUseAuthorization()
        startIfAuthorized()
    }

    func updatePhoneLocation(_ location: NodeLocation?) {
        phoneLocation = location
        evaluate()
    }

    func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    func openLocationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") else { return }
        NSWorkspace.shared.open(url)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        startIfAuthorized()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        macLocation = latest
        evaluate()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        statusLabel = "Mac konumu bekleniyor"
    }

    private func startIfAuthorized() {
        switch manager.authorizationStatus {
        case .authorized, .authorizedAlways:
            manager.startUpdatingLocation()
            UserDefaults.standard.set(true, forKey: "daakSeparationLocationAllowed")
            statusLabel = notificationResolved && !notificationAllowed
                ? "Ayrılma uyarısı için bildirim izni gerekli"
                : "Ayrılma uyarısı açık · 750 m"
        case .denied, .restricted:
            manager.stopUpdatingLocation()
            UserDefaults.standard.set(false, forKey: "daakSeparationLocationAllowed")
            statusLabel = "Ayrılma uyarısı için Mac konum izni gerekli"
        case .notDetermined:
            statusLabel = "Mac konum izni bekleniyor"
        @unknown default:
            statusLabel = "Mac konumu bekleniyor"
        }
    }

    private func evaluate() {
        guard !notificationResolved || notificationAllowed else {
            statusLabel = "Ayrılma uyarısı için bildirim izni gerekli"
            return
        }
        guard let phoneLocation, let macLocation else { return }
        let now = Date().timeIntervalSince1970
        guard now - phoneLocation.capturedAt <= 20 * 60,
              abs(macLocation.timestamp.timeIntervalSinceNow) <= 5 * 60,
              macLocation.horizontalAccuracy >= 0,
              macLocation.horizontalAccuracy <= 500 else {
            statusLabel = "Ayrılma uyarısı açık · güncel konum bekleniyor"
            return
        }

        let phone = CLLocation(
            coordinate: CLLocationCoordinate2D(
                latitude: phoneLocation.latitude,
                longitude: phoneLocation.longitude
            ),
            altitude: 0,
            horizontalAccuracy: phoneLocation.accuracyMeters,
            verticalAccuracy: -1,
            timestamp: Date(timeIntervalSince1970: phoneLocation.capturedAt)
        )
        let rawDistance = macLocation.distance(from: phone)
        let effectiveDistance = max(
            0,
            rawDistance - macLocation.horizontalAccuracy - phoneLocation.accuracyMeters
        )
        distanceMeters = rawDistance

        if effectiveDistance >= alertDistance {
            consecutiveAwaySamples += 1
            statusLabel = "Telefon yaklaşık \(Self.distanceText(rawDistance)) uzakta"
            if consecutiveAwaySamples >= 2 && !hasAlerted {
                hasAlerted = true
                sendAwayNotification(distance: rawDistance)
            }
        } else if effectiveDistance <= reunionDistance {
            consecutiveAwaySamples = 0
            hasAlerted = false
            statusLabel = "Telefon yanında · ayrılma uyarısı açık"
        } else {
            consecutiveAwaySamples = 0
            statusLabel = "Ayrılma uyarısı açık · \(Self.distanceText(rawDistance))"
        }
    }

    private func sendAwayNotification(distance: Double) {
        let content = UNMutableNotificationContent()
        content.title = "DAAK NODE senden uzaklaştı"
        content.body = "Galaxy S9+ yaklaşık \(Self.distanceText(distance)) uzakta. Son konumu DAAK NODE menüsünden açabilirsin."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "app.daaknode.phone-separated",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private static func distanceText(_ distance: Double) -> String {
        if distance >= 1_000 {
            return String(format: "%.1f km", distance / 1_000)
        }
        return "\(Int(distance.rounded())) m"
    }
}

@MainActor
private final class RelayMonitor: ObservableObject {
    @Published private(set) var status: RelayStatus?
    @Published private(set) var lastError: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isSettingPower = false
    @Published private(set) var isMaintainingMemory = false
    @Published var host: String

    private var timer: Timer?
    private let hostKey = "daaklolileHost"
    private let legacyHostKey = "lolileHost"

    init() {
        host = UserDefaults.standard.string(forKey: hostKey)
            ?? UserDefaults.standard.string(forKey: legacyHostKey)
            ?? ""
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    deinit {
        timer?.invalidate()
    }

    var isOnline: Bool {
        guard let status else { return false }
        return status.service.running && status.port.listening && status.bootstrap >= 100
    }

    var isConnected: Bool {
        status != nil
    }

    var menuTitle: String {
        guard let status else { return "daakLOLILE —" }
        if status.hardware?.available == true,
           let watts = status.hardware?.power?.wallEstimateWatts {
            return "daakLOLILE \(String(format: "%.0f W", watts))"
        }
        return "daakLOLILE \(Self.formatGigabytes(status.support?.total ?? status.traffic.total))"
    }

    var baseURL: URL? {
        Self.makeBaseURL(from: host)
    }

    func saveAndRefresh() async {
        host = Self.cleanedHost(host)
        UserDefaults.standard.set(host, forKey: hostKey)
        status = nil
        lastError = nil
        await refresh()
    }

    func refresh() async {
        guard let baseURL else {
            lastError = host.isEmpty ? "Önce Windows PC’nin Tailscale IP’sini yaz." : "IP adresi geçerli değil."
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let url = baseURL.appendingPathComponent("api/status")
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.timeoutInterval = 8
            request.setValue("daakLOLILEMenu/2.1", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw MonitorError.badResponse
            }
            let decoded = try JSONDecoder().decode(RelayStatus.self, from: data)
            status = decoded
            lastError = nil
        } catch {
            lastError = "PC’ye ulaşılamadı. İki cihazda da Tailscale’in açık olduğundan emin ol."
        }
    }

    func openDashboard() {
        guard let baseURL else { return }
        NSWorkspace.shared.open(baseURL)
    }

    func setPowerMode(_ mode: String) async {
        guard let baseURL, status?.permissions?.power == true else { return }
        isSettingPower = true
        defer { isSettingPower = false }
        do {
            let url = baseURL.appendingPathComponent("api/power")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 12
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("daakLOLILEMenu/2.1", forHTTPHeaderField: "User-Agent")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["mode": mode])
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw MonitorError.badResponse
            }
            await refresh()
        } catch {
            lastError = "Güç modu değiştirilemedi. Tailscale bağlantısını kontrol et."
        }
    }

    func maintainMemory() async {
        guard let baseURL, status?.permissions?.memory == true else { return }
        isMaintainingMemory = true
        defer { isMaintainingMemory = false }
        do {
            let url = baseURL.appendingPathComponent("api/memory/maintain")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 20
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("daakLOLILEMenu/2.1", forHTTPHeaderField: "User-Agent")
            request.httpBody = Data("{}".utf8)
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw MonitorError.badResponse
            }
            await refresh()
        } catch {
            lastError = "Bellek bakımı başlatılamadı. Tailscale bağlantısını kontrol et."
        }
    }

    static func formatBytes(_ bytes: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .decimal
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(max(0, bytes)))
    }

    static func formatGigabytes(_ bytes: Double) -> String {
        let value = max(0, bytes) / 1_000_000_000
        if value >= 100 { return String(format: "%.0f GB", value) }
        if value >= 10 { return String(format: "%.1f GB", value) }
        return String(format: "%.2f GB", value)
    }

    static func formatPercent(_ value: Double?) -> String {
        String(format: "%%%.0f", max(0, value ?? 0))
    }

    static func formatTemperature(_ value: Double?) -> String {
        guard let value else { return "sensör yok" }
        return String(format: "%.0f°C", value)
    }

    static func formatPower(_ value: Double?, estimated: Bool = false) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f W%@", value, estimated ? " tah." : "")
    }

    static func formatCostRange(low: Double, high: Double) -> String {
        String(format: "₺%.2f–%.2f", max(0, low), max(0, high))
    }

    static func formatRate(_ bytes: Double?) -> String {
        "\(formatBytes(max(0, bytes ?? 0)))/sn"
    }

    static func volunteerState(_ state: String, running: Bool) -> String {
        if running {
            switch state {
            case "working": return "İşliyor"
            case "measuring": return "Ölçüm yapıyor"
            default: return "Çalışıyor"
            }
        }
        switch state {
        case "account-required": return "Hesap bekliyor"
        case "windows-feature-required": return "WSL bekliyor"
        case "distro-required": return "Linux bekliyor"
        case "reboot-required": return "Yeniden başlatma bekliyor"
        case "probe-install-required": return "Prob bekliyor"
        case "not-installed": return "Kurulum bekliyor"
        case "stopped": return "Kapalı"
        case "error": return "Hata"
        default: return "Hazırlanıyor"
        }
    }

    private static func cleanedHost(_ value: String) -> String {
        var cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "http://", with: "", options: [.caseInsensitive, .anchored])
        cleaned = cleaned.replacingOccurrences(of: "https://", with: "", options: [.caseInsensitive, .anchored])
        if let slash = cleaned.firstIndex(of: "/") {
            cleaned = String(cleaned[..<slash])
        }
        if cleaned.hasSuffix(":17657") {
            cleaned.removeLast(6)
        }
        return cleaned
    }

    private static func makeBaseURL(from value: String) -> URL? {
        let cleaned = cleanedHost(value)
        guard !cleaned.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "http"
        components.host = cleaned
        components.port = 17657
        return components.url
    }

    private enum MonitorError: Error {
        case badResponse
    }
}

private struct StatusPill: View {
    let online: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(online ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(online ? "PC bağlı" : "Bağlantı bekleniyor")
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary, in: Capsule())
    }
}

private struct MetricRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontDesign(.monospaced)
                .textSelection(.enabled)
        }
        .font(.callout)
    }
}

private enum DevicePanel: String, CaseIterable, Identifiable {
    case devices
    case lolile
    case myaL11
    case node

    var id: String { rawValue }

    var title: String {
        switch self {
        case .devices: return "Cihazlar"
        case .lolile: return "LOLİLE"
        case .myaL11: return "MYA-L11"
        case .node: return "S9+"
        }
    }
}

private struct DeviceCard: View {
    let name: String
    let detail: String
    let symbol: String
    let online: Bool
    let status: String
    let actionTitle: String
    let action: () -> Void
    let openDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: openDetails) {
                HStack(spacing: 12) {
                    Image(systemName: symbol)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(online ? Color.green : Color.orange)
                        .frame(width: 38, height: 38)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(name)
                            .font(.headline)
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 5) {
                        Circle()
                            .fill(online ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(13)
        .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct DeviceOverviewView: View {
    @EnvironmentObject private var relay: RelayMonitor
    @EnvironmentObject private var node: NodeMonitor
    @EnvironmentObject private var myaL11: MYAL11Monitor
    @Binding var selection: DevicePanel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tüm cihazların tek güvenli merkezde")
                .font(.caption)
                .foregroundStyle(.secondary)

            DeviceCard(
                name: "LOLİLE",
                detail: "Windows · Relay · Uzaktan kontrol",
                symbol: "desktopcomputer",
                online: relay.isConnected,
                status: relay.isConnected ? "Tailscale üzerinden bağlı" : "Bağlantı bekleniyor",
                actionTitle: "Paneli aç",
                action: relay.openDashboard,
                openDetails: { selection = .lolile }
            )

            DeviceCard(
                name: "MYA-L11",
                detail: "Intel Mac · Sunucu · Ekran · Disk",
                symbol: "laptopcomputer",
                online: myaL11.isOnline,
                status: myaL11.isOnline ? myaL11.routeLabel : "Bağlantı bekleniyor",
                actionTitle: "Ekranı aç",
                action: myaL11.openScreen,
                openDetails: { selection = .myaL11 }
            )

            DeviceCard(
                name: "DAAK NODE",
                detail: "Galaxy S9+ · Find · SSH · Canlı ekran",
                symbol: "iphone",
                online: node.isOnline,
                status: node.stateLabel,
                actionTitle: "Ekranı aç",
                action: { Task { await node.openLiveScreen() } },
                openDetails: { selection = .node }
            )

            HStack(spacing: 10) {
                Image(systemName: "laptopcomputer")
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("BU MAC")
                        .font(.caption.weight(.semibold))
                    Text("DAAK cihaz kontrol merkezi")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Yerel")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            Divider()

            HStack {
                Button {
                    Task {
                        async let relayRefresh: Void = relay.refresh()
                        async let nodeRefresh: Void = node.refresh()
                        async let myaRefresh: Void = myaL11.refresh()
                        _ = await (relayRefresh, nodeRefresh, myaRefresh)
                    }
                } label: {
                    Label("Tümünü yenile", systemImage: "arrow.clockwise")
                }
                .disabled(relay.isRefreshing || node.isRefreshing || myaL11.isRefreshing)

                Spacer()

                Button("Çıkış") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
    }
}

private struct MYAL11MenuView: View {
    @EnvironmentObject private var monitor: MYAL11Monitor
    @State private var confirmsShutdown = false
    @State private var confirmsRestart = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("MYA-L11")
                        .font(.headline)
                    Text("Intel i9 MacBook Pro 16 · sunucu")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusPill(online: monitor.isOnline)
            }

            HStack(spacing: 6) {
                Image(systemName: monitor.route == .cable ? "cable.connector" : "network")
                    .foregroundStyle(monitor.isOnline ? Color.green : Color.orange)
                Text(monitor.routeLabel)
                    .font(.caption.weight(.medium))
                Spacer()
                Text("Kablo öncelikli · otomatik geçiş")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))

            if let status = monitor.status {
                VStack(spacing: 9) {
                    MetricRow(title: "Pil", value: "%\(status.batteryPercent) · \(status.batteryCondition) · \(status.batteryCycles) döngü")
                    MetricRow(title: "Güç", value: status.powerSource)
                    MetricRow(title: "UPS", value: status.upsMessage ?? "UPS telemetrisi bekleniyor")
                    MetricRow(title: "CPU", value: status.cpuUsagePercent.map { String(format: "%%%.0f", $0) } ?? status.loadAverage.trimmingCharacters(in: .whitespaces))
                    MetricRow(title: "Sıcaklık", value: status.cpuTemperatureC.map { String(format: "%.0f°C", $0) } ?? "Sensör izni yok")
                    MetricRow(title: "Boş RAM", value: "%\(status.memoryFreePercent)")
                    MetricRow(title: "Boş disk", value: Self.formatKB(status.diskFreeKb))
                    MetricRow(title: "Docker", value: "\(status.dockerContainersRunning) konteyner")
                    MetricRow(title: "Stats", value: status.services.stats == true ? "Çalışıyor" : "Kontrol gerekli")
                    MetricRow(title: "SSH / Ekran", value: status.services.ssh && status.services.screenSharing ? "Açık / Açık" : "Kontrol gerekli")
                    MetricRow(title: "Uyanık tutma", value: status.services.caffeinateGuard ? "Aktif" : "Kontrol gerekli")
                }
            } else {
                Text(monitor.lastError ?? "Telemetri bekleniyor…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button(action: monitor.openScreen) {
                    Label("Ekran", systemImage: "rectangle.on.rectangle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!monitor.isOnline)

                Button(action: monitor.openDisk) {
                    Label("Disk", systemImage: "externaldrive")
                }
                .buttonStyle(.bordered)
                .disabled(!monitor.isOnline)

                Button(action: monitor.openSSH) {
                    Label("SSH", systemImage: "terminal")
                }
                .buttonStyle(.bordered)
                .disabled(!monitor.isOnline)
            }

            Divider()

            HStack(spacing: 7) {
                Button("Uyandır") { Task { await monitor.power("wake") } }
                    .disabled(monitor.isRunningAction)
                Button("Uyut") { Task { await monitor.power("sleep") } }
                    .disabled(!monitor.isOnline || monitor.isRunningAction)
                Button("Yeniden başlat") { confirmsRestart = true }
                    .disabled(!monitor.isOnline || monitor.isRunningAction)
                Button("Kapat") { confirmsShutdown = true }
                    .disabled(!monitor.isOnline || monitor.isRunningAction)
                    .tint(.red)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Text("Kapatma sonrası Wake-on-LAN garanti değildir; uzaktan erişimi kaybetmemek için normalde yeniden başlat veya uyut.")
                .font(.caption2)
                .foregroundStyle(.orange)

            if let message = monitor.actionMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button {
                    Task { await monitor.refresh() }
                } label: {
                    Label("Yenile", systemImage: "arrow.clockwise")
                }
                .disabled(monitor.isRefreshing)
                Spacer()
                Text("Yalnızca kablo / Tailnet")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .confirmationDialog("MYA-L11 yeniden başlatılsın mı?", isPresented: $confirmsRestart) {
            Button("Yeniden başlat") { Task { await monitor.power("restart") } }
            Button("Vazgeç", role: .cancel) {}
        }
        .confirmationDialog("MYA-L11 kapatılsın mı?", isPresented: $confirmsShutdown) {
            Button("Kapat", role: .destructive) { Task { await monitor.power("shutdown") } }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Tamamen kapandıktan sonra uzaktan yeniden açılması garanti değildir.")
        }
    }

    private static func formatKB(_ value: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: max(0, value) * 1024)
    }
}

private struct NodeMenuView: View {
    @EnvironmentObject private var node: NodeMonitor
    @EnvironmentObject private var separation: SeparationMonitor
    @State private var draftHost = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("DAAK NODE")
                        .font(.headline)
                    Text("Galaxy S9+ · özel Tailscale hattı")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(node.isOnline ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(node.isOnline ? "Bağlı" : "Bekleniyor")
                        .font(.caption.weight(.medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary, in: Capsule())
            }

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Image(systemName: node.hasLocation ? "location.fill" : "location.slash")
                        .foregroundStyle(node.hasLocation ? Color.green : Color.orange)
                    Text(node.stateLabel)
                        .font(.headline)
                }
                Text(node.lastLocationLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 5) {
                    Image(systemName: "bell.and.waves.left.and.right")
                    Text(separation.statusLabel)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                if separation.statusLabel.contains("izin gerekli") {
                    HStack(spacing: 10) {
                        Button("Bildirim izni") {
                            separation.openNotificationSettings()
                        }
                        Button("Konum izni") {
                            separation.openLocationSettings()
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.link)
                }
                if let detail = node.status?.lastError, !detail.isEmpty {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 8) {
                Button {
                    Task { await node.openFind() }
                } label: {
                    Label("Haritada bul", systemImage: "map")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!node.hasLocation)

                Button {
                    Task { await node.openLiveScreen() }
                } label: {
                    Label("Canlı ekran", systemImage: "rectangle.inset.filled.and.person.filled")
                }
                .buttonStyle(.bordered)
                .disabled(!node.isOnline)

                Button {
                    node.openSSH()
                } label: {
                    Label("SSH", systemImage: "terminal")
                }
                .buttonStyle(.bordered)
                .disabled(!node.isOnline)
            }

            Button {
                Task { await node.setPhoneExitNode(enabled: !node.isUsingPhoneExitNode) }
            } label: {
                Label(
                    node.isUsingPhoneExitNode ? "S9 çıkışını kapat" : "Mac’i S9 üzerinden çıkar",
                    systemImage: node.isUsingPhoneExitNode ? "network.slash" : "shield.lefthalf.filled"
                )
            }
            .buttonStyle(.bordered)
            .disabled(!node.isPhoneExitNodeAvailable || node.isSettingExitNode)

            Text(
                node.isUsingPhoneExitNode
                    ? "Açık · IP tabanlı konum S9’un internet çıkışını kullanıyor."
                    : "Kapalı · VPN/exit node yalnızca istediğinde açılır."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

            if let message = node.actionMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = node.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                Text("S9+ · Tailscale IP")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("100.x.x.x", text: $draftHost)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            node.host = draftHost
                            Task { await node.saveAndRefresh() }
                        }
                    Button("Bağlan") {
                        node.host = draftHost
                        Task { await node.saveAndRefresh() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            HStack {
                Button {
                    Task { await node.refresh() }
                } label: {
                    Label("Yenile", systemImage: "arrow.clockwise")
                }
                .disabled(node.isRefreshing)

                Spacer()

                Text("Konum dışarı açılmaz · yalnızca Tailnet")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .onAppear { draftHost = node.host }
    }
}

private struct DAAKDevicesMenuView: View {
    @EnvironmentObject private var relay: RelayMonitor
    @EnvironmentObject private var node: NodeMonitor
    @EnvironmentObject private var myaL11: MYAL11Monitor
    @EnvironmentObject private var separation: SeparationMonitor
    @State private var selection: DevicePanel = .devices

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "circle.grid.2x2.fill")
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 1) {
                    Text("DAAK NODE")
                        .font(.headline)
                    Text("Cihaz merkezi")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\([relay.isConnected, myaL11.isOnline, node.isOnline].filter { $0 }.count)/3 bağlı")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Picker("Cihaz", selection: $selection) {
                ForEach(DevicePanel.allCases) { panel in
                    Text(panel.title).tag(panel)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider()

            switch selection {
            case .devices:
                DeviceOverviewView(selection: $selection)
            case .lolile:
                ScrollView {
                    RelayMenuView()
                }
                .frame(maxHeight: 690)
            case .myaL11:
                MYAL11MenuView()
            case .node:
                NodeMenuView()
            }
        }
        .frame(width: 420)
        .onReceive(node.$location) { location in
            separation.updatePhoneLocation(location)
        }
    }
}

private struct RelayMenuView: View {
    @EnvironmentObject private var monitor: RelayMonitor
    @State private var draftHost = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("daakLOLILE")
                        .font(.headline)
                    Text("Windows sistem monitörü")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusPill(online: monitor.isConnected)
            }

            Divider()

            if let status = monitor.status {
                if let hardware = status.hardware, hardware.available {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(String(format: "%.0f", hardware.power?.wallEstimateWatts ?? 0))
                                .font(.system(size: 38, weight: .semibold, design: .rounded))
                            Text("W")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.purple)
                        }
                        Text("Tahmini anlık priz tüketimi")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 9) {
                        MetricRow(
                            title: "CPU",
                            value: "\(RelayMonitor.formatPercent(hardware.cpu?.loadPercent)) · \(RelayMonitor.formatTemperature(hardware.cpu?.temperatureC)) · \(RelayMonitor.formatPower(hardware.cpu?.powerWatts, estimated: hardware.cpu?.powerSource != "sensor"))"
                        )
                        MetricRow(
                            title: "GPU",
                            value: "\(RelayMonitor.formatPercent(hardware.gpu?.loadPercent)) · \(RelayMonitor.formatTemperature(hardware.gpu?.temperatureC)) · \(RelayMonitor.formatPower(hardware.gpu?.powerWatts, estimated: hardware.gpu?.powerSource != "sensor"))"
                        )
                        MetricRow(
                            title: "RAM",
                            value: "\(RelayMonitor.formatPercent(hardware.memory?.loadPercent)) · \(RelayMonitor.formatBytes(hardware.memory?.usedBytes ?? 0))"
                        )
                        MetricRow(
                            title: "Ethernet",
                            value: "↓ \(RelayMonitor.formatRate(hardware.network?.ethernet?.downloadBytesPerSecond)) · ↑ \(RelayMonitor.formatRate(hardware.network?.ethernet?.uploadBytesPerSecond))"
                        )
                        MetricRow(
                            title: "Bugün / Bu ay",
                            value: String(format: "%.3f / %.3f kWh", hardware.power?.todayKWh ?? 0, hardware.power?.monthKWh ?? 0)
                        )
                    }
                } else {
                    Text("Donanım sensörleri hazırlanıyor…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Divider()

                if let electricity = status.electricity, electricity.available {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Elektrik faturası · bu ay")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(RelayMonitor.formatCostRange(
                                    low: electricity.month.lowTierTry,
                                    high: electricity.month.highTierTry
                                ))
                                .font(.headline.monospacedDigit())
                            }
                            Spacer()
                            Text(String(format: "%.3f kWh", electricity.month.kWh))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        MetricRow(
                            title: "Bugün",
                            value: RelayMonitor.formatCostRange(
                                low: electricity.today.lowTierTry,
                                high: electricity.today.highTierTry
                            )
                        )
                        MetricRow(
                            title: "Bu güç 30 gün sürerse",
                            value: RelayMonitor.formatCostRange(
                                low: electricity.runRate30Days.lowTierTry,
                                high: electricity.runRate30Days.highTierTry
                            )
                        )
                        MetricRow(
                            title: "Yıllık çalışma hızı",
                            value: String(
                                format: "%.0f kWh · SKTT %%%.1f",
                                electricity.runRateAnnual.kWh,
                                electricity.runRateAnnual.skttPercent
                            )
                        )
                        Text("\(electricity.tariff.location) · düşük/yüksek mesken kademesi · akıllı priz yok, PC payı tahminidir.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let recommendation = electricity.scheduleRecommendation {
                            Text("Puant eko \(recommendation.ecoStart)–\(recommendation.ecoEnd) · Snowflake açık kalır · tek zamanlı tarifede saatlik fiyat değişmez.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()
                }

                if let power = status.power, power.available {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Güç modu")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(powerModeLabel(power.effectiveMode))
                                    .font(.headline)
                            }
                            Spacer()
                            Text(power.controlMode == "auto" ? "Puant \(power.nightStart)–\(power.nightEnd)" : "Elle seçildi")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 6) {
                            powerButton("Oto", mode: "auto", selected: power.controlMode == "auto")
                            powerButton("Eko", mode: "eco", selected: power.controlMode == "eco")
                            powerButton("Denge", mode: "balanced", selected: power.controlMode == "balanced")
                            powerButton("Hız", mode: "performance", selected: power.controlMode == "performance")
                        }

                        Text("Uyku kapalıdır; Tor, Tailscale, uzaktan masaüstü ve disk paylaşımı çalışmaya devam eder.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                }

                if let memory = status.memoryMaintenance, memory.available {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Güvenli RAM bakımı")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(memory.pressureDetected ? "Bellek baskısı izlendi" : "RAM dengeli")
                                    .font(.headline)
                            }
                            Spacer()
                            Button(monitor.isMaintainingMemory ? "Bakım yapılıyor…" : "Şimdi bakım") {
                                Task { await monitor.maintainMemory() }
                            }
                            .disabled(
                                monitor.isMaintainingMemory ||
                                status.permissions?.memory != true
                            )
                        }

                        Text("Her gün \(memory.schedule.dailyAt) · Windows önbelleği, Tor ve uzaktan bağlantılar korunur.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                }

                if let volunteer = status.volunteer {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Gönüllü projeler")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(status.support?.activeProjects ?? 0)/4 aktif")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        MetricRow(
                            title: "Folding@home",
                            value: RelayMonitor.volunteerState(volunteer.folding.state, running: volunteer.folding.running)
                        )
                        MetricRow(
                            title: "BOINC",
                            value: RelayMonitor.volunteerState(volunteer.boinc.state, running: volunteer.boinc.running)
                        )
                        MetricRow(
                            title: "RIPE Atlas",
                            value: RelayMonitor.volunteerState(volunteer.ripeAtlas.state, running: volunteer.ripeAtlas.running)
                        )
                        Text("Snowflake 7/24; bilimsel işler kontrollü kaynaklarla. Genel disk paylaşımı yok.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Ağ desteği")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(RelayMonitor.formatGigabytes(status.support?.total ?? status.traffic.total))
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                }

                VStack(spacing: 9) {
                    MetricRow(title: "Middle relay", value: RelayMonitor.formatBytes(status.traffic.total))
                    MetricRow(
                        title: "Snowflake",
                        value: status.snowflake?.running == true
                            ? "\(RelayMonitor.formatBytes(status.snowflake?.traffic.total ?? 0)) · aktif"
                            : "Kapalı"
                    )
                    MetricRow(title: "Eşleşme", value: "Tor talebine göre")
                    Text("Bağlantı oturumları benzersiz kişi sayısı değildir; gizlilik gereği kişi tahmini gösterilmez.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    MetricRow(
                        title: "Aylık kota",
                        value: (status.traffic.unlimited ?? (status.traffic.quota <= 0))
                            ? "Sınırsız"
                            : RelayMonitor.formatBytes(status.traffic.quota)
                    )
                    MetricRow(title: "Hız", value: "\(status.config.rateMbps) / \(status.config.burstMbps) Mbps")
                    MetricRow(title: "Bootstrap", value: "%\(status.bootstrap)")
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(monitor.lastError ?? "Relay durumu alınıyor…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            }

            if let error = monitor.lastError, monitor.status != nil {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                Text("Windows PC · Tailscale IP")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("100.x.x.x", text: $draftHost)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            monitor.host = draftHost
                            Task { await monitor.saveAndRefresh() }
                        }
                    Button("Bağlan") {
                        monitor.host = draftHost
                        Task { await monitor.saveAndRefresh() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            HStack {
                Button {
                    Task { await monitor.refresh() }
                } label: {
                    Label("Yenile", systemImage: "arrow.clockwise")
                }
                .disabled(monitor.isRefreshing)

                Button {
                    monitor.openDashboard()
                } label: {
                    Label("Paneli aç", systemImage: "safari")
                }
                .disabled(monitor.baseURL == nil)

                Spacer()

                Button("Çıkış") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 390)
        .onAppear {
            draftHost = monitor.host
        }
    }

    private func powerButton(_ title: String, mode: String, selected: Bool) -> some View {
        Button(title) {
            Task { await monitor.setPowerMode(mode) }
        }
        .buttonStyle(.bordered)
        .tint(selected ? .green : .purple)
        .disabled(monitor.isSettingPower || monitor.status?.permissions?.power != true)
    }

    private func powerModeLabel(_ mode: String) -> String {
        switch mode {
        case "eco": return "Derin eko"
        case "performance": return "Yüksek performans"
        case "balanced": return "Dengeli"
        default: return "Hazırlanıyor"
        }
    }
}

@main
struct daakLOLILEApp: App {
    @StateObject private var relay = RelayMonitor()
    @StateObject private var node = NodeMonitor()
    @StateObject private var myaL11 = MYAL11Monitor()
    @StateObject private var separation = SeparationMonitor()

    var body: some Scene {
        MenuBarExtra {
            DAAKDevicesMenuView()
                .environmentObject(relay)
                .environmentObject(node)
                .environmentObject(myaL11)
                .environmentObject(separation)
        } label: {
            Image(systemName: "circle.grid.2x2.fill")
                .accessibilityLabel("DAAK NODE cihaz merkezi")
        }
        .menuBarExtraStyle(.window)
    }
}
