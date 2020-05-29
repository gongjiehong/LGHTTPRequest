# LGHTTPRequest
Swift版网络请求和文件下载库

# 功能
- [x] HTTP请求发送，响应，处理
- [x] 参数的URL/JSON/文件编码，AES加密处理
- [x] 上传文件，数据，stream等
- [x] 下载文件，支持断点续传
- [x] HTTP基础认证
- [x] HTTP返回数据验证
- [x] 上传和下载进度回调
- [x] TLS证书密钥管理
- [x] 网络状态检查

# 环境要求
- iOS 12.2+
- Xcode 11.5+
- Swift 5.0+
- CommonCrypto, Dispatch, Foundation.framework, SystemConfiguration.framework, CoreTelephony.framework

# 示例

// MARK: - 请求
    
    @discardableResult
    public func requestJsonOperation(paramaters: LGParameters,
                                     action: String,
                                     serviceHost: LGURLConvertible = kServiceHost,
                                     completionHandler: @escaping LGWebServiceHelper<JsonBaseModel>.JsonObjectHandler,
                                     exceptionHandler: @escaping (Error?) -> Void) -> LGDataRequest?
    {
        if !NetStateHelper.default.isReachable {
            exceptionHandler(LGResponseProcessError.notConnectedToInternet)
            return nil
        }
        let paramEncoder = LGAESEncoding.default
        var param = paramaters
        param = param.merged(with: _LGWebServiceHelper.publicParam)
        param["client_time"] = "\(time(nil))"
        param["api_name"] = action
        param["interface_version"] = interfaceVersionDic[action]
        
        var host: String
        do {
            let hostURL = try serviceHost.asURL()
            host = "\(hostURL.absoluteString)/\(interfaceVersionDic[action] ?? defaultApiVersion)/\(action)"
        } catch  {
            exceptionHandler(error)
            return nil
        }
        
        
        #if DEBUG
            println(param)
        #else
            if isOpenChinaSpeedUp() {
                if let temp = (host as? String)?.replaceApiHostIfNeeded() {
                    host = temp
                }
            }
        #endif
        let request = LGURLSessionManager.default.request(host,
                                                          method: LGHTTPMethod.post,
                                                          parameters: param,
                                                          encoding: paramEncoder,
                                                          headers: ["APPID": kLGAppId, "SeeesionID": getAccessToken()])
        request.validate().responseData { (dataResponse) in
            if dataResponse.result.isFailure {
                exceptionHandler(dataResponse.result.error)
            } else {
                let data = dataResponse.result.value!
                do {
                    guard let base64DecryptData = Data(base64Encoded: data) else {
                        throw LGResponseProcessError.serverDataDecryptFailed
                    }
                    var decryptData = try base64DecryptData.aesDecrypt(with: kLGAppKey)
                    
                    #if DEBUG
                        println(String(data: decryptData, encoding: String.Encoding.utf8) ?? "")
                    #else
                        if self.isOpenChinaSpeedUp() {
                            if var jsonString = String(data: decryptData, encoding: String.Encoding.utf8) {
                                jsonString = jsonString.replaceImageHostIfNeeded()
                                if let replacedData = jsonString.data(using: String.Encoding.utf8) {
                                    decryptData = replacedData
                                }
                            }
                        }
                    #endif
                    let option = JSONSerialization.ReadingOptions.allowFragments
                    let jsonObject = try JSONSerialization.jsonObject(with: decryptData,
                                                                      options: option)
                    let container = LGRequestResultContainer<JsonBaseModel>(jsonObject: jsonObject,
                                                                                type: .originData)
                    if container.isValid {
                        completionHandler(jsonObject)
                    } else {
                        exceptionHandler(container.error)
                    }
                } catch {
                    exceptionHandler(LGResponseProcessError.serverDataDecryptFailed)
                }
            }
        }
        return request
    }
    
# 协议与许可
MIT
