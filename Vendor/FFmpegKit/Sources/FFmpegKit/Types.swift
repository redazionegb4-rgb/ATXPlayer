import Foundation

public enum SessionState: UInt, Sendable {
    case created
    case running
    case failed
    case completed
}

public enum LogRedirectionStrategy: UInt, Sendable {
    case alwaysPrintLogs
    case printLogsWhenNoCallbacksDefined
    case printLogsWhenGlobalCallbackNotDefined
    case printLogsWhenSessionCallbackNotDefined
    case neverPrintLogs
}

public enum Level: Int32, Sendable {
    case avLogStdErr = -16
    case avLogQuiet = -8
    case avLogPanic = 0
    case avLogFatal = 8
    case avLogError = 16
    case avLogWarning = 24
    case avLogInfo = 32
    case avLogVerbose = 40
    case avLogDebug = 48
    case avLogTrace = 56
}

public enum Signal: Int32, Sendable {
    case sigInt = 2
    case sigQuit = 3
    case sigPipe = 13
    case sigTerm = 15
    case sigXcpu = 24
}

public final class ReturnCode: NSObject, @unchecked Sendable {
    public static let success: Int32 = 0
    public static let cancel: Int32 = 255

    private let value: Int32

    public init(_ value: Int32) {
        self.value = value
    }

    public static func isSuccess(_ value: ReturnCode?) -> Bool {
        value?.value == success
    }

    public static func isCancel(_ value: ReturnCode?) -> Bool {
        value?.value == cancel
    }

    public func getValue() -> Int32 { value }
    public func isValueSuccess() -> Bool { value == Self.success }
    public func isValueError() -> Bool { value != Self.success && value != Self.cancel }
    public func isValueCancel() -> Bool { value == Self.cancel }
    public override var description: String { String(value) }
}

public final class Log: NSObject, @unchecked Sendable {
    private let sessionId: Int64
    private let level: Int32
    private let message: String

    public init(_ sessionId: Int64, _ level: Int32, _ message: String) {
        self.sessionId = sessionId
        self.level = level
        self.message = message
    }

    public func getSessionId() -> Int64 { sessionId }
    public func getLevel() -> Int32 { level }
    public func getMessage() -> String { message }
}

public final class Statistics: NSObject, @unchecked Sendable {
    private let sessionId: Int64
    private let videoFrameNumber: Int32
    private let videoFps: Float
    private let videoQuality: Float
    private let size: Int64
    private let time: Double
    private let bitrate: Double
    private let speed: Double

    public init(
        _ sessionId: Int64,
        videoFrameNumber: Int32,
        videoFps: Float,
        videoQuality: Float,
        size: Int64,
        time: Double,
        bitrate: Double,
        speed: Double
    ) {
        self.sessionId = sessionId
        self.videoFrameNumber = videoFrameNumber
        self.videoFps = videoFps
        self.videoQuality = videoQuality
        self.size = size
        self.time = time
        self.bitrate = bitrate
        self.speed = speed
    }

    public func getSessionId() -> Int64 { sessionId }
    public func getVideoFrameNumber() -> Int32 { videoFrameNumber }
    public func getVideoFps() -> Float { videoFps }
    public func getVideoQuality() -> Float { videoQuality }
    public func getSize() -> Int64 { size }
    public func getTime() -> Double { time }
    public func getBitrate() -> Double { bitrate }
    public func getSpeed() -> Double { speed }
}

public typealias LogCallback = (Log) -> Void
public typealias StatisticsCallback = (Statistics) -> Void
public typealias FFmpegSessionCompleteCallback = (FFmpegSession) -> Void
public typealias FFprobeSessionCompleteCallback = (FFprobeSession) -> Void
public typealias MediaInformationSessionCompleteCallback = (MediaInformationSession) -> Void
