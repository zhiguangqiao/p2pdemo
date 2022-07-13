#!/usr/bin/env python3
#coding:utf-8
from ast import Str
import socket
import json
import time
from socketserver import BaseRequestHandler,ThreadingUDPServer
from threading import Lock, Thread
class Peer:
    def __init__(self, ip_pub, port_pub, message):
        self.ipPub = ip_pub
        self.portPub = port_pub
        self.activeTime = time.time()
        self.ipLoc = message[JsonKey.PEER][JsonKey.IPLOC]
        self.portLoc = message[JsonKey.PEER][JsonKey.PORTLOC]
        self.peerId = message[JsonKey.PEER][JsonKey.PEERID]
        self.UUID = message[JsonKey.PEER][JsonKey.UUID]

    def __eq__(self, other):
        return self.peerId == other.peerId

    def pubEqul(self, other):
        return self.ipPub == other.ipPub and self.portPub == other.portPub

class MessageType:
    PING = 'ping'
    PEERS = 'peers'
    PULL = 'pull'


class JsonKey:
    TYPE = 'type'
    PEERID = 'peerId'
    PEER = 'peer'
    PORTLOC = 'portLoc'
    IPLOC = 'ipLoc'
    PORTPUB = 'portPub'
    IPPUB = 'ipPub'
    PEERS = 'peers'
    PINGPONGINFO = 'pingPongInfo'
    TARGET = 'target'
    UUID = 'UUID'

def updatePeers(newPeer):
    lock.acquire()
    result = False
    try:
        index = peers.index(newPeer)
        oldPeer = peers[index]        
        if oldPeer.UUID == newPeer.UUID:
            if oldPeer.pubEqul(newPeer) == False:
                 oldPeer.portPub = 0
                 peers[index] = oldPeer
            result = True
        else:
            peers[index] = newPeer
    except:
        peers.append(newPeer)
    for peer in iter(peers):
        if time.time() - peer.activeTime > 1000:
            peers.remove(peer)
    lock.release()
    return result

def processMessage(socket ,message, client_ip, client_port, server_port):
    if message[JsonKey.TYPE] ==  MessageType.PULL:
        if updatePeers(Peer(client_ip, client_port, message)):
            sendMessage(
                socket,
                {
                    JsonKey.TYPE: MessageType.PEERS,
                    JsonKey.PEERS: list(map(lambda x: x.__dict__, peers))
                },
                client_ip,
                client_port
            )
    elif message[JsonKey.TYPE] ==  MessageType.PING:
        target = message[JsonKey.PINGPONGINFO][JsonKey.TARGET]
        sendMessage(socket, message, target[JsonKey.IPPUB], target[JsonKey.PORTPUB])

def sendMessage(socket ,message, client_ip, client_port):
    print('\nsend:\ncontent:', json.dumps(message),'\nclient_ip:', client_ip, '\nclient_port:', client_port)
    socket.sendto(json.dumps(message).encode('utf8') , (client_ip, client_port))

class Handler(BaseRequestHandler):
    def handle(self):
        client_ip, client_port = self.client_address
        server_address, server_port = self.server.server_address
        print('\n%s connected!'%client_ip)
        print('request:')
        print(self.request)
        data, socket = self.request
        if len(data)>0:
            processMessage(socket , json.loads(data.decode('utf-8')), client_ip, client_port, server_port)
        else:
            print('close')

SERVERPORT = 1777
SERVERPORT2 = 1778
BUF_SIZE=1024
peers = []

def createServer(port):
    HOST = '0.0.0.0'
    ADDR = (HOST,port)
    server = ThreadingUDPServer(ADDR,Handler)  #参数为监听地址和已建立连接的处理类
    print('server listening..')
    server.serve_forever()  #监听，建立好TCP连接后，为该连接创建新的socket和线程，并由处理类中的handle方法处理
    print(server)

if __name__ == '__main__':
    lock = Lock()
   
    th1 = Thread(target=createServer,args=[SERVERPORT])
    th1.start()

    th2 = Thread(target=createServer,args=[SERVERPORT2])
    th2.start()

    th1.join()
    th2.join()