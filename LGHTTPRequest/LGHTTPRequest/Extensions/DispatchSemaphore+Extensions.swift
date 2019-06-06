//
//  DispatchSemaphore+Extensions.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2019/6/6.
//  Copyright © 2019 龚杰洪. All rights reserved.
//

import Foundation

public extension DispatchSemaphore {
    @inline(__always)
    func lg_lock() {
        _ = self.wait(wallTimeout: DispatchWallTime.distantFuture)
    }
    
    @inline(__always)
    func lg_unlock() {
        _ = self.signal()
    }
}
