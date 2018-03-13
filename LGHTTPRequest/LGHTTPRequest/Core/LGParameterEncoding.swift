//
//  LGParameterEncoding.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2017/7/5.
//  Copyright © 2017年 龚杰洪. All rights reserved.
//

import Foundation

public typealias LGParameters = [String: Any]

public protocol LGParameterEncoding {
    func encode(_ urlRequest: LGURLRequestConvertible, with params: LGParameters?) throws -> URLRequest
}

public struct LGURLEncoding: LGParameterEncoding {
    
    public enum LGDestination {
        case methodDependent, queryString, httpBody
    }
    
    public static var `default`: LGURLEncoding {
        return LGURLEncoding()
    }
    
    public static var methodDependent: LGURLEncoding {
        return LGURLEncoding(destination: LGURLEncoding.LGDestination.methodDependent)
    }
    
    public static var queryString: LGURLEncoding {
        return LGURLEncoding(destination: LGURLEncoding.LGDestination.queryString)
    }
    
    public static var httpBody: LGURLEncoding {
        return LGURLEncoding(destination: LGURLEncoding.LGDestination.httpBody)
    }
    
    public let destination: LGDestination
    
    public init(destination: LGDestination = .methodDependent) {
        self.destination = destination
    }
    
    
    public func encode(_ urlRequest: LGURLRequestConvertible, with params: LGParameters?) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()
        
        guard let parameters = params  else {
            return urlRequest
        }
        
        if let httpMethod = LGHTTPMethod(rawValue: urlRequest.httpMethod ?? LGHTTPMethod.get.rawValue), encodesParametersInURL(with: httpMethod) {
            
            guard let url = urlRequest.url else {
                throw LGError.parameterEncodingFailed(reason: LGError.ParameterEncodingFailureReason.missingURL)
            }
            
            if var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false), !parameters.isEmpty {
                let percentEncodedQuery = (urlComponents.percentEncodedQuery.map { $0 + "&" } ?? "") + query(parameters)
                urlComponents.percentEncodedQuery = percentEncodedQuery
                urlRequest.url = urlComponents.url
            }
        }
        else {
            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                urlRequest.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            }
            // allowLossyConversion 在转换过程中是否允许必要的替换和删减
            urlRequest.httpBody = query(parameters).data(using: .utf8, allowLossyConversion: false)
        }
        
        return urlRequest
    }
    
    /*
     * 递归组合参数为keyLevel1[keyLevel2][keyLevel3]....格式
     */
    public func queryComponents(fromKey key: String, value: Any) -> [(String, String)] {
        var components: [(String, String)] = []
        
        if let dictionary = value as? [String: Any] {
            for (nestedKey, value) in dictionary {
                components += queryComponents(fromKey: "\(key)[\(nestedKey)]", value: value)
            }
        } else if let array = value as? [Any] {
            for value in array {
                components += queryComponents(fromKey: "\(key)[]", value: value)
            }
        } else if let value = value as? NSNumber {
            if value.lg_isBool {
                components.append((escape(key), escape((value.boolValue ? "1" : "0"))))
            } else {
                components.append((escape(key), escape("\(value)")))
            }
        } else if let bool = value as? Bool {
            components.append((escape(key), escape((bool ? "1" : "0"))))
        } else {
            components.append((escape(key), escape("\(value)")))
        }
        
        return components
    }

    // MARK: - 转码
    
    public func escape(_ string: String) -> String {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="
        
        var allowedCharacterSet = CharacterSet.urlQueryAllowed
        allowedCharacterSet.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        
        var escaped = ""
        
        if #available(iOS 8.3, *) {
            escaped = string.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) ?? string
        } else {
            // 解决ios8.2之前的bug
            let batchSize = 50
            var index = string.startIndex
            
            while index != string.endIndex {
                let startIndex = index
                let endIndex = string.index(index, offsetBy: batchSize, limitedBy: string.endIndex) ?? string.endIndex
                let range = startIndex..<endIndex
                
                let substring = string[range]
                
                escaped += substring.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) ?? String(substring)
                
                index = endIndex
            }
        }
        
        return escaped
    }
    
    /*
     * 判断是否需要URL编码
     */
    private func encodesParametersInURL(with method: LGHTTPMethod) -> Bool {
        switch destination {
        case .queryString:
            return true
        case .httpBody:
            return false
        default:
            break
        }
        
        switch method {
        case LGHTTPMethod.get, LGHTTPMethod.head, LGHTTPMethod.delete:
            return true
        default:
            return false
        }
    }
    
    private func query(_ parameters: LGParameters) -> String {
        var components: [(String, String)] = []
        
        for key in parameters.keys.sorted(by: <) {
            let value = parameters[key]!
            components += queryComponents(fromKey: key, value: value)
        }
        return components.map { "\($0)=\($1)" }.joined(separator: "&")
    }
}

public struct LGJSONEncoding: LGParameterEncoding {
    
    public static var `default`: LGJSONEncoding {
        return LGJSONEncoding()
    }
    
