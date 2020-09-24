//
//  Data+Extensions.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2018/3/20.
//  Copyright © 2018年 龚杰洪. All rights reserved.
//

import Foundation
import CryptoKit
import CommonCrypto

extension Data {
    
    /// 返回当前Data的MD5值
    ///
    /// - Returns: 当前Data的MD5或nil
    public func md5Hash() -> String {
        let digest = Insecure.MD5.hash(data: self)
        return digest.map {
            String(format: "%02hhx", $0)
        }.joined()
    }
    
    /// 返回当前Data的SHA1值
    ///
    /// - Returns: 当前Data的SHA1或nil
    public func sha1() -> String {
        let digest = Insecure.SHA1.hash(data: self)
        return digest.map {
            String(format: "%02hhx", $0)
        }.joined()
    }
    
    /// 通过key对当前Data进行AES加密，key长度必须为32个字符，前16个字符为实际加密key，后16个字符为IV，填充模式PKCS7，块模式CBC
    ///
    /// - Parameter key: 加密key
    /// - Returns: 加密后的data，一般配合base64使用
    /// - Throws: 整个过程中出现的异常
    public func aesEncrypt(with key: String) throws -> Data {
        guard key.length == 32 else {
            throw LGEncryptorError.invalidKey
        }

        let encryptor = LGEncryptor(algorithm: LGEncryptorAlgorithm.aes_128,
                                    padding: ccPKCS7Padding,
                                    blockMode: kCCModeCBC,
                                    iv: key.substring(fromIndex: 16),
                                    ivEncoding: String.Encoding.utf8)
        return try encryptor.crypt(data: self, key: key.substring(toIndex: 16))
    }
    
    /// 通过key对当前Data进行AES解密，key长度必须为32个字符，前16个字符为实际解密key，后16个字符为IV，填充模式PKCS7，块模式CBC
    ///
    /// - Parameter key: 加密key
    /// - Returns: 解密后的data
    /// - Throws: 整个过程中出现的异常
    public func aesDecrypt(with key: String) throws -> Data {
        guard key.length == 32 else {
            throw LGEncryptorError.invalidKey
        }
        
        let encryptor = LGEncryptor(algorithm: LGEncryptorAlgorithm.aes_128,
                                    padding: ccPKCS7Padding,
                                    blockMode: kCCModeCBC,
                                    iv: key.substring(fromIndex: 16),
                                    ivEncoding: String.Encoding.utf8)
        return try encryptor.decrypt(self, key: key.substring(toIndex: 16))
    }
}


