//
//  LGHTTPRequestSessionManager.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2017/12/25.
//  Copyright © 2017年 龚杰洪. All rights reserved.
//

import Foundation


/// 负责创建和管理LGHTTPRequest及其子类对象，以及底层的URLSession
open class LGURLSessionManager {
    
    /// 生成task的底层session
    public let session: URLSession
    
    /// 处理session委托方法的对象，主要将委托方法转换为闭包进行处理
    public let delegate: LGURLSessionDelegate
    
    /// 每个HTTP body在内存中的上限值，默认1MB，操作将使用stream进行处理
    public static let multipartFormDataEncodingMemoryThreshold: UInt64 = 1024 * 1024
    
    /// task创建后是否马上开始执行请求，默认true
    open var startRequestsImmediately: Bool = true
    
    /// URLRequest的一些通用或默认设置在adapter内完成
    open var adapter: LGRequestAdapter?
    
    /// 后台线程处理完成后的回调block
    open var backgroundCompletionHandler: (() -> Void)?
    
    /// 全局处理队列
    let queue = DispatchQueue(label: "com.LGHTTPRequest.SessionManager." + UUID().uuidString)
    
    // MARK: -  构造方法
    
    /// 通过 configuration，delegate，serverTrustPolicyManager 初始化
    ///
    /// - Parameters:
    ///   - configuration: URLSessionConfiguration, 默认配置为URLSessionConfiguration.default，可设置缓存，cookie等一系列配置
    ///   - delegate: 代理对象，对象负责将URLSession委托进行处理并转换为闭包回调
    ///   - serverTrustPolicyManager: 服务器信任策略管理工具对象
    public init(configuration: URLSessionConfiguration = URLSessionConfiguration.default,
                delegate: LGURLSessionDelegate = LGURLSessionDelegate(),
                serverTrustPolicyManager: LGServerTrustPolicyManager? = nil)
    {
        self.delegate = delegate
        self.session = URLSession(configuration: configuration,
                                  delegate: delegate,
                                  delegateQueue: nil)
        
        commonInit(serverTrustPolicyManager: serverTrustPolicyManager)
    }
    
    /// 通过 session，delegate，serverTrustPolicyManager 初始化
    ///
    /// - Parameters:
    ///   - session: 底层session
    ///   - delegate: 代理对象，对象负责将URLSession委托进行处理并转换为闭包回调
    ///   - serverTrustPolicyManager: 服务器信任策略管理工具对象
    public init?(session: URLSession,
                 delegate: LGURLSessionDelegate,
                 serverTrustPolicyManager: LGServerTrustPolicyManager? = nil)
    {
        guard delegate === session.delegate else { return nil }
        
        self.delegate = delegate
        self.session = session
        
        commonInit(serverTrustPolicyManager: serverTrustPolicyManager)
    }
    
    
    /// 初始化服务器信任策略，处理后台task完成后的回调
    ///
    /// - Parameter serverTrustPolicyManager: 服务器信任策略管理工具对象
    private func commonInit(serverTrustPolicyManager: LGServerTrustPolicyManager?) {
        session.serverTrustPolicyManager = serverTrustPolicyManager
        
        delegate.sessionManager = self
        
        delegate.sessionDidFinishEventsForBackgroundURLSession = { [weak self] session in
            guard let strongSelf = self else { return }
            DispatchQueue.main.async { strongSelf.backgroundCompletionHandler?() }
        }
    }
    
    /// 本类默认单例
    public static let `default`: LGURLSessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = LGURLSessionManager.defaultHTTPHeaders
        // The default value is 6 in macOS, or 4 in iOS.
//        configuration.httpMaximumConnectionsPerHost = 6
        
