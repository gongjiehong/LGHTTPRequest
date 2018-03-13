//
//  LGError.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2017/7/5.
//  Copyright © 2017年 龚杰洪. All rights reserved.
//

import Foundation

public enum LGError: Error {
    
    public enum ParameterEncodingFailureReason {
        case missingURL
        case jsonEncodingFailed(error: Error)
        case propertyListEncodingFailed(error: Error)
        case encryptKeysInvalid
        case stringEncodeFailed
    }
    
    public enum MultipartEncodingFailureReason {
        case bodyPartURLInvalid(url: URL)
        case bodyPartFilenameInvalid(in: URL)
        case bodyPartFileNotReachable(at: URL)
        case bodyPartFileNotReachableWithError(atURL: URL, error: Error)
        case bodyPartFileIsDirectory(at: URL)
        case bodyPartFileSizeNotAvailable(at: URL)
        case bodyPartFileSizeQueryFailedWithError(forURL: URL, error: Error)
        case bodyPartInputStreamCreationFailed(for: URL)
        
        case outputStreamCreationFailed(for: URL)
        case outputStreamFileAlreadyExists(at: URL)
        case outputStreamURLInvalid(url: URL)
        case outputStreamWriteFailed(error: Error)
        
        case inputStreamReadFailed(error: Error)
        
        case stringEncodeFailedWith(name: String)
    }
    
    public enum ResponseValidationFailureReason {
        case dataFileNil
        case dataFileReadFailed(at: URL)
        case missingContentType(acceptableContentTypes: [String])
        case unacceptableContentType(acceptableContentTypes: [String], responseContentType: String)
        case unacceptableStatusCode(code: Int)
    }
    
    public enum ResponseSerializationFailureReason {
        case inputDataNil
        case inputDataNilOrZeroLength
        case inputFileNil
        case inputFileReadFailed(at: URL)
        case stringSerializationFailed(encoding: String.Encoding)
        case jsonSerializationFailed(error: Error)
        case propertyListSerializationFailed(error: Error)
    }
    
    case invalidURL(url: LGURLConvertible)
    
    case parameterEncodingFailed(reason: ParameterEncodingFailureReason)
    
    case multipartEncodingFailed(reason: MultipartEncodingFailureReason)
    
    case responseValidationFailed(reason: ResponseValidationFailureReason)
    
    case responseSerializationFailed(reason: ResponseSerializationFailureReason)
}

// MARK: - 错误类型转换为Bool

extension LGError {
    public var isInvalidURLError: Bool {
        if case .invalidURL = self { return true }
        return false
    }
    
    public var isParameterEncodingError: Bool {
        if case .parameterEncodingFailed = self { return true }
        return false
    }
    
    public var isMultipartEncodingError: Bool {
        if case .multipartEncodingFailed = self { return true }
        return false
    }
    
    public var isResponseValidationError: Bool {
        if case .responseValidationFailed = self { return true }
        return false
    }
    
    public var isResponseSerializationError: Bool {
        if case .responseSerializationFailed = self { return true }
        return false
    }
}

// MARK: - 方便取出异常信息

extension LGError {
    
    /// 错误的LGURLConvertible对象
    public var urlConvertible: LGURLConvertible? {
        switch self {
        case .invalidURL(let url):
            return url
        default:
            return nil
        }
    }
    
    /// 与Error关联的URL
    public var url: URL? {
        switch self {
        case .multipartEncodingFailed(let reason):
            return reason.url
        default:
            return nil
        }
    }
    
    
    /// 无限的数据类型数组获取
    public var acceptableContentTypes: [String]? {
        switch self {
        case .responseValidationFailed(let reason):
            return reason.acceptableContentTypes
        default:
            return nil
        }
    }
    
    /// 无效的数据类型获取
    public var responseContentType: String? {
        switch self {
        case .responseValidationFailed(let reason):
            return reason.responseContentType
        default:
            return nil
        }
    }
    
    /// 错误的HTTPCode
    public var responseCode: Int? {
        switch self {
        case .responseValidationFailed(let reason):
            return reason.responseCode
        default:
            return nil
        }
    }
    
    /// 当字符编码引起错误时获取对应的字符编码
    public var failedStringEncoding: String.Encoding? {
        switch self {
        case .responseSerializationFailed(let reason):
            return reason.failedStringEncoding
        default:
            return nil
        }
    }
}

extension LGError.ParameterEncodingFailureReason {
    /// 获取原始错误信息
    var underlyingError: Error? {
        switch self {
        case .jsonEncodingFailed(let error),
             .propertyListEncodingFailed(let error):
            return error
        default:
            return nil
        }
    }
}

extension LGError.MultipartEncodingFailureReason {
    /// 获取发生表单组装错误时的URL
    var url: URL? {
        switch self {
        case .bodyPartURLInvalid(let url),
             .bodyPartFilenameInvalid(let url),
             .bodyPartFileNotReachable(let url),
             .bodyPartFileIsDirectory(let url),
             .bodyPartFileSizeNotAvailable(let url),
             .bodyPartInputStreamCreationFailed(let url),
             .outputStreamCreationFailed(let url),
             .outputStreamFileAlreadyExists(let url),
             .outputStreamURLInvalid(let url),
             .bodyPartFileNotReachableWithError(let url, _),
             .bodyPartFileSizeQueryFailedWithError(let url, _):
            return url
        default:
            return nil
        }
    }
    
