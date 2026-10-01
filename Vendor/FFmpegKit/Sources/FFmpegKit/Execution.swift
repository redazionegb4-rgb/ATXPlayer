import CFFmpegBridge
import Darwin
import Foundation

internal enum CommandKind {
    case ffmpeg
    case ffprobe
}

internal protocol ExecutionBackend: AnyObject {
    func execute(kind: CommandKind, session: AbstractSession) -> Int32
    func cancel(sessionId: Int64)
    var isLinked: Bool { get }
}

private final class NativeCallbackContext {
    let session: AbstractSession

    init(session: AbstractSession) {
        self.session = session
    }
}

private let nativeLogCallback: @convention(c) (UnsafeMutableRawPointer?, Int32, UnsafePointer<CChar>?) -> Void = {
    context, level, message in
    guard FFmpegKitConfig.isRedirectionEnabled, let context, let message else { return }
    let box = Unmanaged<NativeCallbackContext>.fromOpaque(context).takeUnretainedValue()
    box.session.addLog(Log(box.session.getSessionId(), level, String(cString: message)))
}

private let nativeStatisticsCallback: @convention(c) (
    UnsafeMutableRawPointer?, Int32, Float, Float, Int64, Double, Double, Double
) -> Void = { context, frame, fps, quality, size, time, bitrate, speed in
    guard let context else { return }
    let box = Unmanaged<NativeCallbackContext>.fromOpaque(context).takeUnretainedValue()
    guard let session = box.session as? FFmpegSession else { return }
    session.addStatistics(
        Statistics(
            session.getSessionId(),
            videoFrameNumber: frame,
            videoFps: fps,
            videoQuality: quality,
            size: size,
            time: time,
            bitrate: bitrate,
            speed: speed
        )
    )
}

internal final class NativeExecutionBackend: ExecutionBackend {
    private let executionLock = NSLock()
    var isLinked: Bool { fks_is_linked() == 1 }

    func execute(kind: CommandKind, session: AbstractSession) -> Int32 {
        executionLock.lock()
        defer { executionLock.unlock() }

        let strings = session.getArguments().map { strdup($0) }
        defer { strings.forEach { free($0) } }

        let pointers: [UnsafePointer<CChar>?] = strings.map { pointer in
            pointer.map { UnsafePointer($0) }
        }
        let callbackContext = NativeCallbackContext(session: session)
        let opaque = Unmanaged.passUnretained(callbackContext).toOpaque()

        return pointers.withUnsafeBufferPointer { buffer in
            switch kind {
            case .ffmpeg:
                return fks_ffmpeg_execute(
                    session.getSessionId(),
                    Int32(buffer.count),
                    buffer.baseAddress,
                    opaque,
                    nativeLogCallback,
                    nativeStatisticsCallback
                )
            case .ffprobe:
                return fks_ffprobe_execute(
                    session.getSessionId(),
                    Int32(buffer.count),
                    buffer.baseAddress,
                    opaque,
                    nativeLogCallback
                )
            }
        }
    }

    func cancel(sessionId: Int64) {
        fks_cancel(sessionId)
    }
}

internal enum ExecutionRuntime {
    private static let lock = NSLock()
    private static var _backend: ExecutionBackend = NativeExecutionBackend()

    static var backend: ExecutionBackend {
        get { locked { _backend } }
        set { locked { _backend = newValue } }
    }

    private static func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