        return LGURLSessionManager(configuration: configuration)
    }()
    
    
    /// 默认header，包含一些客户端信息和当前动态库信息
    public static let defaultHTTPHeaders: LGHTTPHeaders = {
        let acceptEncoding: String = "gzip;q=1.0, compress;q=0.5"
        
        let acceptLanguage = Locale.preferredLanguages.prefix(6).enumerated().map { index, languageCode in
            let quality = 1.0 - (Double(index) * 0.1)
            return "\(languageCode);q=\(quality)"
            }.joined(separator: ", ")
        
        let userAgent: String = {
            if let info = Bundle.main.infoDictionary {
                let executable = info[kCFBundleExecutableKey as String] as? String ?? "Unknown"
                let bundle = info[kCFBundleIdentifierKey as String] as? String ?? "Unknown"
                let appVersion = info["CFBundleShortVersionString"] as? String ?? "Unknown"
                let appBuild = info[kCFBundleVersionKey as String] as? String ?? "Unknown"
                
                let osNameVersion: String = {
                    let version = ProcessInfo.processInfo.operatingSystemVersion
                    let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
                    
                    let osName: String = {
                        #if os(iOS)
                            return "iOS"
                        #elseif os(watchOS)
                            return "watchOS"
                        #elseif os(tvOS)
                            return "tvOS"
                        #elseif os(macOS)
                            return "OS X"
                        #elseif os(Linux)
                            return "Linux"
                        #else
                            return "Unknown"
                        #endif
                    }()
                    
                    return "\(osName) \(versionString)"
                }()
                
                let thisFrameworkVersion: String = {
                    guard   let thisBundleInfo = Bundle(for: LGURLSessionManager.self).infoDictionary,
                        let build = thisBundleInfo["CFBundleShortVersionString"]
                        else { return "Unknown" }
                    
                    return "LGHTTPRequest/\(build)"
                }()
                
                return  "\(executable)/\(appVersion) (\(bundle); " +
                "build:\(appBuild); \(osNameVersion)) \(thisFrameworkVersion)"
            }
            
            return "LGHTTPRequest"
        }()
        
        return [
            "Accept-Encoding": acceptEncoding,
            "Accept-Language": acceptLanguage,
            "User-Agent": userAgent
        ]
    }()
    
    /// 析构
    deinit {
        self.session.invalidateAndCancel()
    }
    
    @discardableResult
    open func request(_ url: LGURLConvertible,
                      method: LGHTTPMethod = .get,
                      parameters: LGParameters? = nil,
                      encoding: LGParameterEncoding = LGURLEncoding.default,
                      headers: LGHTTPHeaders? = nil) -> LGDataRequest
    {
        var originalRequest: URLRequest?
        
        do {
            originalRequest = try URLRequest(url: url, method: method, headers: headers)
            let encodedURLRequest = try encoding.encode(originalRequest!, with: parameters)
            return request(encodedURLRequest)
        } catch {
            return request(originalRequest, failedWith: error)
        }
    }
    
    @discardableResult
    open func request(_ urlRequest: LGURLRequestConvertible) -> LGDataRequest {
        var originalRequest: URLRequest?
        
        do {
            originalRequest = try urlRequest.asURLRequest()
            let originalTask = LGDataRequest.Requestable(urlRequest: originalRequest!)
            
            let task = try originalTask.task(session: session, adapter: adapter, queue: queue)
            let request = LGDataRequest(session: session, requestTask: .data(originalTask, task))
            
            delegate[task] = request
            
            if startRequestsImmediately {
                request.resume()
            }
            
            return request
        } catch {
            return request(originalRequest, failedWith: error)
        }
    }
    
    // MARK: Private - Request Implementation
    
    private func request(_ urlRequest: URLRequest?, failedWith error: Error) -> LGDataRequest {
        var requestTask: LGHTTPRequest.RequestTask = .data(nil, nil)
        
        if let urlRequest = urlRequest {
            let originalTask = LGDataRequest.Requestable(urlRequest: urlRequest)
            requestTask = .data(originalTask, nil)
        }
        
        let underlyingError = error
        let request = LGDataRequest(session: session, requestTask: requestTask, error: underlyingError)
        
        if startRequestsImmediately {
            request.resume()
        }
        
        return request
    }
    
    // MARK: - Download Request
    
    // MARK: URL Request
    @discardableResult
    open func download(_ url: LGURLConvertible,
                       method: LGHTTPMethod = .get,
                       parameters: LGParameters? = nil,
                       encoding: LGParameterEncoding = LGURLEncoding.default,
                       headers: LGHTTPHeaders? = nil,
                       to destinationURL: URL? = nil) -> LGDownloadRequest
    {
        do {
            let urlRequest = try URLRequest(url: url, method: method, headers: headers)
            let encodedURLRequest = try encoding.encode(urlRequest, with: parameters)
            return download(encodedURLRequest, to: destinationURL)
        } catch {
            return download(nil, to: destinationURL, failedWith: error)
        }
    }
    
    @discardableResult
    open func download(_ urlRequest: LGURLRequestConvertible,
                       to destination: URL? = nil) -> LGDownloadRequest
    {
        do {
            let urlRequest = try urlRequest.asURLRequest()
            return download(.request(urlRequest), to: destination)
        } catch {
            return download(nil, to: destination, failedWith: error)
        }
    }
    
    
    @discardableResult
    open func download(resumingWith resumeData: Data,
                       to destinationURL: URL? = nil) -> LGDownloadRequest
    {
        return download(.resumeData(resumeData), to: destinationURL)
    }
    
    // MARK: Private - Download Implementation
    
    private func download(_ downloadable: LGDownloadRequest.Downloadable,
                          to destinationURL: URL?) -> LGDownloadRequest
    {
        do {
            let task = try downloadable.task(session: session, adapter: adapter, queue: queue)
            let download = LGDownloadRequest(session: session, requestTask: .download(downloadable, task))
            
            download.downloadDelegate.destinationURL = destinationURL
            
            delegate[task] = download
            
            if startRequestsImmediately {
                download.resume()
            }
            
            return download
        } catch {
            return download(downloadable, to: destinationURL, failedWith: error)
        }
    }
    
    private func download(_ downloadable: LGDownloadRequest.Downloadable?,
                          to destinationURL: URL?,
                          failedWith error: Error) -> LGDownloadRequest
    {
        var downloadTask: LGHTTPRequest.RequestTask = .download(nil, nil)
        
        if let downloadable = downloadable {
            downloadTask = .download(downloadable, nil)
        }
        
        
        let downloadRequest = LGDownloadRequest(session: session, requestTask: downloadTask, error: error)
        downloadRequest.downloadDelegate.destinationURL = destinationURL
        
        if startRequestsImmediately {
            downloadRequest.resume()
        }
        
        return downloadRequest
    }
    
    // MARK: - Upload Request
    
    // MARK: File
    
    @discardableResult
    open func upload(_ fileURL: URL,
                     to url: LGURLConvertible,
                     method: LGHTTPMethod = .post,
                     headers: LGHTTPHeaders? = nil) -> LGUploadRequest
    {
        do {
            let urlRequest = try URLRequest(url: url, method: method, headers: headers)
            return upload(fileURL, with: urlRequest)
        } catch {
            return upload(nil, failedWith: error)
        }
    }
    
    
    @discardableResult
    open func upload(_ fileURL: URL, with urlRequest: LGURLRequestConvertible) -> LGUploadRequest {
        do {
            let urlRequest = try urlRequest.asURLRequest()
            return upload(.file(fileURL, urlRequest))
        } catch {
            return upload(nil, failedWith: error)
        }
    }
    
   
    @discardableResult
    open func upload(_ data: Data,
                     to url: LGURLConvertible,
                     method: LGHTTPMethod = .post,
                     headers: LGHTTPHeaders? = nil) -> LGUploadRequest
    {
        do {
            let urlRequest = try URLRequest(url: url, method: method, headers: headers)
            return upload(data, with: urlRequest)
        } catch {
            return upload(nil, failedWith: error)
        }
    }
    
   
    @discardableResult
    open func upload(_ data: Data, with urlRequest: LGURLRequestConvertible) -> LGUploadRequest {
        do {
            let urlRequest = try urlRequest.asURLRequest()
            return upload(.data(data, urlRequest))
        } catch {
            return upload(nil, failedWith: error)
        }
    }
    
    
    @discardableResult
    open func upload(_ stream: InputStream,
                     to url: LGURLConvertible,
                     method: LGHTTPMethod = .post,
                     headers: LGHTTPHeaders? = nil) -> LGUploadRequest
    {
        do {
            let urlRequest = try URLRequest(url: url, method: method, headers: headers)
            return upload(stream, with: urlRequest)
        } catch {
            return upload(nil, failedWith: error)
        }
    }
    
    
    @discardableResult
    open func upload(_ stream: InputStream, with urlRequest: LGURLRequestConvertible) -> LGUploadRequest {
        do {
            let urlRequest = try urlRequest.asURLRequest()
            return upload(.stream(stream, urlRequest))
        } catch {
            return upload(nil, failedWith: error)
        }
    }
    
    // MARK: MultipartFormData
    
    public enum MultipartFormDataEncodingResult {
        case success(request: LGUploadRequest, streamingFromDisk: Bool, streamFileURL: URL?)
        case failure(Error)
    }
    
    open func upload(multipartFormData: @escaping (LGMultipartFormData) -> Void,
                     usingThreshold encodingMemoryThreshold: UInt64 = multipartFormDataEncodingMemoryThreshold,
                     to url: LGURLConvertible,
                     method: LGHTTPMethod = .post,
                     headers: LGHTTPHeaders? = nil,
                     encodingCompletion: ((MultipartFormDataEncodingResult) -> Void)?)
    {
        do {
            let urlRequest = try URLRequest(url: url, method: method, headers: headers)
            
            return upload(multipartFormData: multipartFormData,
                          usingThreshold: encodingMemoryThreshold,
                          with: urlRequest,
                          encodingCompletion: encodingCompletion)
        } catch {
            DispatchQueue.main.async { encodingCompletion?(.failure(error)) }
        }
    }
    
    open func upload(multipartFormData: @escaping (LGMultipartFormData) -> Void,
        usingThreshold encodingMemoryThreshold: UInt64 = multipartFormDataEncodingMemoryThreshold,
        with urlRequest: LGURLRequestConvertible,
        encodingCompletion: ((MultipartFormDataEncodingResult) -> Void)?)
    {
        DispatchQueue.global(qos: .utility).async {
            let formData = LGMultipartFormData()
            multipartFormData(formData)
            
            var tempFileURL: URL?
            
            do {
                var urlRequestWithContentType = try urlRequest.asURLRequest()
                urlRequestWithContentType.setValue(formData.contentType, forHTTPHeaderField: "Content-Type")
                
                let isBackgroundSession = self.session.configuration.identifier != nil
                
                if formData.contentLength < encodingMemoryThreshold && !isBackgroundSession {
                    let data = try formData.encode()
                    
                    let encodingResult = MultipartFormDataEncodingResult.success(
                        request: self.upload(data, with: urlRequestWithContentType),
                        streamingFromDisk: false,
                        streamFileURL: nil
                    )
                    
                    DispatchQueue.main.async { encodingCompletion?(encodingResult) }
                } else {
                    let fileManager = FileManager.default
                    let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    let directoryURL = tempDirectoryURL.appendingPathComponent("com.lghttprequest.manager/multipart.form.data")
                    let fileName = UUID().uuidString
                    let fileURL = directoryURL.appendingPathComponent(fileName)
                    
                    tempFileURL = fileURL
                    
                    var directoryError: Error?
                    
                    // Create directory inside serial queue to ensure two threads don't do this in parallel
                    self.queue.sync {
                        do {
                            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
                        } catch {
                            directoryError = error
                        }
                    }
                    
                    if let directoryError = directoryError { throw directoryError }
                    
                    try formData.writeEncodedData(to: fileURL)
                    
                    let upload = self.upload(fileURL, with: urlRequestWithContentType)
                    
                    // Cleanup the temp file once the upload is complete
                    upload.delegate.queue.addOperation {
                        do {
                            try FileManager.default.removeItem(at: fileURL)
                        } catch {
                            // No-op
                        }
                    }
                    
                    DispatchQueue.main.async {
                        let encodingResult = MultipartFormDataEncodingResult.success(
                            request: upload,
                            streamingFromDisk: true,
                            streamFileURL: fileURL
                        )
                        
                        encodingCompletion?(encodingResult)
                    }
                }
            } catch {
                // Cleanup the temp file in the event that the multipart form data encoding failed
                if let tempFileURL = tempFileURL {
                    do {
                        try FileManager.default.removeItem(at: tempFileURL)
                    } catch {
                        // No-op
                    }
                }
                
                DispatchQueue.main.async { encodingCompletion?(.failure(error)) }
            }
        }
    }
    
    // MARK: Private - Upload Implementation
    
    private func upload(_ uploadable: LGUploadRequest.Uploadable) -> LGUploadRequest {
        do {
            let task = try uploadable.task(session: session, adapter: adapter, queue: queue)
            let upload = LGUploadRequest(session: session, requestTask: .upload(uploadable, task))
            
            if case let .stream(inputStream, _) = uploadable {
                upload.delegate.taskNeedNewBodyStream = { _, _ in inputStream }
            }
            
            delegate[task] = upload
            
            if startRequestsImmediately { upload.resume() }
            
            return upload
        } catch {
            return upload(uploadable, failedWith: error)
        }
    }
    
    private func upload(_ uploadable: LGUploadRequest.Uploadable?, failedWith error: Error) -> LGUploadRequest {
        var uploadTask: LGHTTPRequest.RequestTask = .upload(nil, nil)
        
        if let uploadable = uploadable {
            uploadTask = .upload(uploadable, nil)
        }
        
        let upload = LGUploadRequest(session: session, requestTask: uploadTask, error: error)
        
        if startRequestsImmediately {
            upload.resume()
        }
        
        return upload
    }
    
