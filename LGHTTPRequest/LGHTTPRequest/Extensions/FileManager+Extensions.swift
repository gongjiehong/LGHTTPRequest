//
//  FileManager+Extensions.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2018/12/4.
//  Copyright © 2018年 龚杰洪. All rights reserved.
//

import Foundation


extension FileManager {
    static var lg_cacheDirectoryPath: String {
        return NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory,
                                                   FileManager.SearchPathDomainMask.userDomainMask,
                                                   true)[0]
    }

    static var lg_cacheDirectoryURL: URL {
        return URL(fileURLWithPath: lg_cacheDirectoryPath)
    }
    
    static var lg_temporaryDirectoryPath: String {
        return NSTemporaryDirectory()
    }
    
    static var lg_temporaryDirectoryURL: URL {
        return URL(fileURLWithPath: lg_temporaryDirectoryPath)
    }
    
    static func createDirectory(withURL url: URL) {
        var isDirectory: ObjCBool = true
        do {
            if !FileManager.default.fileExists(atPath: url.path,
                                               isDirectory: &isDirectory)
            {
                try FileManager.default.createDirectory(at: url,
                                                        withIntermediateDirectories: true,
                                                        attributes: nil)
            } else {
                if !isDirectory.boolValue {
                    try FileManager.default.removeItem(at: url)
                    try FileManager.default.createDirectory(at: url,
                                                            withIntermediateDirectories: true,
                                                            attributes: nil)
                } else {
                    // do nothing
                }
            }
        } catch {
            debugPrint(error)
        }
    }
}