    /// 获取发生表单组装错误时的基础错误
    var underlyingError: Error? {
        switch self {
        case .bodyPartFileNotReachableWithError(_, let error),
             .bodyPartFileSizeQueryFailedWithError(_, let error),
             .outputStreamWriteFailed(let error),
             .inputStreamReadFailed(let error):
            return error
        default:
            return nil
        }
    }
}

extension LGError.ResponseValidationFailureReason {
    var acceptableContentTypes: [String]? {
        switch self {
        case .missingContentType(let types), .unacceptableContentType(let types, _):
            return types
        default:
            return nil
        }
    }
    
    var responseContentType: String? {
        switch self {
        case .unacceptableContentType(_, let responseType):
            return responseType
        default:
            return nil
        }
    }
    
    var responseCode: Int? {
        switch self {
        case .unacceptableStatusCode(let code):
            return code
        default:
            return nil
        }
    }
}

extension LGError.ResponseSerializationFailureReason {
    var failedStringEncoding: String.Encoding? {
        switch self {
        case .stringSerializationFailed(let encoding):
            return encoding
        default:
            return nil
        }
    }
    
    var underlyingError: Error? {
        switch self {
        case .jsonSerializationFailed(let error), .propertyListSerializationFailed(let error):
            return error
        default:
            return nil
        }
    }
}

// MARK: - 错误介绍

extension LGError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "URL无效: \(url)"
        case .parameterEncodingFailed(let reason):
            return reason.localizedDescription
        case .multipartEncodingFailed(let reason):
            return reason.localizedDescription
        case .responseValidationFailed(let reason):
            return reason.localizedDescription
        case .responseSerializationFailed(let reason):
            return reason.localizedDescription
        }
    }
}

extension LGError.ParameterEncodingFailureReason {
    var localizedDescription: String {
        switch self {
        case .missingURL:
            return "组装URLRequest时缺少URL"
        case .jsonEncodingFailed(let error):
            return "JSON编码错误：\n\(error.localizedDescription)"
        case .propertyListEncodingFailed(let error):
            return "PropertyList编码错误：\n\(error.localizedDescription)"
        case .encryptKeysInvalid:
            return "加密参数错误"
        case .stringEncodeFailed:
            return "字符无法编码"
        }
    }
}

extension LGError.MultipartEncodingFailureReason {
    var localizedDescription: String {
        switch self {
        case .bodyPartURLInvalid(let url):
            return "提供的网址不是文件地址: \(url)"
        case .bodyPartFilenameInvalid(let url):
            return "提供的网址没有包含正确的filename: \(url)"
        case .bodyPartFileNotReachable(let url):
            return "文件路径无法读取: \(url)"
        case .bodyPartFileNotReachableWithError(let url, let error):
            return "执行文件地址可达性检查时出错\nURL: \(url)\nError: \(error)"
        case .bodyPartFileIsDirectory(let url):
            return "文件地址是一个文件夹: \(url)"
        case .bodyPartFileSizeNotAvailable(let url):
            return "无法获取文件大小: \(url)"
        case .bodyPartFileSizeQueryFailedWithError(let url, let error):
            return "请求获取文件大小时发生异常：\(url)\nError: \(error)"
        case .bodyPartInputStreamCreationFailed(let url):
            return "无法从指定的URL创建InputStream: \(url)"
        case .outputStreamCreationFailed(let url):
            return "无法为URL创建OutputStream: \(url)"
        case .outputStreamFileAlreadyExists(let url):
            return "OutputStream的写入路径已经存在一个文件: \(url)"
        case .outputStreamURLInvalid(let url):
            return "OutputStream 无效: \(url)"
        case .outputStreamWriteFailed(let error):
            return "OutputStream无法写入: \(error)"
        case .inputStreamReadFailed(let error):
            return "InputStream无法读取: \(error)"
        case .stringEncodeFailedWith(let name):
            return "字符编码失败：\n\(name)"
        }
    }
}

extension LGError.ResponseSerializationFailureReason {
    var localizedDescription: String {
        switch self {
        case .inputDataNil:
            return "返回的数据无法处理，data为空."
        case .inputDataNilOrZeroLength:
            return "返回的数据无法处理，data为空或者长度为0"
        case .inputFileNil:
            return "返回的文件数据无法处理，文件为空"
        case .inputFileReadFailed(let url):
            return "返回的文件数据无法处理，文件路径为空: \(url)."
        case .stringSerializationFailed(let encoding):
            return "返回数据无法以当前编码进行序列化: \(encoding)."
        case .jsonSerializationFailed(let error):
            return "无法进行JSON解码:\n\(error.localizedDescription)"
        case .propertyListSerializationFailed(let error):
            return "无法进行PropertyList解码:\n\(error.localizedDescription)"
        }
    }
}

extension LGError.ResponseValidationFailureReason {
    var localizedDescription: String {
        switch self {
        case .dataFileNil:
            return "返回结果验证失败，文件为空."
        case .dataFileReadFailed(let url):
            return "返回结果验证失败，文件无法读取: \(url)."
        case .missingContentType(let types):
            return "返回结果Content-Type缺失，支持的类型不匹配 \(types.joined(separator: ",")) "
        case .unacceptableContentType(let acceptableTypes, let responseType):
            return "返回结果Content-Type \"\(responseType)\" 和支持的 \(acceptableTypes.joined(separator: ",")) 类型不匹配"
        case .unacceptableStatusCode(let code):
            return "HTTPCode不是正常结果:\(code)"
        }
    }
}

