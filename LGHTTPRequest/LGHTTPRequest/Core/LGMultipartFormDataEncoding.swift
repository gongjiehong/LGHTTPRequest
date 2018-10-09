//
//  LGMultipartFormDataEncoding.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2017/7/11.
//  Copyright © 2017年 龚杰洪. All rights reserved.
//

import Foundation


public protocol LGMultipartFormDataEncoding {
    
    func encode(_ urlRequest: LGURLRequestConvertible, with data: LGMultipartFormData) throws -> URLRequest
}


public class LGMultipartFormDataEncoder: LGMultipartFormDataEncoding {
    public let maxBodySize: UInt64 = 1_024 * 1_024 // 最大1MB
    
    
    static func randomBodyFileName() -> String {
        return String(format: "LGHTTPRequest.body.%@", UUID().uuidString)
    }
    
    public func encode(_ urlRequest: LGURLRequestConvertible, with data: LGMultipartFormData) throws -> URLRequest {
        var request = try urlRequest.asURLRequest()
        
        if data.contentLength >= maxBodySize {
            let filePath = FileManager.lg_cacheDirectoryPath + LGMultipartFormDataEncoder.randomBodyFileName()
            let fileUrl = URL(fileURLWithPath: filePath)
            
            try data.writeEncodedData(to: fileUrl)
            
            request.httpBodyStream = InputStream(fileAtPath: filePath)
        }
        else {
            let bodyData = try data.encode()
            request.httpBody = bodyData
        }
        request.setValue(data.contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.contentLength)", forHTTPHeaderField: "Content-Length")
        return request
    }
    
    public init() {
        
    }
}


extension FileManager {
    static var lg_cacheDirectoryPath: String {
        return NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory,
                                                   FileManager.SearchPathDomainMask.userDomainMask,
                                                   true)[0]
    }
}
