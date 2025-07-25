//
//  File.swift
//  
//
//  Created by lmmmowi on 2024/5/21.
//

import Foundation
import Combine
import GroupActivities

@available(visionOS 26, *)
@available(iOS, unavailable)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
@available(macOS, unavailable)
final public class GroupStateObserverMock : ObservableObject {

    @Published final public private(set) var isEligibleForGroupSession: Bool
    
    private let groupStateObserver = GroupStateObserver()
    private var cancellable: AnyCancellable?
    
    public init() {
        if let _ = SharePlayMockManager.useMock() {
            self.isEligibleForGroupSession = true
        }
        else {
            self.isEligibleForGroupSession = groupStateObserver.isEligibleForGroupSession
            self.cancellable = groupStateObserver.$isEligibleForGroupSession
                .sink { [weak self] value in
                    self?.isEligibleForGroupSession = value
                }
            
            SharePlayMockManager.getInstance().register(self)
        }
    }
    
    func setMock() {
        self.isEligibleForGroupSession = true
        self.cancellable = nil
    }
}

@available(visionOS 26, *)
@available(iOS, unavailable)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
@available(macOS, unavailable)
extension SharePlayMockManager {
    
    func register(_ observer: GroupStateObserverMock) {
        groupStateObservers.append(observer)
    }
}
