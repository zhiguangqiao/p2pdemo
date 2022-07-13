//
//  Const.swift
//  P2PClient
//
//  Created by goodluck on 2022/7/4.
//

import Foundation

class Const {
    static let cellDequeueId = "cellDequeueId"
    static let peerUUIDKey = "peerUUIDKey"
    static let serverIp = "49.235.120.123"
    static let serverPort: UInt16 = 1777
    static let sendPort: UInt16 = UInt16(arc4random() % (UInt32(UInt16.max) - 1024) + 1024)

    static var uuid: String = {
        if let uuid = UserDefaults.standard.string(forKey: Const.peerUUIDKey) {
            return uuid
        }
        let uuid = NSUUID().uuidString
        UserDefaults.standard.set(uuid, forKey: Const.peerUUIDKey)
        return uuid
    }()

}
