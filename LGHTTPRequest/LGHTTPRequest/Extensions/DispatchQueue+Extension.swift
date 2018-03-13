//
//  DispatchQueue+Extension.swift
//  LGHTTPRequest
//
//  Created by 龚杰洪 on 2018/3/9.
//  Copyright © 2018年 龚杰洪. All rights reserved.
//

import Dispatch
import Foundation


/// 优先级 main > userInteractive > userInitiated > default > utility > background
/// default由系统管理，开发者一般不使用这个
extension DispatchQueue {
    
    /// 除main外最高优先级，主要用来处理需要跟用户交互的任务，例如动画，需要在一瞬间完成
    public static var userInteractive: DispatchQueue { return DispatchQueue.global(qos: .userInteractive) }
    
    /// 处理由用户发起的并且需要立即得到结果的任务, 主要是一些后续交互，例如滑动table，预加载后续的内容
    public static var userInitiated: DispatchQueue { return DispatchQueue.global(qos: .userInitiated) }
    
    /// 需要消耗比较长时间的任务，比如下载
    public static var utility: DispatchQueue { return DispatchQueue.global(qos: .utility) }
    
    /// 处理大量耗时的任务，或者不用用户感知的任务，持续更长时间
    public static var background: DispatchQueue { return DispatchQueue.global(qos: .background) }
    
    
    /// 在指定队列中延时执行一项任务
    ///
    /// - Parameters:
    ///   - delay: 延时的时间
    ///   - closure: 执行的任务闭包
    public func after(_ delay: TimeInterval, execute closure: @escaping () -> Void) {
        asyncAfter(deadline: .now() + delay, execute: closure)
    }
}