#if !os(watchOS)
    
    // MARK: - Stream Request
    
    // MARK: Hostname and Port
    
    /// Creates a `StreamRequest` for bidirectional streaming using the `hostname` and `port`.
    ///
    /// If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.
    ///
    /// - parameter hostName: The hostname of the server to connect to.
    /// - parameter port:     The port of the server to connect to.
    ///
    /// - returns: The created `StreamRequest`.
    @discardableResult
    @available(iOS 9.0, macOS 10.11, tvOS 9.0, *)
    open func stream(withHostName hostName: String, port: Int) -> LGStreamRequest {
        return stream(.stream(hostName: hostName, port: port))
    }
    
    // MARK: NetService
    
    /// Creates a `StreamRequest` for bidirectional streaming using the `netService`.
    ///
    /// If `startRequestsImmediately` is `true`, the request will have `resume()` called before being returned.
    ///
    /// - parameter netService: The net service used to identify the endpoint.
    ///
    /// - returns: The created `StreamRequest`.
    @discardableResult
    @available(iOS 9.0, macOS 10.11, tvOS 9.0, *)
    open func stream(with netService: NetService) -> LGStreamRequest {
        return stream(.netService(netService))
    }
    
    // MARK: Private - Stream Implementation
    
    @available(iOS 9.0, macOS 10.11, tvOS 9.0, *)
    private func stream(_ streamable: LGStreamRequest.Streamable) -> LGStreamRequest {
        do {
            let task = try streamable.task(session: session, adapter: adapter, queue: queue)
            let request = LGStreamRequest(session: session, requestTask: .stream(streamable, task))
            
            delegate[task] = request
            
            if startRequestsImmediately { request.resume() }
            
            return request
        } catch {
            return stream(failedWith: error)
        }
    }
    
    @available(iOS 9.0, macOS 10.11, tvOS 9.0, *)
    private func stream(failedWith error: Error) -> LGStreamRequest {
        let stream = LGStreamRequest(session: session, requestTask: .stream(nil, nil), error: error)
        if startRequestsImmediately { stream.resume() }
        return stream
    }
    
    #endif

}
