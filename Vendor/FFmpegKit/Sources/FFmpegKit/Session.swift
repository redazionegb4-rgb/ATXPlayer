import Foundation

public protocol Session: AnyObject {
    func getLogCallback() -> LogCallback?
    func getSessionId() -> Int64
    func getCreateTime() -> Date
    func getStartTime() -> Date?
    func getEndTime() -> Date?
    func getDuration() -> Int64
    func getArguments() -> [String]
    func getCommand() -> String
    func getAllLogsWithTimeout(_ waitTimeout: Int32) -> [Log]
    func getAllLogs() -> [Log]
    func getLogs() -> [Log]
    func getAllLogsAsStringWithTimeout(_ waitTimeout: Int32) -> String
    func getAllLogsAsString() -> String
    func getLogsAsString() -> String
    func getOutput() -> String
    func getState() -> SessionState
    func getReturnCode() -> ReturnCode?
    func getFailStackTrace() -> String?
    func getLogRedirectionStrategy() -> LogRedirectionStrategy
    func thereAreAsynchronousMessagesInTransmit() -> Bool
    func addLog(_ log: Log)
    func startRunning()
    func complete(_ returnCode: ReturnCode)
    func fail(_ error: Error)
    func isFFmpeg() -> Bool
    func isFFprobe() -> Bool
    func isMediaInformation() -> Bool
    func cancel()
}

open class AbstractSession: NSObject, Session, @unchecked Sendable {
    public static let defaultTimeoutForAsynchronousMessagesInTransmit: Int32 = 5_000

    private let lock = NSRecursiveLock()
    private let sessionId: Int64
    private let logCallback: LogCallback?
    private let createTime = Date()
    private var startTime: Date?
    private var endTime: Date?
    private let arguments: [String]
    private var logs: [Log] = []
    private var state: SessionState = .created
    private var returnCode: ReturnCode?
    private var failStackTrace: String?
    private let logRedirectionStrategy: LogRedirectionStrategy

    public init(
        _ arguments: [String],
        withLogCallback logCallback: LogCallback?,
        withLogRedirectionStrategy logRedirectionStrategy: LogRedirectionStrategy
    ) {
        self.sessionId = FFmpegKitConfig.nextSessionId()
        self.arguments = arguments
        self.logCallback = logCallback
        self.logRedirectionStrategy = logRedirectionStrategy
        super.init()
        FFmpegKitConfig.addSession(self)
    }

    public func getLogCallback() -> LogCallback? { logCallback }
    public func getSessionId() -> Int64 { sessionId }
    public func getCreateTime() -> Date { createTime }
    public func getStartTime() -> Date? { synchronized { startTime } }
    public func getEndTime() -> Date? { synchronized { endTime } }

    public func getDuration() -> Int64 {
        synchronized {
            guard let startTime, let endTime else { return 0 }
            return Int64(endTime.timeIntervalSince(startTime) * 1_000)
        }
    }

    public func getArguments() -> [String] { arguments }
    public func getCommand() -> String { FFmpegKitConfig.argumentsToString(arguments) }
    public func getAllLogsWithTimeout(_ waitTimeout: Int32) -> [Log] { getLogs() }
    public func getAllLogs() -> [Log] { getAllLogsWithTimeout(Self.defaultTimeoutForAsynchronousMessagesInTransmit) }
    public func getLogs() -> [Log] { synchronized { logs } }
    public func getAllLogsAsStringWithTimeout(_ waitTimeout: Int32) -> String { getLogsAsString() }
    public func getAllLogsAsString() -> String { getAllLogsAsStringWithTimeout(Self.defaultTimeoutForAsynchronousMessagesInTransmit) }
    public func getLogsAsString() -> String { synchronized { logs.map { $0.getMessage() }.joined() } }
    public func getOutput() -> String { getAllLogsAsString() }
    public func getState() -> SessionState { synchronized { state } }
    public func getReturnCode() -> ReturnCode? { synchronized { returnCode } }
    public func getFailStackTrace() -> String? { synchronized { failStackTrace } }
    public func getLogRedirectionStrategy() -> LogRedirectionStrategy { logRedirectionStrategy }
    public func thereAreAsynchronousMessagesInTransmit() -> Bool { false }

    public func addLog(_ log: Log) {
        synchronized { logs.append(log) }
        logCallback?(log)
        FFmpegKitConfig.dispatchGlobalLog(log)
    }

    public func startRunning() {
        synchronized {
            state = .running
            startTime = Date()
        }
    }

    public func complete(_ returnCode: ReturnCode) {
        synchronized {
            self.returnCode = returnCode
            state = .completed
            endTime = Date()
        }
    }

    public func fail(_ error: Error) {
        synchronized {
            failStackTrace = String(reflecting: error)
            state = .failed
            endTime = Date()
        }
    }

    open func isFFmpeg() -> Bool { false }
    open func isFFprobe() -> Bool { false }
    open func isMediaInformation() -> Bool { false }
    public func cancel() { FFmpegKitConfig.cancel(sessionId) }

    @discardableResult
    internal func synchronized<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

public final class FFmpegSession: AbstractSession, @unchecked Sendable {
    private let completeCallback: FFmpegSessionCompleteCallback?
    private let statisticsCallback: StatisticsCallback?
    private var statistics: [Statistics] = []

    public static func create(_ arguments: [String]) -> FFmpegSession {
        create(arguments, withCompleteCallback: nil, withLogCallback: nil, withStatisticsCallback: nil)
    }

    public static func create(_ arguments: [String], withCompleteCallback callback: FFmpegSessionCompleteCallback?) -> FFmpegSession {
        create(arguments, withCompleteCallback: callback, withLogCallback: nil, withStatisticsCallback: nil)
    }

