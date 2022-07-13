//
//  MessageModels.swift
//  P2PClient
//
//  Created by goodluck on 2022/7/6.
//

import Foundation

enum ConnectState: String {
    case loc
    case pub
    case none
}

class Peer: Codable {
    let ipPub: String?
    let portPub: UInt16?

    let ipLoc: String
    let portLoc: UInt16
    let peerId: String
    let UUID: String
    private enum CodingKeys: String, CodingKey {
        case ipPub
        case portPub
        case ipLoc
        case portLoc
        case peerId
        case UUID
    }
    init(
        ipPub: String? = nil,
        portPub: UInt16? = nil,
        ipLoc: String,
        portLoc: UInt16,
        peerId: String
    ) {
        self.ipPub = ipPub
        self.ipLoc = ipLoc
        self.portPub = portPub
        self.portLoc = portLoc
        self.peerId = peerId
        self.UUID = NSUUID().uuidString

    }
    var state = ConnectState.none

    var liveIp: String? {
        switch state {
        case .loc:
            return ipLoc
        case .pub:
            return ipPub
        case .none:
            return nil
        }
    }
    var livePort: UInt16? {
        switch state {
        case .loc:
            return portLoc
        case .pub:
            return portPub
        case .none:
            return nil
        }
    }

    var isMe: Bool {
        return Const.uuid == peerId
    }
}

enum PingType: String, Codable {
    case local
    case direct
    case viaTracer
    var isLocal: Bool {
        return self == .local
    }
}

struct PingPongInfo: Codable {
    let source: Peer
    let target: Peer
    let type: PingType
    init(source: Peer, target: Peer, type: PingType) {
        self.target = target
        self.source = source
        self.type = type
    }
    var isLocal: Bool {
        return type == .local
    }
}

enum P2PMessage {
    case pullPeers(Peer)
    case peers([Peer])
    case ping(PingPongInfo)
    case pong(PingPongInfo)
    case content(String)

    private enum MessageType: String, Codable {
        case peers
        case ping
        case pong
        case pull
        case content
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case peers
        case pingPongInfo
        case peer
        case content
    }
}

extension P2PMessage: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)
        switch type {
        case .peers:
            let peers = try container.decode([Peer].self, forKey: .peers)
            self = .peers(peers)
        case .ping:
            let pingPongInfo = try container.decode(PingPongInfo.self, forKey: .pingPongInfo)
            self = .ping(pingPongInfo)
        case .pong:
            let pingPongInfo = try container.decode(PingPongInfo.self, forKey: .pingPongInfo)
            self = .pong(pingPongInfo)
        case .pull:
            assert(false)
            let peer = try container.decode(Peer.self, forKey: .peer)
            self = .pullPeers(peer)
        case .content:
            let content = try container.decode(String.self, forKey: .content)
            self = .content(content)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .peers:
            assert(false)
        case .ping(let pingPongInfo):
            try container.encode(MessageType.ping, forKey: .type)
            try container.encode(pingPongInfo, forKey: .pingPongInfo)
        case .pong(let pingPongInfo):
            try container.encode(MessageType.pong, forKey: .type)
            try container.encode(pingPongInfo, forKey: .pingPongInfo)
        case .pullPeers(let peer):
                try container.encode(MessageType.pull, forKey: .type)
                try container.encode(peer, forKey: .peer)
        case .content(let content):
            try container.encode(MessageType.content, forKey: .type)
            try container.encode(content, forKey: .content)
        }
    }
}
