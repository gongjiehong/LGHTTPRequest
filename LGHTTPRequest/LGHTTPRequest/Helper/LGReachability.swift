//
//  LGReachability.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2017/7/6.
//  Copyright © 2017年 龚杰洪. All rights reserved.
//

import Foundation
import SystemConfiguration
import CoreTelephony


/// 当前连接的移动网络类型, iOS7.0以后为如下内容
/*
 public let CTRadioAccessTechnologyGPRS: String // 2G
 public let CTRadioAccessTechnologyEdge: String // 2G
 public let CTRadioAccessTechnologyWCDMA: String // 3G
 public let CTRadioAccessTechnologyHSDPA: String // 3.5G
 public let CTRadioAccessTechnologyHSUPA: String // 3.75G
 public let CTRadioAccessTechnologyCDMA1x: String // 3G
 public let CTRadioAccessTechnologyCDMAEVDORev0: String // 3G
 public let CTRadioAccessTechnologyCDMAEVDORevA: String // 3G
 public let CTRadioAccessTechnologyCDMAEVDORevB: String // 3G
 public let CTRadioAccessTechnologyeHRPD: String // 3G 也是CDMA的一个演进标准，使用极少
 public let CTRadioAccessTechnologyLTE: String // 4G
 */
public typealias LGMobileNetworkType = String

// MARK: -  移动网络类型重载
extension LGMobileNetworkType {
    
    /// 判断2G,3G,4G
    public var shortMobileNetworkType: String {
        switch self {
        case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge:
            return "2G"
        case CTRadioAccessTechnologyWCDMA,
             CTRadioAccessTechnologyHSDPA,
             CTRadioAccessTechnologyHSUPA,
             CTRadioAccessTechnologyCDMA1x,
             CTRadioAccessTechnologyCDMAEVDORev0,
             CTRadioAccessTechnologyCDMAEVDORevA,
             CTRadioAccessTechnologyCDMAEVDORevB,
             CTRadioAccessTechnologyeHRPD:
            return "3G"
        case CTRadioAccessTechnologyLTE:
            return "4G"
        default:
            return "Unknown"
        }
    }
    
    public var debugDescription: String {
        switch self {
        case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge:
            return self + "2G"
        case CTRadioAccessTechnologyWCDMA,
             CTRadioAccessTechnologyHSDPA,
             CTRadioAccessTechnologyHSUPA,
             CTRadioAccessTechnologyCDMA1x,
             CTRadioAccessTechnologyCDMAEVDORev0,
             CTRadioAccessTechnologyCDMAEVDORevA,
             CTRadioAccessTechnologyCDMAEVDORevB,
             CTRadioAccessTechnologyeHRPD:
            return self + "3G"
        case CTRadioAccessTechnologyLTE:
            return self + "4G"
        default:
            return self + "Unknown"
        }
    }
}


/// 定义未知移动网络类型
public let LGMobileNetworkTypeUnknown = "CTRadioAccessTechnologyUnknown"

// MARK: -  网络状态监控
/// 判断当前网络是否连通，以及获取当前网络类型
public class LGReachability {
    
    /// 网络连通状态定义
    ///
    /// - unknown: 位置
    /// - notReachable: 没有连接
    /// - reachable: 成功连接->连接类型
    public enum LGNetworkReachabilityStatus {
        case unknown
        case notReachable
        case reachable(LGConnectionType)
    }
    
    /// 网络连接类型定义
    ///
    /// - ethernetOrWiFi: 网卡连接或者WIFI连接
    /// - moblieNetwork: 移动蜂窝数据
    public enum LGConnectionType {
        case ethernetOrWiFi
        case moblieNetwork
    }
    
    /// 监听器闭包
    public typealias Listener = (LGNetworkReachabilityStatus) -> Void
    
    /// 网络是否连通
    public var isReachable: Bool {
        return isReachableOnWWAN || isReachableOnEthernetOrWiFi
    }
    
    /// 是否连通了移动网络
    public var isReachableOnWWAN: Bool {
        return networkReachabilityStatus == LGNetworkReachabilityStatus.reachable(.moblieNetwork)
    }
    
    /// 是否通过网卡或WIFI连通
    public var isReachableOnEthernetOrWiFi: Bool {
        return networkReachabilityStatus == .reachable(.ethernetOrWiFi)
    }
    
    /// 当前移动网络类型
    public var mobileNetworkType: LGMobileNetworkType = LGMobileNetworkTypeUnknown
    
    /// 当前网络连通状态
    public var networkReachabilityStatus: LGNetworkReachabilityStatus {
        guard let flags = self.flags else {
            return .unknown
        }
        return networkReachabilityStatusForFlags(flags)
    }
    
    /// 处理连通状态监听的队列，默认main
    public var listenerQueue: DispatchQueue = DispatchQueue.main
    
    /// 监听器闭包属性
    public var listener: Listener?
    
    /// 当前网络连接标记
    private var flags: SCNetworkReachabilityFlags? {
        var flags = SCNetworkReachabilityFlags()
        
        if SCNetworkReachabilityGetFlags(reachability, &flags) {
            return flags
        }
        
        return nil
    }

