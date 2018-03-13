//
//  LGStreamRequest.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2018/1/3.
//  Copyright © 2018年 龚杰洪. All rights reserved.
//

import Foundation

@available(iOS 9.0, macOS 10.11, tvOS 9.0, *)
open class LGStreamRequest: LGHTTPRequest {
    enum Streamable: LGTaskConvertible {
        case stream(hostName: String, port: Int)
        case netService(NetService)
        
        func task(session: URLSession, adapter: LGRequestAdapter?, queue: DispatchQueue) throws -> URLSessionTask {
            let task: URLSessionTask
            
            switch self {
            case let .stream(hostName, port):
                task = queue.sync { session.streamTask(withHostName: hostName, port: port) }
            case let .netService(netService):
                task = queue.sync { session.streamTask(with: netService) }
            }
            
            return task
        }
    }
}


