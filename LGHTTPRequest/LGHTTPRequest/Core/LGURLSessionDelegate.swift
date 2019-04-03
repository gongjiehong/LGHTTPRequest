//
//  LGHTTPRequestSessionDelegate.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2017/12/25.
//  Copyright © 2017年 龚杰洪. All rights reserved.
//

import Foundation



/// 负责将URLSession的底层回调转为block进行处理并分发到各个不同代理
open class LGURLSessionDelegate: NSObject {
    
    open var sessionDidBecomeInvalidWithError: ((URLSession, Error?) -> Void)?
    
    open var sessionDidReceiveChallenge: ((URLSession, URLAuthenticationChallenge)
    -> (URLSession.AuthChallengeDisposition, URLCredential?))?
    
    open var sessionDidReceiveChallengeWithCompletion: ((URLSession,
    URLAuthenticationChallenge,
    @escaping (URLSession.AuthChallengeDisposition,
    URLCredential?) -> Void) -> Void)?
    
    open var sessionDidFinishEventsForBackgroundURLSession: ((URLSession) -> Void)?
    
    // MARK: URLSessionTaskDelegate Overrides
    
    open var taskWillPerformHTTPRedirection: ((URLSession, URLSessionTask, HTTPURLResponse, URLRequest)
    -> URLRequest?)?
    
    open var taskWillPerformHTTPRedirectionWithCompletion: ((URLSession,
    URLSessionTask,
    HTTPURLResponse,
    URLRequest,
    @escaping (URLRequest?) -> Void) -> Void)?
    
    open var taskDidReceiveChallenge: ((URLSession, URLSessionTask, URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?))?
    
    
    open var taskDidReceiveChallengeWithCompletion: ((URLSession, URLSessionTask, URLAuthenticationChallenge, @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void)?
    
    open var taskNeedNewBodyStream: ((URLSession, URLSessionTask) -> InputStream?)?
    
    
    open var taskNeedNewBodyStreamWithCompletion: ((URLSession, URLSessionTask, @escaping (InputStream?) -> Void) -> Void)?
    
    
    open var taskDidSendBodyData: ((URLSession, URLSessionTask, Int64, Int64, Int64) -> Void)?
    
    open var taskDidComplete: ((URLSession, URLSessionTask, Error?) -> Void)?
    
    // MARK: URLSessionDataDelegate Overrides
    
    open var dataTaskDidReceiveResponse: ((URLSession, URLSessionDataTask, URLResponse) -> URLSession.ResponseDisposition)?
    
    open var dataTaskDidReceiveResponseWithCompletion: ((URLSession, URLSessionDataTask, URLResponse, @escaping (URLSession.ResponseDisposition) -> Void) -> Void)?
    
    open var dataTaskDidBecomeDownloadTask: ((URLSession, URLSessionDataTask, URLSessionDownloadTask) -> Void)?
    
    open var dataTaskDidReceiveData: ((URLSession, URLSessionDataTask, Data) -> Void)?
    
    open var dataTaskWillCacheResponse: ((URLSession, URLSessionDataTask, CachedURLResponse) -> CachedURLResponse?)?
    
    open var dataTaskWillCacheResponseWithCompletion: ((URLSession, URLSessionDataTask, CachedURLResponse, @escaping (CachedURLResponse?) -> Void) -> Void)?
    
    // MARK: URLSessionDownloadDelegate Overrides
    
    open var downloadTaskDidFinishDownloadingToURL: ((URLSession, URLSessionDownloadTask, URL) -> Void)?
    
    open var downloadTaskDidWriteData: ((URLSession, URLSessionDownloadTask, Int64, Int64, Int64) -> Void)?
    
    open var downloadTaskDidResumeAtOffset: ((URLSession, URLSessionDownloadTask, Int64, Int64) -> Void)?
    
    #if !os(watchOS)
    
    
    private var _streamTaskReadClosed: Any?
    private var _streamTaskWriteClosed: Any?
    private var _streamTaskBetterRouteDiscovered: Any?
    private var _streamTaskDidBecomeInputStream: Any?
    
    @available(iOS 9.0, macOS 10.11, tvOS 9.0, *)
    open var streamTaskReadClosed: ((URLSession, URLSessionStreamTask) -> Void)? {
        get {
            return _streamTaskReadClosed as? (URLSession, URLSessionStreamTask) -> Void
        }
        set {
            _streamTaskReadClosed = newValue
        }
    }
    
    @available(iOS 9.0, macOS 10.11, tvOS 9.0, *)
    open var streamTaskWriteClosed: ((URLSession, URLSessionStreamTask) -> Void)? {
        get {
            return _streamTaskWriteClosed as? (URLSession, URLSessionStreamTask) -> Void
        }
        set {
            _streamTaskWriteClosed = newValue
        }
    }
    
    @available(iOS 9.0, macOS 10.11, tvOS 9.0, *)
    open var streamTaskBetterRouteDiscovered: ((URLSession, URLSessionStreamTask) -> Void)? {
        get {
            return _streamTaskBetterRouteDiscovered as? (URLSession, URLSessionStreamTask) -> Void
        }
        set {
            _streamTaskBetterRouteDiscovered = newValue
        }
    }
    
    @available(iOS 9.0, macOS 10.11, tvOS 9.0, *)
    open var streamTaskDidBecomeInputAndOutputStreams: ((URLSession, URLSessionStreamTask, InputStream, OutputStream) -> Void)? {
        get {
            return _streamTaskDidBecomeInputStream as? (URLSession, URLSessionStreamTask, InputStream, OutputStream) -> Void
        }
        set {
            _streamTaskDidBecomeInputStream = newValue
        }
    }
    
    #endif
    
    weak var sessionManager: LGURLSessionManager?
    
    private var requests = LGWeakValueDictionary<Int, LGHTTPRequest>()
    
    open subscript(task: URLSessionTask) -> LGHTTPRequest? {
        get {
            return requests[task.taskIdentifier]
        }
        set {
            requests[task.taskIdentifier] = newValue
        }
    }
    
    private var streamDownloadRequests = LGWeakValueDictionary<String, LGStreamDownloadRequest>()
    open subscript(url: LGURLConvertible) -> LGStreamDownloadRequest? {
        get {
            do {
                let urlString = try url.asURL().absoluteString
                return streamDownloadRequests[urlString]
            } catch {
                return nil
            }
        }
        set {
            do {
                let urlString = try url.asURL().absoluteString
                streamDownloadRequests[urlString] = newValue
            } catch {
            }
        }
    }
    
    public override init() {
        super.init()
    }
}

// MARK: - URLSessionDelegate

extension LGURLSessionDelegate: URLSessionDelegate {
    
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        sessionDidBecomeInvalidWithError?(session, error)
    }
    
