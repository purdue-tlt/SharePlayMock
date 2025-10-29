//
//  File.swift
//  
//
//  Created by lmmmowi on 2024/5/22.
//

import Foundation
import Starscream

@available(visionOS 26, *)
@available(iOS, unavailable)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
@available(macOS, unavailable)
class WebSocketConnection: WebSocketDelegate {
    
    private var socket: WebSocket
    private var connected: Bool = false
    
    init(_ url: String) {
        var request = URLRequest(url: URL(string: url)!)
        request.timeoutInterval = 5
        self.socket = WebSocket(request: request)
        socket.delegate = self
    }
    
    func connect() {
        socket.connect()
    }
    
    func waitReady() async {
        while !connected {
            do {
                try await Task.sleep(nanoseconds: 1_00_000_000)
            } catch {
                logger.error("\(error)")
            }
        }
    }
    
    public func didReceive(event: Starscream.WebSocketEvent, client: any Starscream.WebSocketClient) {
        switch event {
        case .connected:
            connected = true
            logger.info("websocket connected")
            break
        case .text(let string):
            if let notification = WebSocketMessageCodec.decode(string) {
                if let mock = SharePlayMockManager.useMock() {
                    mock.onReceiveNotification(notification)
                }
            }
            break
        default:
            logger.debug("did receive event: \(event)")
            break
        }
    }
    
    func send(_ command: Command) {
        let text = WebSocketMessageCodec.encode(command)
        socket.write(string: text)
    }
}


extension Starscream.WebSocketEvent: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .connected(_):
            "connected"
        case .disconnected(_, _):
            "disconnected"
        case .text(_):
            "text"
        case .binary(_):
            "binary"
        case .pong(_):
            "pong"
        case .ping(_):
            "ping"
        case .error(_):
            "error"
        case .viabilityChanged(_):
            "viabilityChanged"
        case .reconnectSuggested(_):
            "reconnectSuggested"
        case .cancelled:
            "cancelled"
        case .peerClosed:
            "peerClosed"
        }
    }
}

@available(visionOS 26, *)
@available(iOS, unavailable)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
@available(macOS, unavailable)
extension SharePlayMockManager {
    func onReceiveNotification(_ notification: WebSocketMessage) {
        switch notification.type {
        case "connected":
            self.localParticipantId = UUID(uuidString: notification.participantId!)
            break
        case "session_started":
            let identifier = notification.identifier!
            if self.groupActivityTypes.keys.contains(identifier) {
                let type = self.groupActivityTypes[identifier]! as any GroupActivityMock.Type
                let data = notification.activityData!
                if let activity = ActivityCodec.decode(data, type: type) {
                    register(activity)
                
                    let id = UUID(uuidString: notification.sessionId!)!
					let initiatingParticipantId = UUID(uuidString: notification.initiatingParticipantId!)!
					let isLocallyInitiated = localParticipantId == initiatingParticipantId
                    activity.onSessionDetected(id, isLocallyInitiated)
                }
            }
            break
        case "session_joined":
            handleNotification(notification) { activity in
                let id = UUID(uuidString: notification.sessionId!)!
                activity.onJoinSession(id)
            }
            break
        case "session_left":
            handleNotification(notification) { activity in
                let id = UUID(uuidString: notification.sessionId!)!
                activity.onLeaveSession(id)
            }
            break
        case "session_ended":
            handleNotification(notification) { activity in
                let id = UUID(uuidString: notification.sessionId!)!
                activity.onEndSession(id)
            }
            break
        case "session_active_participants_changed":
            handleNotification(notification) { activity in
                let id = UUID(uuidString: notification.sessionId!)!
                let participantIds = notification.participantId!.split(separator: ",").map { String($0)}
                activity.onParticipantsChanged(id, participantIds: participantIds)
            }
            break
        case "send_message":
            handleNotification(notification) { activity in
                let id = UUID(uuidString: notification.sessionId!)!
                let source = notification.source!
                let messageTypeName = notification.messageTypeName!
                let messageValue = notification.messageValue!
                if source == localParticipantId!.uuidString {
                    return
                }
                activity.onMessage(id, identifier: notification.identifier!, source: source, messageTypeName: messageTypeName, messageValue: messageValue)
            }
            break
        default:
            logger.info("Received notification: \(String(describing: notification))")
            break
        }
    }
    
    private func handleNotification(_ notification: WebSocketMessage, handler: (_ activity: any GroupActivityMock) -> ())  {
        let identifier = notification.identifier!
        if groupActivities.keys.contains(identifier) {
            let activity = groupActivities[identifier]!
            handler(activity)
        }
    }
}

struct WebSocketMessageCodec {
    static func encode(_ command: Command) -> String {
        let encoder = JSONEncoder()

        do {
            let jsonData = try encoder.encode(command)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        } catch {
            logger.error("Failed to encode JSON: \(error.localizedDescription)")
        }
        return ""
    }
    
    static func decode(_ jsonString: String) -> WebSocketMessage? {
        if let jsonData = jsonString.data(using: .utf8) {
            let decoder = JSONDecoder()
            
            do {
                return try decoder.decode(WebSocketMessage.self, from: jsonData)
            } catch {
                logger.error("Failed to decode JSON: \(error.localizedDescription)")
            }
        } else {
            logger.error("Failed to convert JSON string to Data.")
        }
        return nil
    }
}

struct Command: Codable {
    var action: String
    var identifier: String?
    var activityData: String?
	var initiatingParticipantId: String?
    var sessionId: String?
    var source: String?
    var messageTypeName: String?
    var messageValue: String?
    var participantIds: [String]?
    
	static func activate(identifier: String, activityData: String, initiatingParticipantId: String) -> Command {
		return Command(action: "activate", identifier: identifier, activityData: activityData, initiatingParticipantId: initiatingParticipantId)
    }
    
    static func querySession(identifier: String, sessionId: String?) -> Command {
        return Command(action: "query_session", identifier: identifier, sessionId: sessionId)
    }
    
    static func joinSession(identifier: String, sessionId: String) -> Command {
        return Command(action: "join_session", identifier: identifier, sessionId: sessionId)
    }
    
    static func leaveSession(identifier: String, sessionId: String) -> Command {
        return Command(action: "leave_session", identifier: identifier, sessionId: sessionId)
    }
    
    static func endSession(identifier: String, sessionId: String) -> Command {
        return Command(action: "end_session", identifier: identifier, sessionId: sessionId)
    }
    
    static func sendMessage(identifier: String, sessionId: String, source: String, messageTypeName: String, messageValue: String, participantIds: [String]?) -> Command {
        return Command(action: "send_message", identifier: identifier, sessionId: sessionId, source: source,
                       messageTypeName: messageTypeName, messageValue: messageValue, participantIds: participantIds)
    }
}

struct WebSocketMessage: Codable {
    var type: String
    var identifier: String?
    var activityData: String?
	var initiatingParticipantId: String?
    var sessionId: String?
    var participantId: String?
    var source: String?
    var messageTypeName: String?
    var messageValue: String?
}
