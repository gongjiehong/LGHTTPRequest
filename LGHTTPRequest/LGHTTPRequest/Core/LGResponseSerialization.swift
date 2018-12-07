//
//  LGResponseSerialization.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2018/3/7.
//  Copyright © 2018年 龚杰洪. All rights reserved.
//

import Foundation

extension LGDataRequest {
    @discardableResult
    public func response(queue: DispatchQueue? = nil,
                         completionHandler: @escaping (LGHTTPDefaultResponse) -> Void) -> Self 
    {
        delegate.queue.addOperation {
            (queue ?? DispatchQueue.main).async {
                var dataResponse = LGHTTPDefaultResponse(request: self.request,
                                                         response: self.response,
                                                         data: self.delegate.receivedData,
                                                         error: self.delegate.error)
                dataResponse.add(self.delegate.metrics)
                
                completionHandler(dataResponse)
            }
        }
        
        return self
    }
    
    @discardableResult
    public func response<T: LGHTTPDataResponseSerializerProtocol>(
        queue: DispatchQueue? = nil,
        responseSerializer: T,
        completionHandler: @escaping (LGHTTPDataResponse<T.SerializedObject>) -> Void)
        -> Self
    {
        delegate.queue.addOperation {
            let result = responseSerializer.serializeResponse(self.request,
                                                              self.response,
                                                              self.delegate.receivedData,
                                                              self.delegate.error)
            
            var dataResponse = LGHTTPDataResponse<T.SerializedObject>(request: self.request,
                                                                      response: self.response,
                                                                      data: self.delegate.receivedData,
                                                                      result: result)
            dataResponse.add(self.delegate.metrics)
            
            (queue ?? DispatchQueue.main).async { completionHandler(dataResponse) }
        }
        
        return self
    }
}

extension LGDownloadRequest {
    @discardableResult
    public func response( queue: DispatchQueue? = nil,
                          completionHandler: @escaping (LGHTTPDownloadDefaultResponse) -> Void) -> Self
    {
        delegate.queue.addOperation {
            (queue ?? DispatchQueue.main).async {
                var response = LGHTTPDownloadDefaultResponse(request: self.request,
                                                             response: self.response,
                                                             temporaryURL: self.downloadDelegate.temporaryURL,
                                                             destinationURL: self.downloadDelegate.destinationURL,
                                                             resumeData: self.downloadDelegate.resumeData,
                                                             error: self.downloadDelegate.error)
                response.add(self.delegate.metrics)
                
                completionHandler(response)
            }
        }
        
        return self
    }
    
    @discardableResult
    public func response<T: LGHTTPDownloadResponseSerializerProtocol>(
        queue: DispatchQueue? = nil,
        responseSerializer: T,
        completionHandler: @escaping (LGHTTPDownloadResponse<T.SerializedObject>) -> Void)-> Self
    {
        delegate.queue.addOperation {
            let result = responseSerializer.serializeResponse(self.request,
                                                              self.response,
                                                              self.downloadDelegate.destinationURL,
                                                              self.downloadDelegate.error)
            
            var response = LGHTTPDownloadResponse<T.SerializedObject>(
                request: self.request,
                response: self.response,
                temporaryURL: self.downloadDelegate.temporaryURL,
                destinationURL: self.downloadDelegate.destinationURL,
                resumeData: self.downloadDelegate.resumeData,
                result: result
            )
            
            response.add(self.delegate.metrics)
            
            (queue ?? DispatchQueue.main).async { completionHandler(response) }
        }
        
        return self
    }
}


/// HTTPCode 204 和 205 HTTPBody为空
/// 相关介绍: https://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
fileprivate let emptyHTTPBodyStatusCodes: Set<Int> = [204, 205]

extension LGHTTPRequest {
    
