//
//  LGHTTPRequestCommon.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2017/7/7.
//  Copyright © 2017年 龚杰洪. All rights reserved.
//

import Foundation

public enum LGHTTPMethod: String {
    case get     = "GET"
    case post    = "POST"
    case put     = "PUT"
    case delete  = "DELETE"
    case head    = "HEAD"
    case options = "OPTIONS"
    case trace   = "TRACE"
}

// MARK: - URL安全转换

public protocol LGURLConvertible {
    func asURL() throws -> URL
}

// MARK: - 根据URL获取文件名和缓存key

public protocol LGURLSource: LGURLConvertible {
    func getFileName() throws -> String
    func getCacheKey() throws -> String
}


extension String: LGURLSource {
    public func getFileName() throws -> String {
        let url = try self.asURL()
        let absoluteString = url.absoluteString
        if let cacheKey = absoluteString.md5Hash() {
            return cacheKey + url.pathExtension
        } else {
            throw LGError.invalidStringEncoding
        }
    }
    
    public func getCacheKey() throws -> String {
        let url = try self.asURL()
        let absoluteString = url.absoluteString
        if let cacheKey = absoluteString.md5Hash() {
            return cacheKey
        } else {
            throw LGError.invalidStringEncoding
        }
    }
    
    public func asURL() throws -> URL {
        guard let url = URL(string: self) else {
            throw LGError.invalidURL(url: self)
        }
        return url
    }
}

extension URL: LGURLSource {
    public func getFileName() throws -> String {
        if let cacheKey = absoluteString.md5Hash() {
            return cacheKey + self.pathExtension
        } else {
            throw LGError.invalidStringEncoding
        }
    }
    
    public func getCacheKey() throws -> String {
        if let cacheKey = absoluteString.md5Hash() {
            return cacheKey
        } else {
            throw LGError.invalidStringEncoding
        }
    }
    
    public func asURL() throws -> URL {
        return self
    }
}

extension URLComponents: LGURLSource {
    public func getFileName() throws -> String {
        let url = try self.asURL()
        let absoluteString = url.absoluteString
        if let cacheKey = absoluteString.md5Hash() {
            return cacheKey + url.pathExtension
        } else {
            throw LGError.invalidStringEncoding
        }
    }
    
    public func getCacheKey() throws -> String {
        let url = try self.asURL()
        let absoluteString = url.absoluteString
        if let cacheKey = absoluteString.md5Hash() {
            return cacheKey
        } else {
            throw LGError.invalidStringEncoding
        }
    }
    
    public func asURL() throws -> URL {
        guard let url = self.url else {
            throw LGError.invalidURL(url: self)
        }
        return url
    }
}

// MARK: - URLRequest安全转换

public protocol LGURLRequestConvertible {
    func asURLRequest() throws -> URLRequest
}

extension LGURLRequestConvertible {
    public var urlRequest: URLRequest? {
        return try? asURLRequest()
    }
}

extension URLRequest: LGURLRequestConvertible {
    public func asURLRequest() throws -> URLRequest {
        return self
    }
}

extension URLRequest {

    public init(url: LGURLConvertible, method: LGHTTPMethod, headers: LGHTTPHeaders? = nil) throws {
        let url = try url.asURL()
        
        self.init(url: url)
        
        self.httpMethod = method.rawValue
        
        if let headers = headers {
            for (headerField, headerValue) in headers {
                self.setValue(headerValue, forHTTPHeaderField: headerField)
            }
        }
    }
    
    func adapt(using adapter: LGRequestAdapter?) throws -> URLRequest {
        guard let adapter = adapter else { return self }
        return try adapter.adapt(self)
    }
}


