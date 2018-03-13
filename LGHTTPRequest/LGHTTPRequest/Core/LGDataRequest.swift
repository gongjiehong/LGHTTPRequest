//
//  LGDataRequest.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2018/1/3.
//  Copyright © 2018年 龚杰洪. All rights reserved.
//

import Foundation

open class LGDataRequest: LGHTTPRequest {
    struct Requestable: LGTaskConvertible {
        let urlRequest: URLRequest
        
        func task(session: URLSession, adapter: LGRequestAdapter?, queue: DispatchQueue) throws -> URLSessionTask {
            do {
                let urlRequest = try self.urlRequest.adapt(using: adapter)
                return queue.sync { session.dataTask(with: urlRequest) }
            } catch {
                throw error
            }
        }
    }
    
    open override var request: URLRequest? {
        if let request = super.request {
            return request
        }
        
        if let requestable = originalTask as? Requestable {
            return requestable.urlRequest
        }
        
        return nil
    }
    
    open var progress: Progress { return dataDelegate.progress }
    
    var dataDelegate: LGDataTaskDelegate { return delegate as! LGDataTaskDelegate }
    
    @discardableResult
    open func stream(closure: ((Data) -> Void)? = nil) -> Self {
        dataDelegate.dataStream = closure
        return self
    }
    
    
    @discardableResult
    open func downloadProgress(queue: DispatchQueue = DispatchQueue.main, closure: @escaping LGProgressHandler) -> Self {
        dataDelegate.progressHandler = (closure, queue)
        return self
    }
}
