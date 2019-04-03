//
//  LGWeakValueDictionary.swift
//  LGWebImage
//
//  Created by 龚杰洪 on 2019/3/14.
//  Copyright © 2019年 龚杰洪. All rights reserved.
//

import Foundation


/// 替代NSMapTable的弱Value字典，线程安全
public class LGWeakValueDictionary<KeyType: Hashable, ValueType: AnyObject> {
    
    /// 存储空间
    private var dictionary: Dictionary<KeyType, LGWeakBox<ValueType>>
    
    /// deinit监视器
    private var deinitWatcherKey: String = "DeinitWatcher"
    
    /// 线程安全互斥锁
    private var lock: pthread_mutex_t = pthread_mutex_t()

    
    public var block: (ValueType) -> () = { _ in }
    
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
    
    public func value(forKey key: KeyType) -> ValueType? {
        pthread_mutex_lock(&lock)
        defer {
            pthread_mutex_unlock(&lock)
        }
        return dictionary[key]?.value
    }
    
    @discardableResult
    public func removeValue(forKey key: KeyType) -> ValueType? {
        pthread_mutex_lock(&lock)
        defer {
            pthread_mutex_unlock(&lock)
        }
        return self.dictionary.removeValue(forKey: key)?.value
    }

    public var count: Int {
        pthread_mutex_lock(&lock)
        defer {
            pthread_mutex_unlock(&lock)
        }
        return self.dictionary.count
    }
    
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

fileprivate class LGWeakBox<T: AnyObject> {
    weak var value: T?
    init(_ value: T?) {
        self.value = value
    }
}

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