    /// 将HTTP返回的Data直接处理成LGResult并返回
    ///
    /// - Parameters:
    ///   - response: 服务器返回的HTTPURLResponse信息
    ///   - data: 服务器返回的Data
    ///   - error: 如果不为空，说明请求出错了
    /// - Returns: LGResult
    public static func serializeResponseData(response: HTTPURLResponse?, data: Data?, error: Error?) -> LGResult<Data> {
        if let error = error {
            return LGResult.failure(error)
        }
        
        /// 如果HTTPCode为204或205，直接返回空数据，特殊处理
        if let response = response, emptyHTTPBodyStatusCodes.contains(response.statusCode) {
            return LGResult.success(Data())
        }
        
        /// 数据为空直接返回错误
        guard let validData = data else {
            return LGResult.failure(LGError.responseSerializationFailed(reason: .inputDataNil))
        }
        
        return LGResult.success(validData)
    }
}

extension LGDataRequest {
    
    /// 创建响应序列化工具
    ///
    /// - Returns: LGHTTPDataResponseSerializer
    public static func dataResponseSerializer() -> LGHTTPDataResponseSerializer<Data> {
        return LGHTTPDataResponseSerializer { _, response, data, error in
            return LGHTTPRequest.serializeResponseData(response: response, data: data, error: error)
        }
    }
    
    
    /// 添加返回结果序列化工具，以便请求完成后进行处理
    ///
    /// - Parameters:
    ///   - queue: 处理结果的队列
    ///   - completionHandler: 返回数据闭包
    /// - Returns: 当前请求
    @discardableResult
    public func responseData(queue: DispatchQueue? = nil,
                             completionHandler: @escaping (LGHTTPDataResponse<Data>) -> Void) -> Self
    {
        return response(queue: queue,
                        responseSerializer: LGDataRequest.dataResponseSerializer(),
                        completionHandler: completionHandler)
    }
}


extension LGDownloadRequest {
    
    /// 创建响应序列化工具
    ///
    /// - Returns: LGHTTPDownloadResponseSerializer
    public static func dataResponseSerializer() -> LGHTTPDownloadResponseSerializer<Data> {
        return LGHTTPDownloadResponseSerializer { _, response, fileURL, error in
            if let error = error {
                return LGResult.failure(error)
            }
            
            guard let fileURL = fileURL else {
                return .failure(LGError.responseSerializationFailed(reason: .inputFileNil))
            }
            
            do {
                let data = try Data(contentsOf: fileURL)
                return LGHTTPRequest.serializeResponseData(response: response, data: data, error: error)
            } catch {
                return LGResult.failure(LGError.responseSerializationFailed(reason: .inputFileReadFailed(at: fileURL)))
            }
        }
    }
    
    
    /// 添加返回结果序列化工具，以便请求完成后进行处理
    ///
    /// - Parameters:
    ///   - queue: 处理结果的队列
    ///   - completionHandler: 返回数据闭包
    /// - Returns: 当前请求
    @discardableResult
    public func responseData(queue: DispatchQueue? = nil,
                             completionHandler: @escaping (LGHTTPDownloadResponse<Data>) -> Void) -> Self
    {
        return response(queue: queue,
                        responseSerializer: LGDownloadRequest.dataResponseSerializer(),
                        completionHandler: completionHandler)
    }
}


// MARK: -  将结果序列化为String

extension LGHTTPRequest {
    /// 将返回结果根据字符编码序列化为String
    ///
    /// - Parameters:
    ///   - encoding: 字符编码
    ///   - response: 原始HTTPURLResponse
    ///   - data: 返回的原始数据
    ///   - error: 如不为空，则请求有错误
    /// - Returns: serializeResponseString
    public static func serializeResponseString(encoding: String.Encoding?,
                                               response: HTTPURLResponse?,
                                               data: Data?,
                                               error: Error?) -> LGResult<String>
    {
        if let error = error {
            return LGResult.failure(error)
        }
        
        if let response = response, emptyHTTPBodyStatusCodes.contains(response.statusCode) {
            return LGResult.success("")
        }
        
        guard let validData = data else {
            return LGResult.failure(LGError.responseSerializationFailed(reason: .inputDataNil))
        }
        
        var convertedEncoding = encoding
        
        if let encodingName = response?.textEncodingName as CFString?, convertedEncoding == nil {
            let cfEncoding = CFStringConvertIANACharSetNameToEncoding(encodingName)
            let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
            convertedEncoding = String.Encoding(rawValue: nsEncoding)
        }
        
        let actualEncoding = convertedEncoding ?? .utf8
        
        if let string = String(data: validData, encoding: actualEncoding) {
            return LGResult.success(string)
        } else {
            let reason = LGError.ResponseSerializationFailureReason.stringSerializationFailed(encoding: actualEncoding)
            return LGResult.failure(LGError.responseSerializationFailed(reason: reason))
        }
    }
}

