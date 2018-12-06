//
//  LGHTTPRequestTaskDelegate.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2017/12/25.
//  Copyright © 2017年 龚杰洪. All rights reserved.
//

import Foundation


/// 处理上传和下载进度数据的闭包
public typealias LGProgressHandler = (Progress) -> Void

open class LGURLSessionTaskDelegate: NSObject, URLSessionTaskDelegate {
    
    /// 线程锁
    private let taskLock = DispatchSemaphore(value: 1)
    
    /// 串行队列，队列开始是暂停状态，主要用户添加完成执行的任务，等请求任务执行完成后将暂停状态设置为false,队列自动触发前面添加的任务
    public let queue: OperationQueue
    
    /// 返回的数据data
    public var receivedData: Data? {
        return nil
    }
    
    /// 整个请求过程中的错误都将记录在这里
    public var error: Error?
    
    fileprivate var _task: URLSessionTask? {
        didSet {
            self.reset()
        }
    }
    
    /// URLSessionTaskMetrics对象，iOS10后有效，方便写代码，直接用AnyObject代替，iOS10以前不可用
    var metrics: AnyObject?
    
    var credential: URLCredential?
    
    var task: URLSessionTask? {
        set {
            _ = taskLock.wait(timeout: DispatchTime.distantFuture)
            defer {
                _ = taskLock.signal()
            }
            _task = newValue
        } get {
            _ = taskLock.wait(timeout: DispatchTime.distantFuture)
            defer {
                _ = taskLock.signal()
            }
            return _task
        }
    }
    
    func reset() {
        error = nil
    }
    
    init(task: URLSessionTask?) {
        _task = task
        
        self.queue = {
            let tempQueue = OperationQueue()
            
            // 为了避免线程同步问题，设置为1
            tempQueue.maxConcurrentOperationCount = 1
            tempQueue.isSuspended = true
            tempQueue.qualityOfService = QualityOfService.default
            
            return tempQueue
        }()
    }
    
    // MARK: -  delegate to block
    typealias ChallengeResult = (URLSession.AuthChallengeDisposition, URLCredential?)
    var taskWillPerformHTTPRedirection: ((URLSession, URLSessionTask, HTTPURLResponse, URLRequest) -> URLRequest?)?
    var taskDidReceiveChallenge: ((URLSession, URLSessionTask, URLAuthenticationChallenge) -> ChallengeResult)?
    var taskNeedNewBodyStream: ((URLSession, URLSessionTask) -> InputStream?)?
    var taskDidCompleteWithError: ((URLSession, URLSessionTask, Error?) -> Void)?
    
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           willPerformHTTPRedirection response: HTTPURLResponse,
                           newRequest request: URLRequest,
                           completionHandler: @escaping (URLRequest?) -> Void)
    {
        var redirectRequest: URLRequest? = request
        
        if let block = taskWillPerformHTTPRedirection {
            redirectRequest = block(session, task, response, request)
        }
        
        completionHandler(redirectRequest)
    }
    
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    {
        var disposition = URLSession.AuthChallengeDisposition.performDefaultHandling
        var credential: URLCredential?
        
        if let block = taskDidReceiveChallenge {
            (disposition, credential) = block(session, task, challenge)
        } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            let host = challenge.protectionSpace.host
            
            if  let serverTrustPolicy = session.serverTrustPolicyManager?[host],
                let serverTrust = challenge.protectionSpace.serverTrust
            {
                if serverTrustPolicy.evaluate(serverTrust, forHost: host) {
                    disposition = .useCredential
                    credential = URLCredential(trust: serverTrust)
                } else {
                    disposition = .cancelAuthenticationChallenge
                }
            }
        } else {
            if challenge.previousFailureCount > 0 {
                disposition = .rejectProtectionSpace
            } else {
                let storage = session.configuration.urlCredentialStorage
                
                credential = self.credential ?? storage?.defaultCredential(for: challenge.protectionSpace)
                
                if credential != nil {
                    disposition = .useCredential
                }
            }
        }
        
        completionHandler(disposition, credential)
    }
    
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           needNewBodyStream completionHandler: @escaping (InputStream?) -> Void)
    {
        var bodyStream: InputStream?
        
        if let block = taskNeedNewBodyStream {
            bodyStream = block(session, task)
        }
        
        completionHandler(bodyStream)
    }
    
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           didCompleteWithError error: Error?)
    {
        if let block = taskDidCompleteWithError {
            block(session, task, error)
        } else {
            if let error = error {
                if self.error == nil { self.error = error }
                
                if  let downloadDelegate = self as? LGDownloadTaskDelegate,
                    let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data
                {
                    downloadDelegate.resumeData = resumeData
                }
            }
            queue.isSuspended = false
        }
    }
}



