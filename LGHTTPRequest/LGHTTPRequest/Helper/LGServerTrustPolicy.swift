//
//  LGServerTrustPolicy.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2017/12/25.
//  Copyright © 2017年 龚杰洪. All rights reserved.
//

import Foundation

/// 安全策略定义和处理，关于验证参见这里
/// http://www.cnblogs.com/oc-bowen/p/5896041.html
///
/// - performDefaultEvaluation: 使用默认策略进行评估，只有合法的证书才能通过评估
/// - performRevokedEvaluation: 对注销证书做的一种额外设置
/// - pinCertificates: 使用固定的证书来进行评估，有助于防止中间人攻击，可以指定是否验证证书链，是非常严格的验证
/// - pinPublicKeys: 使用固定的公钥来进行评估，有助于防止中间人攻击
/// - disableEvaluation: 关闭评估，任何服务都信任，不安全
/// - customEvaluation->Bool: 使用给定的block策略来进行评估，用于未枚举的评估策略

public enum LGServerTrustPolicy {
    case performDefaultEvaluation(validateHost: Bool)
    
    case performRevokedEvaluation(validateHost: Bool, revocationFlags: CFOptionFlags)
    
    case pinCertificates(certificates: [SecCertificate], validateCertificateChain: Bool, validateHost: Bool)
    
    case pinPublicKeys(publicKeys: [SecKey], validateCertificateChain: Bool, validateHost: Bool)
    
    case disableEvaluation
    
    case customEvaluation((_ serverTrust: SecTrust, _ host: String) -> Bool)
    
    
    /// 从指定bundle获取证书
    ///
    /// - Parameter bundle: 存储证书的bundle
    /// - Returns: 给定包中的所有证书， SecCertificate array
    public static func certificates(in bundle: Bundle = Bundle.main) -> [SecCertificate] {
        var certificates: [SecCertificate] = []
        
        /// 扫描bundle下所有证书的路径
        let paths = Set([".cer", ".CER", ".crt", ".CRT", ".der", ".DER"].map { fileExtension in
            bundle.paths(forResourcesOfType: fileExtension, inDirectory: nil)
            }.joined())
        
        for path in paths {
            if  let certificateData = try? Data(contentsOf: URL(fileURLWithPath: path)) as CFData,
                let certificate = SecCertificateCreateWithData(nil, certificateData)
            {
                certificates.append(certificate)
            }
        }
        
        return certificates
    }
    
    
    /// 获取证书的public key
    ///
    /// - Parameter certificate: 给定证书
    /// - Returns: SecKey?
    private static func publicKey(for certificate: SecCertificate) -> SecKey? {
        var publicKey: SecKey?
        
        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?
        let trustCreationStatus = SecTrustCreateWithCertificates(certificate, policy, &trust)
        
        if let trust = trust, trustCreationStatus == errSecSuccess {
            publicKey = SecTrustCopyPublicKey(trust)
        }
        
        return publicKey
    }

    /// 获取public key
    ///
    /// - Parameter bundle: 给定的bundle
    /// - Returns: 给定的bundle下的所有证书的public key
    public static func publicKeys(in bundle: Bundle = Bundle.main) -> [SecKey] {
        var publicKeys: [SecKey] = []
        
        for certificate in certificates(in: bundle) {
            if let publicKey = publicKey(for: certificate) {
                publicKeys.append(publicKey)
            }
        }
        
        return publicKeys
    }
    
    // MARK: - Evaluation
    
