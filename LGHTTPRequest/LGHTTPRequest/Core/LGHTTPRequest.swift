//
//  LGHTTPRequest.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2017/7/5.
//  Copyright © 2017年 龚杰洪. All rights reserved.
//

import Foundation


public protocol LGRequestAdapter {
    func adapt(_ urlRequest: URLRequest) throws -> URLRequest
}

protocol LGTaskConvertible {
    func task(session: URLSession, adapter: LGRequestAdapter?, queue: DispatchQueue) throws -> URLSessionTask
}

open class LGHTTPRequest {
    
    enum RequestTask {
        case data(LGTaskConvertible?, URLSessionTask?)
        case download(LGTaskConvertible?, URLSessionTask?)
        case upload(LGTaskConvertible?, URLSessionTask?)
        case stream(LGTaskConvertible?, URLSessionTask?)
    }
    
    private var taskDelegate: LGURLSessionTaskDelegate
    private var taskDelegateLock = DispatchSemaphore(value: 1)
    
    open internal(set) var delegate: LGURLSessionTaskDelegate {
        get {
            _ = taskDelegateLock.wait(timeout: DispatchTime.distantFuture)
            defer {
                _ = taskDelegateLock.signal()
            }
            return taskDelegate
        }
        set {
            _ = taskDelegateLock.wait(timeout: DispatchTime.distantFuture)
            defer {
                _ = taskDelegateLock.signal()
            }
            taskDelegate = newValue
        }
    }
    
    open var task: URLSessionTask? { return delegate.task }
    
    open let session: URLSession
    
    open var request: URLRequest? { return task?.originalRequest }
    
    open var response: HTTPURLResponse? { return task?.response as? HTTPURLResponse }
    
    let originalTask: LGTaskConvertible?
    
    var validations: [() -> Void] = []
    
    init(session: URLSession, requestTask: RequestTask, error: Error? = nil) {
        self.session = session
        
        switch requestTask {
        case .data(let originalTask, let task):
            taskDelegate = LGDataTaskDelegate(task: task)
            self.originalTask = originalTask
        case .download(let originalTask, let task):
            taskDelegate = LGDownloadTaskDelegate(task: task)
            self.originalTask = originalTask
        case .upload(let originalTask, let task):
            taskDelegate = LGUploadTaskDelegate(task: task)
            self.originalTask = originalTask
        case .stream(let originalTask, let task):
            taskDelegate = LGURLSessionTaskDelegate(task: task)
            self.originalTask = originalTask
        }
        
        delegate.error = error
    }
    
    @discardableResult
    open func authenticate(
        user: String,
        password: String,
        persistence: URLCredential.Persistence = .forSession)
        -> Self
    {
        let credential = URLCredential(user: user, password: password, persistence: persistence)
        return authenticate(usingCredential: credential)
    }
    
    @discardableResult
    open func authenticate(usingCredential credential: URLCredential) -> Self {
        delegate.credential = credential
        return self
    }
    
    open static func authorizationHeader(user: String, password: String) -> (key: String, value: String)? {
        guard let data = "\(user):\(password)".data(using: .utf8) else { return nil }
        
        let credential = data.base64EncodedString(options: [])
        
        return (key: "Authorization", value: "Basic \(credential)")
    }
    
    // MARK: 请求状态控制
    
    /// 恢复请求状态
    open func resume() {
        guard let task = task else { delegate.queue.isSuspended = false ; return }
        
        task.resume()
    }
    
    
    /// 暂停当前请求
    open func suspend() {
        guard let task = task else { return }
        
        task.suspend()
    }
    

    /// 取消请求
    open func cancel() {
        guard let task = task else { return }
        
        task.cancel()
    }
    
    deinit {
        print("LGHTTPRequest deinit")
    }
}


extension LGHTTPRequest: CustomStringConvertible {
    public var description: String {
        var components: [String] = []
        
        if let HTTPMethod = request?.httpMethod {
            components.append("method = " + HTTPMethod)
        }
        
        if let urlString = request?.url?.absoluteString {
            components.append("url = " + urlString)
        }
        
        if let response = response {
            components.append("code = (\(response.statusCode))")
        }
        
        return components.joined(separator: ",")
    }
}

extension LGHTTPRequest: CustomDebugStringConvertible {
    public var debugDescription: String {
        var components: [String] = []
        
        guard let request = self.request, let url = request.url else {
                return "request is emtpy"
        }
        
        if session.configuration.httpShouldSetCookies {
            if
                let cookieStorage = session.configuration.httpCookieStorage,
                let cookies = cookieStorage.cookies(for: url), !cookies.isEmpty
            {
                let string = cookies.reduce("") { $0 + "\($1.name)=\($1.value);" }
                components.append("-b \"\(string[..<string.index(before: string.endIndex)])\"")
            }
        }
        
        var headers: [AnyHashable: Any] = [:]
        
        if let additionalHeaders = session.configuration.httpAdditionalHeaders {
            for (field, value) in additionalHeaders where field != AnyHashable("Cookie") {
                headers[field] = value
            }
        }
        
        if let headerFields = request.allHTTPHeaderFields {
            for (field, value) in headerFields where field != "Cookie" {
                headers[field] = value
            }
        }
        
        for (field, value) in headers {
            components.append("-H \"\(field): \(value)\"")
        }
        
        if let httpBodyData = request.httpBody, let httpBody = String(data: httpBodyData, encoding: .utf8) {
            var escapedBody = httpBody.replacingOccurrences(of: "\\\"", with: "\\\\\"")
            escapedBody = escapedBody.replacingOccurrences(of: "\"", with: "\\\"")
            
            components.append("-d \"\(escapedBody)\"")
        }
        
        components.append("\"\(url.absoluteString)\"")
        
        return components.joined(separator: " \\\n\t")
    }
}
