//
//  LGResult.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2018/3/7.
//  Copyright © 2018年 龚杰洪. All rights reserved.
//

import Foundation

// MARK: -  Define

/// 将请求结果根据Value组装为成功或者失败两种枚举
///
/// - success: 成功并包含成功的数据结果
/// - failure: 失败并包含错误信息
public enum LGResult<Value> {
    
    case success(Value)
    case failure(Error)
    
    /// 是否为请求成功，在初始化的时候就已确定
    public var isSuccess: Bool {
        switch self {
        case .success:
            return true
        default:
            return false
        }
    }
    
    /// 是否为请求失败，在初始化的时候就已确定
    public var isFailure: Bool {
        return !isSuccess
    }
    
    /// 结果值，如果成功就一定有值，否则为nil
    public var value: Value? {
        switch self {
        case .success(let value):
            return value
        default:
            return nil
        }
    }
    
    /// 错误信息，失败才有，否则为nil
    public var error: Error? {
        switch self {
        case .failure(let error):
            return error
        default:
            return nil
        }
    }
    
    /// 通过闭包初始化，如果闭包内处理数据不成功，则抛出错误，并接受错误后组装错误信息
    ///
    /// - Parameter value: 处理数据的闭包
    public init(value: () throws -> Value) {
        do {
            self = try .success(value())
        } catch {
            self = .failure(error)
        }
    }
}

// MARK: - description & debugDescription
extension LGResult: CustomStringConvertible {
    public var description: String {
        switch self {
        case .success:
            return "success"
        default:
            return "failure"
        }
    }
}

extension LGResult: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .success(let value):
            return "success: value = \(value)"
        case .failure(let error):
            return "failure: error = \(error)"
        }
    }
}

// MARK: -  功能性API
extension LGResult {
    public func unwrap() throws -> Value {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
    
    public func map<T>(_ transform: (Value) -> T) -> LGResult<T> {
        switch self {
        case .success(let value):
            return .success(transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }
    
    public func flatMap<T>(_ transform: (Value) throws -> T) -> LGResult<T> {
        switch self {
        case .success(let value):
            do {
                return try .success(transform(value))
            } catch {
                return .failure(error)
            }
        case .failure(let error):
            return .failure(error)
        }
    }
    
    public func mapError<T: Error>(_ transform: (Error) -> T) -> LGResult {
        switch self {
        case .failure(let error):
            return .failure(transform(error))
        case .success:
            return self
        }
    }
    
    public func flatMapError<T: Error>(_ transform: (Error) throws -> T) -> LGResult {
        switch self {
        case .failure(let error):
            do {
                return try .failure(transform(error))
            } catch {
                return .failure(error)
            }
        case .success:
            return self
        }
    }
    
    @discardableResult
    public func withValue(_ closure: (Value) -> Void) -> LGResult {
        if case let .success(value) = self { closure(value) }
        
        return self
    }
    
    @discardableResult
    public func withError(_ closure: (Error) -> Void) -> LGResult {
        if case let .failure(error) = self { closure(error) }
        
        return self
    }
    
    @discardableResult
    public func ifSuccess(_ closure: () -> Void) -> LGResult {
        if isSuccess { closure() }
        
        return self
    }
    
    @discardableResult
    public func ifFailure(_ closure: () -> Void) -> LGResult {
        if isFailure { closure() }
        
        return self
    }
}
