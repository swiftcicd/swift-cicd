import Foundation

public struct SlackMessage: Encodable, Equatable {
    let channel: String?
    let username: String?
    let text: String?
    let iconEmoji: String?
    let iconURL: URL?
    let attachments: [Attachment]

    public init(channel: String? = nil, username: String? = nil, text: String? = nil, iconEmoji: String? = nil, iconURL: URL? = nil, attachments: [Attachment]) {
        self.channel = channel
        self.username = username
        self.text = text
        self.iconEmoji = iconEmoji
        self.iconURL = iconURL
        self.attachments = attachments
    }
}

public struct Attachment: Encodable, Equatable {
    let color: String?
    let title: String
    let text: String
    let fields: [Field]

    public init(color: String? = nil, title: String, text: String, fields: [Field] = []) {
        self.color = color
        self.title = title
        self.text = text
        self.fields = fields
    }
}

public struct Field: Encodable, Equatable {
    let title: String
    let value: String
    let short: Bool

    public init(title: String, value: String, short: Bool) {
        self.title = title
        self.value = value
        self.short = short
    }
}

extension SlackMessage {
    enum CodingKeys: String, CodingKey {
        case channel
        case username
        case text
        case iconEmoji = "icon_emoji"
        case iconURL = "icon_url"
        case attachments
    }
}
