import Foundation

actor QuotaSnapshotCache {
    static let shared = QuotaSnapshotCache()

    private var entries: [ServiceID: (snapshot: QuotaSnapshot, checkedAt: Date)] = [:]

    func snapshot(for serviceID: ServiceID, maxAge: TimeInterval) -> QuotaSnapshot? {
        guard let entry = entries[serviceID] else {
            return nil
        }

        guard Date().timeIntervalSince(entry.checkedAt) <= maxAge else {
            return nil
        }

        return entry.snapshot
    }

    func store(_ snapshot: QuotaSnapshot, for serviceID: ServiceID) {
        entries[serviceID] = (snapshot, Date())
    }
}

actor SpendSnapshotCache {
    static let shared = SpendSnapshotCache()

    private var entries: [ServiceID: (snapshot: SpendSnapshot, checkedAt: Date)] = [:]

    func snapshot(for serviceID: ServiceID, maxAge: TimeInterval) -> SpendSnapshot? {
        guard let entry = entries[serviceID] else {
            return nil
        }

        guard Date().timeIntervalSince(entry.checkedAt) <= maxAge else {
            return nil
        }

        return entry.snapshot
    }

    func store(_ snapshot: SpendSnapshot, for serviceID: ServiceID) {
        entries[serviceID] = (snapshot, Date())
    }
}

struct CodexProbeService {
    private let quotaCacheMaxAge: TimeInterval = 30 * 60
    private let codexQuotaCacheMaxAge: TimeInterval = 5 * 60
    private let spendCacheMaxAge: TimeInterval = 30 * 60
    private let codexLocalMonitor = CodexLocalMonitor()
    private let codexLocalUsageMonitor = CodexLocalUsageMonitor()

    func runAllChecks(settings: MonitorSettings) async -> MonitorSnapshot {
        let sessionResult = makeSession(settings: settings)
        let definitions = ServiceDefinitions.all(settings: settings)

        guard case .success(let session) = sessionResult else {
            let detail = (try? sessionResult.get()) == nil ? L10n.text(.detailInvalidProxy) : "Probe setup failed."
            let results = invalidResults(settings: settings, definitions: definitions, detail: detail)
            return MonitorSnapshot(results: results, checkedAt: Date(), overallState: .blocked)
        }

        var results: [ProbeResult] = []

        for definition in definitions where settings.isServiceEnabled(definition.id) {
            if definition.id == .codex {
                if definition.appLabel != nil {
                    results.append(await probeCodexSurface(kind: .app, label: definition.appLabel ?? "App", settings: settings, session: session))
                }

                results.append(await probeCodexSurface(kind: .web, label: definition.webLabel, settings: settings, session: session))

                if let apiProbe = definition.apiProbe {
                    results.append(await probeAdditionalAPI(definition, apiProbe: apiProbe, session: session, settings: settings, overrideURLString: settings.configuredURLString(for: .api)))
                }

                continue
            }

            if definition.webURLString.isEmpty == false {
                results.append(await probeWebService(definition, settings: settings, session: session))
            }

            if let apiProbe = definition.apiProbe {
                results.append(await probeAdditionalAPI(definition, apiProbe: apiProbe, session: session, settings: settings, overrideURLString: nil))
            }
        }

        if results.isEmpty {
            return MonitorSnapshot(results: [], checkedAt: Date(), overallState: .healthy)
        }

        return MonitorSnapshot(
            results: results,
            checkedAt: Date(),
            overallState: Self.resolveOverallState(results: results)
        )
    }

    private func invalidResults(settings: MonitorSettings, definitions: [ServiceDefinition], detail: String) -> [ProbeResult] {
        var results: [ProbeResult] = []

        for definition in definitions where settings.isServiceEnabled(definition.id) {
            if definition.id == .codex {
                results.append(ProbeResult(serviceID: .codex, serviceName: definition.name, probeLabel: definition.appLabel ?? "App Sign-in", kind: .app, requestedURL: settings.configuredURLString(for: .app), state: .fail, detail: detail, statusCode: nil, latencyMs: nil, checkedAt: Date(), quota: nil, spend: nil))
                results.append(ProbeResult(serviceID: .codex, serviceName: definition.name, probeLabel: definition.webLabel, kind: .web, requestedURL: settings.configuredURLString(for: .web), state: .fail, detail: detail, statusCode: nil, latencyMs: nil, checkedAt: Date(), quota: nil, spend: nil))
                results.append(ProbeResult(serviceID: .codex, serviceName: definition.name, probeLabel: definition.apiProbe?.label ?? "API", kind: .api, requestedURL: settings.configuredURLString(for: .api), state: .fail, detail: detail, statusCode: nil, latencyMs: nil, checkedAt: Date(), quota: nil, spend: nil))
                continue
            }

            results.append(ProbeResult(serviceID: definition.id, serviceName: definition.name, probeLabel: definition.webLabel, kind: .web, requestedURL: definition.webURLString, state: .fail, detail: detail, statusCode: nil, latencyMs: nil, checkedAt: Date(), quota: nil, spend: nil))

            if let apiProbe = definition.apiProbe {
                results.append(ProbeResult(serviceID: definition.id, serviceName: definition.name, probeLabel: apiProbe.label, kind: .api, requestedURL: apiProbe.urlString, state: .fail, detail: detail, statusCode: nil, latencyMs: nil, checkedAt: Date(), quota: nil, spend: nil))
            }
        }

        return results
    }