    public func urlSession(_ session: URLSession,
                           didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    {
        if sessionDidReceiveChallengeWithCompletion != nil {
            sessionDidReceiveChallengeWithCompletion?(session, challenge, completionHandler)
            return
        }
        
        var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
        var credential: URLCredential?
        
        if let sessionDidReceiveChallenge = sessionDidReceiveChallenge {
            (disposition, credential) = sessionDidReceiveChallenge(session, challenge)
        } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            let host = challenge.protectionSpace.host
            
            if  let serverTrustPolicy = session.serverTrustPolicyManager?.serverTrustPolicy(forHost: host),
                let serverTrust = challenge.protectionSpace.serverTrust
            {
                if serverTrustPolicy.evaluate(serverTrust, forHost: host) {
                    disposition = .useCredential
                    credential = URLCredential(trust: serverTrust)
                } else {
                    disposition = .cancelAuthenticationChallenge
                }
            }
        }
        
        completionHandler(disposition, credential)
    }
    
    #if !os(macOS)
    
    open func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        sessionDidFinishEventsForBackgroundURLSession?(session)
    }
    
    #endif
}

// MARK: - URLSessionTaskDelegate

extension LGURLSessionDelegate: URLSessionTaskDelegate {
    
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           willPerformHTTPRedirection response: HTTPURLResponse,
                           newRequest request: URLRequest,
                           completionHandler: @escaping (URLRequest?) -> Void)
    {
        if taskWillPerformHTTPRedirectionWithCompletion != nil {
            taskWillPerformHTTPRedirectionWithCompletion?(session, task, response, request, completionHandler)
            return
        }
        
        var redirectRequest: URLRequest? = request
        
        if let taskWillPerformHTTPRedirection = taskWillPerformHTTPRedirection {
            redirectRequest = taskWillPerformHTTPRedirection(session, task, response, request)
        }
        
        completionHandler(redirectRequest)
    }
    
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    {
        if taskDidReceiveChallengeWithCompletion != nil {
            taskDidReceiveChallengeWithCompletion?(session, task, challenge, completionHandler)
            return
        }
        
        
        if let taskDidReceiveChallenge = taskDidReceiveChallenge {
            let result = taskDidReceiveChallenge(session, task, challenge)
            completionHandler(result.0, result.1)
        } else if let delegate = self[task]?.delegate {
            delegate.urlSession(session,
                                task: task,
                                didReceive: challenge,
                                completionHandler: completionHandler)
        } else {
            urlSession(session, didReceive: challenge, completionHandler: completionHandler)
        }
    }
    
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           needNewBodyStream completionHandler: @escaping (InputStream?) -> Void)
    {
        if taskNeedNewBodyStreamWithCompletion != nil {
            taskNeedNewBodyStreamWithCompletion?(session, task, completionHandler)
            return
        }
        
        if let taskNeedNewBodyStream = taskNeedNewBodyStream {
            completionHandler(taskNeedNewBodyStream(session, task))
        } else if let delegate = self[task]?.delegate {
            delegate.urlSession(session, task: task, needNewBodyStream: completionHandler)
        }
    }
    
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           didSendBodyData bytesSent: Int64,
                           totalBytesSent: Int64,
                           totalBytesExpectedToSend: Int64)
    {
        if let taskDidSendBodyData = taskDidSendBodyData {
            taskDidSendBodyData(session, task, bytesSent, totalBytesSent, totalBytesExpectedToSend)
        } else if let delegate = self[task]?.delegate as? LGUploadTaskDelegate {
            delegate.URLSession(session,
                                task: task,
                                didSendBodyData: bytesSent,
                                totalBytesSent: totalBytesSent,
                                totalBytesExpectedToSend: totalBytesExpectedToSend)
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let completeTask: (URLSession, URLSessionTask, Error?) -> Void = { [weak self] session, task, error in
            guard let strongSelf = self else { return }
            
            strongSelf.taskDidComplete?(session, task, error)
            
            if let request = strongSelf[task] as? LGStreamDownloadRequest, let key = request.request?.url?.absoluteString {
                strongSelf[key] = nil
            }
            
            strongSelf[task]?.delegate.urlSession(session, task: task, didCompleteWithError: error)
            
            strongSelf[task] = nil
        }
        
        guard let request = self[task], let _ = sessionManager else {
            completeTask(session, task, error)
            return
        }
        
        var error: Error? = error
        
        if request.delegate.error != nil {
            error = request.delegate.error
        }
        
        completeTask(session, task, error)
    }
    
    #if !os(watchOS)
    
    @available(iOS 10.0, macOS 10.12, tvOS 10.0, *)
    open func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        self[task]?.delegate.metrics = metrics
    }
    
    #endif
}

