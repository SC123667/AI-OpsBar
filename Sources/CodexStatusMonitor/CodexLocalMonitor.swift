import Darwin
import Foundation

struct CodexLocalMonitor {
    private let host = "127.0.0.1"
    private let startupTimeout: TimeInterval = 3
    private let socketTimeout: TimeInterval = 3

    func fetchQuotaSnapshot() async -> QuotaSnapshot? {
        await Task.detached(priority: .utility) {
            self.fetchQuotaSnapshotBlocking()
        }.value
    }

    private func fetchQuotaSnapshotBlocking() -> QuotaSnapshot? {
        do {
            let port = try reservePort()
            let process = try launchAppServer(port: port)
            defer { stop(process: process) }

            try waitForServer(port: port, process: process)

            let client = try LocalWebSocketClient(host: host, port: port, timeout: socketTimeout)
            defer { client.close() }

            try client.handshake()
            _ = try client.request(
                method: "initialize",
                id: "aiopsbar-init",
                params: [
                    "clientInfo": [
                        "name": "AI OpsBar",
                        "version": "0.4",
                    ],
                    "capabilities": NSNull(),
                ]
            )
            try client.notify(method: "initialized", params: NSNull())

            let rateLimitsResult = try client.request(
                method: "account/rateLimits/read",
                id: "aiopsbar-ratelimits",
                params: NSNull()
            )
            let accountResult = try client.request(
                method: "account/read",
                id: "aiopsbar-account",
                params: [
                    "refreshToken": false,
                ]
            )

            return quotaSnapshot(rateLimitsResult: rateLimitsResult, accountResult: accountResult)
        } catch {
            return QuotaSnapshot(
                label: L10n.text(.quotaCodexLocalSource),
                remaining: nil,
                limit: nil,
                resetAt: nil,
                detail: error.localizedDescription,
                summaryText: L10n.text(.quotaCodexUnavailableSummary)
            )
        }
    }

    private func quotaSnapshot(rateLimitsResult: [String: Any], accountResult: [String: Any]) -> QuotaSnapshot {
        let account = accountResult["account"] as? [String: Any]

        if account == nil {
            return QuotaSnapshot(
                label: L10n.text(.quotaCodexLocalSource),
                remaining: nil,
                limit: nil,
                resetAt: nil,
                detail: L10n.text(.quotaCodexSignedOutHint),
                summaryText: L10n.text(.quotaCodexSignedOutSummary)
            )
        }

        let rateLimits = selectRateLimitPayload(from: rateLimitsResult)
        let primary = rateLimits["primary"] as? [String: Any]
        let secondary = rateLimits["secondary"] as? [String: Any]
        let credits = rateLimits["credits"] as? [String: Any]

        let primaryUsed = Self.intValue(from: primary?["usedPercent"])
        let secondaryUsed = Self.intValue(from: secondary?["usedPercent"])
        let primaryReset = Self.dateValue(from: primary?["resetsAt"])
        let plan = displayPlan(
            rateLimits["planType"] as? String
                ?? account?["planType"] as? String
        )

        var segments: [String] = []

        if let plan {
            segments.append("\(L10n.text(.quotaPlanPrefix)) \(plan)")
        }

        if let primaryUsed {
            segments.append("P \(primaryUsed)%\(windowSuffix(from: primary))")
        }

        if let secondaryUsed {
            segments.append("S \(secondaryUsed)%\(windowSuffix(from: secondary))")
        }

        if let primaryReset {
            segments.append("\(L10n.text(.quotaResetPrefix)) \(DateFormatter.localizedString(from: primaryReset, dateStyle: .none, timeStyle: .short))")
        }

        if let credits {
            if Self.boolValue(from: credits["unlimited"]) == true {
                segments.append("\(L10n.text(.quotaCreditsPrefix)) ∞")
            } else if let balance = stringValue(from: credits["balance"]), balance.isEmpty == false {
                segments.append("\(L10n.text(.quotaCreditsPrefix)) \(balance)")
            }
        }

        if segments.isEmpty, let limitName = stringValue(from: rateLimits["limitName"]), limitName.isEmpty == false {
            segments.append(limitName)
        }

        return QuotaSnapshot(
            label: L10n.text(.quotaCodexLocalSource),
            remaining: primaryUsed.map { max(0, 100 - $0) },
            limit: primaryUsed == nil ? nil : 100,
            resetAt: primaryReset,
            detail: L10n.text(.quotaCodexLocalHint),
            summaryText: segments.isEmpty ? L10n.text(.quotaCodexWaitingSummary) : segments.joined(separator: " · ")
        )
    }

