import Foundation

public extension Slack {
    struct LegacyMessage: Encodable, Equatable {
        let channel: String?
        let username: String?
        let text: String?
        let iconEmoji: String?
        let iconURL: URL?
        let attachments: [Attachment]

        public init(
            channel: String? = nil,
            username: String? = nil,
            text: String? = nil,
            iconEmoji: String? = nil,
            iconURL: URL? = nil,
            attachments: [Attachment] = []
        ) {
            self.channel = channel
            self.username = username
            self.text = text
            self.iconEmoji = iconEmoji
            self.iconURL = iconURL
            self.attachments = attachments
        }
    }

    struct Attachment: Encodable, Equatable {
        let markdownIn: [String]
        let color: String?
        let title: String?
        let titleLink: String?
        let text: String?
        let fields: [Field]
        let footer: String?

        public init(
            markdownIn: [String] = [],
            color: String? = nil,
            title: String? = nil,
            titleLink: String? = nil,
            text: String? = nil,
            fields: [Field] = [],
            footer: String? = nil
        ) {
            self.markdownIn = markdownIn
            self.color = color
            self.title = title
            self.titleLink = titleLink
            self.text = text
            self.fields = fields
            self.footer = footer
        }
    }

    struct Field: Encodable, Equatable {
        let title: String
        let value: String
        let short: Bool

        public init(title: String, value: String, short: Bool = false) {
            self.title = title
            self.value = value
            self.short = short
        }
    }
}

extension Slack.LegacyMessage {
    enum CodingKeys: String, CodingKey {
        case channel
        case username
        case text
        case iconEmoji = "icon_emoji"
        case iconURL = "icon_url"
        case attachments
    }
}

extension Slack.Attachment {
    enum CodingKeys: String, CodingKey {
        case markdownIn = "mrkdwn_in"
        case color
        case title
        case titleLink = "title_link"
        case text
        case fields
        case footer
    }
}
