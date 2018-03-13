//
//  LGHTTPResponse.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2018/3/7.
//  Copyright © 2018年 龚杰洪. All rights reserved.
//

import Foundation


public struct LGHTTPDefaultResponse {
    public let request: URLRequest?
    public let response: HTTPURLResponse?
    public let data: Data?
    public let error: Error?
    
    var _metrics: AnyObject?
    
    public init(request: URLRequest?,
                response: HTTPURLResponse?,
                data: Data?, error: Error?,
                metrics: AnyObject? = nil)
    {
        self.request = request
        self.response = response
        self.data = data
        self.error = error
        self._metrics = metrics
    }
}


public struct LGHTTPDataResponse<Value> {
    public let request: URLRequest?
    
    public let response: HTTPURLResponse?
    
    public let data: Data?
    
    public let result: LGResult<Value>
    
    var _metrics: AnyObject?
    
    public var value: Value? {
        return result.value
    }
    
    public var error: Error? {
        return result.error
    }
    
    public init(request: URLRequest?,
                response: HTTPURLResponse?,
                data: Data?,
                result: LGResult<Value>,
                metrics: AnyObject? = nil) {
        self.request = request
        self.response = response
        self.data = data
        self.result = result
        self._metrics = metrics
    }
}

extension LGHTTPDataResponse: CustomDebugStringConvertible, CustomStringConvertible {
    public var description: String {
        return result.description
    }
    
    public var debugDescription: String {
        var outputArray = [String]()
        outputArray.append(request == nil ? "request: nil" : "request: \(request!)")
        outputArray.append(response == nil ? "response: nil" : "response: \(request!)")
        outputArray.append(data == nil ? "data: nil" :
            (String(data: data!, encoding: String.Encoding.utf8) ?? "data: \(data?.count ?? 0) bytes"))
        outputArray.append("result: \(result.debugDescription)")
        return outputArray.joined(separator: "\n")
    }
}

extension LGHTTPDataResponse {
    public func map<T>(_ transform: (Value) -> T) -> LGHTTPDataResponse<T> {
        var response = LGHTTPDataResponse<T>(request: self.request,
                                             response: self.response,
                                             data: self.data,
                                             result: self.result.map(transform))
        response._metrics = _metrics
        
        return response
    }
    
    public func flatMap<T>(_ transform: (Value) throws -> T) -> LGHTTPDataResponse<T> {
        var response = LGHTTPDataResponse<T>(request: self.request,
                                             response: self.response,
                                             data: self.data,
                                             result: self.result.flatMap(transform))
        response._metrics = _metrics
        
        return response
    }
    
    public func mapError<E: Error>(_ transform: (Error) -> E) -> LGHTTPDataResponse {
        var response = LGHTTPDataResponse(request: self.request,
                                          response: self.response,
                                          data: self.data,
                                          result: self.result.mapError(transform))
        response._metrics = _metrics
        
        return response
    }
    
    public func flatMapError<E: Error>(_ transform: (Error) throws -> E) -> LGHTTPDataResponse {
        var response = LGHTTPDataResponse(request: self.request,
                                          response: self.response,
                                          data: self.data,
                                          result: self.result.flatMapError(transform))
        response._metrics = _metrics
        
        return response
    }
}


public struct LGHTTPDownloadDefaultResponse {
    public let request: URLRequest?
    
    public let response: HTTPURLResponse?
    
    public let temporaryURL: URL?
    
    public let destinationURL: URL?
    
    public let resumeData: Data?
    
    public let error: Error?
    
    var _metrics: AnyObject?
    
    public init(request: URLRequest?,
                response: HTTPURLResponse?,
                temporaryURL: URL?,
                destinationURL: URL?,
                resumeData: Data?,
                error: Error?,
                metrics: AnyObject? = nil)
    {
        self.request = request
        self.response = response
        self.temporaryURL = temporaryURL
        self.destinationURL = destinationURL
        self.resumeData = resumeData
        self.error = error
        self._metrics = metrics
    }
}

public struct LGHTTPDownloadResponse<Value> {
    
    public let request: URLRequest?
    
    public let response: HTTPURLResponse?
    
    public let temporaryURL: URL?
    
    public let destinationURL: URL?
    
    public let resumeData: Data?
    
    public let result: LGResult<Value>
    
    public var value: Value? { return result.value }
    
    public var error: Error? { return result.error }
    
    var _metrics: AnyObject?
    
    public init(request: URLRequest?,
                response: HTTPURLResponse?,
                temporaryURL: URL?,
                destinationURL: URL?,
                resumeData: Data?,
                result: LGResult<Value>,
                metrics: AnyObject? = nil)
    {
        self.request = request
        self.response = response
        self.temporaryURL = temporaryURL
        self.destinationURL = destinationURL
        self.resumeData = resumeData
        self.result = result
        self._metrics = metrics
    }
}