extension LGDataRequest {
    /// 返回将返回结果序列化为字符串的序列化工具
    ///
    /// - Parameter encoding: 字符编码
    /// - Returns: LGHTTPDataResponseSerializer
    public static func stringResponseSerializer(encoding: String.Encoding? = nil)
        -> LGHTTPDataResponseSerializer<String>
    {
        return LGHTTPDataResponseSerializer { _, response, data, error in
            return LGHTTPRequest.serializeResponseString(encoding: encoding,
                                                         response: response,
                                                         data: data,
                                                         error: error)
        }
    }
    
    /// 添加返回结果序列化工具，以便请求完成后进行处理
    ///
    /// - Parameters:
    ///   - queue: 处理结果和返回数据的队列
    ///   - encoding: 字符编码
    ///   - completionHandler: 处理完成后返回数据的闭包
    /// - Returns: 当前请求
    @discardableResult
    public func responseString(queue: DispatchQueue? = nil,
                               encoding: String.Encoding? = nil,
                               completionHandler: @escaping (LGHTTPDataResponse<String>) -> Void) -> Self
    {
        return response(queue: queue,
                        responseSerializer: LGDataRequest.stringResponseSerializer(encoding: encoding),
                        completionHandler: completionHandler)
    }
}

extension LGDownloadRequest {
    /// 返回将返回结果序列化为字符串的序列化工具
    ///
    /// - Parameter encoding: 字符编码
    /// - Returns: LGHTTPDownloadResponseSerializer
    public static func stringResponseSerializer(encoding: String.Encoding? = nil)
        -> LGHTTPDownloadResponseSerializer<String>
    {
        return LGHTTPDownloadResponseSerializer { _, response, fileURL, error in
            if let error = error {
                return LGResult.failure(error)
            }
            
            guard let fileURL = fileURL else {
                return LGResult.failure(LGError.responseSerializationFailed(reason: .inputFileNil))
            }
            
            do {
                let data = try Data(contentsOf: fileURL)
                return LGHTTPRequest.serializeResponseString(encoding: encoding,
                                                             response: response,
                                                             data: data,
                                                             error: error)
            } catch {
                return LGResult.failure(LGError.responseSerializationFailed(reason: .inputFileReadFailed(at: fileURL)))
            }
        }
    }
    
    
    /// 添加返回结果序列化工具，以便请求完成后进行处理
    ///
    /// - Parameters:
    ///   - queue: 处理结果和返回数据的队列，默认为main
    ///   - encoding: 字符编码
    ///   - completionHandler: 处理完成后返回数据的闭包
    /// - Returns: 当前请求
    @discardableResult
    public func responseString(queue: DispatchQueue? = nil,
                               encoding: String.Encoding? = nil,
                               completionHandler: @escaping (LGHTTPDownloadResponse<String>) -> Void) -> Self
    {
        return response(queue: queue,
                        responseSerializer: LGDownloadRequest.stringResponseSerializer(encoding: encoding),
                        completionHandler: completionHandler)
    }
}

// MARK: -  序列化为JSON对象

extension LGHTTPRequest {
    
