import Foundation

public enum FFprobeKit {
    public static func executeWithArguments(_ arguments: [String]) -> FFprobeSession {
        let session = FFprobeSession.create(arguments)
        FFmpegKitConfig.ffprobeExecute(session)
        return session
    }

    public static func execute(withArguments arguments: [String]) -> FFprobeSession {
        executeWithArguments(arguments)
    }

    public static func execute(_ command: String) -> FFprobeSession {
        executeWithArguments(FFmpegKitConfig.parseArguments(command))
    }

    public static func executeWithArgumentsAsync(
        _ arguments: [String],
        withCompleteCallback completeCallback: FFprobeSessionCompleteCallback?
    ) -> FFprobeSession {
        executeWithArgumentsAsync(
            arguments,
            withCompleteCallback: completeCallback,
            withLogCallback: nil,
            onDispatchQueue: .global(qos: .userInitiated)
        )
    }

    public static func executeWithArgumentsAsync(
        _ arguments: [String],
        withCompleteCallback completeCallback: FFprobeSessionCompleteCallback?,
        withLogCallback logCallback: LogCallback?
    ) -> FFprobeSession {
        executeWithArgumentsAsync(
            arguments,
            withCompleteCallback: completeCallback,
            withLogCallback: logCallback,
            onDispatchQueue: .global(qos: .userInitiated)
        )
    }

    public static func executeWithArgumentsAsync(
        _ arguments: [String],
        withCompleteCallback completeCallback: FFprobeSessionCompleteCallback?,
        onDispatchQueue queue: DispatchQueue
    ) -> FFprobeSession {
        executeWithArgumentsAsync(arguments, withCompleteCallback: completeCallback, withLogCallback: nil, onDispatchQueue: queue)
    }

    public static func executeWithArgumentsAsync(
        _ arguments: [String],
        withCompleteCallback completeCallback: FFprobeSessionCompleteCallback?,
        withLogCallback logCallback: LogCallback?,
        onDispatchQueue queue: DispatchQueue
    ) -> FFprobeSession {
        let session = FFprobeSession.create(arguments, withCompleteCallback: completeCallback, withLogCallback: logCallback)
        FFmpegKitConfig.asyncFFprobeExecute(session, onDispatchQueue: queue)
        return session
    }

    public static func executeAsync(
        _ command: String,
        withCompleteCallback completeCallback: FFprobeSessionCompleteCallback?
    ) -> FFprobeSession {
        executeWithArgumentsAsync(FFmpegKitConfig.parseArguments(command), withCompleteCallback: completeCallback)
    }

    public static func executeAsync(
        _ command: String,
        withCompleteCallback completeCallback: FFprobeSessionCompleteCallback?,
        withLogCallback logCallback: LogCallback?
    ) -> FFprobeSession {
        executeWithArgumentsAsync(
            FFmpegKitConfig.parseArguments(command),
            withCompleteCallback: completeCallback,
            withLogCallback: logCallback
        )
    }

    public static func executeAsync(
        _ command: String,
        withCompleteCallback completeCallback: FFprobeSessionCompleteCallback?,
        onDispatchQueue queue: DispatchQueue
    ) -> FFprobeSession {
        executeWithArgumentsAsync(
            FFmpegKitConfig.parseArguments(command),
            withCompleteCallback: completeCallback,
            onDispatchQueue: queue
        )
    }

    public static func executeAsync(
        _ command: String,
        withCompleteCallback completeCallback: FFprobeSessionCompleteCallback?,
        withLogCallback logCallback: LogCallback?,
        onDispatchQueue queue: DispatchQueue
    ) -> FFprobeSession {
        executeWithArgumentsAsync(
            FFmpegKitConfig.parseArguments(command),
            withCompleteCallback: completeCallback,
            withLogCallback: logCallback,
            onDispatchQueue: queue
        )
    }

    public static func getMediaInformation(_ path: String) -> MediaInformationSession {
        getMediaInformation(path, withTimeout: 5_000)
    }

    public static func getMediaInformation(_ path: String, withTimeout waitTimeout: Int32) -> MediaInformationSession {
        let session = MediaInformationSession.create(mediaInformationArguments(path))
        FFmpegKitConfig.getMediaInformationExecute(session, withTimeout: waitTimeout)
        return session
    }