// MARK: - LGDataTaskDelegate with URLSessionDataDelegate
open class LGDataTaskDelegate: LGURLSessionTaskDelegate, URLSessionDataDelegate {
    var dataTask: URLSessionDataTask {
        return self.task as! URLSessionDataTask
    }
    
    override public var receivedData: Data? {
        if dataStream != nil {
            return nil
        } else {
            return mutableData
        }
    }
    
    var progress: Progress
    var progressHandler: (closure: LGProgressHandler, queue: DispatchQueue)?
    
    var dataStream: ((_ data: Data) -> Void)?
    
    var totalBytesReceived: Int64 = 0
    var mutableData: Data
    
    var expectedContentLength: Int64
    
    override init(task: URLSessionTask?) {
        mutableData = Data()
        progress = Progress(totalUnitCount: 0)
        expectedContentLength = NSURLSessionTransferSizeUnknown
        super.init(task: task)
    }
    
    override func reset() {
        super.reset()
        
        progress = Progress(totalUnitCount: 0)
        totalBytesReceived = 0
        mutableData = Data()
        expectedContentLength = NSURLSessionTransferSizeUnknown
    }
    
    // MARK: delegete to block
    
    var dataTaskDidReceiveResponse: ((URLSession, URLSessionDataTask, URLResponse) -> URLSession.ResponseDisposition)?
    var dataTaskDidBecomeDownloadTask: ((URLSession, URLSessionDataTask, URLSessionDownloadTask) -> Void)?
    var dataTaskDidReceiveData: ((URLSession, URLSessionDataTask, Data) -> Void)?
    var dataTaskWillCacheResponse: ((URLSession, URLSessionDataTask, CachedURLResponse) -> CachedURLResponse?)?
    
    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didReceive response: URLResponse,
                           completionHandler: @escaping (URLSession.ResponseDisposition) -> Void)
    {
        var disposition: URLSession.ResponseDisposition = .allow
        
        expectedContentLength = response.expectedContentLength
        
        if let block = dataTaskDidReceiveResponse {
            disposition = block(session, dataTask, response)
        }
        
        completionHandler(disposition)
    }
    
    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didBecome downloadTask: URLSessionDownloadTask)
    {
        dataTaskDidBecomeDownloadTask?(session, dataTask, downloadTask)
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data)
    {
        if let block = dataTaskDidReceiveData {
            block(session, dataTask, data)
        } else {
            if let dataStream = dataStream {
                dataStream(data)
            } else {
                mutableData.append(data)
            }
            
            let bytesReceived = Int64(data.count)
            totalBytesReceived += bytesReceived
            
            /// 在返回数据的时候获取要传输的总数据量
            let totalBytesExpected = dataTask.response?.expectedContentLength ?? NSURLSessionTransferSizeUnknown
            
            progress.totalUnitCount = totalBytesExpected
            progress.completedUnitCount = totalBytesReceived
            
            if let progressHandler = progressHandler {
                progressHandler.queue.async {
                    progressHandler.closure(self.progress)
                }
            }
        }
    }
    
    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           willCacheResponse proposedResponse: CachedURLResponse,
                           completionHandler: @escaping (CachedURLResponse?) -> Void)
    {
        var cachedResponse: CachedURLResponse? = proposedResponse
        
        if let dataTaskWillCacheResponse = dataTaskWillCacheResponse {
            cachedResponse = dataTaskWillCacheResponse(session, dataTask, proposedResponse)
        }
        
        completionHandler(cachedResponse)
    }
}

