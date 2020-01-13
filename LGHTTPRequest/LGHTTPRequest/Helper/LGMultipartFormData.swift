//
//  LGMultipartFormData.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2017/7/6.
//  Copyright © 2017年 龚杰洪. All rights reserved.
//

import Foundation
import MobileCoreServices

/// 定义HTTPHeader数据类型，字符
public typealias LGHTTPHeaders = [String: String]


/// 组装表单数据
open class LGMultipartFormData {
    // CRLF字符串
    public struct LGEncodingCharacters {
        static let CRLF = "\r\n"
    }

    // 处理Boundary字符串并转换为Data
    struct LGBoundaryGenerator {
        
        /// 定义边界（Boundary）的位置标记
        ///
        /// - initial: 开始位置
        /// - encapsulated: 中间的封装
        /// - final: 结束位置
        enum LGBoundaryType {
            case initial, encapsulated, final
        }
        
        
        /// boundary 不宜太长，保证不重复即可
        ///
        /// - Returns: LGHTTPRequest.boundary + 两个随机无符号32位整数的16进制
        static func randomBoundary() -> String {
            return String(format: "LGHTTPRequest.boundary.%08x%08x", arc4random(), arc4random())
        }
        
        /// 根据边界位置标记组装数据
        ///
        /// - Parameters:
        ///   - boundaryType: LGBoundaryType
        ///   - boundary: 随机的边界字符串
        /// - Returns: 组装好的字符串UTF8 Data
        static func boundaryData(forBoundaryType boundaryType: LGBoundaryType, boundary: String) -> Data {
            let boundaryText: String
            
            switch boundaryType {
            case .initial:
                boundaryText = "--\(boundary)\(LGEncodingCharacters.CRLF)"
            case .encapsulated:
                boundaryText = "\(LGEncodingCharacters.CRLF)--\(boundary)\(LGEncodingCharacters.CRLF)"
            case .final:
                boundaryText = "\(LGEncodingCharacters.CRLF)--\(boundary)--\(LGEncodingCharacters.CRLF)"
            }
            // 这里理论上不会有异常
            return boundaryText.data(using: String.Encoding.utf8, allowLossyConversion: false)!
        }
    }
    
    
    // 每个表单部分的容器
    class LGBodyPart {
        let headers: LGHTTPHeaders
        let bodyStream: InputStream
        let bodyContentLength: UInt64
        var hasInitialBoundary = false
        var hasFinalBoundary = false
        init(headers: LGHTTPHeaders, bodyStream: InputStream, bodyContentLength: UInt64) {
            self.headers = headers
            self.bodyStream = bodyStream
            self.bodyContentLength = bodyContentLength
        }
    }
    
    // 通过boundary 分隔表单的每一项
    open lazy var contentType: String = "multipart/form-data; charset=utf-8; boundary=\(self.boundary)"
    
    /// 内容长度，不包含boundary
    public var contentLength: UInt64 {
        return bodyParts.reduce(0) { $0 + $1.bodyContentLength }
    }
    
    /// 分隔边界
    public let boundary: String
    
    /// 内部存储body的每一部分
    private var bodyParts: [LGBodyPart]
    
    /// 组装过程中出现的错误存储
    private var bodyPartError: LGError?
    
    /// 输入输出流的buffer大小，官方推荐1024（1KB）
    /// see: https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/Streams/Articles/ReadingInputStreams.html
    private let streamBufferSize: Int
    
    public init() {
        self.boundary = LGBoundaryGenerator.randomBoundary()
        self.bodyParts = []
    
        // 苹果爸爸说的最佳buffer size 为1024（1KB）
        self.streamBufferSize = 1_024
    }
    
    // MARK: - 通过stream 添加
    