    public static var prettyPrinted: LGJSONEncoding {
        return LGJSONEncoding(options: .prettyPrinted)
    }
    
    public let options: JSONSerialization.WritingOptions

    public init(options: JSONSerialization.WritingOptions = []) {
        self.options = options
    }
    
    
    public func encode(_ urlRequest: LGURLRequestConvertible, with params: LGParameters?) throws -> URLRequest {
        var request = try urlRequest.asURLRequest()
        
        guard let parameters = params else {
            return request
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: parameters, options: self.options)
            
            // 设置content type
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            
            // 设置httpBody
            request.httpBody = jsonData
            
        }
        catch {
            let reason = LGError.ParameterEncodingFailureReason.jsonEncodingFailed(error: error)
            throw LGError.parameterEncodingFailed(reason: reason)
        }
        
        return request
    }
    
    public func encode(_ urlRequest: LGURLRequestConvertible, with jsonObject: Any? = nil) throws -> URLRequest {
        var request = try urlRequest.asURLRequest()
        
        guard jsonObject != nil else {
            return request
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonObject!, options: self.options)
            
            // 设置content type
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            
            // 设置httpBody
            request.httpBody = jsonData
            
        }
        catch {
            let reason = LGError.ParameterEncodingFailureReason.jsonEncodingFailed(error: error)
            throw LGError.parameterEncodingFailed(reason: reason)
        }
        
        return request
    }
}


public struct LGPropertyListEncoding: LGParameterEncoding {

    public static var `default`: LGPropertyListEncoding {
        return LGPropertyListEncoding()
    }
    
    public static var xml: LGPropertyListEncoding {
        return LGPropertyListEncoding(format: .xml)
    }
    
    public static var binary: LGPropertyListEncoding {
        return LGPropertyListEncoding(format: .binary)
    }
    
    public let format: PropertyListSerialization.PropertyListFormat
    
    public let options: PropertyListSerialization.WriteOptions
    
    // 默认XML
    public init(format: PropertyListSerialization.PropertyListFormat = .xml,
                options: PropertyListSerialization.WriteOptions = 0)
    {
        self.format = format
        self.options = options
    }
    
    public func encode(_ urlRequest: LGURLRequestConvertible, with params: LGParameters?) throws -> URLRequest {
        var request = try urlRequest.asURLRequest()
        
        guard let parameters = params else {
            return request
        }
        
        do {
            let plistData = try PropertyListSerialization.data(fromPropertyList: parameters, format: self.format, options: self.options)
            // 设置content type
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/x-plist", forHTTPHeaderField: "Content-Type")
            }
            
            // 设置httpBody
            request.httpBody = plistData
            
        } catch {
            let reason = LGError.ParameterEncodingFailureReason.propertyListEncodingFailed(error: error)
            throw LGError.parameterEncodingFailed(reason: reason)
        }
        return request
    }
}

public struct LGJsonXOREncoding: LGParameterEncoding {
    
    public static var `default`: LGPropertyListEncoding {
        return LGPropertyListEncoding()
    }
    
    public var encodePublicKey: String
    
    public var encodePrivateKey: String
    
    public init(publicKey: String, privateKey: String) {
        self.encodePublicKey = publicKey
        self.encodePrivateKey = privateKey
    }
    
    public init() {
        self.encodePublicKey = ""
        self.encodePrivateKey = ""
    }
    
    public func encode(_ urlRequest: LGURLRequestConvertible, with params: LGParameters?) throws -> URLRequest {
        if self.encodePublicKey.count == 0 || self.encodePrivateKey.count == 0 {
            let reason = LGError.ParameterEncodingFailureReason.encryptKeysInvalid
            throw LGError.parameterEncodingFailed(reason: reason)
        }
        
        var request = try urlRequest.asURLRequest()
        
        guard let parameters = params else {
            return request
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: parameters,
                                                      options: JSONSerialization.WritingOptions.prettyPrinted)
            
            guard let jsonString = String(data: jsonData, encoding: String.Encoding.utf8) else {
                let reason = LGError.ParameterEncodingFailureReason.stringEncodeFailed
                throw LGError.parameterEncodingFailed(reason: reason)
            }
            
            let urlEncodeString = jsonString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
            guard urlEncodeString != nil else {
                let reason = LGError.ParameterEncodingFailureReason.stringEncodeFailed
                throw LGError.parameterEncodingFailed(reason: reason)
            }
            
            let encodedData = urlEncodeString!.XOREncrypt(withKey: self.encodePrivateKey).base64EncodedData()

            // 设置httpBody
            request.httpBody = encodedData
            
        }
        catch {
            let reason = LGError.ParameterEncodingFailureReason.jsonEncodingFailed(error: error)
            throw LGError.parameterEncodingFailed(reason: reason)
        }
        
        return request
    }
}

fileprivate extension NSNumber {
    var lg_isBool: Bool {
        return CFBooleanGetTypeID() == CFGetTypeID(self)
    }
}
