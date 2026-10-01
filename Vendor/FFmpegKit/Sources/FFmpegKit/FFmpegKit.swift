import Foundation

public enum FFmpegKit {
    public static func executeWithArguments(_ arguments: [String]) -> FFmpegSession {
        let session = FFmpegSession.create(arguments)
        FFmpegKitConfig.ffmpegExecute(session)
        return session
    }

    public static func execute(withArguments arguments: [String]) -> FFmpegSession {
        executeWithArguments(arguments)
    }

    public static func execute(_ command: String) -> FFmpegSession {
        executeWithArguments(FFmpegKitConfig.parseArguments(command))
    }

    public static func executeWithArgumentsAsync(
        _ arguments: [String],
        withCompleteCallback completeCallback: FFmpegSessionCompleteCallback?
    ) -> FFmpegSession {
        executeWithArgumentsAsync(
            arguments,
            withCompleteCallback: completeCallback,
            withLogCallback: nil,
            withStatisticsCallback: nil,
            onDispatchQueue: .global(qos: .userInitiated)
        )
    }

    public static func executeWithArgumentsAsync(
        _ arguments: [String],
        withCompleteCallback completeCallback: FFmpegSessionCompleteCallback?,
        withLogCallback logCallback: LogCallback?,
        withStatisticsCallback statisticsCallback: StatisticsCallback?
    ) -> FFmpegSession {
        executeWithArgumentsAsync(
            arguments,
            withCompleteCallback: completeCallback,
            withLogCallback: logCallback,
            withStatisticsCallback: statisticsCallback,
            onDispatchQueue: .global(qos: .userInitiated)
        )
    }

    public static func executeWithArgumentsAsync(
        _ arguments: [String],
        withCompleteCallback completeCallback: FFmpegSessionCompleteCallback?,
        onDispatchQueue queue: DispatchQueue
    ) -> FFmpegSession {
        executeWithArgumentsAsync(
            arguments,
            withCompleteCallback: completeCallback,
            withLogCallback: nil,
            withStatisticsCallback: nil,
            onDispatchQueue: queue
        )
    }

    public static func executeWithArgumentsAsync(
        _ arguments: [String],
        withCompleteCallback completeCallback: FFmpegSessionCompleteCallback?,
        withLogCallback logCallback: LogCallback?,
        withStatisticsCallback statisticsCallback: StatisticsCallback?,
        onDispatchQueue queue: DispatchQueue
    ) -> FFmpegSession {
        let session = FFmpegSession.create(
            arguments,
            withCompleteCallback: completeCallback,
            withLogCallback: logCallback,
            withStatisticsCallback: statisticsCallback
        )
        FFmpegKitConfig.asyncFFmpegExecute(session, onDispatchQueue: queue)
        return session
    }

    public static func executeAsync(
        _ command: String,
        withCompleteCallback completeCallback: FFmpegSessionCompleteCallback?
    ) -> FFmpegSession {
        executeWithArgumentsAsync(FFmpegKitConfig.parseArguments(command), withCompleteCallback: completeCallback)
    }

    public static func executeAsync(
        _ command: String,
        withCompleteCallback completeCallback: FFmpegSessionCompleteCallback?,
        withLogCallback logCallback: LogCallback?,
        withStatisticsCallback statisticsCallback: StatisticsCallback?
    ) -> FFmpegSession {
        executeWithArgumentsAsync(
            FFmpegKitConfig.parseArguments(command),
            withCompleteCallback: completeCallback,
            withLogCallback: logCallback,
            withStatisticsCallback: statisticsCallback
        )
    }

    public static func executeAsync(
        _ command: String,
        withCompleteCallback completeCallback: FFmpegSessionCompleteCallback?,
        onDispatchQueue queue: DispatchQueue
    ) -> FFmpegSession {
        executeWithArgumentsAsync(
            FFmpegKitConfig.parseArguments(command),
            withCompleteCallback: completeCallback,
            onDispatchQueue: queue
        )
    }

    public static func executeAsync(
        _ command: String,
        withCompleteCallback completeCallback: FFmpegSessionCompleteCallback?,
        withLogCallback logCallback: LogCallback?,
        withStatisticsCallback statisticsCallback: StatisticsCallback?,
        onDispatchQueue queue: DispatchQueue
    ) -> FFmpegSession {
        executeWithArgumentsAsync(
            FFmpegKitConfig.parseArguments(command),
            withCompleteCallback: completeCallback,
            withLogCallback: logCallback,
            withStatisticsCallback: statisticsCallback,
            onDispatchQueue: queue
        )
    }

    public static func cancel() {
        FFmpegKitConfig.getFFmpegSessions()
            .filter { $0.getState() == .running }
            .forEach { $0.cancel() }
    }

    public static func cancel(_ sessionId: Int64) { FFmpegKitConfig.cancel(sessionId) }
    public static func listSessions() -> [FFmpegSession] { FFmpegKitConfig.getFFmpegSessions() }
}
