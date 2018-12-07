//
//  LGStreamDownloadRequest.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2018/12/4.
//  Copyright © 2018年 龚杰洪. All rights reserved.
//

import UIKit

open class LGStreamDownloadRequest: LGDataRequest {
    enum StreamDownloadable: LGTaskConvertible {
        case request(URLRequest, Data?)
        
        func task(session: URLSession, adapter: LGRequestAdapter?, queue: DispatchQueue) throws -> URLSessionTask {
            do {
                let task: URLSessionTask
                
                switch self {
                case let .request(urlRequest, data):
                    var urlRequest = try urlRequest.adapt(using: adapter)
//                    if let resumeData = data {
//                        // 设置断点续传header
//                        urlRequest.addValue("bytes=\(resumeData.count)-", forHTTPHeaderField: "Range")
//                    }
                    task = queue.sync { session.dataTask(with: urlRequest) }
                }
                return task
            } catch {
                throw error
            }
        }
    }
    
    open override var request: URLRequest? {
        if let request = super.request {
            return request
        }
        
        if let downloadable = originalTask as? StreamDownloadable, case let .request(urlRequest, _) = downloadable {
            return urlRequest
        }
        
        return nil
    }
    
    override init(session: URLSession, requestTask: RequestTask, error: Error? = nil) {
        super.init(session: session, requestTask: requestTask, error: error)
        switch requestTask {
        case .streamDownload(let originalTask, let task):
            if let downloadable = originalTask as? StreamDownloadable, case let .request(_, data) = downloadable {
                self.delegate = LGStreamDownloadTaskDelegate(task: task, destinationURL: nil, resumeData: data)
            }
            break
        default:
            break
        }
    }
    
    override open var progress: Progress { return downloadDelegate.progress }
    
    var downloadDelegate: LGStreamDownloadTaskDelegate { return delegate as! LGStreamDownloadTaskDelegate }
    
    public var temporaryURL: URL {
        return self.downloadDelegate.temporaryURL
    }
    
    public var destinationURL: URL {
        return self.downloadDelegate.destinationURL
    }
}
