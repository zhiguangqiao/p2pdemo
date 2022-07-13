//
//  UDPAsyncSocket.swift
//  P2PClient
//
//  Created by goodluck on 2022/7/10.
//

import Foundation
import RxSwift
import RxRelay
import CocoaAsyncSocket

struct Message {
    enum Direction: String {
        case recive
        case send
    }
    let data: Data
    let host: String
    let port: UInt16
    let direction: Direction
    init(data: Data, host: String, port: UInt16, direction: Direction = .send) {
        self.data = data
        self.host = host
        self.port = port
        self.direction = direction
    }
}


class UDPAsyncSocket: NSObject {

    public let dataReceivedRelay = BehaviorRelay<Data?>(value: nil)
    let bindPort: UInt16
    init(bindPort: UInt16) {
        self.bindPort = bindPort
        super.init()
        self.setupUdp()
    }
    lazy var cocoaSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: .global())

    func setupUdp() {
        try? cocoaSocket.bind(toPort: bindPort)
        try? cocoaSocket.beginReceiving()
    }

    func sendMessage(message: Message) {
        self.cocoaSocket.send(message.data, toHost: message.host, port: message.port, withTimeout: 100, tag: 0)
    }

}

extension UDPAsyncSocket: GCDAsyncUdpSocketDelegate {
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        print("didReceive")
        DispatchQueue.main.async {
            self.dataReceivedRelay.accept(data)
        }
    }
    func udpSocket(_ sock: GCDAsyncUdpSocket, didSendDataWithTag tag: Int) {
        print("didSendDataWithTag")
    }
    func udpSocket(_ sock: GCDAsyncUdpSocket, didConnectToAddress address: Data) {
        print("didConnectToAddress")
    }
    func udpSocket(_ sock: GCDAsyncUdpSocket, didNotConnect error: Error?) {
        print("didNotConnect")
    }
    func udpSocketDidClose(_ sock: GCDAsyncUdpSocket, withError error: Error?) {
        print("udpSocketDidClose")
    }
    func udpSocket(_ sock: GCDAsyncUdpSocket, didNotSendDataWithTag tag: Int, dueToError error: Error?) {
        print("didNotSendDataWithTag")
    }
}