    private func selectRateLimitPayload(from result: [String: Any]) -> [String: Any] {
        if let rateLimitsByID = result["rateLimitsByLimitId"] as? [String: Any],
           let codexLimits = rateLimitsByID["codex"] as? [String: Any] {
            return codexLimits
        }

        return result["rateLimits"] as? [String: Any] ?? [:]
    }

    private func displayPlan(_ rawValue: String?) -> String? {
        guard let rawValue, rawValue.isEmpty == false else {
            return nil
        }

        return rawValue
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    private func windowSuffix(from window: [String: Any]?) -> String {
        guard let minutes = Self.intValue(from: window?["windowDurationMins"]) else {
            return ""
        }

        return "/\(Self.durationString(minutes: minutes))"
    }

    private func reservePort() throws -> UInt16 {
        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else {
            throw CodexLocalMonitorError.socket("Failed to create local socket.")
        }
        defer { Darwin.close(socketFD) }

        var value: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &value, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.stride)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(0).bigEndian
        inet_pton(AF_INET, host, &address.sin_addr)

        let bindResult = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { pointer in
                Darwin.bind(socketFD, pointer, socklen_t(MemoryLayout<sockaddr_in>.stride))
            }
        }

        guard bindResult == 0 else {
            throw CodexLocalMonitorError.socket("Failed to reserve a local port.")
        }

        var boundAddress = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.stride)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { pointer in
                getsockname(socketFD, pointer, &length)
            }
        }

        guard nameResult == 0 else {
            throw CodexLocalMonitorError.socket("Failed to read the reserved local port.")
        }

        return UInt16(bigEndian: boundAddress.sin_port)
    }

    private func launchAppServer(port: UInt16) throws -> Process {
        let outputPipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["codex", "app-server", "--listen", "ws://\(host):\(port)"]
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()
        return process
    }

    private func stop(process: Process) {
        guard process.isRunning else {
            return
        }

        process.interrupt()
        usleep(150_000)

        if process.isRunning {
            process.terminate()
            usleep(150_000)
        }
    }

    private func waitForServer(port: UInt16, process: Process) throws {
        let deadline = Date().addingTimeInterval(startupTimeout)

        while Date() < deadline {
            if !process.isRunning {
                throw CodexLocalMonitorError.appServer("The local codex app-server exited before responding.")
            }

            if Self.canConnect(host: host, port: port, timeout: 0.25) {
                return
            }

            usleep(100_000)
        }

        throw CodexLocalMonitorError.appServer("Timed out while starting the local codex app-server.")
    }

    private static func canConnect(host: String, port: UInt16, timeout: TimeInterval) -> Bool {
        guard let socketFD = try? makeConnectedSocket(host: host, port: port, timeout: timeout) else {
            return false
        }

        Darwin.close(socketFD)
        return true
    }

    fileprivate static func makeConnectedSocket(host: String, port: UInt16, timeout: TimeInterval) throws -> Int32 {
        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else {
            throw CodexLocalMonitorError.socket("Failed to create a TCP socket.")
        }

        var readTimeout = timeval(
            tv_sec: Int(timeout),
            tv_usec: __darwin_suseconds_t((timeout - floor(timeout)) * 1_000_000)
        )
        var writeTimeout = readTimeout
        setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &readTimeout, socklen_t(MemoryLayout<timeval>.stride))
        setsockopt(socketFD, SOL_SOCKET, SO_SNDTIMEO, &writeTimeout, socklen_t(MemoryLayout<timeval>.stride))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.stride)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        inet_pton(AF_INET, host, &address.sin_addr)

        let connectResult = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { pointer in
                Darwin.connect(socketFD, pointer, socklen_t(MemoryLayout<sockaddr_in>.stride))
            }
        }

        guard connectResult == 0 else {
            let code = errno
            Darwin.close(socketFD)
            throw CodexLocalMonitorError.socket("Failed to connect to the local codex app-server (\(code)).")
        }

        return socketFD
    }

    private static func intValue(from value: Any?) -> Int? {
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

    private static func boolValue(from value: Any?) -> Bool? {
        switch value {
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number.boolValue
        default:
            return nil
        }
    }

    private static func dateValue(from value: Any?) -> Date? {
        guard let seconds = intValue(from: value), seconds > 0 else {
            return nil
        }

        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }

    private func stringValue(from value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private static func durationString(minutes: Int) -> String {
        if minutes >= 1_440 {
            return "\(Int((Double(minutes) / 1_440).rounded()))d"
        }

        if minutes >= 60 {
            return "\(Int((Double(minutes) / 60).rounded()))h"
        }

        return "\(minutes)m"
    }
}

private enum CodexLocalMonitorError: LocalizedError {
    case socket(String)
    case handshake(String)
    case appServer(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .socket(let message),
             .handshake(let message),
             .appServer(let message),
             .server(let message):
            return message
        }
    }
}

