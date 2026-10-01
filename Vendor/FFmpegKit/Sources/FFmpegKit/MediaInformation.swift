import Foundation

open class InformationDictionary: NSObject, @unchecked Sendable {
    internal let properties: [String: Any]

    public init(_ properties: [String: Any]) {
        self.properties = properties
    }

    public func getStringProperty(_ key: String) -> String? { properties[key] as? String }
    public func getNumberProperty(_ key: String) -> NSNumber? { properties[key] as? NSNumber }
    public func getProperty(_ key: String) -> Any? { properties[key] }
    public func getAllProperties() -> [String: Any] { properties }
}

public final class StreamInformation: InformationDictionary, @unchecked Sendable {
    public func getIndex() -> NSNumber? { getNumberProperty("index") }
    public func getType() -> String? { getStringProperty("codec_type") }
    public func getCodec() -> String? { getStringProperty("codec_name") }
    public func getCodecLong() -> String? { getStringProperty("codec_long_name") }
    public func getFormat() -> String? { getStringProperty("pix_fmt") }
    public func getWidth() -> NSNumber? { getNumberProperty("width") }
    public func getHeight() -> NSNumber? { getNumberProperty("height") }
    public func getBitrate() -> String? { getStringProperty("bit_rate") }
    public func getSampleRate() -> String? { getStringProperty("sample_rate") }
    public func getSampleFormat() -> String? { getStringProperty("sample_fmt") }
    public func getChannelLayout() -> String? { getStringProperty("channel_layout") }
    public func getSampleAspectRatio() -> String? { getStringProperty("sample_aspect_ratio") }
    public func getDisplayAspectRatio() -> String? { getStringProperty("display_aspect_ratio") }
    public func getAverageFrameRate() -> String? { getStringProperty("avg_frame_rate") }
    public func getRealFrameRate() -> String? { getStringProperty("r_frame_rate") }
    public func getTimeBase() -> String? { getStringProperty("time_base") }
    public func getCodecTimeBase() -> String? { getStringProperty("codec_time_base") }
    public func getTags() -> [String: Any]? { getProperty("tags") as? [String: Any] }
}

public final class Chapter: InformationDictionary, @unchecked Sendable {
    public func getId() -> NSNumber? { getNumberProperty("id") }
    public func getTimeBase() -> String? { getStringProperty("time_base") }
    public func getStart() -> NSNumber? { getNumberProperty("start") }
    public func getStartTime() -> String? { getStringProperty("start_time") }
    public func getEnd() -> NSNumber? { getNumberProperty("end") }
    public func getEndTime() -> String? { getStringProperty("end_time") }
    public func getTags() -> [String: Any]? { getProperty("tags") as? [String: Any] }
}

public final class MediaInformation: InformationDictionary, @unchecked Sendable {
    private let streams: [StreamInformation]
    private let chapters: [Chapter]

    public init(_ properties: [String: Any], withStreams streams: [StreamInformation], withChapters chapters: [Chapter]) {
        self.streams = streams
        self.chapters = chapters
        super.init(properties)
    }

    private var formatProperties: [String: Any]? { properties["format"] as? [String: Any] }
    public func getFilename() -> String? { getStringFormatProperty("filename") }
    public func getFormat() -> String? { getStringFormatProperty("format_name") }
    public func getLongFormat() -> String? { getStringFormatProperty("format_long_name") }
    public func getDuration() -> String? { getStringFormatProperty("duration") }
    public func getStartTime() -> String? { getStringFormatProperty("start_time") }
    public func getSize() -> String? { getStringFormatProperty("size") }
    public func getBitrate() -> String? { getStringFormatProperty("bit_rate") }
    public func getTags() -> [String: Any]? { getFormatProperty("tags") as? [String: Any] }
    public func getStreams() -> [StreamInformation] { streams }
    public func getChapters() -> [Chapter] { chapters }
    public func getStringFormatProperty(_ key: String) -> String? { formatProperties?[key] as? String }
    public func getNumberFormatProperty(_ key: String) -> NSNumber? { formatProperties?[key] as? NSNumber }
    public func getFormatProperty(_ key: String) -> Any? { formatProperties?[key] }
    public func getFormatProperties() -> [String: Any]? { formatProperties }
}

public enum MediaInformationJsonParser {
    public static func from(_ ffprobeJsonOutput: String) -> MediaInformation? {
        try? fromWithError(ffprobeJsonOutput)
    }

    public static func fromWithError(_ ffprobeJsonOutput: String) throws -> MediaInformation? {
        guard let data = ffprobeJsonOutput.data(using: .utf8) else { return nil }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let streams = (root["streams"] as? [[String: Any]] ?? []).map(StreamInformation.init)
        let chapters = (root["chapters"] as? [[String: Any]] ?? []).map(Chapter.init)
        return MediaInformation(root, withStreams: streams, withChapters: chapters)
    }
}