    /// 网络可达性连接器
    private let reachability: SCNetworkReachability
    
    /// 网络可达性标记
    private var previousFlags: SCNetworkReachabilityFlags
    
    /// 通过一个正常可达的host进行创建监听，但监SCNetworkReachability听只是保证本地连接连通，无法保证数据包真实送达服务器
    /// 如需验证真实可达性，这个库是个不错的选择https://github.com/dustturtle/RealReachability
    /// - Parameter host: 判断网络连接可达性的host，通常可以使用自己APP的服务域名或者直接用Apple
    public convenience init?(host: String) {
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, host) else {
            return nil
        }
        self.init(reachability: reachability)
    }

    /// 创建一个监控设备一般路由状态（0.0.0.0）的监听器实例，包含ipv4和ipv6
    public convenience init?() {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        
        guard let reachability = withUnsafePointer(to: &address, { pointer in
            return pointer.withMemoryRebound(to: sockaddr.self, capacity: MemoryLayout<sockaddr>.size) {
                return SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else {
            return nil
        }
        
        self.init(reachability: reachability)
    }
    
    private init(reachability: SCNetworkReachability) {
        self.reachability = reachability
        self.previousFlags = SCNetworkReachabilityFlags()
    }
    
    deinit {
        stopListening()
    }
    
    /// 开始监听
    ///
    /// - Returns: 是否成功进行监听
    @discardableResult
    public func startListening() -> Bool {
        var context = SCNetworkReachabilityContext(version: 0,
                                                   info: nil,
                                                   retain: nil,
                                                   release: nil,
                                                   copyDescription: nil)
        context.info = Unmanaged.passUnretained(self).toOpaque()
        
        let callbackEnabled = SCNetworkReachabilitySetCallback(
            reachability,
            { (_, flags, info) in
                let reachability = Unmanaged<LGReachability>.fromOpaque(info!).takeUnretainedValue()
                reachability.notifyListener(flags)
        },
            &context
        )
        
        let queueEnabled = SCNetworkReachabilitySetDispatchQueue(reachability, listenerQueue)
        
        listenerQueue.async {
            self.previousFlags = SCNetworkReachabilityFlags()
            self.notifyListener(self.flags ?? SCNetworkReachabilityFlags())
        }
        
        return callbackEnabled && queueEnabled
    }
    
    /// 停止监听
    public func stopListening() {
        SCNetworkReachabilitySetCallback(reachability, nil, nil)
        SCNetworkReachabilitySetDispatchQueue(reachability, nil)
    }
    
    /// 状态改变后进行
    ///
    /// - Parameter flags: 监听回调
    func notifyListener(_ flags: SCNetworkReachabilityFlags) {
        guard previousFlags != flags else { return }
        previousFlags = flags
        
        listener?(networkReachabilityStatusForFlags(flags))
    }
    
    /// 将SCNetworkReachabilityFlags状态处理为LGNetworkReachabilityStatus连通状态
    ///
    /// - Parameter flags: SCNetworkReachabilityFlags
    /// - Returns: LGNetworkReachabilityStatus
    func networkReachabilityStatusForFlags(_ flags: SCNetworkReachabilityFlags) -> LGNetworkReachabilityStatus {
        guard isNetworkReachable(with: flags) else { return .notReachable }
        
        var networkStatus: LGNetworkReachabilityStatus = .reachable(.ethernetOrWiFi)
        
        #if os(iOS)
        if flags.contains(.isWWAN) {
            networkStatus = .reachable(.moblieNetwork)
            getMobileNetworkType()
        }
        #endif
        return networkStatus
    }
    
    /// 获取移动网络类型并保存到self.mobileNetworkType
    func getMobileNetworkType() {
        let telephony = CTTelephonyNetworkInfo()
        if telephony.currentRadioAccessTechnology != nil{
            self.mobileNetworkType = telephony.currentRadioAccessTechnology!
        }
        else {
            self.mobileNetworkType = LGMobileNetworkTypeUnknown
        }
    }
    
    /// 直接根据SCNetworkReachabilityFlags判断网络是否连通
    ///
    /// - Parameter flags: SCNetworkReachabilityFlags
    /// - Returns: 连通true，没有false
    func isNetworkReachable(with flags: SCNetworkReachabilityFlags) -> Bool {
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        let transientConnection = flags.contains(.transientConnection)
        
        return isReachable && !needsConnection && transientConnection
    }
}

// MARK: -  重载 == 运算符，判断网络连通状态是否相等
extension LGReachability.LGNetworkReachabilityStatus: Equatable {}

public func == (lhs: LGReachability.LGNetworkReachabilityStatus, rhs: LGReachability.LGNetworkReachabilityStatus) -> Bool
{
    switch (lhs, rhs) {
    case (.unknown, .unknown):
        return true
    case (.notReachable, .notReachable):
        return true
    case let (.reachable(lhsConnectionType), .reachable(rhsConnectionType)):
        return lhsConnectionType == rhsConnectionType
    default:
        return false
    }
}