    public static func getMediaInformationAsync(
        _ path: String,
        withCompleteCallback completeCallback: MediaInformationSessionCompleteCallback?
    ) -> MediaInformationSession {
        getMediaInformationAsync(
            path,
            withCompleteCallback: completeCallback,
            withLogCallback: nil,
            onDispatchQueue: .global(qos: .userInitiated),
            withTimeout: 5_000
        )
    }

    public static func getMediaInformationAsync(
        _ path: String,
        withCompleteCallback completeCallback: MediaInformationSessionCompleteCallback?,
        withLogCallback logCallback: LogCallback?,
        withTimeout waitTimeout: Int32
    ) -> MediaInformationSession {
        getMediaInformationAsync(
            path,
            withCompleteCallback: completeCallback,
            withLogCallback: logCallback,
            onDispatchQueue: .global(qos: .userInitiated),
            withTimeout: waitTimeout
        )
    }

    public static func getMediaInformationAsync(
        _ path: String,
        withCompleteCallback completeCallback: MediaInformationSessionCompleteCallback?,
        onDispatchQueue queue: DispatchQueue
    ) -> MediaInformationSession {
        getMediaInformationAsync(
            path,
            withCompleteCallback: completeCallback,
            withLogCallback: nil,
            onDispatchQueue: queue,
            withTimeout: 5_000
        )
    }

    public static func getMediaInformationAsync(
        _ path: String,
        withCompleteCallback completeCallback: MediaInformationSessionCompleteCallback?,
        withLogCallback logCallback: LogCallback?,
        onDispatchQueue queue: DispatchQueue,
        withTimeout waitTimeout: Int32
    ) -> MediaInformationSession {
        let session = MediaInformationSession.create(
            mediaInformationArguments(path),
            withCompleteCallback: completeCallback,
            withLogCallback: logCallback
        )
        FFmpegKitConfig.asyncGetMediaInformationExecute(session, onDispatchQueue: queue, withTimeout: waitTimeout)
        return session
    }

    public static func getMediaInformationFromCommand(_ command: String) -> MediaInformationSession {
        let session = MediaInformationSession.create(FFmpegKitConfig.parseArguments(command))
        FFmpegKitConfig.getMediaInformationExecute(session, withTimeout: 5_000)
        return session
    }

    public static func getMediaInformationFromCommandAsync(
        _ command: String,
        withCompleteCallback completeCallback: MediaInformationSessionCompleteCallback?,
        withLogCallback logCallback: LogCallback?,
        onDispatchQueue queue: DispatchQueue,
        withTimeout waitTimeout: Int32
    ) -> MediaInformationSession {
        getMediaInformationFromCommandArgumentsAsync(
            FFmpegKitConfig.parseArguments(command),
            withCompleteCallback: completeCallback,
            withLogCallback: logCallback,
            onDispatchQueue: queue,
            withTimeout: waitTimeout
        )
    }

    public static func getMediaInformationFromCommandArgumentsAsync(
        _ arguments: [String],
        withCompleteCallback completeCallback: MediaInformationSessionCompleteCallback?,
        withLogCallback logCallback: LogCallback?,
        onDispatchQueue queue: DispatchQueue,
        withTimeout waitTimeout: Int32
    ) -> MediaInformationSession {
        let session = MediaInformationSession.create(
            arguments,
            withCompleteCallback: completeCallback,
            withLogCallback: logCallback
        )
        FFmpegKitConfig.asyncGetMediaInformationExecute(session, onDispatchQueue: queue, withTimeout: waitTimeout)
        return session
    }

    public static func listFFprobeSessions() -> [FFprobeSession] { FFmpegKitConfig.getFFprobeSessions() }
    public static func listMediaInformationSessions() -> [MediaInformationSession] { FFmpegKitConfig.getMediaInformationSessions() }

    private static func mediaInformationArguments(_ path: String) -> [String] {
        ["-v", "error", "-hide_banner", "-print_format", "json", "-show_format", "-show_streams", "-show_chapters", path]
    }
}
