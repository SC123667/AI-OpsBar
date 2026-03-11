import Foundation

struct CodexLocalUsageMonitor {
    private let fileManager = FileManager.default
    private let fractionalSecondTimestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private var sessionsDirectoryURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)
    }

    private var archivedSessionsDirectoryURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("archived_sessions", isDirectory: true)
    }

    private var usageDirectoryURLs: [URL] {
        [sessionsDirectoryURL, archivedSessionsDirectoryURL].filter {
            fileManager.fileExists(atPath: $0.path)
        }
    }

    func fetchQuotaFallbackSnapshot() -> QuotaSnapshot? {
        guard let report = scanUsageReport(),
              let quota = report.latestQuota else {
            return nil
        }

        var parts: [String] = []

        if let plan = quota.planType, !plan.isEmpty {
            parts.append("\(L10n.text(.quotaPlanPrefix)) \(plan)")
        }

        if let primaryUsed = quota.primaryUsedPercent {
            parts.append("P \(primaryUsed)%\(durationSuffix(minutes: quota.primaryWindowMinutes))")
        }

        if let secondaryUsed = quota.secondaryUsedPercent {
            parts.append("S \(secondaryUsed)%\(durationSuffix(minutes: quota.secondaryWindowMinutes))")
        }

        if let resetAt = quota.primaryResetAt {
            parts.append("\(L10n.text(.quotaResetPrefix)) \(DateFormatter.localizedString(from: resetAt, dateStyle: .none, timeStyle: .short))")
        }

        if let balance = quota.creditBalance, !balance.isEmpty {
            parts.append("\(L10n.text(.quotaCreditsPrefix)) \(balance)")
        }

        return QuotaSnapshot(
            label: L10n.text(.quotaCodexLocalSource),
            remaining: quota.primaryUsedPercent.map { max(0, 100 - $0) },
            limit: quota.primaryUsedPercent == nil ? nil : 100,
            resetAt: quota.primaryResetAt,
            detail: L10n.text(.quotaCodexLocalFallbackHint),
            summaryText: parts.isEmpty ? L10n.text(.quotaCodexWaitingSummary) : parts.joined(separator: " · ")
        )
    }

    func fetchUsageSpendSnapshot() -> SpendSnapshot? {
        guard let report = scanUsageReport(),
              report.totalTokens > 0 else {
            return nil
        }

        let tokenCounts = Dictionary(uniqueKeysWithValues: SpendWindow.allCases.map { window in
            (window.rawValue, report.tokens(for: window))
        })

        return SpendSnapshot(
            label: L10n.text(.spendMonitoring),
            currencyCode: "USD",
            amounts: [:],
            tokenCounts: tokenCounts,
            detail: L10n.text(.spendCodexLocalHint),
            summaryText: nil,
            isEstimated: false
        )
    }

    private func scanUsageReport() -> UsageReport? {
        guard !usageDirectoryURLs.isEmpty else {
            return nil
        }

        var tokensByWindow: [SpendWindow: Int] = [:]
        SpendWindow.allCases.forEach { tokensByWindow[$0] = 0 }

        let now = Date()
        var latestQuota: QuotaRecord?
        var seenUsageKeys = Set<String>()

        for directoryURL in usageDirectoryURLs {
            guard let enumerator = fileManager.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "jsonl" else {
                    continue
                }

                guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
                    continue
                }

                for line in contents.split(separator: "\n") {
                    let lineString = String(line)

                    guard let data = lineString.data(using: .utf8),
                          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let timestampString = object["timestamp"] as? String,
                          let timestamp = parseTimestamp(timestampString),
                          let type = object["type"] as? String,
                          type == "event_msg",
                          let payload = object["payload"] as? [String: Any],
                          let payloadType = payload["type"] as? String,
                          payloadType == "token_count" else {
                        continue
                    }

                    if let quota = quotaRecord(from: payload["rate_limits"], timestamp: timestamp),
                       quota.limitID == "codex" {
                        if latestQuota == nil || quota.timestamp > latestQuota?.timestamp ?? .distantPast {
                            latestQuota = quota
                        }
                    }

                    guard let usage = tokenUsage(from: payload["info"]),
                          usage.totalTokens > 0 else {
                        continue
                    }

                    let dedupeKey = "\(timestampString)|\(usage.inputTokens)|\(usage.cachedInputTokens)|\(usage.outputTokens)|\(usage.reasoningOutputTokens)|\(usage.totalTokens)"
                    guard seenUsageKeys.insert(dedupeKey).inserted else {
                        continue
                    }

                    for window in SpendWindow.allCases {
                        if includes(timestamp: timestamp, in: window, now: now) {
                            tokensByWindow[window, default: 0] += usage.totalTokens
                        }
                    }
                }
            }
        }

        return UsageReport(tokensByWindow: tokensByWindow, latestQuota: latestQuota)
    }

    private func parseTimestamp(_ timestampString: String) -> Date? {
        fractionalSecondTimestampFormatter.date(from: timestampString)
            ?? timestampFormatter.date(from: timestampString)
    }

    private func tokenUsage(from infoValue: Any?) -> TokenUsage? {
        guard let info = infoValue as? [String: Any] else {
            return nil
        }

        let container = (info["last_token_usage"] as? [String: Any])
            ?? (info["lastTokenUsage"] as? [String: Any])
            ?? (info["total_token_usage"] as? [String: Any])
            ?? (info["totalTokenUsage"] as? [String: Any])

        guard let usage = container else {
            return nil
        }

        let inputTokens = intValue(usage["input_tokens"] ?? usage["inputTokens"]) ?? 0
        let cachedInputTokens = intValue(usage["cached_input_tokens"] ?? usage["cachedInputTokens"]) ?? 0
        let outputTokens = intValue(usage["output_tokens"] ?? usage["outputTokens"]) ?? 0
        let reasoningOutputTokens = intValue(usage["reasoning_output_tokens"] ?? usage["reasoningOutputTokens"]) ?? 0
        let totalTokens = intValue(usage["total_tokens"] ?? usage["totalTokens"]) ?? (inputTokens + outputTokens)

        return TokenUsage(
            inputTokens: inputTokens,
            cachedInputTokens: cachedInputTokens,
            outputTokens: outputTokens,
            reasoningOutputTokens: reasoningOutputTokens,
            totalTokens: totalTokens
        )
    }

    private func quotaRecord(from rateLimitsValue: Any?, timestamp: Date) -> QuotaRecord? {
        guard let rateLimits = rateLimitsValue as? [String: Any] else {
            return nil
        }

        return QuotaRecord(
            timestamp: timestamp,
            limitID: stringValue(rateLimits["limit_id"] ?? rateLimits["limitId"]),
            planType: stringValue(rateLimits["plan_type"] ?? rateLimits["planType"]),
            primaryUsedPercent: intValue((rateLimits["primary"] as? [String: Any])?["used_percent"] ?? (rateLimits["primary"] as? [String: Any])?["usedPercent"]),
            secondaryUsedPercent: intValue((rateLimits["secondary"] as? [String: Any])?["used_percent"] ?? (rateLimits["secondary"] as? [String: Any])?["usedPercent"]),
            primaryWindowMinutes: intValue((rateLimits["primary"] as? [String: Any])?["window_minutes"] ?? (rateLimits["primary"] as? [String: Any])?["windowDurationMins"]),
            secondaryWindowMinutes: intValue((rateLimits["secondary"] as? [String: Any])?["window_minutes"] ?? (rateLimits["secondary"] as? [String: Any])?["windowDurationMins"]),
            primaryResetAt: dateValue((rateLimits["primary"] as? [String: Any])?["resets_at"] ?? (rateLimits["primary"] as? [String: Any])?["resetsAt"]),
            creditBalance: stringValue((rateLimits["credits"] as? [String: Any])?["balance"])
        )
    }

    private func includes(timestamp: Date, in window: SpendWindow, now: Date) -> Bool {
        if window == .all {
            return true
        }

        let cutoff = now.addingTimeInterval(-windowDuration(for: window))
        return timestamp >= cutoff
    }

    private func windowDuration(for window: SpendWindow) -> TimeInterval {
        switch window {
        case .fiveHours:
            return 5 * 60 * 60
        case .oneDay:
            return 24 * 60 * 60
        case .sevenDays:
            return 7 * 24 * 60 * 60
        case .thirtyDays:
            return 30 * 24 * 60 * 60
        case .all:
            return .greatestFiniteMagnitude
        }
    }
    private func durationSuffix(minutes: Int?) -> String {
        guard let minutes else {
            return ""
        }

        if minutes >= 1_440 {
            return "/\(Int((Double(minutes) / 1_440).rounded()))d"
        }

        if minutes >= 60 {
            return "/\(Int((Double(minutes) / 60).rounded()))h"
        }

        return "/\(minutes)m"
    }

    private func intValue(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string)
        default:
            return nil
        }
    }

    private func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private func dateValue(_ value: Any?) -> Date? {
        guard let seconds = intValue(value), seconds > 0 else {
            return nil
        }

        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }
}

private struct UsageReport {
    let tokensByWindow: [SpendWindow: Int]
    let latestQuota: QuotaRecord?

    var totalTokens: Int {
        tokensByWindow[.all] ?? 0
    }

    func tokens(for window: SpendWindow) -> Int {
        tokensByWindow[window] ?? 0
    }
}

private struct TokenUsage {
    let inputTokens: Int
    let cachedInputTokens: Int
    let outputTokens: Int
    let reasoningOutputTokens: Int
    let totalTokens: Int
}

private struct QuotaRecord {
    let timestamp: Date
    let limitID: String?
    let planType: String?
    let primaryUsedPercent: Int?
    let secondaryUsedPercent: Int?
    let primaryWindowMinutes: Int?
    let secondaryWindowMinutes: Int?
    let primaryResetAt: Date?
    let creditBalance: String?
}