    private func makeSession(settings: MonitorSettings) -> Result<URLSession, Error> {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = AppConfig.requestTimeout
        configuration.timeoutIntervalForResource = AppConfig.requestTimeout
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

        if settings.proxyEnabled {
            let host = settings.proxyHost.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !host.isEmpty, let port = settings.proxyPortValue, port > 0 else {
                return .failure(URLError(.badURL))
            }

            configuration.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable as String: 1,
                kCFNetworkProxiesHTTPProxy as String: host,
                kCFNetworkProxiesHTTPPort as String: port,
                kCFNetworkProxiesHTTPSEnable as String: 1,
                kCFNetworkProxiesHTTPSProxy as String: host,
                kCFNetworkProxiesHTTPSPort as String: port,
            ]
        }

        return .success(URLSession(configuration: configuration))
    }

    private func probeCodexSurface(kind: ProbeKind, label: String, settings: MonitorSettings, session: URLSession) async -> ProbeResult {
        guard let url = settings.resolvedURL(for: kind) else {
            return ProbeResult(serviceID: .codex, serviceName: "Codex", probeLabel: label, kind: kind, requestedURL: settings.configuredURLString(for: kind), state: .fail, detail: L10n.text(.detailInvalidURL), statusCode: nil, latencyMs: nil, checkedAt: Date(), quota: nil, spend: nil)
        }

        return await runRequest(
            serviceID: .codex,
            serviceName: "Codex",
            probeLabel: label,
            kind: kind,
            settings: settings,
            url: url,
            session: session,
            method: kind == .api ? "GET" : "HEAD",
            keychainAccount: kind == .api ? AppConfig.keychainAccount : nil,
            authType: kind == .api ? .bearer : nil,
            extraHeaders: [:],
            body: nil
        )
    }

    private func probeWebService(_ definition: ServiceDefinition, settings: MonitorSettings, session: URLSession) async -> ProbeResult {
        guard let url = URL(string: definition.webURLString) else {
            return ProbeResult(serviceID: definition.id, serviceName: definition.name, probeLabel: definition.webLabel, kind: .web, requestedURL: definition.webURLString, state: .fail, detail: L10n.text(.detailInvalidURL), statusCode: nil, latencyMs: nil, checkedAt: Date(), quota: nil, spend: nil)
        }

        return await runRequest(
            serviceID: definition.id,
            serviceName: definition.name,
            probeLabel: definition.webLabel,
            kind: .web,
            settings: settings,
            url: url,
            session: session,
            method: "HEAD",
            keychainAccount: nil,
            authType: nil,
            extraHeaders: [:],
            body: nil
        )
    }

    private func probeAdditionalAPI(
        _ definition: ServiceDefinition,
        apiProbe: ServiceAPIProbe,
        session: URLSession,
        settings: MonitorSettings,
        overrideURLString: String?
    ) async -> ProbeResult {
        let requestedURLString = overrideURLString ?? apiProbe.urlString

        guard let url = URL(string: requestedURLString) else {
            return ProbeResult(serviceID: definition.id, serviceName: definition.name, probeLabel: apiProbe.label, kind: .api, requestedURL: requestedURLString, state: .fail, detail: L10n.text(.detailInvalidURL), statusCode: nil, latencyMs: nil, checkedAt: Date(), quota: nil, spend: nil)
        }

        return await runRequest(
            serviceID: definition.id,
            serviceName: definition.name,
            probeLabel: apiProbe.label,
            kind: .api,
            settings: settings,
            url: url,
            session: session,
            method: apiProbe.method,
            keychainAccount: apiProbe.keychainAccount,
            authType: apiProbe.authType,
            extraHeaders: apiProbe.headers,
            body: apiProbe.body
        )
    }

    private func runRequest(
        serviceID: ServiceID,
        serviceName: String,
        probeLabel: String,
        kind: ProbeKind,
        settings: MonitorSettings,
        url: URL,
        session: URLSession,
        method: String,
        keychainAccount: String?,
        authType: ProbeAuthType?,
        extraHeaders: [String: String],
        body: Data?
    ) async -> ProbeResult {
        let apiKey = keychainAccount.flatMap { KeychainHelper.loadAPIKey(account: $0) }
        let start = DispatchTime.now().uptimeNanoseconds

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = AppConfig.requestTimeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(AppConfig.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.httpBody = body

        for (header, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }

        if let apiKey, let authType {
            applyAuth(apiKey: apiKey, authType: authType, to: &request)
        }

        do {
            let (data, response) = try await session.data(for: request)
            let latencyMs = Self.elapsedMilliseconds(since: start)
            let httpResponse = response as? HTTPURLResponse
            let headerQuota = httpResponse.flatMap(extractHeaderQuotaSnapshot)
            let bodyUsageQuota = extractBodyUsageQuotaSnapshot(from: data)
            let supplementalQuota: QuotaSnapshot?
            if headerQuota == nil, bodyUsageQuota == nil {
                supplementalQuota = await loadSupplementalQuotaSnapshot(
                    serviceID: serviceID,
                    settings: settings,
                    session: session,
                    apiKey: apiKey,
                    keychainAccount: keychainAccount
                )
            } else {
                supplementalQuota = nil
            }
            let supplementalSpend = kind == .api
                ? await loadSupplementalSpendSnapshot(
                    serviceID: serviceID,
                    settings: settings,
                    session: session,
                    apiKey: apiKey
                )
                : nil

            return interpretResponse(
                serviceID: serviceID,
                serviceName: serviceName,
                probeLabel: probeLabel,
                kind: kind,
                url: url,
                response: httpResponse,
                latencyMs: latencyMs,
                hasAPIKey: apiKey != nil,
                quota: headerQuota ?? bodyUsageQuota ?? supplementalQuota,
                spend: supplementalSpend
            )
        } catch {
            return ProbeResult(
                serviceID: serviceID,
                serviceName: serviceName,
                probeLabel: probeLabel,
                kind: kind,
                requestedURL: url.absoluteString,
                state: .fail,
                detail: Self.describeTransportError(error),
                statusCode: nil,
                latencyMs: Self.elapsedMilliseconds(since: start),
                checkedAt: Date(),
                quota: nil,
                spend: nil
            )
        }
    }

    private func interpretResponse(
        serviceID: ServiceID,
        serviceName: String,
        probeLabel: String,
        kind: ProbeKind,
        url: URL,
        response: HTTPURLResponse?,
        latencyMs: Int,
        hasAPIKey: Bool,
        quota: QuotaSnapshot?,
        spend: SpendSnapshot?
    ) -> ProbeResult {
        let statusCode = response?.statusCode
        let code = statusCode ?? -1

        switch kind {
        case .app, .web:
            if (200..<400).contains(code) {
                return ProbeResult(serviceID: serviceID, serviceName: serviceName, probeLabel: probeLabel, kind: kind, requestedURL: url.absoluteString, state: .pass, detail: L10n.text(.detailReachable), statusCode: statusCode, latencyMs: latencyMs, checkedAt: Date(), quota: nil, spend: nil)
            }

            return ProbeResult(serviceID: serviceID, serviceName: serviceName, probeLabel: probeLabel, kind: kind, requestedURL: url.absoluteString, state: .fail, detail: "\(L10n.text(.detailUnexpectedHTTPPrefix)) \(code)", statusCode: statusCode, latencyMs: latencyMs, checkedAt: Date(), quota: nil, spend: nil)

        case .api:
            if (200..<300).contains(code) {
                return ProbeResult(serviceID: serviceID, serviceName: serviceName, probeLabel: probeLabel, kind: kind, requestedURL: url.absoluteString, state: .pass, detail: hasAPIKey ? L10n.text(.detailAPIAuthenticated) : L10n.text(.detailReachable), statusCode: statusCode, latencyMs: latencyMs, checkedAt: Date(), quota: quota, spend: spend)
            }

            if !hasAPIKey, code == 401 || code == 403 {
                return ProbeResult(serviceID: serviceID, serviceName: serviceName, probeLabel: probeLabel, kind: kind, requestedURL: url.absoluteString, state: .pass, detail: L10n.text(.detailAPIReachableNoKey), statusCode: statusCode, latencyMs: latencyMs, checkedAt: Date(), quota: quota, spend: spend)
            }

            if hasAPIKey, code == 401 || code == 403 {
                return ProbeResult(serviceID: serviceID, serviceName: serviceName, probeLabel: probeLabel, kind: kind, requestedURL: url.absoluteString, state: .warning, detail: L10n.text(.detailAPIKeyRejected), statusCode: statusCode, latencyMs: latencyMs, checkedAt: Date(), quota: quota, spend: spend)
            }

            if code == 429 {
                return ProbeResult(serviceID: serviceID, serviceName: serviceName, probeLabel: probeLabel, kind: kind, requestedURL: url.absoluteString, state: .warning, detail: L10n.text(.detailAPIRateLimited), statusCode: statusCode, latencyMs: latencyMs, checkedAt: Date(), quota: quota, spend: spend)
            }

            return ProbeResult(serviceID: serviceID, serviceName: serviceName, probeLabel: probeLabel, kind: kind, requestedURL: url.absoluteString, state: .fail, detail: "\(L10n.text(.detailUnexpectedHTTPPrefix)) \(code)", statusCode: statusCode, latencyMs: latencyMs, checkedAt: Date(), quota: quota, spend: spend)
        }
    }

    private func extractHeaderQuotaSnapshot(from response: HTTPURLResponse) -> QuotaSnapshot? {
        let headers = Dictionary(uniqueKeysWithValues: response.allHeaderFields.compactMap { key, value -> (String, String)? in
            guard let key = key as? String else {
                return nil
            }

            return (key.lowercased(), String(describing: value))
        })

        let requestLimit = firstInt(
            in: headers,
            keys: [
                "x-ratelimit-limit-requests",
                "ratelimit-limit-requests",
                "x-ratelimit-limit",
                "ratelimit-limit",
            ]
        )
        let requestRemaining = firstInt(
            in: headers,
            keys: [
                "x-ratelimit-remaining-requests",
                "ratelimit-remaining-requests",
                "x-ratelimit-remaining",
                "ratelimit-remaining",
            ]
        )
        let requestReset = firstDate(
            in: headers,
            keys: [
                "x-ratelimit-reset-requests",
                "ratelimit-reset-requests",
                "x-ratelimit-reset",
                "ratelimit-reset",
            ]
        )

        if requestLimit != nil || requestRemaining != nil || requestReset != nil {
            return QuotaSnapshot(
                label: L10n.text(.quotaHeaderSource),
                remaining: requestRemaining,
                limit: requestLimit,
                resetAt: requestReset,
                detail: L10n.text(.quotaHeaderDetail),
                summaryText: nil
            )
        }

        let tokenLimit = firstInt(
            in: headers,
            keys: [
                "x-ratelimit-limit-tokens",
                "ratelimit-limit-tokens",
            ]
        )
        let tokenRemaining = firstInt(
            in: headers,
            keys: [
                "x-ratelimit-remaining-tokens",
                "ratelimit-remaining-tokens",
            ]
        )
        let tokenReset = firstDate(
            in: headers,
            keys: [
                "x-ratelimit-reset-tokens",
                "ratelimit-reset-tokens",
            ]
        )

        if tokenLimit != nil || tokenRemaining != nil || tokenReset != nil {
            return QuotaSnapshot(
                label: L10n.text(.quotaTokenSource),
                remaining: tokenRemaining,
                limit: tokenLimit,
                resetAt: tokenReset,
                detail: L10n.text(.quotaTokenDetail),
                summaryText: nil
            )
        }

        return nil
    }

    private func extractBodyUsageQuotaSnapshot(from data: Data) -> QuotaSnapshot? {
        guard !data.isEmpty,
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let usageObject = lookupUsageObject(in: jsonObject) else {
            return nil
        }

        let input = firstIntValue(in: usageObject, keys: ["input_tokens", "prompt_tokens", "promptTokenCount", "inputTokenCount", "prompt_tokens_details.cached_tokens"])
        let output = firstIntValue(in: usageObject, keys: ["output_tokens", "completion_tokens", "candidatesTokenCount", "outputTokenCount"])
        let total = firstIntValue(in: usageObject, keys: ["total_tokens", "totalTokenCount", "totalTokens"]) ?? {
            if let input, let output {
                return input + output
            }
            return nil
        }()
        let cached = firstIntValue(in: usageObject, keys: ["input_cached_tokens", "cached_input_tokens", "cachedContentTokenCount"])

        var segments: [String] = []

        if let input {
            segments.append("\(L10n.text(.quotaInputShort)) \(input)")
        }

        if let output {
            segments.append("\(L10n.text(.quotaOutputShort)) \(output)")
        }

        if let total {
            segments.append("\(L10n.text(.quotaTotalShort)) \(total)")
        }

        if let cached {
            segments.append("\(L10n.text(.quotaCachedShort)) \(cached)")
        }

        guard !segments.isEmpty else {
            return nil
        }

        let summary = segments.joined(separator: " · ")
        return QuotaSnapshot(
            label: L10n.text(.quotaUsageSource),
            remaining: nil,
            limit: nil,
            resetAt: nil,
            detail: L10n.text(.quotaUsageDetail),
            summaryText: summary
        )
    }

    private func loadSupplementalQuotaSnapshot(
        serviceID: ServiceID,
        settings: MonitorSettings,
        session: URLSession,
        apiKey: String?,
        keychainAccount: String?
    ) async -> QuotaSnapshot? {
        let quotaSupport = ServiceDefinitions.definition(for: serviceID, settings: settings)?.quotaSupport
        let maxAge = serviceID == .codex ? codexQuotaCacheMaxAge : quotaCacheMaxAge

        if let cached = await QuotaSnapshotCache.shared.snapshot(for: serviceID, maxAge: maxAge) {
            return cached
        }

        let snapshot: QuotaSnapshot?

        switch quotaSupport {
        case .codexAppServer:
            let liveSnapshot = await codexLocalMonitor.fetchQuotaSnapshot()
            if liveSnapshot?.summaryText == L10n.text(.quotaCodexUnavailableSummary),
               let fallbackSnapshot = codexLocalUsageMonitor.fetchQuotaFallbackSnapshot() {
                snapshot = fallbackSnapshot
            } else {
                snapshot = liveSnapshot
            }
        case .openAIUsageAPI:
            guard let apiKey else {
                return nil
            }
            snapshot = await fetchOpenAICompletionUsage(session: session, apiKey: apiKey)
        case .anthropicUsageAPI:
            guard let apiKey else {
                return nil
            }
            snapshot = await fetchAnthropicUsageQuota(session: session, apiKey: apiKey)
        default:
            snapshot = nil
        }

        if let snapshot {
            await QuotaSnapshotCache.shared.store(snapshot, for: serviceID)
        }

        return snapshot
    }

    private func loadSupplementalSpendSnapshot(
        serviceID: ServiceID,
        settings: MonitorSettings,
        session: URLSession,
        apiKey: String?
    ) async -> SpendSnapshot? {
        guard let spendSupport = ServiceDefinitions.definition(for: serviceID, settings: settings)?.spendSupport,
              spendSupport != .none else {
            return nil
        }

        if let cached = await SpendSnapshotCache.shared.snapshot(for: serviceID, maxAge: spendCacheMaxAge) {
            return cached
        }

        let snapshot: SpendSnapshot?

        switch spendSupport {
        case .codexLocalLogs:
            snapshot = codexLocalUsageMonitor.fetchUsageSpendSnapshot()
        case .openAIOrganizationCosts:
            guard let apiKey else {
                return nil
            }
            snapshot = await fetchOpenAIOrganizationCosts(session: session, apiKey: apiKey)
        case .none:
            snapshot = nil
        }

        if let snapshot {
            await SpendSnapshotCache.shared.store(snapshot, for: serviceID)
        }

        return snapshot
    }

    private func fetchOpenAICompletionUsage(session: URLSession, apiKey: String) async -> QuotaSnapshot? {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = AppConfig.requestTimeout
        request.setValue(AppConfig.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = Data("""
        {"model":"gpt-4.1-nano","messages":[{"role":"user","content":"ping"}],"max_tokens":1}
        """.utf8)

        do {
            let (data, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

            guard (200..<300).contains(statusCode) else {
                return nil
            }

            return extractBodyUsageQuotaSnapshot(from: data)
        } catch {
            return nil
        }
    }

    private func fetchAnthropicUsageQuota(session: URLSession, apiKey: String) async -> QuotaSnapshot? {
        if !apiKey.hasPrefix("sk-ant-admin") {
            return QuotaSnapshot(label: L10n.text(.quotaUsageSource), remaining: nil, limit: nil, resetAt: nil, detail: L10n.text(.quotaAnthropicAdminRequiredHint), summaryText: L10n.text(.quotaAnthropicAdminRequiredSummary))
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let endingAt = formatter.string(from: Date())
        let startingAt = formatter.string(from: Date().addingTimeInterval(-86_400))
        guard let encodedStart = startingAt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedEnd = endingAt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.anthropic.com/v1/organizations/usage_report/messages?starting_at=\(encodedStart)&ending_at=\(encodedEnd)&bucket_width=1d&limit=1") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = AppConfig.requestTimeout
        request.setValue(AppConfig.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        do {
            let (data, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

            if statusCode == 401 || statusCode == 403 {
                return QuotaSnapshot(label: L10n.text(.quotaUsageSource), remaining: nil, limit: nil, resetAt: nil, detail: L10n.text(.quotaAnthropicAdminHint), summaryText: L10n.text(.quotaAnthropicAdminSummary))
            }

            guard (200..<300).contains(statusCode) else {
                return nil
            }

            return parseAggregateUsageQuota(
                from: data,
                label: L10n.text(.quotaUsageSource),
                detail: L10n.text(.quotaAnthropicAdminHint)
            )
        } catch {
            return nil
        }
    }

    private func fetchOpenAIOrganizationCosts(session: URLSession, apiKey: String) async -> SpendSnapshot? {
        let now = Date()
        var page: String?
        var pageObjects: [Any] = []
        var seenPages = Set<String>()

        while true {
            guard var components = URLComponents(string: "https://api.openai.com/v1/organization/costs") else {
                return nil
            }

            var queryItems = [
                URLQueryItem(name: "start_time", value: "0"),
                URLQueryItem(name: "end_time", value: String(Int(now.timeIntervalSince1970))),
            ]

            if let page, !page.isEmpty {
                queryItems.append(URLQueryItem(name: "page", value: page))
            }

            components.queryItems = queryItems

            guard let url = components.url else {
                return nil
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = AppConfig.requestTimeout
            request.setValue(AppConfig.userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            do {
                let (data, response) = try await session.data(for: request)
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

                if statusCode == 401 || statusCode == 403 {
                    return SpendSnapshot(
                        label: L10n.text(.spendMonitoring),
                        currencyCode: "USD",
                        amounts: [:],
                        detail: L10n.text(.spendOpenAIAdminHint),
                        summaryText: L10n.text(.spendAdminRequiredSummary),
                        isEstimated: false
                    )
                }

                guard (200..<300).contains(statusCode),
                      let object = try? JSONSerialization.jsonObject(with: data) else {
                    return nil
                }

                pageObjects.append(object)

                guard let nextPage = nextPageToken(in: object),
                      !nextPage.isEmpty,
                      seenPages.insert(nextPage).inserted else {
                    break
                }

                page = nextPage
            } catch {
                return nil
            }
        }

        return parseOpenAICostSnapshot(from: pageObjects, now: now)
    }

    private func parseOpenAICostSnapshot(from pageObjects: [Any], now: Date) -> SpendSnapshot? {
        var buckets: [CostBucket] = []

        for object in pageObjects {
            collectCostBuckets(in: object, into: &buckets)
        }

        guard !buckets.isEmpty else {
            return SpendSnapshot(
                label: L10n.text(.spendMonitoring),
                currencyCode: "USD",
                amounts: [:],
                detail: L10n.text(.spendOpenAIWindowHint),
                summaryText: L10n.text(.spendNoDataSummary),
                isEstimated: false
            )
        }

        let currencyCode = buckets.compactMap(\.currencyCode).first(where: { !$0.isEmpty }) ?? "USD"
        let amounts = Dictionary(uniqueKeysWithValues: SpendWindow.allCases.map { window in
            (window.rawValue, amount(for: window, from: buckets, now: now))
        })

        return SpendSnapshot(
            label: L10n.text(.spendMonitoring),
            currencyCode: currencyCode,
            amounts: amounts,
            detail: L10n.text(.spendOpenAIWindowHint),
            summaryText: nil,
            isEstimated: true
        )
    }

    private func parseAggregateUsageQuota(from data: Data, label: String, detail: String) -> QuotaSnapshot? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        let input = sumNumericValues(in: object, keys: ["input_tokens", "uncached_input_tokens", "prompt_tokens"])
        let output = sumNumericValues(in: object, keys: ["output_tokens", "completion_tokens"])
        let requests = sumNumericValues(in: object, keys: ["num_model_requests", "requests"])
        let total = (input > 0 || output > 0) ? (input + output) : 0

        var segments: [String] = []
        if input > 0 {
            segments.append("\(L10n.text(.quotaInputShort)) \(input)")
        }
        if output > 0 {
            segments.append("\(L10n.text(.quotaOutputShort)) \(output)")
        }
        if total > 0 {
            segments.append("\(L10n.text(.quotaTotalShort)) \(total)")
        }
        if requests > 0 {
            segments.append("req \(requests)")
        }

        guard !segments.isEmpty else {
            return nil
        }

        return QuotaSnapshot(
            label: label,
            remaining: nil,
            limit: nil,
            resetAt: nil,
            detail: detail,
            summaryText: segments.joined(separator: " · ")
        )
    }

    private struct CostBucket {
        let startDate: Date
        let endDate: Date
        let amount: Double
        let currencyCode: String?
    }

    private func amount(for window: SpendWindow, from buckets: [CostBucket], now: Date) -> Double {
        guard window != .all else {
            return buckets.reduce(0) { $0 + $1.amount }
        }

        let windowStart = now.addingTimeInterval(-windowDuration(for: window))

        return buckets.reduce(0) { total, bucket in
            let bucketDuration = max(bucket.endDate.timeIntervalSince(bucket.startDate), 1)
            let overlapStart = max(bucket.startDate, windowStart)
            let overlapEnd = min(bucket.endDate, now)
            let overlap = max(overlapEnd.timeIntervalSince(overlapStart), 0)

            guard overlap > 0 else {
                return total
            }

            return total + bucket.amount * (overlap / bucketDuration)
        }
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
            return 0
        }
    }

    private func collectCostBuckets(in object: Any, into buckets: inout [CostBucket]) {
        if let dictionary = object as? [String: Any] {
            if let bucket = costBucket(from: dictionary) {
                buckets.append(bucket)
                return
            }

            for value in dictionary.values {
                collectCostBuckets(in: value, into: &buckets)
            }
        } else if let array = object as? [Any] {
            for value in array {
                collectCostBuckets(in: value, into: &buckets)
            }
        }
    }

    private func costBucket(from dictionary: [String: Any]) -> CostBucket? {
        guard let startDate = firstTimestamp(in: dictionary, keys: ["start_time", "startAt", "start_at"]) else {
            return nil
        }

        let endDate = firstTimestamp(in: dictionary, keys: ["end_time", "endAt", "end_at"])
            ?? startDate.addingTimeInterval(24 * 60 * 60)

        if let entries = firstArray(in: dictionary, keys: ["results", "line_items", "items", "data"]) {
            let amountPairs = entries.compactMap(extractAmountPair)

            guard !amountPairs.isEmpty else {
                return nil
            }

            return CostBucket(
                startDate: startDate,
                endDate: endDate,
                amount: amountPairs.reduce(0) { $0 + $1.amount },
                currencyCode: amountPairs.compactMap(\.currencyCode).first
            )
        }

        guard let amountPair = extractAmountPair(from: dictionary) else {
            return nil
        }

        return CostBucket(
            startDate: startDate,
            endDate: endDate,
            amount: amountPair.amount,
            currencyCode: amountPair.currencyCode
        )
    }

    private func extractAmountPair(from object: Any) -> (amount: Double, currencyCode: String?)? {
        guard let dictionary = object as? [String: Any] else {
            return nil
        }

        if let amountObject = dictionary["amount"] {
            if let amountDictionary = amountObject as? [String: Any] {
                let amount = firstDouble(in: amountDictionary, keys: ["value", "amount", "total", "usd"])
                let currencyCode = firstString(in: amountDictionary, keys: ["currency", "currency_code"])

                if let amount {
                    return (amount, currencyCode)
                }
            } else if let amount = numericDouble(from: amountObject) {
                return (amount, firstString(in: dictionary, keys: ["currency", "currency_code"]))
            }
        }

        for key in ["cost", "amount_value", "total_amount", "usd"] {
            if let amount = dictionary[key].flatMap(numericDouble(from:)) {
                return (amount, firstString(in: dictionary, keys: ["currency", "currency_code"]))
            }
        }

        return nil
    }

    private func nextPageToken(in object: Any) -> String? {
        if let dictionary = object as? [String: Any] {
            if let token = firstString(in: dictionary, keys: ["next_page", "nextPage", "after"]) {
                return token
            }

            for value in dictionary.values {
                if let token = nextPageToken(in: value) {
                    return token
                }
            }
        } else if let array = object as? [Any] {
            for value in array {
                if let token = nextPageToken(in: value) {
                    return token
                }
            }
        }

        return nil
    }

    private func firstInt(in headers: [String: String], keys: [String]) -> Int? {
        for key in keys {
            guard let value = headers[key] else {
                continue
            }

            let digits = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if let intValue = Int(digits) {
                return intValue
            }
        }

        return nil
    }

    private func firstTimestamp(in dictionary: [String: Any], keys: [String]) -> Date? {
        for key in keys {
            guard let value = dictionary[key],
                  let seconds = numericDouble(from: value) else {
                continue
            }

            return Date(timeIntervalSince1970: seconds)
        }

        return nil
    }

    private func firstArray(in dictionary: [String: Any], keys: [String]) -> [Any]? {
        for key in keys {
            if let value = dictionary[key] as? [Any] {
                return value
            }
        }

        return nil
    }

    private func firstString(in dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key] as? String,
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }

        return nil
    }

    private func firstDouble(in dictionary: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = dictionary[key],
               let amount = numericDouble(from: value) {
                return amount
            }
        }

        return nil
    }

    private func numericDouble(from value: Any) -> Double? {
        if let doubleValue = value as? Double {
            return doubleValue
        }

        if let intValue = value as? Int {
            return Double(intValue)
        }

        if let number = value as? NSNumber {
            return number.doubleValue
        }

        if let string = value as? String {
            return Double(string)
        }

        return nil
    }

    private func lookupUsageObject(in jsonObject: Any) -> Any? {
        if let dictionary = jsonObject as? [String: Any] {
            if let usage = dictionary["usage"] {
                return usage
            }

            if let usage = dictionary["usageMetadata"] {
                return usage
            }

            if let usage = dictionary["usage_metadata"] {
                return usage
            }

            for value in dictionary.values {
                if let usage = lookupUsageObject(in: value) {
                    return usage
                }
            }
        }

        if let array = jsonObject as? [Any] {
            for value in array {
                if let usage = lookupUsageObject(in: value) {
                    return usage
                }
            }
        }

        return nil
    }

    private func firstIntValue(in usageObject: Any, keys: [String]) -> Int? {
        for key in keys {
            if let value = value(forKeyPath: key, in: usageObject) {
                if let intValue = value as? Int {
                    return intValue
                }

                if let number = value as? NSNumber {
                    return number.intValue
                }

                if let string = value as? String, let intValue = Int(string) {
                    return intValue
                }
            }
        }

        return nil
    }

    private func sumNumericValues(in object: Any, keys: [String]) -> Int {
        var total = 0

        if let dictionary = object as? [String: Any] {
            for (key, value) in dictionary {
                if keys.contains(key) {
                    if let intValue = value as? Int {
                        total += intValue
                    } else if let number = value as? NSNumber {
                        total += number.intValue
                    } else if let string = value as? String, let intValue = Int(string) {
                        total += intValue
                    }
                }

                total += sumNumericValues(in: value, keys: keys)
            }
        } else if let array = object as? [Any] {
            for value in array {
                total += sumNumericValues(in: value, keys: keys)
            }
        }

        return total
    }

    private func value(forKeyPath keyPath: String, in object: Any) -> Any? {
        let keys = keyPath.split(separator: ".").map(String.init)
        var current: Any? = object

        for key in keys {
            guard let dictionary = current as? [String: Any] else {
                return nil
            }

            current = dictionary[key]
        }

        return current
    }

    private func firstDate(in headers: [String: String], keys: [String]) -> Date? {
        for key in keys {
            guard let value = headers[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                continue
            }

            if let seconds = TimeInterval(value) {
                if seconds > 1_000_000_000 {
                    return Date(timeIntervalSince1970: seconds)
                }

                return Date().addingTimeInterval(seconds)
            }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"

            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private static func resolveOverallState(results: [ProbeResult]) -> OverallState {
        guard !results.isEmpty else {
            return .checking
        }

        let failures = results.filter { $0.state == .fail }.count
        let warnings = results.filter { $0.state == .warning }.count

        if failures == 0, warnings == 0 {
            return .healthy
        }

        if failures == results.count {
            return .blocked
        }

        return .degraded
    }

    private static func elapsedMilliseconds(since start: UInt64) -> Int {
        let end = DispatchTime.now().uptimeNanoseconds
        return Int((end - start) / 1_000_000)
    }

    private func applyAuth(apiKey: String, authType: ProbeAuthType, to request: inout URLRequest) {
        switch authType {
        case .bearer:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        case .anthropic:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        case .googleAPIKey:
            guard var components = URLComponents(url: request.url ?? URL(string: "https://invalid.local")!, resolvingAgainstBaseURL: false) else {
                return
            }

            var queryItems = components.queryItems ?? []
            queryItems.append(URLQueryItem(name: "key", value: apiKey))
            components.queryItems = queryItems
            request.url = components.url
        case .basicUsername:
            let value = "\(apiKey):"
            let encoded = Data(value.utf8).base64EncodedString()
            request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
        }
    }

    private static func describeTransportError(_ error: Error) -> String {
        guard let urlError = error as? URLError else {
            return error.localizedDescription
        }

        switch urlError.code {
        case .notConnectedToInternet:
            return L10n.text(.errorNoInternet)
        case .timedOut:
            return L10n.text(.errorTimedOut)
        case .cannotFindHost, .dnsLookupFailed:
            return L10n.text(.errorDNSLookupFailed)
        case .cannotConnectToHost:
            return L10n.text(.errorConnectionRefused)
        case .networkConnectionLost:
            return L10n.text(.errorConnectionLost)
        case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateUntrusted:
            return L10n.text(.errorTLSHandshakeFailed)
        default:
            return urlError.localizedDescription
        }
    }
}