extension LGHTTPDownloadResponse: CustomDebugStringConvertible, CustomStringConvertible {
    public var description: String {
        return result.description
    }
    
    public var debugDescription: String {
        var outputArray = [String]()
        outputArray.append(request == nil ? "request: nil" : "request: \(request!)")
        outputArray.append(response == nil ? "response: nil" : "response: \(response!)")
        outputArray.append(resumeData == nil ? "data: nil" :"data: \(resumeData?.count ?? 0) bytes")
        outputArray.append("result: \(result.debugDescription)")
        outputArray.append(temporaryURL == nil ? "temporaryURL: nil" : "temporaryURL: \(temporaryURL!)")
        outputArray.append(destinationURL == nil ? "destinationURL: nil" : "destinationURL: \(destinationURL!)")
        return outputArray.joined(separator: "\n")
    }
}

extension LGHTTPDownloadResponse {
    public func map<T>(_ transform: (Value) -> T) -> LGHTTPDownloadResponse<T> {
        var response = LGHTTPDownloadResponse<T>(request: self.request,
                                                 response: self.response,
                                                 temporaryURL: self.temporaryURL,
                                                 destinationURL: self.destinationURL,
                                                 resumeData: self.resumeData,
                                                 result: self.result.map(transform))
        response._metrics = _metrics
        
        return response
    }
    
    public func flatMap<T>(_ transform: (Value) throws -> T) -> LGHTTPDownloadResponse<T> {
        let response = LGHTTPDownloadResponse<T>(request: self.request,
                                                 response: self.response,
                                                 temporaryURL: self.temporaryURL,
                                                 destinationURL: self.destinationURL,
                                                 resumeData: self.resumeData,
                                                 result: self.result.flatMap(transform))
        
        return response
    }
    
    public func mapError<E: Error>(_ transform: (Error) -> E) -> LGHTTPDownloadResponse {
        var response = LGHTTPDownloadResponse(request: self.request,
                                              response: self.response,
                                              temporaryURL: self.temporaryURL,
                                              destinationURL: self.destinationURL,
                                              resumeData: self.resumeData,
                                              result: self.result.mapError(transform))
        response._metrics = _metrics
        
        return response
    }
    
    public func flatMapError<E: Error>(_ transform: (Error) throws -> E) -> LGHTTPDownloadResponse {
        var response = LGHTTPDownloadResponse(request: request,
                                              response: self.response,
                                              temporaryURL: self.temporaryURL,
                                              destinationURL: self.destinationURL,
                                              resumeData: self.resumeData,
                                              result: self.result.flatMapError(transform))
        
        response._metrics = _metrics
        return response
    }
}


// MARK: - 统计信息协议

protocol LGHTTPResponseMetrics {
    var _metrics: AnyObject? { get set }
    mutating func add(_ metrics: AnyObject?)
}

extension LGHTTPResponseMetrics {
    mutating func add(_ metrics: AnyObject?) {
        #if !os(watchOS)
        guard #available(iOS 10.0, macOS 10.12, tvOS 10.0, *) else { return }
        guard let metrics = metrics as? URLSessionTaskMetrics else { return }
        
        _metrics = metrics
        #endif
    }
}

// MARK: - 统计信息获取

@available(iOS 10.0, macOS 10.12, tvOS 10.0, *)
extension LGHTTPDefaultResponse: LGHTTPResponseMetrics {
    #if !os(watchOS)
    public var metrics: URLSessionTaskMetrics? { return _metrics as? URLSessionTaskMetrics }
    #endif
}

@available(iOS 10.0, macOS 10.12, tvOS 10.0, *)
extension LGHTTPDataResponse: LGHTTPResponseMetrics {
    #if !os(watchOS)
    public var metrics: URLSessionTaskMetrics? { return _metrics as? URLSessionTaskMetrics }
    #endif
}

@available(iOS 10.0, macOS 10.12, tvOS 10.0, *)
extension LGHTTPDownloadDefaultResponse: LGHTTPResponseMetrics {
    #if !os(watchOS)
    public var metrics: URLSessionTaskMetrics? { return _metrics as? URLSessionTaskMetrics }
    #endif
}

@available(iOS 10.0, macOS 10.12, tvOS 10.0, *)
extension LGHTTPDownloadResponse: LGHTTPResponseMetrics {
    #if !os(watchOS)
    public var metrics: URLSessionTaskMetrics? { return _metrics as? URLSessionTaskMetrics }
#endif
}