    /// 将返回结果序列化为JSON对象 Any类型
    ///
    /// - Parameters:
    ///   - options: JSONSerialization.ReadingOptions 默认为.allowFragments
    ///   - response: 原始HTTPURLResponse
    ///   - data: 服务器返回的原始Data
    ///   - error: 如不为空，则请求有错误，直接返回
    /// - Returns: LGResult<Any> Any JSON Object
    public static func serializeResponseJSON(options: JSONSerialization.ReadingOptions,
                                             response: HTTPURLResponse?,
                                             data: Data?,
                                             error: Error?) -> LGResult<Any>
    {
        if let error = error {
            return LGResult.failure(error)
        }
        
        if let response = response, emptyHTTPBodyStatusCodes.contains(response.statusCode) {
            return LGResult.success(NSNull())
        }
        
        guard let validData = data, validData.count > 0 else {
            return LGResult.failure(LGError.responseSerializationFailed(reason: .inputDataNilOrZeroLength))
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: validData, options: options)
            return LGResult.success(json)
        } catch {
            return LGResult.failure(LGError.responseSerializationFailed(reason: .jsonSerializationFailed(error: error)))
        }
    }
}

extension LGDataRequest {
    
    /// 返回将返回结果序列化为JSON对象的序列化工具
    ///
    /// - Parameter options: JSONSerialization.ReadingOptions 默认 .allowFragments
    /// - Returns: LGHTTPDataResponseSerializer<Any> Any JSON Object
    public static func jsonResponseSerializer(options: JSONSerialization.ReadingOptions = .allowFragments)
        -> LGHTTPDataResponseSerializer<Any>
    {
        return LGHTTPDataResponseSerializer { _, response, data, error in
            return LGHTTPRequest.serializeResponseJSON(options: options,
                                                       response: response,
                                                       data: data,
                                                       error: error)
        }
    }
    
    
    /// 添加返回结果序列化工具，以便请求完成后进行处理
    ///
    /// - Parameters:
    ///   - queue: 处理和返回数据的队列
    ///   - options: JSONSerialization.ReadingOptions 默认 .allowFragments
    ///   - completionHandler: 处理后返回数据的闭包
    /// - Returns: 当前请求
    @discardableResult
    public func responseJSON(queue: DispatchQueue? = nil,
                             options: JSONSerialization.ReadingOptions = .allowFragments,
                             completionHandler: @escaping (LGHTTPDataResponse<Any>) -> Void) -> Self
    {
        return response(queue: queue,
                        responseSerializer: LGDataRequest.jsonResponseSerializer(options: options),
                        completionHandler: completionHandler)
    }
}

extension LGDownloadRequest {
    public static func jsonResponseSerializer(options: JSONSerialization.ReadingOptions = .allowFragments)
        -> LGHTTPDownloadResponseSerializer<Any>
    {
        return LGHTTPDownloadResponseSerializer { _, response, fileURL, error in
            if let error = error {
                return LGResult.failure(error)
            }
            
            guard let fileURL = fileURL else {
                return LGResult.failure(LGError.responseSerializationFailed(reason: .inputFileNil))
            }
            
            do {
                let data = try Data(contentsOf: fileURL)
                return LGDataRequest.serializeResponseJSON(options: options,
                                                           response: response,
                                                           data: data,
                                                           error: error)
            } catch {
                return LGResult.failure(LGError.responseSerializationFailed(reason: .inputFileReadFailed(at: fileURL)))
            }
        }
    }
    
    
    @discardableResult
    public func responseJSON(queue: DispatchQueue? = nil,
                             options: JSONSerialization.ReadingOptions = .allowFragments,
                             completionHandler: @escaping (LGHTTPDownloadResponse<Any>) -> Void) -> Self
    {
        return response(queue: queue,
                        responseSerializer: LGDownloadRequest.jsonResponseSerializer(options: options),
                        completionHandler: completionHandler)
    }
}

// MARK: -  序列化为PropertyList对象

extension LGHTTPRequest {
    public static func serializeResponsePropertyList(options: PropertyListSerialization.ReadOptions,
                                                     response: HTTPURLResponse?,
                                                     data: Data?,
                                                     error: Error?)-> LGResult<Any>
    {
        if let error = error {
            return LGResult.failure(error)
        }
        
        if let response = response, emptyHTTPBodyStatusCodes.contains(response.statusCode) {
            return LGResult.success(NSNull())
        }
        
        guard let validData = data, validData.count > 0 else {
            return LGResult.failure(LGError.responseSerializationFailed(reason: .inputDataNilOrZeroLength))
        }
        
        do {
            let plist = try PropertyListSerialization.propertyList(from: validData,
                                                                   options: options,
                                                                   format: nil)
            return LGResult.success(plist)
        } catch {
            let reason = LGError.ResponseSerializationFailureReason.propertyListSerializationFailed(error: error)
            return LGResult.failure(LGError.responseSerializationFailed(reason: reason))
        }
    }
}