private final class LocalWebSocketClient {
    private let socketFD: Int32

    init(host: String, port: UInt16, timeout: TimeInterval) throws {
        socketFD = try CodexLocalMonitor.makeConnectedSocket(host: host, port: port, timeout: timeout)
    }

    func close() {
        Darwin.shutdown(socketFD, SHUT_RDWR)
        Darwin.close(socketFD)
    }

    func handshake() throws {
        let keyData = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
        let key = keyData.base64EncodedString()
        let request = [
            "GET / HTTP/1.1",
            "Host: 127.0.0.1",
            "Upgrade: websocket",
            "Connection: Upgrade",
            "Sec-WebSocket-Key: \(key)",
            "Sec-WebSocket-Version: 13",
            "",
            "",
        ].joined(separator: "\r\n")

        try writeAll(Data(request.utf8))

        let headerData = try readUntilHTTPHeaderTerminator()
        guard let headerString = String(data: headerData, encoding: .utf8),
              headerString.contains(" 101 ") else {
            throw CodexLocalMonitorError.handshake("The local codex app-server rejected the WebSocket handshake.")
        }
    }

    func request(method: String, id: String, params: Any) throws -> [String: Any] {
        let payload: [String: Any] = [
            "method": method,
            "id": id,
            "params": params,
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        try sendTextFrame(data)

        while true {
            let message = try receiveJSONMessage()

            guard let messageID = message["id"] else {
                continue
            }

            if String(describing: messageID) != id {
                continue
            }

            if let error = message["error"] as? [String: Any] {
                throw CodexLocalMonitorError.server(serverMessage(from: error) ?? "The local codex app-server returned an error.")
            }

            if let result = message["result"] as? [String: Any] {
                return result
            }

            if message["result"] is NSNull {
                return [:]
            }

            if let value = message["result"] {
                return ["value": value]
            }

            return [:]
        }
    }

    func notify(method: String, params: Any) throws {
        let payload: [String: Any] = [
            "method": method,
            "params": params,
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        try sendTextFrame(data)
    }

    private func sendTextFrame(_ payload: Data) throws {
        var frame = Data()
        frame.append(0x81)

        let maskKey = (0..<4).map { _ in UInt8.random(in: .min ... .max) }
        appendLength(payload.count, masked: true, to: &frame)
        frame.append(contentsOf: maskKey)

        for (index, byte) in payload.enumerated() {
            frame.append(byte ^ maskKey[index % maskKey.count])
        }

        try writeAll(frame)
    }

    private func receiveJSONMessage() throws -> [String: Any] {
        while true {
            let (opcode, payload) = try readFrame()

            switch opcode {
            case 0x1:
                guard let object = try JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
                    throw CodexLocalMonitorError.server("The local codex app-server returned malformed JSON.")
                }
                return object
            case 0x8:
                throw CodexLocalMonitorError.server("The local codex app-server closed the connection.")
            case 0x9:
                try sendControlFrame(opcode: 0xA, payload: payload)
            default:
                continue
            }
        }
    }

    private func sendControlFrame(opcode: UInt8, payload: Data) throws {
        var frame = Data()
        frame.append(0x80 | opcode)

        let maskKey = (0..<4).map { _ in UInt8.random(in: .min ... .max) }
        appendLength(payload.count, masked: true, to: &frame)
        frame.append(contentsOf: maskKey)

        for (index, byte) in payload.enumerated() {
            frame.append(byte ^ maskKey[index % maskKey.count])
        }

        try writeAll(frame)
    }

    private func readFrame() throws -> (UInt8, Data) {
        let header = try readExactly(length: 2)
        let opcode = header[0] & 0x0F
        let masked = (header[1] & 0x80) != 0

        var payloadLength = Int(header[1] & 0x7F)

        if payloadLength == 126 {
            let extended = try readExactly(length: 2)
            payloadLength = Int(extended.withUnsafeBytes { $0.load(as: UInt16.self).bigEndian })
        } else if payloadLength == 127 {
            let extended = try readExactly(length: 8)
            payloadLength = Int(extended.withUnsafeBytes { $0.load(as: UInt64.self).bigEndian })
        }

        let maskKey = masked ? try readExactly(length: 4) : Data()
        var payload = try readExactly(length: payloadLength)

        if masked {
            for index in payload.indices {
                payload[index] ^= maskKey[maskKey.startIndex + (index % 4)]
            }
        }

        return (opcode, payload)
    }

    private func readUntilHTTPHeaderTerminator() throws -> Data {
        let separator = Data("\r\n\r\n".utf8)
        var buffer = Data()

        while buffer.range(of: separator) == nil {
            let chunk = try readExactly(length: 1)
            buffer.append(chunk)

            if buffer.count > 8_192 {
                throw CodexLocalMonitorError.handshake("The WebSocket handshake response was unexpectedly large.")
            }
        }

        return buffer
    }

    private func readExactly(length: Int) throws -> Data {
        var buffer = Data(count: length)
        var offset = 0

        while offset < length {
            let result = buffer.withUnsafeMutableBytes { rawBuffer -> Int in
                guard let baseAddress = rawBuffer.baseAddress else {
                    return -1
                }

                let pointer = baseAddress.advanced(by: offset)
                return Darwin.read(socketFD, pointer, length - offset)
            }

            if result == 0 {
                throw CodexLocalMonitorError.socket("The local codex socket closed unexpectedly.")
            }

            if result < 0 {
                throw CodexLocalMonitorError.socket("Failed to read from the local codex socket (\(errno)).")
            }

            offset += result
        }

        return buffer
    }

    private func writeAll(_ data: Data) throws {
        var written = 0

        while written < data.count {
            let result = data.withUnsafeBytes { rawBuffer -> Int in
                guard let baseAddress = rawBuffer.baseAddress else {
                    return -1
                }

                let pointer = baseAddress.advanced(by: written)
                return Darwin.write(socketFD, pointer, data.count - written)
            }

            if result <= 0 {
                throw CodexLocalMonitorError.socket("Failed to write to the local codex socket (\(errno)).")
            }

            written += result
        }
    }

    private func appendLength(_ length: Int, masked: Bool, to data: inout Data) {
        let maskBit: UInt8 = masked ? 0x80 : 0x00

        if length < 126 {
            data.append(maskBit | UInt8(length))
            return
        }

        if length <= Int(UInt16.max) {
            data.append(maskBit | 126)
            var value = UInt16(length).bigEndian
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
            return
        }

        data.append(maskBit | 127)
        var value = UInt64(length).bigEndian
        withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
    }

    private func serverMessage(from error: [String: Any]) -> String? {
        if let message = error["message"] as? String, message.isEmpty == false {
            return message
        }

        if let code = error["code"] {
            return String(describing: code)
        }

        return nil
    }
}
