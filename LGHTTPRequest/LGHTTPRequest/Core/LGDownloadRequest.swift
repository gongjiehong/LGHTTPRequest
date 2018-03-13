//
//  LGDownloadRequest.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2017/7/7.
//  Copyright © 2017年 龚杰洪. All rights reserved.
//

import UIKit

open class LGDownloadRequest: LGHTTPRequest {
    enum Downloadable: LGTaskConvertible {
        case request(URLRequest)
        case resumeData(Data)
        
        func task(session: URLSession, adapter: LGRequestAdapter?, queue: DispatchQueue) throws -> URLSessionTask {
            do {
                let task: URLSessionTask
                
                switch self {
                case let .request(urlRequest):
                    let urlRequest = try urlRequest.adapt(using: adapter)
                    task = queue.sync { session.downloadTask(with: urlRequest) }
                case let .resumeData(resumeData):
                    task = queue.sync { session.downloadTask(withResumeData: resumeData) }
                }
                
                return task
            } catch {
                throw error
            }
        }
    }
    
    open override var request: URLRequest? {
        if let request = super.request { return request }
        
        if let downloadable = originalTask as? Downloadable, case let .request(urlRequest) = downloadable {
            return urlRequest
        }

        return nil
    }
    
    open var resumeData: Data? { return downloadDelegate.resumeData }
    
    open var progress: Progress { return downloadDelegate.progress }
    
    var downloadDelegate: LGDownloadTaskDelegate { return delegate as! LGDownloadTaskDelegate }
    
    // MARK: 下载状态
    
    /// 取消下载
    open override func cancel() {
        downloadDelegate.downloadTask.cancel { (data) in
            self.downloadDelegate.resumeData = data
        }
    }
    
    @discardableResult
    open func downloadProgress(queue: DispatchQueue = DispatchQueue.main,
                               closure: @escaping LGProgressHandler) -> Self
    {
        downloadDelegate.progressHandler = (closure, queue)
        return self
    }
    
    open func didReceiveData() {
        self.downloadDelegate.downloadTaskDidWriteData = {(_, _, _, _, _) in
            
        }
    }
}