extension LGDataRequest {
    
    public static func propertyListResponseSerializer(options: PropertyListSerialization.ReadOptions = [])
        -> LGHTTPDataResponseSerializer<Any>
    {
        return LGHTTPDataResponseSerializer { _, response, data, error in
            return LGHTTPRequest.serializeResponsePropertyList(options: options,
                                                               response: response,
                                                               data: data,
                                                               error: error)
        }
    }
    
    
    @discardableResult
    public func responsePropertyList(queue: DispatchQueue? = nil,
                                     options: PropertyListSerialization.ReadOptions = [],
                                     completionHandler: @escaping (LGHTTPDataResponse<Any>) -> Void) -> Self
    {
        return response(queue: queue,
                        responseSerializer: LGDataRequest.propertyListResponseSerializer(options: options),
                        completionHandler: completionHandler)
    }
}

extension LGDownloadRequest {
    
    public static func propertyListResponseSerializer(options: PropertyListSerialization.ReadOptions = [])
        -> LGHTTPDownloadResponseSerializer<Any>
    {
        return LGHTTPDownloadResponseSerializer { _, response, fileURL, error in
            if let error = error {
                return LGResult.failure(error)
            }
            
            guard let fileURL = fileURL else {
                return LGResult.failure(LGError.responseSerializationFailed(reason: .inputFileNil))
            }
            
            do {
                let data = try Data(contentsOf: fileURL)
                return LGHTTPRequest.serializeResponsePropertyList(options: options,
                                                                   response: response,
                                                                   data: data,
                                                                   error: error)
            } catch {
                return LGResult.failure(LGError.responseSerializationFailed(reason: .inputFileReadFailed(at: fileURL)))
            }
        }
    }
    
    @discardableResult
    public func responsePropertyList(queue: DispatchQueue? = nil,
                                     options: PropertyListSerialization.ReadOptions = [],
                                     completionHandler: @escaping (LGHTTPDownloadResponse<Any>) -> Void) -> Self
    {
        return response(queue: queue,
                        responseSerializer: LGDownloadRequest.propertyListResponseSerializer(options: options),
                        completionHandler: completionHandler)
    }
}


/// 处理返回数据的时候，所有类型序列化工具必须遵循的协议
public protocol LGHTTPDataResponseSerializerProtocol {
    
    /// <#Description#>
    associatedtype SerializedObject
    
    typealias DataResponseBlock = ((URLRequest?, HTTPURLResponse?, Data?, Error?) -> LGResult<SerializedObject>)
    
    var serializeResponse: DataResponseBlock { get }
}

public struct LGHTTPDataResponseSerializer<Value>: LGHTTPDataResponseSerializerProtocol {
    public typealias SerializedObject = Value
    
    public var serializeResponse: DataResponseBlock
    
    public init(serializeResponse: @escaping DataResponseBlock) {
        self.serializeResponse = serializeResponse
    }
}

public protocol LGHTTPDownloadResponseSerializerProtocol {
    associatedtype SerializedObject
    
    typealias DownloadResponseBlock = ((URLRequest?, HTTPURLResponse?, URL?, Error?) -> LGResult<SerializedObject>)
    
    var serializeResponse: DownloadResponseBlock { get }
}


/// <#Description#>
public struct LGHTTPDownloadResponseSerializer<Value>: LGHTTPDownloadResponseSerializerProtocol {
    public typealias SerializedObject = Value
    
    public var serializeResponse: DownloadResponseBlock
    
    public init(serializeResponse: @escaping DownloadResponseBlock) {
        self.serializeResponse = serializeResponse
    }
}

// MARK: -  上传和下载的进度条，数据分片处理
extension LGUploadRequest {
    
}

