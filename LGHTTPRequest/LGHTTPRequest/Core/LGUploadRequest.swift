//
//  LGUploadRequest.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2018/1/3.
//  Copyright © 2018年 龚杰洪. All rights reserved.
//

import Foundation


open class LGUploadRequest: LGDataRequest {
    enum Uploadable: LGTaskConvertible {
        case data(Data, URLRequest)
        case file(URL, URLRequest)
        case stream(InputStream, URLRequest)
        
        func task(session: URLSession, adapter: LGRequestAdapter?, queue: DispatchQueue) throws -> URLSessionTask {
            do {
                let task: URLSessionTask
                
                switch self {
                case let .data(data, urlRequest):
                    let urlRequest = try urlRequest.adapt(using: adapter)
                    task = queue.sync { session.uploadTask(with: urlRequest, from: data) }
                case let .file(url, urlRequest):
                    let urlRequest = try urlRequest.adapt(using: adapter)
                    task = queue.sync { session.uploadTask(with: urlRequest, fromFile: url) }
                case let .stream(_, urlRequest):
                    let urlRequest = try urlRequest.adapt(using: adapter)
                    task = queue.sync { session.uploadTask(withStreamedRequest: urlRequest) }
                }
                
                return task
            } catch {
                throw error
            }
        }
    }

    open override var request: URLRequest? {
        if let request = super.request { return request }
        
        guard let uploadable = originalTask as? Uploadable else { return nil }
        
        switch uploadable {
        case .data(_, let urlRequest), .file(_, let urlRequest), .stream(_, let urlRequest):
            return urlRequest
        }
    }
    
    open var uploadProgress: Progress { return uploadDelegate.uploadProgress }
    
    var uploadDelegate: LGUploadTaskDelegate { return delegate as! LGUploadTaskDelegate }
    

    @discardableResult
    open func uploadProgress(queue: DispatchQueue = DispatchQueue.main, closure: @escaping LGProgressHandler) -> Self {
        uploadDelegate.uploadProgressHandler = (closure, queue)
        return self
    }
}
