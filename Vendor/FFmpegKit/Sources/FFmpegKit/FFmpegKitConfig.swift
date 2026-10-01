import CFFmpegBridge
import Darwin
import Foundation

public enum FFmpegKitConfig {
    private static let lock = NSRecursiveLock()
    private static var sessionId: Int64 = 1
    private static var sessions: [Session] = []
    private static var sessionHistorySize = 10
    private static var logCallback: LogCallback?
    private static var statisticsCallback: StatisticsCallback?
    private static var ffmpegCompleteCallback: FFmpegSessionCompleteCallback?
    private static var ffprobeCompleteCallback: FFprobeSessionCompleteCallback?
    private static var mediaInformationCompleteCallback: MediaInformationSessionCompleteCallback?
    private static var logLevel = Level.avLogInfo.rawValue
    private static var redirectionStrategy = LogRedirectionStrategy.printLogsWhenNoCallbacksDefined
    private static var redirectionEnabled = true

    internal static func nextSessionId() -> Int64 {
        synchronized {
            defer { sessionId += 1 }
            return sessionId
        }
    }

    internal static func addSession(_ session: Session) {
        synchronized {
            sessions.append(session)
            if sessions.count > sessionHistorySize {
                sessions.removeFirst(sessions.count - sessionHistorySize)
            }
        }
    }

    public static func ffmpegExecute(_ session: FFmpegSession) {
        execute(.ffmpeg, session: session)
        session.getCompleteCallback()?(session)
        synchronized { ffmpegCompleteCallback }?(session)
    }

    public static func ffprobeExecute(_ session: FFprobeSession) {
        execute(.ffprobe, session: session)
        session.getCompleteCallback()?(session)
        synchronized { ffprobeCompleteCallback }?(session)
    }

    public static func getMediaInformationExecute(_ session: MediaInformationSession, withTimeout waitTimeout: Int32) {
        execute(.ffprobe, session: session)
        if ReturnCode.isSuccess(session.getReturnCode()) {
            session.setMediaInformation(MediaInformationJsonParser.from(session.getOutput()))
        }
        session.getCompleteCallback()?(session)
        synchronized { mediaInformationCompleteCallback }?(session)
    }

    public static func asyncFFmpegExecute(_ session: FFmpegSession) {
        asyncFFmpegExecute(session, onDispatchQueue: .global(qos: .userInitiated))
    }

    public static func asyncFFmpegExecute(_ session: FFmpegSession, onDispatchQueue queue: DispatchQueue) {
        queue.async { ffmpegExecute(session) }
    }

    public static func asyncFFprobeExecute(_ session: FFprobeSession) {
        asyncFFprobeExecute(session, onDispatchQueue: .global(qos: .userInitiated))
    }

    public static func asyncFFprobeExecute(_ session: FFprobeSession, onDispatchQueue queue: DispatchQueue) {
        queue.async { ffprobeExecute(session) }
    }

    public static func asyncGetMediaInformationExecute(_ session: MediaInformationSession, withTimeout waitTimeout: Int32) {
        asyncGetMediaInformationExecute(session, onDispatchQueue: .global(qos: .userInitiated), withTimeout: waitTimeout)
    }

    public static func asyncGetMediaInformationExecute(
        _ session: MediaInformationSession,
        onDispatchQueue queue: DispatchQueue,
        withTimeout waitTimeout: Int32
    ) {
        queue.async { getMediaInformationExecute(session, withTimeout: waitTimeout) }
    }

    private static func execute(_ kind: CommandKind, session: AbstractSession) {
        session.startRunning()
        let result = ExecutionRuntime.backend.execute(kind: kind, session: session)
        session.complete(ReturnCode(result))
    }

    public static func cancel(_ sessionId: Int64) { ExecutionRuntime.backend.cancel(sessionId: sessionId) }
    public static func enableRedirection() { synchronized { redirectionEnabled = true } }
    public static func disableRedirection() { synchronized { redirectionEnabled = false } }
    public static func getFFmpegVersion() -> String { String(cString: fks_ffmpeg_version()) }
    public static func getVersion() -> String { "6.0-swift" }
    public static func isLTSBuild() -> Int32 { 0 }
    public static func getBuildDate() -> String { "swift" }

    public static func setEnvironmentVariable(_ variableName: String, value: String) -> Int32 {
        Int32(setenv(variableName, value, 1))
    }

    public static func setFontconfigConfigurationPath(_ path: String) -> Int32 {
        Int32(setenv("FONTCONFIG_PATH", path, 1))
    }

    public static func setFontDirectory(_ fontDirectoryPath: String, with fontNameMapping: [String: String]?) {
        setFontDirectoryList([fontDirectoryPath], with: fontNameMapping)
    }

    public static func setFontDirectoryList(_ fontDirectoryList: [String], with fontNameMapping: [String: String]?) {
        let directories = fontDirectoryList.map { "  <dir>\($0.xmlEscaped)</dir>" }.joined(separator: "\n")
        let aliases = (fontNameMapping ?? [:]).map { source, target in
            "  <alias><family>\(source.xmlEscaped)</family><prefer><family>\(target.xmlEscaped)</family></prefer></alias>"
        }.joined(separator: "\n")
        let configuration = "<?xml version=\"1.0\"?><!DOCTYPE fontconfig SYSTEM \"fonts.dtd\"><fontconfig>\n\(directories)\n\(aliases)\n</fontconfig>"
        let directory = (NSTemporaryDirectory() as NSString).appendingPathComponent("ffmpeg-kit-fontconfig")
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let file = (directory as NSString).appendingPathComponent("fonts.conf")
        try? configuration.write(toFile: file, atomically: true, encoding: .utf8)
        _ = setenv("FONTCONFIG_PATH", directory, 1)
        _ = setenv("FONTCONFIG_FILE", "fonts.conf", 1)
    }

