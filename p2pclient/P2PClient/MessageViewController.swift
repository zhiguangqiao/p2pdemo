//
//  MessageViewController.swift
//  P2PClient
//
//  Created by goodluck on 2022/7/4.
//

import UIKit
import RxSwift

class MessageViewController: UIViewController {
    let bag = DisposeBag()
    let tableView = UITableView(frame: .zero, style: .plain)
    var messages: [(isMe: Bool, content: Int)] = []
    {
        didSet{
            tableView.reloadData()
        }
    }
    let peer: Peer
    let udp: UDPAsyncSocket
    init(peer: Peer, udp: UDPAsyncSocket) {
        self.peer = peer
        self.udp = udp
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubviews()
        udp.dataReceivedRelay.compactMap{ $0 }.subscribe(onNext: { data in
            guard
                let p2pMessage = try? JSONDecoder().decode(P2PMessage.self, from: data)
            else {
                return
            }
            switch p2pMessage {
            case .content(let message):
                self.messages.append((false, Int(message) ?? 0))
            case .pullPeers(_):
                break
            case .peers(_):
                break
            case .ping(_):
                break
            case .pong(_):
                break
            }
        }).disposed(by: bag)

    }
    func setupSubviews()  {
        self.title = "Message List"
        let sendButton = UIButton(type: .roundedRect)
        sendButton.setTitle("Send Random Number", for: .normal)
        sendButton.addTarget(self, action: #selector(sendNumber), for: .touchUpInside)
        self.navigationItem.rightBarButtonItem = .init(customView: sendButton)
        view.addSubview(tableView)
        tableView.rowHeight = 50
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Const.cellDequeueId)
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        tableView.delegate = self
        tableView.dataSource = self
    }
    @objc
    func sendNumber() {
        let numberP = arc4random()
        if
            let data = try? JSONEncoder().encode(P2PMessage.content(numberP.description)),
            let ip = peer.liveIp,
            let port = peer.livePort
        {
            udp.sendMessage(message: .init(data: data, host: ip, port: port))
            messages.append((true, Int(numberP)))
        }
    }
}

extension MessageViewController : UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Const.cellDequeueId, for: indexPath)
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.font = .systemFont(ofSize: 12)
        let meessage = messages[indexPath.row]
        cell.textLabel?.text = "\(meessage.isMe ? "send" : "recive"):\n \(meessage.content)"
        cell.textLabel?.textAlignment = meessage.isMe ? .left : .right
        return cell
    }
}
