import Foundation

struct CodexProbeService {
    func runAllChecks(settings: MonitorSettings) async -> MonitorSnapshot {
        let sessionResult = makeSession(settings: settings)

        guard case .success(let session) = sessionResult else {
            let detail = (try? sessionResult.get()) == nil ? L10n.text(.detailInvalidProxy) : "Probe setup failed."
            let results = invalidResults(settings: settings, detail: detail)
            return MonitorSnapshot(results: results, checkedAt: Date(), overallState: .blocked)
        }

        var results: [ProbeResult] = []

        results.append(await probeCodexSurface(kind: .app, label: "App Sign-in", settings: settings, session: session))
        results.append(await probeCodexSurface(kind: .web, label: "Web", settings: settings, session: session))
        results.append(await probeCodexSurface(kind: .api, label: "API", settings: settings, session: session))

        for definition in ServiceDefinitions.all {
            results.append(await probeWebService(definition, session: session))

            if let apiProbe = definition.apiProbe {
                results.append(await probeAdditionalAPI(definition, apiProbe: apiProbe, session: session))
            }
        }

        return MonitorSnapshot(
            results: results,
            checkedAt: Date(),
            overallState: Self.resolveOverallState(results: results)
        )
    }

    private func invalidResults(settings: MonitorSettings, detail: String) -> [ProbeResult] {
        var results: [ProbeResult] = [
            ProbeResult(serviceName: "Codex", probeLabel: "App Sign-in", kind: .app, requestedURL: settings.configuredURLString(for: .app), state: .fail, detail: detail, statusCode: nil, latencyMs: nil, checkedAt: Date()),
            ProbeResult(serviceName: "Codex", probeLabel: "Web", kind: .web, requestedURL: settings.configuredURLString(for: .web), state: .fail, detail: detail, statusCode: nil, latencyMs: nil, checkedAt: Date()),
            ProbeResult(serviceName: "Codex", probeLabel: "API", kind: .api, requestedURL: settings.configuredURLString(for: .api), state: .fail, detail: detail, statusCode: nil, latencyMs: nil, checkedAt: Date()),
        ]

        for definition in ServiceDefinitions.all {
            results.append(ProbeResult(serviceName: definition.name, probeLabel: definition.webLabel, kind: .web, requestedURL: definition.webURLString, state: .fail, detail: detail, statusCode: nil, latencyMs: nil, checkedAt: Date()))

            if let apiProbe = definition.apiProbe {
                results.append(ProbeResult(serviceName: definition.name, probeLabel: apiProbe.label, kind: .api, requestedURL: apiProbe.urlString, state: .fail, detail: detail, statusCode: nil, latencyMs: nil, checkedAt: Date()))
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
            return ProbeResult(serviceName: "Codex", probeLabel: label, kind: kind, requestedURL: settings.configuredURLString(for: kind), state: .fail, detail: L10n.text(.detailInvalidURL), statusCode: nil, latencyMs: nil, checkedAt: Date())
        }

        return await runRequest(
            serviceName: "Codex",
            probeLabel: label,
            kind: kind,
            url: url,
            session: session,
            method: kind == .api ? "GET" : "HEAD",
            keychainAccount: kind == .api ? AppConfig.keychainAccount : nil,
            authType: kind == .api ? .bearer : nil,
            extraHeaders: [:],
            body: nil
        )
    }

    private func probeWebService(_ definition: ServiceDefinition, session: URLSession) async -> ProbeResult {
        guard let url = URL(string: definition.webURLString) else {
            return ProbeResult(serviceName: definition.name, probeLabel: definition.webLabel, kind: .web, requestedURL: definition.webURLString, state: .fail, detail: L10n.text(.detailInvalidURL), statusCode: nil, latencyMs: nil, checkedAt: Date())
        }

        return await runRequest(
            serviceName: definition.name,
            probeLabel: definition.webLabel,
            kind: .web,
            url: url,
            session: session,
            method: "HEAD",
            keychainAccount: nil,
            authType: nil,
            extraHeaders: [:],
            body: nil
        )
    }

    private func probeAdditionalAPI(_ definition: ServiceDefinition, apiProbe: ServiceAPIProbe, session: URLSession) async -> ProbeResult {
        guard let url = URL(string: apiProbe.urlString) else {
            return ProbeResult(serviceName: definition.name, probeLabel: apiProbe.label, kind: .api, requestedURL: apiProbe.urlString, state: .fail, detail: L10n.text(.detailInvalidURL), statusCode: nil, latencyMs: nil, checkedAt: Date())
        }

        return await runRequest(
            serviceName: definition.name,
            probeLabel: apiProbe.label,
            kind: .api,
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
        serviceName: String,
        probeLabel: String,
        kind: ProbeKind,
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
            let (_, response) = try await session.data(for: request)
            let latencyMs = Self.elapsedMilliseconds(since: start)
            let statusCode = (response as? HTTPURLResponse)?.statusCode

            return interpretResponse(
                serviceName: serviceName,
                probeLabel: probeLabel,
                kind: kind,
                url: url,
                statusCode: statusCode,
                latencyMs: latencyMs,
                hasAPIKey: apiKey != nil
            )
        } catch {
            return ProbeResult(
                serviceName: serviceName,
                probeLabel: probeLabel,
                kind: kind,
                requestedURL: url.absoluteString,
                state: .fail,
                detail: Self.describeTransportError(error),
                statusCode: nil,
                latencyMs: Self.elapsedMilliseconds(since: start),
                checkedAt: Date()
            )
        }
    }

    private func interpretResponse(
        serviceName: String,
        probeLabel: String,
        kind: ProbeKind,
        url: URL,
        statusCode: Int?,
        latencyMs: Int,
        hasAPIKey: Bool
    ) -> ProbeResult {
        let code = statusCode ?? -1

        switch kind {
        case .app, .web:
            if (200..<400).contains(code) {
                return ProbeResult(serviceName: serviceName, probeLabel: probeLabel, kind: kind, requestedURL: url.absoluteString, state: .pass, detail: L10n.text(.detailReachable), statusCode: statusCode, latencyMs: latencyMs, checkedAt: Date())
            }

            return ProbeResult(serviceName: serviceName, probeLabel: probeLabel, kind: kind, requestedURL: url.absoluteString, state: .fail, detail: "\(L10n.text(.detailUnexpectedHTTPPrefix)) \(code)", statusCode: statusCode, latencyMs: latencyMs, checkedAt: Date())

        case .api:
            if (200..<300).contains(code) {
                return ProbeResult(serviceName: serviceName, probeLabel: probeLabel, kind: kind, requestedURL: url.absoluteString, state: .pass, detail: hasAPIKey ? L10n.text(.detailAPIAuthenticated) : L10n.text(.detailReachable), statusCode: statusCode, latencyMs: latencyMs, checkedAt: Date())
            }

            if !hasAPIKey, code == 401 || code == 403 {
                return ProbeResult(serviceName: serviceName, probeLabel: probeLabel, kind: kind, requestedURL: url.absoluteString, state: .warning, detail: L10n.text(.detailAPIReachableNoKey), statusCode: statusCode, latencyMs: latencyMs, checkedAt: Date())
            }

            if hasAPIKey, code == 401 || code == 403 {
                return ProbeResult(serviceName: serviceName, probeLabel: probeLabel, kind: kind, requestedURL: url.absoluteString, state: .warning, detail: L10n.text(.detailAPIKeyRejected), statusCode: statusCode, latencyMs: latencyMs, checkedAt: Date())
            }

            if code == 429 {
                return ProbeResult(serviceName: serviceName, probeLabel: probeLabel, kind: kind, requestedURL: url.absoluteString, state: .warning, detail: L10n.text(.detailAPIRateLimited), statusCode: statusCode, latencyMs: latencyMs, checkedAt: Date())
            }

            return ProbeResult(serviceName: serviceName, probeLabel: probeLabel, kind: kind, requestedURL: url.absoluteString, state: .fail, detail: "\(L10n.text(.detailUnexpectedHTTPPrefix)) \(code)", statusCode: statusCode, latencyMs: latencyMs, checkedAt: Date())
        }
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
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        case .basicUsername:
            let token = Data("\(apiKey):".utf8).base64EncodedString()
            request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
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
        case .secureConnectionFailed,
             .serverCertificateHasBadDate,
             .serverCertificateNotYetValid,
             .serverCertificateUntrusted,
             .clientCertificateRejected:
            return L10n.text(.errorTLSHandshakeFailed)
        default:
            return urlError.localizedDescription
        }
    }
}