    /// 通过流添加一部分HTTPBody
    ///
    /// - Parameters:
    ///   - stream: 文件输入流
    ///   - length: 数据长度
    ///   - headers: 自定义的header
    public func append(_ stream: InputStream, withLength length: UInt64, headers: LGHTTPHeaders) {
        let bodyPart = LGBodyPart(headers: headers, bodyStream: stream, bodyContentLength: length)
        bodyParts.append(bodyPart)
    }
    
    
    /// 通过文件流添加一部分HTTPBody
    /// `Content-Disposition: form-data; name=#{name}; filename=#{filename}`
    /// - Parameters:
    ///   - stream: 文件输入流
    ///   - length: 文件数据长度
    ///   - name: key名字
    ///   - fileName: 文件名
    ///   - mimeType: 文件的类型MIME
    public func append(_ stream: InputStream,
                       withLength length: UInt64,
                       name: String,
                       fileName: String,
                       mimeType: String)
    {
        let headers = contentHeaders(withName: name, fileName: fileName, mimeType: mimeType)
        append(stream, withLength: length, headers: headers)
    }
    
    // MARK: - 直接添加string
    public func append(_ string: String, withName name: String) throws {
        guard let data = string.data(using: String.Encoding.utf8) else {
            throw LGError.multipartEncodingFailed(reason: .stringEncodeFailedWith(name: name))
        }
        let headers = contentHeaders(withName: name)
        let stream = InputStream(data: data)
        let length = UInt64(data.count)
        
        append(stream, withLength: length, headers: headers)
    }
    
    // MARK: - 通过data 添加
    public func append(_ data: Data, withName name: String) {
        let headers = contentHeaders(withName: name)
        let stream = InputStream(data: data)
        let length = UInt64(data.count)
        
        append(stream, withLength: length, headers: headers)
    }
    
    public func append(_ data: Data, withName name: String, mimeType: String) {
        let headers = contentHeaders(withName: name, mimeType: mimeType)
        let stream = InputStream(data: data)
        let length = UInt64(data.count)
        append(stream, withLength: length, headers: headers)
    }
    
    public func append(_ data: Data, withName name: String, fileName: String, mimeType: String) {
        let headers = contentHeaders(withName: name, fileName: fileName, mimeType: mimeType)
        let stream = InputStream(data: data)
        let length = UInt64(data.count)
        
        append(stream, withLength: length, headers: headers)
    }
    
    // MARK: - 通过文件路径添加
    public func append(_ fileURL: URL, withName name: String) {
        let fileName = fileURL.lastPathComponent
        let pathExtension = fileURL.pathExtension
        
        if !fileName.isEmpty && !pathExtension.isEmpty {
            let mime = mimeType(forPathExtension: pathExtension)
            append(fileURL, withName: name, fileName: fileName, mimeType: mime)
        } else {
            setBodyPartError(withReason: .bodyPartFilenameInvalid(in: fileURL))
        }
    }
    
    public func append(_ fileURL: URL, withName name: String, fileName: String, mimeType: String) {
        let headers = contentHeaders(withName: name, fileName: fileName, mimeType: mimeType)
        
        //============================================================
        //                 Check 1 - 是否为文件路径
        //============================================================
        
        guard fileURL.isFileURL else {
            setBodyPartError(withReason: .bodyPartURLInvalid(url: fileURL))
            return
        }
        
        //============================================================
        //              Check 2 - 文件是否存在
        //============================================================
        
        do {
            let isReachable = try fileURL.checkPromisedItemIsReachable()
            guard isReachable else {
                setBodyPartError(withReason: .bodyPartFileNotReachable(at: fileURL))
                return
            }
        } catch {
            setBodyPartError(withReason: .bodyPartFileNotReachableWithError(atURL: fileURL, error: error))
            return
        }
        
        //============================================================
        //            Check 3 - 是否是文件夹路径
        //============================================================
        
        var isDirectory: ObjCBool = false
        let path = fileURL.path
        
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && !isDirectory.boolValue else {
            setBodyPartError(withReason: .bodyPartFileIsDirectory(at: fileURL))
            return
        }
        
        //============================================================
        //          Check 4 - 能不能读取文件大小
        //============================================================
        
        let bodyContentLength: UInt64
        
        do {
            guard let fileSize = try FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber else {
                setBodyPartError(withReason: .bodyPartFileSizeNotAvailable(at: fileURL))
                return
            }
            
            bodyContentLength = fileSize.uint64Value
        }
        catch {
            setBodyPartError(withReason: .bodyPartFileSizeQueryFailedWithError(forURL: fileURL, error: error))
            return
        }
        
        //============================================================
        //       Check 5 - 能不能创建stream
        //============================================================
        
        guard let stream = InputStream(url: fileURL) else {
            setBodyPartError(withReason: .bodyPartInputStreamCreationFailed(for: fileURL))
            return
        }
        
        append(stream, withLength: bodyContentLength, headers: headers)
    }
    


    
    