// MARK: - URLSessionDataDelegate

extension LGURLSessionDelegate: URLSessionDataDelegate {
    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didReceive response: URLResponse,
                           completionHandler: @escaping (URLSession.ResponseDisposition) -> Void)
    {
        if dataTaskDidReceiveResponseWithCompletion != nil {
            dataTaskDidReceiveResponseWithCompletion?(session, dataTask, response, completionHandler)
        }  else if let delegate = self[dataTask]?.delegate as? LGDataTaskDelegate {
            delegate.urlSession(session,
                                dataTask: dataTask,
                                didReceive: response,
                                completionHandler: completionHandler)
        } else {
            var disposition: URLSession.ResponseDisposition = .allow
            
            if let dataTaskDidReceiveResponse = dataTaskDidReceiveResponse {
                disposition = dataTaskDidReceiveResponse(session, dataTask, response)
            }
            
            completionHandler(disposition)
        }
    }
    
    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didBecome downloadTask: URLSessionDownloadTask)
    {
        if let dataTaskDidBecomeDownloadTask = dataTaskDidBecomeDownloadTask {
            dataTaskDidBecomeDownloadTask(session, dataTask, downloadTask)
        } else {
            self[downloadTask]?.delegate = LGDownloadTaskDelegate(task: downloadTask)
        }
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if let dataTaskDidReceiveData = dataTaskDidReceiveData {
            dataTaskDidReceiveData(session, dataTask, data)
        } else if let delegate = self[dataTask]?.delegate as? LGDataTaskDelegate {
            delegate.urlSession(session, dataTask: dataTask, didReceive: data)
        }
    }
    
    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           willCacheResponse proposedResponse: CachedURLResponse,
                           completionHandler: @escaping (CachedURLResponse?) -> Void)
    {
        if dataTaskWillCacheResponseWithCompletion != nil {
            dataTaskWillCacheResponseWithCompletion?(session, dataTask, proposedResponse, completionHandler)
            return
        }
        
        if let dataTaskWillCacheResponse = dataTaskWillCacheResponse {
            completionHandler(dataTaskWillCacheResponse(session, dataTask, proposedResponse))
        } else if let delegate = self[dataTask]?.delegate as? LGDataTaskDelegate {
            delegate.urlSession(session,
                                dataTask: dataTask,
                                willCacheResponse: proposedResponse,
                                completionHandler: completionHandler)
        } else {
            completionHandler(proposedResponse)
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension LGURLSessionDelegate: URLSessionDownloadDelegate {
    
    open func urlSession(_ session: URLSession,
                         downloadTask: URLSessionDownloadTask,
                         didFinishDownloadingTo location: URL)
    {
        if let downloadTaskDidFinishDownloadingToURL = downloadTaskDidFinishDownloadingToURL {
            downloadTaskDidFinishDownloadingToURL(session, downloadTask, location)
        } else if let delegate = self[downloadTask]?.delegate as? LGDownloadTaskDelegate {
            delegate.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
        }
    }
    
    open func urlSession(_ session: URLSession,
                         downloadTask: URLSessionDownloadTask,
                         didWriteData bytesWritten: Int64,
                         totalBytesWritten: Int64,
                         totalBytesExpectedToWrite: Int64)
    {
        if let downloadTaskDidWriteData = downloadTaskDidWriteData {
            downloadTaskDidWriteData(session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
        } else if let delegate = self[downloadTask]?.delegate as? LGDownloadTaskDelegate {
            delegate.urlSession(
                session,
                downloadTask: downloadTask,
                didWriteData: bytesWritten,
                totalBytesWritten: totalBytesWritten,
                totalBytesExpectedToWrite: totalBytesExpectedToWrite
            )
        }
    }
    
    open func urlSession(_ session: URLSession,
                         downloadTask: URLSessionDownloadTask,
                         didResumeAtOffset fileOffset: Int64,
                         expectedTotalBytes: Int64)
    {
        if let downloadTaskDidResumeAtOffset = downloadTaskDidResumeAtOffset {
            downloadTaskDidResumeAtOffset(session, downloadTask, fileOffset, expectedTotalBytes)
        } else if let delegate = self[downloadTask]?.delegate as? LGDownloadTaskDelegate {
            delegate.urlSession(
                session,
                downloadTask: downloadTask,
                didResumeAtOffset: fileOffset,
                expectedTotalBytes: expectedTotalBytes
            )
        }
    }
}

// MARK: - URLSessionStreamDelegate

#if !os(watchOS)
@available(iOS 9.0, macOS 10.11, tvOS 9.0, *)
extension LGURLSessionDelegate: URLSessionStreamDelegate {
    
    open func urlSession(_ session: URLSession, readClosedFor streamTask: URLSessionStreamTask) {
        streamTaskReadClosed?(session, streamTask)
    }
    
    
    open func urlSession(_ session: URLSession, writeClosedFor streamTask: URLSessionStreamTask) {
        streamTaskWriteClosed?(session, streamTask)
    }
    
    
    open func urlSession(_ session: URLSession, betterRouteDiscoveredFor streamTask: URLSessionStreamTask) {
        streamTaskBetterRouteDiscovered?(session, streamTask)
    }
    
    
    open func urlSession(_ session: URLSession,
                         streamTask: URLSessionStreamTask,
                         didBecome inputStream: InputStream,
                         outputStream: OutputStream)
    {
        streamTaskDidBecomeInputAndOutputStreams?(session, streamTask, inputStream, outputStream)
    }
}

#endif

