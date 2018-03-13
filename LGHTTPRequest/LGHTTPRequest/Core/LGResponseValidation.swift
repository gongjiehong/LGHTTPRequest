//
//  LGResponseValidation.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2018/3/12.
//  Copyright © 2018年 龚杰洪. All rights reserved.
//

import Foundation

extension LGHTTPRequest {
    
    // MARK: -  辅助验证类型定义
    
    fileprivate typealias ErrorReason = LGError.ResponseValidationFailureReason

    public enum ValidationResult {
        case success
        case failure(Error)
    }
    
    fileprivate struct MIMEType {
        let type: String
        let subType: String
        
        var isWildcard: Bool {
            return type == "*" && subType == "*"
        }
        
        init?(_ string: String) {
            let components: [String] =  {
                let stripped = string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                let split = stripped[..<(stripped.range(of: ";")?.lowerBound ?? stripped.endIndex)]
                return split.components(separatedBy: "/")
            }()
            
            if let type = components.first, let subType = components.last {
                self.type = type
                self.subType = subType
            } else {
                return nil
            }
        }
        
        func matches(_ mime: MIMEType) -> Bool {
            switch (type,subType) {
            case (mime.type, mime.subType), (mime.type, "*"), ("*", "*"), ("*", mime.subType):
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: -  属性
    
    /// 支持的状态码穷举，2XX
    fileprivate var acceptableStatusCodes: [Int] {
        return Array(200..<300)
    }
    
    /// 支持的内容类型，在Header中已有定义
    fileprivate var acceptableContentTypes: [String] {
        if let accept = request?.value(forHTTPHeaderField: "Accept") {
            return accept.components(separatedBy: ",")
        }
        return ["*/*"]
    }
    
    // MARK: -  请求结果状态码验证
    fileprivate func validate<S: Sequence>(statusCode acceptableStatusCodes: S,
                                           response: HTTPURLResponse)
        -> ValidationResult where S.Iterator.Element == Int
    {
        if acceptableStatusCodes.contains(response.statusCode) {
            return ValidationResult.success
        } else {
            let error: LGError = {
                let reason = ErrorReason.unacceptableStatusCode(code: response.statusCode)
                return LGError.responseValidationFailed(reason: reason)
            }()
            return ValidationResult.failure(error)
        }
    }
    
    // MARK: -  结果类型验证
    
    fileprivate func validate<S: Sequence>(contentType acceptableContentTypes: S,
                                           response: HTTPURLResponse,
                                           data: Data?)
        -> ValidationResult where S.Iterator.Element == String
    {
        guard let data = data, data.count > 0 else {
            return ValidationResult.success
        }
        
        guard let responseContentType = response.mimeType, let responseMIMEType = MIMEType(responseContentType) else {
                for contentType in acceptableContentTypes {
                    /// 如果是通配类型，直接返回成功
                    if let mimeType = MIMEType(contentType), mimeType.isWildcard {
                        return ValidationResult.success
                    }
                }
                
                let error: LGError = {
                    let reason = ErrorReason.missingContentType(acceptableContentTypes: Array(acceptableContentTypes))
                    return LGError.responseValidationFailed(reason: reason)
                }()
                
                return ValidationResult.failure(error)
        }
        
        for contentType in acceptableContentTypes {
            /// 如果在可用的四种类型内，返回成功
            if let acceptableMIMEType = MIMEType(contentType), acceptableMIMEType.matches(responseMIMEType) {
                return ValidationResult.success
            }
        }
        
        let error: LGError = {
            let reason = ErrorReason.unacceptableContentType(acceptableContentTypes: Array(acceptableContentTypes),
                                                             responseContentType: responseContentType)
            
            return LGError.responseValidationFailed(reason: reason)
        }()
        
        return ValidationResult.failure(error)
    }
}
// MARK: - LGDataRequest Validation
extension LGDataRequest {
    
    /// 通过URLRequest返回结果和返回数据进行验证的闭包，返回ValidationResult验证结果
    public typealias Validation = (URLRequest?, HTTPURLResponse, Data?) -> ValidationResult
    
    
    /// 通过闭包验证请求是否出错，如果验证失败，后续请求都会有error
    ///
    /// - Parameter validation: 验证数据的闭包
    /// - Returns: 当前请求
    @discardableResult
    public func validate(_ validation: @escaping Validation) -> Self {
        let validationExecution: () -> Void = { [unowned self] in
            if let response = self.response,
                self.delegate.error == nil,
                case let ValidationResult.failure(error) = validation(self.request,
                                                                      response,
                                                                      self.delegate.receivedData)
            {
                self.delegate.error = error
            }
        }
        
        validations.append(validationExecution)
        
        return self
    }
    
    /// 验证返回的HTTPCode是否在指定的范围内
    ///
    /// - Parameter acceptableStatusCodes: 指定的HTTPCode范围
    /// - Returns: 当前Request
    @discardableResult
    public func validate<S: Sequence>(statusCode acceptableStatusCodes: S) -> Self where S.Iterator.Element == Int {
        return validate { [unowned self] _, response, _ in
            return self.validate(statusCode: acceptableStatusCodes, response: response)
        }
    }
    
    /// 验证返回的数据内容是否满足类型要求
    ///
    /// - Parameter acceptableContentTypes: 指定的类型，可以通配，也可以是子类型
    /// - Returns: 当前request
    @discardableResult
    public func validate<S: Sequence>(contentType acceptableContentTypes: S)
        -> Self where S.Iterator.Element == String
    {
        return validate { [unowned self] _, response, data in
            return self.validate(contentType: acceptableContentTypes,
                                 response: response,
                                 data: data)
        }
    }
    
    /// 同时验证返回的状态码（2XX）和数据类型(Header默认)是否满足要求
    ///
    /// - Returns: 当前请求
    @discardableResult
    public func validate() -> Self {
        return validate(statusCode: self.acceptableStatusCodes).validate(contentType: self.acceptableContentTypes)
    }
}

// MARK: - LGDownloadRequest Validation

extension LGDownloadRequest {
    /// 通过请求，返回response，临时文件路径，目标文件路径进行验证的闭包
    public typealias Validation = (
        _ request: URLRequest?,
        _ response: HTTPURLResponse,
        _ temporaryURL: URL?,
        _ destinationURL: URL?) -> ValidationResult

    /// 通过闭包验证请求是否出错，如果验证失败，后续请求都会有error
    ///
    /// - Parameter validation: 验证数据的闭包
    /// - Returns: 当前请求
    @discardableResult
    public func validate(_ validation: @escaping Validation) -> Self {
        let validationExecution: () -> Void = { [unowned self] in
            let request = self.request
            let temporaryURL = self.downloadDelegate.temporaryURL
            let destinationURL = self.downloadDelegate.destinationURL
            
            if
                let response = self.response,
                self.delegate.error == nil,
                case let ValidationResult.failure(error) = validation(request, response, temporaryURL, destinationURL)
            {
                self.delegate.error = error
            }
        }
        
        validations.append(validationExecution)
        
        return self
    }
    
    /// 验证返回的HTTPCode是否在指定的范围内
    ///
    /// - Parameter acceptableStatusCodes: 指定的HTTPCode范围
    /// - Returns: 当前Request
    @discardableResult
    public func validate<S: Sequence>(statusCode acceptableStatusCodes: S) -> Self where S.Iterator.Element == Int {
        return validate { [unowned self] _, response, _, _ in
            return self.validate(statusCode: acceptableStatusCodes, response: response)
        }
    }
    

    /// 验证返回的数据内容是否满足类型要求,如果文件下载后在目标路径没有文件，则也会出现错误
    ///
    /// - Parameter acceptableContentTypes: 指定的类型，可以通配，也可以是子类型
    /// - Returns: 当前request
    @discardableResult
    public func validate<S: Sequence>(contentType acceptableContentTypes: S)
        -> Self where S.Iterator.Element == String
    {
        return validate { [unowned self] _, response, _, _ in
            let fileURL = self.downloadDelegate.destinationURL
            
            guard let validFileURL = fileURL else {
                return ValidationResult.failure(LGError.responseValidationFailed(reason: .dataFileNil))
            }
            
            do {
                let data = try Data(contentsOf: validFileURL)
                return self.validate(contentType: acceptableContentTypes, response: response, data: data)
            } catch {
                let reason = ErrorReason.dataFileReadFailed(at: validFileURL)
                return ValidationResult.failure(LGError.responseValidationFailed(reason: reason))
            }
        }
    }
    
    /// 同时验证返回的状态码（2XX）和数据类型(Header默认)是否满足要求，下载后的文件无法读取也视为不满足要求
    ///
    /// - Returns: 当前请求
    @discardableResult
    public func validate() -> Self {
        return validate(statusCode: self.acceptableStatusCodes).validate(contentType: self.acceptableContentTypes)
    }
}