    // MARK: - Private - 获取MIME
    
    private func mimeType(forPathExtension pathExtension: String) -> String {
        if
            let id = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
                                                           pathExtension as CFString, nil)?.takeRetainedValue(),
            let contentType = UTTypeCopyPreferredTagWithClass(id, kUTTagClassMIMEType)?.takeRetainedValue()
        {
            return contentType as String
        }
        
        return "application/octet-stream"
    }
    
    // MARK: - Private - 创建表单每一部分的头
    
    private func contentHeaders(withName name: String,
                                fileName: String? = nil,
                                mimeType: String? = nil) -> [String: String]
    {
        var disposition = "form-data; name=\"\(name)\""
        if let fileName = fileName {
            disposition += "; filename=\"\(fileName)\""
        }
        
        var headers = ["Content-Disposition": disposition]
        if let mimeType = mimeType {
            headers["Content-Type"] = mimeType
        }
        
        return headers
    }
    
    // MARK: - Private - 组装边界成Data
    
    private func initialBoundaryData() -> Data {
        return LGBoundaryGenerator.boundaryData(forBoundaryType: .initial, boundary: boundary)
    }
    
    private func encapsulatedBoundaryData() -> Data {
        return LGBoundaryGenerator.boundaryData(forBoundaryType: .encapsulated, boundary: boundary)
    }
    
    private func finalBoundaryData() -> Data {
        return LGBoundaryGenerator.boundaryData(forBoundaryType: .final, boundary: boundary)
    }
    
    // MARK: - Private - 处理错误
    
    private func setBodyPartError(withReason reason: LGError.MultipartEncodingFailureReason) {
        guard bodyPartError == nil else {
            return
        }
        bodyPartError = LGError.multipartEncodingFailed(reason: reason)
    }
    
    // MARK: - 编码相关
    public func encode() throws -> Data {
        if let bodyPartError = bodyPartError {
            throw bodyPartError
        }
        
        var encoded = Data()
        
        bodyParts.first?.hasInitialBoundary = true
        bodyParts.last?.hasFinalBoundary = true
        
        for bodyPart in bodyParts {
            let encodedData = try encode(bodyPart)
            encoded.append(encodedData)
        }
        
        return encoded
    }
    
    // 将组装好的数据写入文件，在超出buffer size的时候使用，节约内存
    public func writeEncodedData(to fileURL: URL) throws {
        if let bodyPartError = bodyPartError {
            throw bodyPartError
        }
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            throw LGError.multipartEncodingFailed(reason: .outputStreamFileAlreadyExists(at: fileURL))
        } else if !fileURL.isFileURL {
            throw LGError.multipartEncodingFailed(reason: .outputStreamURLInvalid(url: fileURL))
        }
        
        guard let outputStream = OutputStream(url: fileURL, append: false) else {
            throw LGError.multipartEncodingFailed(reason: .outputStreamCreationFailed(for: fileURL))
        }
        
        outputStream.open()
        defer {
            outputStream.close()
        }
        
        self.bodyParts.first?.hasInitialBoundary = true
        self.bodyParts.last?.hasFinalBoundary = true
        
        for bodyPart in self.bodyParts {
            try write(bodyPart, to: outputStream)
        }
    }
    
    
    // MARK: - Private - Body Part Encoding
    
    private func encode(_ bodyPart: LGBodyPart) throws -> Data {
        var encoded = Data()
        
        // 如果第一条添加开始boundary, 否则添加中间分隔
        let initialData = bodyPart.hasInitialBoundary ? initialBoundaryData() : encapsulatedBoundaryData()
        encoded.append(initialData)
        
        // header 转换为文本并添加CRLF
        let headerData = encodeHeaders(for: bodyPart)
        encoded.append(headerData)
        
        // 从stream读取数据并添加
        let bodyStreamData = try encodeBodyStream(for: bodyPart)
        encoded.append(bodyStreamData)
        
        // 结尾添加结束符
        if bodyPart.hasFinalBoundary {
            encoded.append(finalBoundaryData())
        }
        
        return encoded
    }
    
    private func encodeHeaders(for bodyPart: LGBodyPart) -> Data {
        var headerText = ""
        
        for (key, value) in bodyPart.headers {
            headerText += "\(key): \(value)\(LGEncodingCharacters.CRLF)"
        }
        headerText += LGEncodingCharacters.CRLF
        
        return headerText.data(using: String.Encoding.utf8, allowLossyConversion: false)!
    }
    
    private func encodeBodyStream(for bodyPart: LGBodyPart) throws -> Data {
        let inputStream = bodyPart.bodyStream
        inputStream.open()
        // defer 关键字，等到下文结束后才处理这些个脏数据
        defer {
            inputStream.close()
        }
        
        var encoded = Data()
        
        while inputStream.hasBytesAvailable {
            var buffer = [UInt8](repeating: 0, count: streamBufferSize)
            let bytesRead = inputStream.read(&buffer, maxLength: streamBufferSize)
            
            if let error = inputStream.streamError {
                throw LGError.multipartEncodingFailed(reason: .inputStreamReadFailed(error: error))
            }
            
            if bytesRead > 0 {
                encoded.append(buffer, count: bytesRead)
            } else {
                break
            }
        }
        
        return encoded
    }
    
    // MARK: - Private - 将body数据写入OutputStream
    
    private func write(_ bodyPart: LGBodyPart, to outputStream: OutputStream) throws {
        try writeInitialBoundaryData(for: bodyPart, to: outputStream)
        try writeHeaderData(for: bodyPart, to: outputStream)
        try writeBodyStream(for: bodyPart, to: outputStream)
        try writeFinalBoundaryData(for: bodyPart, to: outputStream)
    }
    
    private func writeInitialBoundaryData(for bodyPart: LGBodyPart, to outputStream: OutputStream) throws {
        let initialData = bodyPart.hasInitialBoundary ? initialBoundaryData() : encapsulatedBoundaryData()
        return try write(initialData, to: outputStream)
    }
    
    private func writeHeaderData(for bodyPart: LGBodyPart, to outputStream: OutputStream) throws {
        let headerData = encodeHeaders(for: bodyPart)
        return try write(headerData, to: outputStream)
    }
    
    private func writeBodyStream(for bodyPart: LGBodyPart, to outputStream: OutputStream) throws {
        let inputStream = bodyPart.bodyStream
        
        inputStream.open()
        defer { inputStream.close() }
        
        while inputStream.hasBytesAvailable {
            var buffer = [UInt8](repeating: 0, count: streamBufferSize)
            let bytesRead = inputStream.read(&buffer, maxLength: streamBufferSize)
            
            if let streamError = inputStream.streamError {
                throw LGError.multipartEncodingFailed(reason: .inputStreamReadFailed(error: streamError))
            }
            
            if bytesRead > 0 {
                if buffer.count != bytesRead {
                    buffer = Array(buffer[0..<bytesRead])
                }
                
                try write(&buffer, to: outputStream)
            } else {
                break
            }
        }
    }
    
    private func writeFinalBoundaryData(for bodyPart: LGBodyPart, to outputStream: OutputStream) throws {
        if bodyPart.hasFinalBoundary {
            return try write(finalBoundaryData(), to: outputStream)
        }
    }
    
    // MARK: - Private - 将buffer数据写入stream
    
    private func write(_ data: Data, to outputStream: OutputStream) throws {
        var buffer = [UInt8](repeating: 0, count: data.count)
        data.copyBytes(to: &buffer, count: data.count)
        
        return try write(&buffer, to: outputStream)
    }
    
    private func write(_ buffer: inout [UInt8], to outputStream: OutputStream) throws {
        var bytesToWrite = buffer.count
        
        while bytesToWrite > 0, outputStream.hasSpaceAvailable {
            let bytesWritten = outputStream.write(buffer, maxLength: bytesToWrite)
            
            if let error = outputStream.streamError {
                throw LGError.multipartEncodingFailed(reason: .outputStreamWriteFailed(error: error))
            }
            
            bytesToWrite -= bytesWritten
            
            if bytesToWrite > 0 {
                buffer = Array(buffer[bytesWritten..<buffer.count])
            }
        }
    }
}