class LGStreamDownloadTaskDelegate: LGDataTaskDelegate {
    var resumeData: Data?
    override var receivedData: Data? { return mutableData }
    
    var temporaryURL: URL
    var destinationURL: URL
    
    private let downloadDirName: String = "com.LGHTTPRequest.download"
    
    static func temporaryURL(fromURLRequest request: LGURLRequestConvertible) -> URL {
        var fileName: String
        do {
            let url = try request.asURLRequest().url
            if let url = url {
                fileName = try url.getFileName()
            } else {
                fileName = UUID().uuidString
            }
        } catch {
            fileName = UUID().uuidString
        }

        let downloadDirName: String = "com.LGHTTPRequest.download"
        
        var temporaryURL = FileManager.lg_temporaryDirectoryURL.appendingPathComponent(downloadDirName,
                                                                                       isDirectory: true)
        FileManager.createDirectory(withURL: temporaryURL)
        temporaryURL = temporaryURL.appendingPathComponent(fileName, isDirectory: false)
        return temporaryURL
    }
    
    override init(task: URLSessionTask?) {
        var fileName: String
        if let url = task?.currentRequest?.url {
            do {
                fileName = try url.getFileName()
            } catch {
                fileName = UUID().uuidString
            }
        } else {
            fileName = UUID().uuidString
        }
        
        var temporaryURL = FileManager.lg_temporaryDirectoryURL.appendingPathComponent(downloadDirName,
                                                                                       isDirectory: true)
        FileManager.createDirectory(withURL: temporaryURL)
        temporaryURL = temporaryURL.appendingPathComponent(fileName, isDirectory: false)
        
        
        var destinationURL = FileManager.lg_cacheDirectoryURL.appendingPathComponent(downloadDirName,
                                                                                     isDirectory: true)
        FileManager.createDirectory(withURL: destinationURL)
        destinationURL = destinationURL.appendingPathComponent(fileName,
                                                               isDirectory: false)
        
        self.temporaryURL = temporaryURL
        self.destinationURL = destinationURL
        super.init(task: task)
    }
    
    init(task: URLSessionTask?, destinationURL: URL? = nil, resumeData: Data? = nil) {
        var fileName: String
        if let url = task?.currentRequest?.url {
            do {
                fileName = try url.getFileName()
            } catch {
                fileName = UUID().uuidString
            }
        } else {
            fileName = UUID().uuidString
        }
        
        var temporaryURL = FileManager.lg_temporaryDirectoryURL.appendingPathComponent(downloadDirName,
                                                                                       isDirectory: true)
        FileManager.createDirectory(withURL: temporaryURL)
        temporaryURL = temporaryURL.appendingPathComponent(fileName, isDirectory: false)
        
        self.temporaryURL = temporaryURL
        
        if let destinationURL = destinationURL {
            self.destinationURL = destinationURL
            FileManager.createDirectory(withURL: destinationURL.deletingLastPathComponent())
        } else {
            var destinationURL = FileManager.lg_cacheDirectoryURL.appendingPathComponent(downloadDirName,
                                                                                         isDirectory: true)
            FileManager.createDirectory(withURL: destinationURL)
            destinationURL = destinationURL.appendingPathComponent(fileName,
                                                                   isDirectory: false)
            self.destinationURL = destinationURL
        }
        
        super.init(task: task)
        
        if let resumeData = resumeData {
            mutableData.append(resumeData)
        }
    }
    
    override func reset() {
        super.reset()
        
        progress = Progress(totalUnitCount: 0)
        totalBytesReceived = 0
        mutableData = Data()
        expectedContentLength = NSURLSessionTransferSizeUnknown
        resumeData = nil
    }
    
