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

extension String: LGURLConvertible {
    public func asURL() throws -> URL {
        guard let url = URL(string: self) else {
            throw LGError.invalidURL(url: self)
        }
        return url
    }
}

extension URL: LGURLConvertible {
    public func asURL() throws -> URL {
        return self
    }
}

extension URLComponents: LGURLConvertible {
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
