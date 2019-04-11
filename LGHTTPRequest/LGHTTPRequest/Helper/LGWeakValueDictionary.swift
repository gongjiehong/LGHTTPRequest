//
//  LGWeakValueDictionary.swift
//  LGWebImage
//
//  Created by 龚杰洪 on 2019/3/14.
//  Copyright © 2019年 龚杰洪. All rights reserved.
//

import Foundation


/// 替代NSMapTable的弱Value字典，线程安全，未实现filter，map等高级方法
public class LGWeakValueDictionary<KeyType: Hashable, ValueType: AnyObject> {
    
    /// 存储空间
    private var dictionary: Dictionary<KeyType, LGWeakBox<ValueType>>
    
    /// deinit监视器
    private var deinitWatcherKey: String = "DeinitWatcher"
    
    /// 线程安全互斥锁
    private var lock: pthread_mutex_t = pthread_mutex_t()

    
    /// 初始化，可以预置一部分数据，否则数据为空
    ///
    /// - Parameters:
    ///   - dic: 预置数据，默认空
    ///   - : 默认空
    public init(_ dic: Dictionary<KeyType, ValueType> = [:]) {
        
        pthread_mutex_init(&lock, nil)
        
        dictionary = Dictionary<KeyType, LGWeakBox<ValueType>>()
        for (key, value) in dic {
            setValue(value, forKey: key)
        }
    }
    
    /// subscript get and set value
    ///
    /// - Parameter key: key to set or get
    public subscript(key: KeyType) -> ValueType? {
        get {
            return value(forKey: key)
        } set {
            setValue(newValue, forKey: key)
        }
    }
    
    /// 存储值，当value为空时删除当前存储
    ///
    /// - Parameters:
    ///   - value: 存储值，可以为空
    ///   - key: key
    public func setValue(_ value: ValueType?, forKey key: KeyType) {
        pthread_mutex_lock(&lock)
        defer {
            pthread_mutex_unlock(&lock)
        }
        if let value = value {
            let weakBox = LGWeakBox(value)
            
            let watcher = LGDeinitWatcher { [weak self] in
                guard let strongSelf = self else {return}
                strongSelf.removeValue(forKey: key)
            }
            
            objc_setAssociatedObject(value,
                                     &deinitWatcherKey,
                                     watcher,
                                     objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            self.dictionary[key] = weakBox
            
        } else {
            dictionary[key] = nil
        }
    }
    
    /// 取值
    ///
    /// - Parameter key: 需要获取值的key
    /// - Returns: 值
    public func value(forKey key: KeyType) -> ValueType? {
        pthread_mutex_lock(&lock)
        defer {
            pthread_mutex_unlock(&lock)
        }
        return dictionary[key]?.value
    }
    
    /// 通过key删除存储z的值
    ///
    /// - Parameter key: 需要删除的key
    /// - Returns: 被删除的值
    @discardableResult
    public func removeValue(forKey key: KeyType) -> ValueType? {
        pthread_mutex_lock(&lock)
        defer {
            pthread_mutex_unlock(&lock)
        }
        return self.dictionary.removeValue(forKey: key)?.value
    }

    /// 总数
    public var count: Int {
        pthread_mutex_lock(&lock)
        defer {
            pthread_mutex_unlock(&lock)
        }
        return self.dictionary.count
    }
    
    /// 是否为空
    public var isEmpty: Bool {
        pthread_mutex_lock(&lock)
        defer {
            pthread_mutex_unlock(&lock)
        }
        return self.dictionary.isEmpty
    }
    
    deinit {
        pthread_mutex_destroy(&lock)
    }
}

/// weak方式存储对应的值
fileprivate class LGWeakBox<T: AnyObject> {
    weak var value: T?
    init(_ value: T?) {
        self.value = value
    }
}

/// 销毁监视器，结合LGWeakBox将其设置为存储值的一个动态属性，当宿主被释放后当前对象也会释放，从而实现weak通知
fileprivate class LGDeinitWatcher {
    typealias Callback = () -> ()
    let callback: Callback
    
    init(_ callback: @escaping Callback) {
        self.callback = callback
    }
    
    deinit {
        callback()
    }
}