    public override func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didReceive response: URLResponse,
                           completionHandler: @escaping (URLSession.ResponseDisposition) -> Void)
    {
        var disposition: URLSession.ResponseDisposition = .allow
        
        expectedContentLength = response.expectedContentLength
        
        if let block = dataTaskDidReceiveResponse {
            disposition = block(session, dataTask, response)
        }
        
        completionHandler(disposition)
    }
    
    public override func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didBecome downloadTask: URLSessionDownloadTask)
    {
        dataTaskDidBecomeDownloadTask?(session, dataTask, downloadTask)
    }
    
    // MARK: delegete to block
    public override func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data)
    {
        if let block = dataTaskDidReceiveData {
            block(session, dataTask, data)
        } else {
            if let dataStream = dataStream {
                dataStream(data)
            } else {
                mutableData.append(data)
                
                // Write Data
                let inputStream = InputStream(data: data)
                // 此处需要先创建文件夹，如果未创建文件夹则无法使用stream
                guard let outputStream = OutputStream(url: temporaryURL,
                                                      append: true) else { return }
                
                inputStream.schedule(in: RunLoop.current, forMode: RunLoop.Mode.default)
                outputStream.schedule(in: RunLoop.current, forMode: RunLoop.Mode.default)
                inputStream.open()
                outputStream.open()
                
                while inputStream.hasBytesAvailable && outputStream.hasSpaceAvailable {
                    var buffer = [UInt8](repeating: 0, count: 1_024)
                    
                    let bytesRead = inputStream.read(&buffer, maxLength: 1_024)
                    if inputStream.streamError != nil || bytesRead < 0 {
                        break
                    }
                    
                    let bytesWritten = outputStream.write(&buffer, maxLength: bytesRead)
                    if outputStream.streamError != nil || bytesWritten < 0 {
                        break
                    }
                    
                    if bytesRead == 0 && bytesWritten == 0 {
                        break
                    }
                }
                
                inputStream.remove(from: RunLoop.current, forMode: RunLoop.Mode.default)
                outputStream.remove(from: RunLoop.current, forMode: RunLoop.Mode.default)
                
                inputStream.close()
                outputStream.close()
            }
            
            let bytesReceived = Int64(data.count)
            totalBytesReceived += bytesReceived
            
            /// 在返回数据的时候获取要传输的总数据量
            let totalBytesExpected = dataTask.response?.expectedContentLength ?? NSURLSessionTransferSizeUnknown
            
            progress.totalUnitCount = totalBytesExpected
            progress.completedUnitCount = totalBytesReceived
            
            if let progressHandler = progressHandler {
                progressHandler.queue.async {
                    progressHandler.closure(self.progress)
                }
            }
        }
    }
    
    override func urlSession(_ session: URLSession,
                             task: URLSessionTask,
                             didCompleteWithError error: Error?)
    {
        do {
            if FileManager.default.fileExists(atPath: self.destinationURL.path) {
                try FileManager.default.removeItem(at: self.destinationURL)
            }
            try FileManager.default.moveItem(at: self.temporaryURL, to: self.destinationURL)
        } catch {
        }
        super.urlSession(session, task: task, didCompleteWithError: error)
    }
}

// MARK: - LGDownloadTaskDelegate with URLSessionDownloadDelegate
class LGDownloadTaskDelegate: LGURLSessionTaskDelegate, URLSessionDownloadDelegate {
    
    var resumeData: Data?
    
    var downloadTask: URLSessionDownloadTask {
        return task as! URLSessionDownloadTask
    }
    
    var progress: Progress
    var progressHandler: (closure: LGProgressHandler, queue: DispatchQueue)?
    
    override var receivedData: Data? { return resumeData }
    
    var temporaryURL: URL?
    var destinationURL: URL?
    
    override init(task: URLSessionTask?) {
        self.progress = Progress(totalUnitCount: 0)
        let path = FileManager.lg_cacheDirectoryPath + "/com.LGHTTPRequest.download/" + UUID().uuidString
        self.destinationURL = URL(fileURLWithPath: path)
        super.init(task: task)
    }
    