    /// 评估给定的的主机是否信任
    /// 分不同策略进行验证，但验证过程都一样，拢共分三步
    /// 1. SecPolicyCreateSSL 创建策略，是否验证host
    /// 2. SecTrustSetPolicies 为待验证的对象设置策略
    /// 3. trustIsValid 进行验证
    ///
    /// - Parameters:
    ///   - serverTrust: 服务器的信任评估 SecTrust
    ///   - host: 主机host
    /// - Returns: 是否验证通过 Bool
    public func evaluate(_ serverTrust: SecTrust, forHost host: String) -> Bool {
        var serverTrustIsValid = false
        
        switch self {
        case let .performDefaultEvaluation(validateHost):
            let policy = SecPolicyCreateSSL(true, validateHost ? host as CFString : nil)
            SecTrustSetPolicies(serverTrust, policy)
            
            serverTrustIsValid = trustIsValid(serverTrust)
        case let .performRevokedEvaluation(validateHost, revocationFlags):
            let defaultPolicy = SecPolicyCreateSSL(true, validateHost ? host as CFString : nil)
            let revokedPolicy = SecPolicyCreateRevocation(revocationFlags)
            SecTrustSetPolicies(serverTrust, [defaultPolicy, revokedPolicy] as CFTypeRef)
            
            serverTrustIsValid = trustIsValid(serverTrust)
        case let .pinCertificates(pinnedCertificates, validateCertificateChain, validateHost):
            if validateCertificateChain {
                let policy = SecPolicyCreateSSL(true, validateHost ? host as CFString : nil)
                SecTrustSetPolicies(serverTrust, policy)
                
                SecTrustSetAnchorCertificates(serverTrust, pinnedCertificates as CFArray)
                SecTrustSetAnchorCertificatesOnly(serverTrust, true)
                
                serverTrustIsValid = trustIsValid(serverTrust)
            } else {
                let serverCertificatesDataArray = certificateData(for: serverTrust)
                let pinnedCertificatesDataArray = certificateData(for: pinnedCertificates)
                
                outerLoop: for serverCertificateData in serverCertificatesDataArray {
                    for pinnedCertificateData in pinnedCertificatesDataArray {
                        if serverCertificateData == pinnedCertificateData {
                            serverTrustIsValid = true
                            break outerLoop
                        }
                    }
                }
            }
        case let .pinPublicKeys(pinnedPublicKeys, validateCertificateChain, validateHost):
            var certificateChainEvaluationPassed = true
            
            if validateCertificateChain {
                let policy = SecPolicyCreateSSL(true, validateHost ? host as CFString : nil)
                SecTrustSetPolicies(serverTrust, policy)
                
                certificateChainEvaluationPassed = trustIsValid(serverTrust)
            }
            
            if certificateChainEvaluationPassed {
                outerLoop: for serverPublicKey in LGServerTrustPolicy.publicKeys(for: serverTrust) as [AnyObject] {
                    for pinnedPublicKey in pinnedPublicKeys as [AnyObject] {
                        if serverPublicKey.isEqual(pinnedPublicKey) {
                            serverTrustIsValid = true
                            break outerLoop
                        }
                    }
                }
            }
        case .disableEvaluation:
            serverTrustIsValid = true
        case let .customEvaluation(closure):
            serverTrustIsValid = closure(serverTrust, host)
        }
        
        return serverTrustIsValid
    }
    
    // MARK: - Private - 信息验证
    
    private func trustIsValid(_ trust: SecTrust) -> Bool {
        var isValid = false
        
        var result = SecTrustResultType.invalid
        let status = SecTrustEvaluate(trust, &result)
        
        if status == errSecSuccess {
            let unspecified = SecTrustResultType.unspecified
            let proceed = SecTrustResultType.proceed
            
            
            isValid = result == unspecified || result == proceed
        }
        
        return isValid
    }
    
    // MARK: - Private - 证书数据
    
    private func certificateData(for trust: SecTrust) -> [Data] {
        var certificates: [SecCertificate] = []
        
        for index in 0..<SecTrustGetCertificateCount(trust) {
            if let certificate = SecTrustGetCertificateAtIndex(trust, index) {
                certificates.append(certificate)
            }
        }
        
        return certificateData(for: certificates)
    }
    
    private func certificateData(for certificates: [SecCertificate]) -> [Data] {
        return certificates.map { SecCertificateCopyData($0) as Data }
    }
    
    // MARK: - Private - 提取公钥
    
    private static func publicKeys(for trust: SecTrust) -> [SecKey] {
        var publicKeys: [SecKey] = []
        
        for index in 0..<SecTrustGetCertificateCount(trust) {
            if
                let certificate = SecTrustGetCertificateAtIndex(trust, index),
                let publicKey = publicKey(for: certificate)
            {
                publicKeys.append(publicKey)
            }
        }
        
        return publicKeys
    }
}


/// 安全策略管理器
open class LGServerTrustPolicyManager {
    
    public let policies: [String: LGServerTrustPolicy]
    

    public init(policies: [String: LGServerTrustPolicy]) {
        self.policies = policies
    }

    open func serverTrustPolicy(forHost host: String) -> LGServerTrustPolicy? {
        return policies[host]
    }
    
    public subscript(host: String) -> LGServerTrustPolicy? {
        return self.policies[host]
    }
}



// MARK: - 将安全策略管理器绑定到 URLSession
public extension URLSession {
    private struct AssociatedKeys {
        static var managerKey = "URLSession.ServerTrustPolicyManager"
    }
    
    var serverTrustPolicyManager: LGServerTrustPolicyManager? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.managerKey) as? LGServerTrustPolicyManager
        }
        set (manager) {
            objc_setAssociatedObject(self, &AssociatedKeys.managerKey, manager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

