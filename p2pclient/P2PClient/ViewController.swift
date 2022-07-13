//
//  ViewController.swift
//  P2PClient
//
//  Created by goodluck on 2022/7/2.
//

import UIKit
import CFNetwork
import RxSwift
import CocoaAsyncSocket


class ViewController: UIViewController {
    let bag = DisposeBag()
    let pullButton = UIButton(type: .roundedRect)
    let tableView = UITableView(frame: .zero, style: .plain)
    var me: Peer? {
        return peers.first { peer in
            peer.isMe
        }
    }
    var peers: [Peer] = [] {
        didSet {
            tableView.reloadData()
        }
    }
    lazy var udp = UDPAsyncSocket(bindPort: Const.sendPort)
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubviews()
        udp.dataReceivedRelay.compactMap { $0 }.subscribe(onNext: { data in
            guard
                let p2pMessage = try? JSONDecoder().decode(P2PMessage.self, from: data)
            else {
                return
            }
            print("receiveValue: \(p2pMessage)")
            switch p2pMessage {
            case .peers(let peers):
                self.peers = peers
            case .ping(let info):
                guard info.target.isMe else { return }
                self.sendPong(pingInfo: info)
                if info.type != .viaTracer {
                    self.updatePeerState(peer: info.source, isLocal: info.isLocal)
                }
            case .pong(let info):
                guard info.source.isMe else { return }
                if info.type != .viaTracer {
                    self.updatePeerState(peer: info.target, isLocal: info.isLocal)
                }
            case .pullPeers, .content:
                break
            }
        }) .disposed(by: bag)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
            self.pullPeersFromTracker()
        })

    }

    func updatePeerState(peer: Peer, isLocal: Bool) {
        self.peers.forEach { tmpPeer in
            if tmpPeer.peerId == peer.peerId, tmpPeer.state != .loc {
                tmpPeer.state = isLocal ? .loc : .pub
                self.tableView.reloadData()
            }
        }
    }
    func setupSubviews()  {
        self.title = "Peers"
        self.view.backgroundColor = .white
        pullButton.setTitle("pull peers", for: .normal)
        pullButton.addTarget(self, action: #selector(pullPeersFromTracker), for: .touchUpInside)
        self.navigationItem.rightBarButtonItem = .init(customView: pullButton)
        view.addSubview(tableView)
        tableView.rowHeight = 160
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Const.cellDequeueId)
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        tableView.delegate = self
        tableView.dataSource = self
    }
}

extension ViewController : UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Const.cellDequeueId, for: indexPath)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let peer = peers[indexPath.row]
        if
            let data = try? encoder.encode(peer),
            let title = String.init(data: data, encoding: .utf8)
        {
            cell.textLabel?.text = "\(title) \nstate: \(peer.state.rawValue) \nisMe: \(peer.isMe)"
            if peer.isMe {
                cell.backgroundColor = .gray
            } else if peer.state == .pub {
                cell.backgroundColor = .green
            } else if peer.state == .loc {
                cell.backgroundColor = .blue
            } else {
                cell.backgroundColor = .red
            }
            cell.isUserInteractionEnabled = !peer.isMe
        }
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.font = .systemFont(ofSize: 12)
        return cell
    }


    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let peer = peers[indexPath.row]
        if peer.state == .none {
            sendPing(target: peer, pingType: .local)
            sendPing(target: peer, pingType: .viaTracer)
            loopDirectPing(peer: peer, time: 3)
        } else {
            self.navigationController?.pushViewController(MessageViewController(peer: peer, udp: udp), animated: true)
        }
    }

    func loopDirectPing(peer: Peer, time: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if peer.state == .none, time > 0 {
                self.sendPing(target: peer, pingType: .direct)
                self.loopDirectPing(peer:peer, time: time - 1)
            }
        }
    }


    func sendPing(target: Peer, pingType: PingType) {
        guard let me = me else { return }
        let ping = P2PMessage.ping(.init(source: me, target: target, type: pingType))
        guard let data = try? JSONEncoder().encode(ping) else { return }
        switch pingType {
        case .local:
            udp.sendMessage(message: .init(data: data, host: target.ipLoc, port: target.portLoc))
        case .direct:
            guard let ipPub = target.ipPub, let portPub = target.portPub, portPub > 1024 else { return }
            udp.sendMessage(message: .init(data: data, host: ipPub, port: portPub))
        case .viaTracer:
            if let portPub = target.portPub, portPub > 1024 {
                udp.sendMessage(message: .init(data: data, host: Const.serverIp, port: Const.serverPort))
            }
        }
    }

    func sendPong(pingInfo: PingPongInfo) {
        let pong = P2PMessage.pong(pingInfo)
        guard let pongData = try? JSONEncoder().encode(pong) else { return }
        if pingInfo.isLocal {
            self.udp.sendMessage(
                message: .init(
                    data: pongData,
                    host: pingInfo.source.ipLoc,
                    port: pingInfo.source.portLoc
                )
            )
        } else {
            if
                let pubIp = pingInfo.source.ipPub,
                let pubPort = pingInfo.source.portPub
            {
                self.udp.sendMessage(message: .init(data: pongData, host: pubIp, port: pubPort))
            }
        }
    }
    @objc
    func pullPeersFromTracker() {
        guard
            let ip = LocalAddress.localIp
        else { return }
        let pull = P2PMessage.pullPeers(.init(ipLoc: ip, portLoc: Const.sendPort, peerId: Const.uuid))
        if let data = try? JSONEncoder().encode(pull) {
            self.udp.sendMessage(message: .init(data: data, host: Const.serverIp, port: Const.serverPort))
            self.udp.sendMessage(message: .init(data: data, host: Const.serverIp, port: Const.serverPort + 1))
        }
    }
}
