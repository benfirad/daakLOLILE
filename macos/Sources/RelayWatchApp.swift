import SwiftUI
import AppKit
import Foundation

private struct RelayStatus: Decodable {
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

    let updatedAt: String
    let service: Service
    let port: Port
    let bootstrap: Int
    let consensus: Consensus
    let config: Configuration
    let traffic: Traffic
    let snowflake: Snowflake?
    let support: Support?
    let hardware: Hardware?
}

@MainActor
private final class RelayMonitor: ObservableObject {
    @Published private(set) var status: RelayStatus?
    @Published private(set) var lastError: String?
    @Published private(set) var isRefreshing = false
    @Published var host: String

    private var timer: Timer?
    private let hostKey = "relayWatchHost"

    init() {
        host = UserDefaults.standard.string(forKey: hostKey) ?? ""
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
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
        guard let status else { return "RelayWatch —" }
        if status.hardware?.available == true,
           let watts = status.hardware?.power?.wallEstimateWatts {
            return "RelayWatch \(String(format: "%.0f W", watts))"
        }
        return "RelayWatch \(Self.formatGigabytes(status.support?.total ?? status.traffic.total))"
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
            request.setValue("RelayWatchMenu/1.0", forHTTPHeaderField: "User-Agent")
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

    static func formatRate(_ bytes: Double?) -> String {
        "\(formatBytes(max(0, bytes ?? 0)))/sn"
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

private struct RelayMenuView: View {
    @EnvironmentObject private var monitor: RelayMonitor
    @State private var draftHost = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("RelayWatch")
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
                    MetricRow(title: "Yardım edilen bağlantı", value: String(Int(status.snowflake?.traffic.connections ?? 0)))
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
}

@main
struct RelayWatchApp: App {
    @StateObject private var monitor = RelayMonitor()

    var body: some Scene {
        MenuBarExtra {
            RelayMenuView()
                .environmentObject(monitor)
        } label: {
            Label(monitor.menuTitle, systemImage: monitor.isConnected ? "bolt.fill" : "bolt.slash")
        }
        .menuBarExtraStyle(.window)
    }
}