    init(task: URLSessionTask?, destinationURL: URL?) {
        self.progress = Progress(totalUnitCount: 0)
        self.destinationURL = destinationURL
        super.init(task: task)
    }
    
    override func reset() {
        super.reset()
        
        progress = Progress(totalUnitCount: 0)
        resumeData = nil
    }
    
    // MARK: -  delegate to block
    var downloadTaskDidFinishDownloadingToURL: ((URLSession, URLSessionDownloadTask, URL) -> Void)?
    var downloadTaskDidWriteData: ((URLSession, URLSessionDownloadTask, Int64, Int64, Int64) -> Void)?
    var downloadTaskDidResumeAtOffset: ((URLSession, URLSessionDownloadTask, Int64, Int64) -> Void)?
    
    
    /// 完成下载并存储到location位置
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL)
    {
        temporaryURL = location
        
        guard let destinationURL = self.destinationURL else { return }
        
        do {
            // 如果原路径有文件直接删除
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            // 如果目标路径的文件夹未事先创建，则直接创建文件夹
            var isDirectory: ObjCBool = false
            let dirPath = destinationURL.deletingLastPathComponent().absoluteString
            let dirIsExists = FileManager.default.fileExists(atPath: dirPath,
                                                             isDirectory: &isDirectory)
            if !(isDirectory.boolValue && dirIsExists) {
                try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
            }
            // 拷贝文件到目标路径
            try FileManager.default.moveItem(at: location, to: destinationURL)
        } catch {
            self.error = error
        }
        
        if let block = downloadTaskDidFinishDownloadingToURL {
            block(session, downloadTask, destinationURL)
        }
    }
    
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64)
    {
        if let downloadTaskDidWriteData = downloadTaskDidWriteData {
            downloadTaskDidWriteData(
                session,
                downloadTask,
                bytesWritten,
                totalBytesWritten,
                totalBytesExpectedToWrite
            )
        }
        
        if let progressHandler = progressHandler {
            progress.totalUnitCount = totalBytesExpectedToWrite
            progress.completedUnitCount = totalBytesWritten
            
            progressHandler.queue.async { progressHandler.closure(self.progress) }
        }
    }
    
    /// 之前失败的下载被重启
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didResumeAtOffset fileOffset: Int64,
                    expectedTotalBytes: Int64)
    {
        if let downloadTaskDidResumeAtOffset = downloadTaskDidResumeAtOffset {
            downloadTaskDidResumeAtOffset(session, downloadTask, fileOffset, expectedTotalBytes)
        } else {
            progress.totalUnitCount = expectedTotalBytes
            progress.completedUnitCount = fileOffset
        }
    }
}

// MARK: - LGUploadTaskDelegate with URLSessionUploadTask
class LGUploadTaskDelegate: LGDataTaskDelegate {
    // MARK: -  属性
    var uploadTask: URLSessionUploadTask { return task as! URLSessionUploadTask }
    
    var uploadProgress: Progress
    var uploadProgressHandler: (closure: LGProgressHandler, queue: DispatchQueue)?
    
    // MARK: -  构造
    override init(task: URLSessionTask?) {
        uploadProgress = Progress(totalUnitCount: 0)
        super.init(task: task)
    }
    
    override func reset() {
        super.reset()
        uploadProgress = Progress(totalUnitCount: 0)
    }
    
    // MARK: delegate to block
    var taskDidSendBodyData: ((URLSession, URLSessionTask, Int64, Int64, Int64) -> Void)?
    
    func URLSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64)
    {
        if let taskDidSendBodyData = taskDidSendBodyData {
            taskDidSendBodyData(session, task, bytesSent, totalBytesSent, totalBytesExpectedToSend)
        }
        
        uploadProgress.totalUnitCount = totalBytesExpectedToSend
        uploadProgress.completedUnitCount = totalBytesSent
        if let uploadProgressHandler = uploadProgressHandler {
            uploadProgressHandler.queue.async { uploadProgressHandler.closure(self.uploadProgress) }
        }
    }
}