    public static func ignoreSignal(_ value: Signal) {
        Darwin.signal(value.rawValue, SIG_IGN)
    }

    public static func registerNewFFmpegPipe() -> String? {
        let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("ffmpeg-kit-\(UUID().uuidString)")
        return mkfifo(path, S_IRUSR | S_IWUSR) == 0 ? path : nil
    }

    public static func closeFFmpegPipe(_ path: String) { unlink(path) }
    public static func enableLogCallback(_ callback: LogCallback?) { synchronized { logCallback = callback } }
    public static func enableStatisticsCallback(_ callback: StatisticsCallback?) { synchronized { statisticsCallback = callback } }
    public static func enableFFmpegSessionCompleteCallback(_ callback: FFmpegSessionCompleteCallback?) { synchronized { ffmpegCompleteCallback = callback } }
    public static func getFFmpegSessionCompleteCallback() -> FFmpegSessionCompleteCallback? { synchronized { ffmpegCompleteCallback } }
    public static func enableFFprobeSessionCompleteCallback(_ callback: FFprobeSessionCompleteCallback?) { synchronized { ffprobeCompleteCallback = callback } }
    public static func getFFprobeSessionCompleteCallback() -> FFprobeSessionCompleteCallback? { synchronized { ffprobeCompleteCallback } }
    public static func enableMediaInformationSessionCompleteCallback(_ callback: MediaInformationSessionCompleteCallback?) { synchronized { mediaInformationCompleteCallback = callback } }
    public static func getMediaInformationSessionCompleteCallback() -> MediaInformationSessionCompleteCallback? { synchronized { mediaInformationCompleteCallback } }
    public static func getLogLevel() -> Int32 { synchronized { logLevel } }
    public static func setLogLevel(_ level: Int32) { synchronized { logLevel = level } }
    public static func logLevelToString(_ level: Int32) -> String {
        switch level {
        case Level.avLogQuiet.rawValue: return "QUIET"
        case Level.avLogPanic.rawValue: return "PANIC"
        case Level.avLogFatal.rawValue: return "FATAL"
        case Level.avLogError.rawValue: return "ERROR"
        case Level.avLogWarning.rawValue: return "WARNING"
        case Level.avLogInfo.rawValue: return "INFO"
        case Level.avLogVerbose.rawValue: return "VERBOSE"
        case Level.avLogDebug.rawValue: return "DEBUG"
        case Level.avLogTrace.rawValue: return "TRACE"
        default: return "STDERR"
        }
    }
    public static func getSessionHistorySize() -> Int { synchronized { sessionHistorySize } }

    public static func setSessionHistorySize(_ size: Int) {
        guard size > 0 else { return }
        synchronized {
            sessionHistorySize = size
            if sessions.count > size { sessions.removeFirst(sessions.count - size) }
        }
    }

    public static func getSession(_ sessionId: Int64) -> Session? { synchronized { sessions.last { $0.getSessionId() == sessionId } } }
    public static func getLastSession() -> Session? { synchronized { sessions.last } }
    public static func getLastCompletedSession() -> Session? { synchronized { sessions.last { $0.getState() == .completed } } }
    public static func getSessions() -> [Session] { synchronized { sessions } }
    public static func clearSessions() { synchronized { sessions.removeAll() } }
    public static func getFFmpegSessions() -> [FFmpegSession] { synchronized { sessions.compactMap { $0 as? FFmpegSession } } }
    public static func getFFprobeSessions() -> [FFprobeSession] { synchronized { sessions.compactMap { $0 as? FFprobeSession } } }
    public static func getMediaInformationSessions() -> [MediaInformationSession] { synchronized { sessions.compactMap { $0 as? MediaInformationSession } } }
    public static func getSessionsByState(_ state: SessionState) -> [Session] { synchronized { sessions.filter { $0.getState() == state } } }
    public static func getLogRedirectionStrategy() -> LogRedirectionStrategy { synchronized { redirectionStrategy } }
    public static func setLogRedirectionStrategy(_ strategy: LogRedirectionStrategy) { synchronized { redirectionStrategy = strategy } }
    public static func messagesInTransmit(_ sessionId: Int64) -> Int32 { 0 }
    public static func sessionStateToString(_ state: SessionState) -> String { String(describing: state).uppercased() }

    public static func parseArguments(_ command: String) -> [String] {
        var arguments: [String] = []
        var current = ""
        var quote: Character?
        var escaped = false

        for character in command {
            if escaped {
                current.append(character)
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if let activeQuote = quote {
                if character == activeQuote { quote = nil } else { current.append(character) }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character.isWhitespace {
                if !current.isEmpty { arguments.append(current); current = "" }
            } else {
                current.append(character)
            }
        }
        if escaped { current.append("\\") }
        if !current.isEmpty { arguments.append(current) }
        return arguments
    }

    public static func argumentsToString(_ arguments: [String]) -> String {
        arguments.map { argument in
            guard argument.contains(where: { $0.isWhitespace || $0 == "\"" || $0 == "'" }) else { return argument }
            return "\"\(argument.replacingOccurrences(of: "\"", with: "\\\""))\""
        }.joined(separator: " ")
    }

    public static func isNativeFFmpegLinked() -> Bool { ExecutionRuntime.backend.isLinked }
    internal static func dispatchGlobalLog(_ log: Log) { synchronized { logCallback }?(log) }
    internal static func dispatchGlobalStatistics(_ statistics: Statistics) { synchronized { statisticsCallback }?(statistics) }
    internal static var isRedirectionEnabled: Bool { synchronized { redirectionEnabled } }

    @discardableResult
    private static func synchronized<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

private extension String {
    var xmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