    public static func create(
        _ arguments: [String],
        withCompleteCallback completeCallback: FFmpegSessionCompleteCallback?,
        withLogCallback logCallback: LogCallback?,
        withStatisticsCallback statisticsCallback: StatisticsCallback?
    ) -> FFmpegSession {
        FFmpegSession(
            arguments,
            withCompleteCallback: completeCallback,
            withLogCallback: logCallback,
            withStatisticsCallback: statisticsCallback,
            withLogRedirectionStrategy: FFmpegKitConfig.getLogRedirectionStrategy()
        )
    }

    public static func create(
        _ arguments: [String],
        withCompleteCallback completeCallback: FFmpegSessionCompleteCallback?,
        withLogCallback logCallback: LogCallback?,
        withStatisticsCallback statisticsCallback: StatisticsCallback?,
        withLogRedirectionStrategy strategy: LogRedirectionStrategy
    ) -> FFmpegSession {
        FFmpegSession(
            arguments,
            withCompleteCallback: completeCallback,
            withLogCallback: logCallback,
            withStatisticsCallback: statisticsCallback,
            withLogRedirectionStrategy: strategy
        )
    }

    public init(
        _ arguments: [String],
        withCompleteCallback completeCallback: FFmpegSessionCompleteCallback?,
        withLogCallback logCallback: LogCallback?,
        withStatisticsCallback statisticsCallback: StatisticsCallback?,
        withLogRedirectionStrategy strategy: LogRedirectionStrategy
    ) {
        self.completeCallback = completeCallback
        self.statisticsCallback = statisticsCallback
        super.init(arguments, withLogCallback: logCallback, withLogRedirectionStrategy: strategy)
    }

    public func getStatisticsCallback() -> StatisticsCallback? { statisticsCallback }
    public func getCompleteCallback() -> FFmpegSessionCompleteCallback? { completeCallback }
    public func getAllStatisticsWithTimeout(_ waitTimeout: Int32) -> [Statistics] { getStatistics() }
    public func getAllStatistics() -> [Statistics] { getStatistics() }
    public func getStatistics() -> [Statistics] { synchronized { statistics } }
    public func getLastReceivedStatistics() -> Statistics? { synchronized { statistics.last } }

    public func addStatistics(_ value: Statistics) {
        synchronized { statistics.append(value) }
        statisticsCallback?(value)
        FFmpegKitConfig.dispatchGlobalStatistics(value)
    }

    public override func isFFmpeg() -> Bool { true }
}

public final class FFprobeSession: AbstractSession, @unchecked Sendable {
    private let completeCallback: FFprobeSessionCompleteCallback?

    public static func create(_ arguments: [String]) -> FFprobeSession {
        create(arguments, withCompleteCallback: nil, withLogCallback: nil)
    }

    public static func create(_ arguments: [String], withCompleteCallback callback: FFprobeSessionCompleteCallback?) -> FFprobeSession {
        create(arguments, withCompleteCallback: callback, withLogCallback: nil)
    }

    public static func create(
        _ arguments: [String],
        withCompleteCallback completeCallback: FFprobeSessionCompleteCallback?,
        withLogCallback logCallback: LogCallback?
    ) -> FFprobeSession {
        FFprobeSession(arguments, completeCallback: completeCallback, logCallback: logCallback)
    }

    public static func create(
        _ arguments: [String],
        withCompleteCallback completeCallback: FFprobeSessionCompleteCallback?,
        withLogCallback logCallback: LogCallback?,
        withLogRedirectionStrategy strategy: LogRedirectionStrategy
    ) -> FFprobeSession {
        FFprobeSession(arguments, completeCallback: completeCallback, logCallback: logCallback, strategy: strategy)
    }

    private init(
        _ arguments: [String],
        completeCallback: FFprobeSessionCompleteCallback?,
        logCallback: LogCallback?,
        strategy: LogRedirectionStrategy = FFmpegKitConfig.getLogRedirectionStrategy()
    ) {
        self.completeCallback = completeCallback
        super.init(arguments, withLogCallback: logCallback, withLogRedirectionStrategy: strategy)
    }

    public func getCompleteCallback() -> FFprobeSessionCompleteCallback? { completeCallback }
    public override func isFFprobe() -> Bool { true }
}

public final class MediaInformationSession: AbstractSession, @unchecked Sendable {
    private let completeCallback: MediaInformationSessionCompleteCallback?
    private var mediaInformation: MediaInformation?

    public static func create(_ arguments: [String]) -> MediaInformationSession {
        create(arguments, withCompleteCallback: nil, withLogCallback: nil)
    }

    public static func create(
        _ arguments: [String],
        withCompleteCallback completeCallback: MediaInformationSessionCompleteCallback?,
        withLogCallback logCallback: LogCallback?
    ) -> MediaInformationSession {
        MediaInformationSession(arguments, completeCallback: completeCallback, logCallback: logCallback)
    }

    private init(_ arguments: [String], completeCallback: MediaInformationSessionCompleteCallback?, logCallback: LogCallback?) {
        self.completeCallback = completeCallback
        super.init(arguments, withLogCallback: logCallback, withLogRedirectionStrategy: .neverPrintLogs)
    }

    public func getMediaInformation() -> MediaInformation? { synchronized { mediaInformation } }
    public func setMediaInformation(_ value: MediaInformation?) { synchronized { mediaInformation = value } }
    public func getCompleteCallback() -> MediaInformationSessionCompleteCallback? { completeCallback }
    public override func isMediaInformation() -> Bool { true }
}
