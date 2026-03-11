import Foundation

struct ServiceHistoryStore {
    static func load() -> [String: [ServiceHistorySample]] {
        guard let data = UserDefaults.standard.data(forKey: AppConfig.historyKey),
              let history = try? JSONDecoder().decode([String: [ServiceHistorySample]].self, from: data) else {
            return [:]
        }

        return history
    }

    static func save(_ history: [String: [ServiceHistorySample]]) {
        guard let data = try? JSONEncoder().encode(history) else {
            return
        }

        UserDefaults.standard.set(data, forKey: AppConfig.historyKey)
    }

    static func append(
        summaries: [ServiceStatusSummary],
        checkedAt: Date,
        into history: inout [String: [ServiceHistorySample]]
    ) {
        for summary in summaries {
            let sample = ServiceHistorySample(
                checkedAt: checkedAt,
                state: summary.overallState,
                issueCount: summary.issueCount,
                latencyMs: summary.primaryLatencyMs,
                quotaSummary: summary.quotaSummary
            )

            var samples = history[summary.serviceID.rawValue] ?? []
            if samples.last?.checkedAt == checkedAt {
                samples.removeLast()
            }
            samples.append(sample)
            if samples.count > AppConfig.historySampleLimit {
                samples.removeFirst(samples.count - AppConfig.historySampleLimit)
            }
            history[summary.serviceID.rawValue] = samples
        }
    }
}
