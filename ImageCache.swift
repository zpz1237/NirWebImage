//
//  ImageCache.swift
//  NirWebImage
//
//  Created by Nirvana on 11/15/15.
//  Copyright © 2015 NSNirvana. All rights reserved.
//

import UIKit

public typealias RetrieveImageDiskTask = dispatch_block_t

private let cacheReverseDNS = "com.NirWebImage.ImageCache."
private let ioQueueName = "com.NirWebImage.ImageCache.ioQueue."
private let processQueueName = "com.NirWebImage.ImageCache.processQueue."
public let NirWebImageDidCleanDiskCacheNotification = "com.NirWebImage.DidCleanDiskCacheNotification"
public let NirWebImageDiskCacheCleanedHashKey = "com.NirWebImage.cleanedHash"
private let defaultCacheName = "default"
private let defaultCacheInstance = ImageCache(name: defaultCacheName)
private let defaultMaxCachePeriodInSecond: NSTimeInterval = 60 * 60 * 24 * 7

public enum CacheType {
    case None, Memory, Disk
}

public class ImageCache {
    //内存缓存
    private let memoryCache = NSCache()
    public var maxMemoryCost: UInt = 0 {
        didSet {
            self.memoryCache.totalCostLimit = Int(maxMemoryCost)
        }
    }
    
    //硬盘缓存
    private let ioQueue: dispatch_queue_t
    private let diskCachePath: String
    private var fileManager: NSFileManager!
    
    //最大缓存时长
    public var maxCachePeriodInSecond = defaultMaxCachePeriodInSecond
    
    //最大缓存大小，零意味着无限制
    public var MaxDiskCacheSize: UInt = 0
    
    private let processQueue: dispatch_queue_t
    
    public class var defaultCache: ImageCache {
        return defaultCacheInstance
    }
    
    public init(name: String) {
        if name.isEmpty {
            fatalError()
        }
        
        let cacheName = cacheReverseDNS + name
        memoryCache.name = cacheName
        
        let paths = NSSearchPathForDirectoriesInDomains(.CachesDirectory, NSSearchPathDomainMask.UserDomainMask, true)
        diskCachePath = (paths.first! as NSString).stringByAppendingPathComponent(cacheName)
        
        ioQueue = dispatch_queue_create(ioQueueName + name, DISPATCH_QUEUE_SERIAL)
        processQueue = dispatch_queue_create(processQueueName, DISPATCH_QUEUE_CONCURRENT)
        
        dispatch_sync(ioQueue) { () -> Void in
            self.fileManager = NSFileManager()
        }
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "clearMemoryCache", name: UIApplicationDidReceiveMemoryWarningNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "clearExpiredDiskCache", name: UIApplicationWillTerminateNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "backgroundCleanExpiredDiskCache", name: UIApplicationDidEnterBackgroundNotification, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}

public extension ImageCache {
    public func storeImage(image: UIImage, originalData: NSData? = nil, forKey key: String) {
        storeImage(image, originalData: originalData, forKey: key, toDisk: true, completionHandler: nil)
    }
    
    public func storeImage(image: UIImage, originalData: NSData? = nil, forKey key: String, toDisk: Bool, completionHandler: (() -> ())?) {
        memoryCache.setObject(image, forKey: key, cost: image.nir_imageCost)
        
        func callHandlerInMainQueue() {
            if let handler = completionHandler {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    handler()
                })
            }
        }
        
        if toDisk {
            dispatch_async(ioQueue, { () -> Void in
                let imageFormat: ImageFormat
                if let originalData = originalData {
                    imageFormat = originalData.nir_imageFormat
                } else {
                    imageFormat = .Unknown
                }
                
                let data: NSData?
                switch imageFormat {
                case .PNG: data = UIImagePNGRepresentation(image)
                case .JPEG: data = UIImageJPEGRepresentation(image, 1.0)
                case .GIF: data = UIImageGIFRepresentation(image)
                case .Unknown: data = originalData
                }
                
                if let data = data {
                    if !self.fileManager.fileExistsAtPath(self.diskCachePath) {
                        do {
                            try self.fileManager.createDirectoryAtPath(self.diskCachePath, withIntermediateDirectories: true, attributes: nil)
                        } catch {
                        }
                    }
                    
                    self.fileManager.createFileAtPath(self.cachePathForKey(key), contents: data, attributes: nil)
                    callHandlerInMainQueue()
                } else {
                    callHandlerInMainQueue()
                }
            })
        } else {
            callHandlerInMainQueue()
        }
    }
    
    public func removeImageForKey(key: String) {
        removeImageForKey(key, fromDisk: true, completionHandler: nil)
    }
    
    public func removeImageForKey(key: String, fromDisk: Bool, completionHandler: (() -> ())?) {
        memoryCache.removeObjectForKey(key)
        
        func callHandlerInMainQueue() {
            if let handler = completionHandler {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    handler()
                })
            }
        }
        
        if fromDisk {
            dispatch_async(ioQueue, { () -> Void in
                do {
                    try self.fileManager.removeItemAtPath(self.cachePathForKey(key))
                } catch {
                }
            })
        } else {
            callHandlerInMainQueue()
        }
    }
}

extension ImageCache {
    public func retrieveImageForKey(key: String, options: NirWebImageManager.Options, completionHandler: ((UIImage?,CacheType!) -> ())?) -> RetrieveImageDiskTask? {
        guard let completionHandler = completionHandler else {
            return nil
        }
        
        var block: RetrieveImageDiskTask?
        if let image = self.retrieveImageInMemoryCacheForKey(key) {
            if options.shouldDecode {
                dispatch_async(self.processQueue, { () -> Void in
                    let result = image.nir_decodeImage(scale: options.scale)
                    dispatch_async(options.queue, { () -> Void in
                        completionHandler(result, .Memory)
                    })
                })
            } else {
                completionHandler(image, .Memory)
            }
        } else {
            var sSelf: ImageCache! = self
            block = dispatch_block_create(DISPATCH_BLOCK_INHERIT_QOS_CLASS, { () -> Void in
                dispatch_async(sSelf.ioQueue, { () -> Void in
                    if let image = sSelf.retrieveImageInDiskCacheForKey(key, scale: options.scale) {
                        if options.shouldDecode {
                            dispatch_async(sSelf.processQueue, { () -> Void in
                                let result = image.nir_decodeImage(scale: options.scale)
                                sSelf.storeImage(result!, forKey: key, toDisk: false, completionHandler: nil)
                                
                                dispatch_async(options.queue, { () -> Void in
                                    completionHandler(result, .Memory)
                                    sSelf = nil
                                })
                            })
                        } else {
                            sSelf.storeImage(image, forKey: key, toDisk: false, completionHandler: nil)
                            dispatch_async(options.queue, { () -> Void in
                                completionHandler(image, .Disk)
                                sSelf = nil
                            })
                        }
                    } else {
                        dispatch_async(options.queue, { () -> Void in
                            completionHandler(nil, nil)
                            sSelf = nil
                        })
                    }
                })
            })
            dispatch_async(dispatch_get_main_queue(), block!)
        }
        return block
    }
    
    public func retrieveImageInMemoryCacheForKey(key: String) -> UIImage? {
        return memoryCache.objectForKey(key) as? UIImage
    }
    
    public func retrieveImageInDiskCacheForKey(key: String, scale: CGFloat = NirWebImageManager.DefaultOptions.scale) -> UIImage? {
        return diskImageForKey(key, scale: scale)
    }
    
}

extension ImageCache {
    public func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }
    
    public func clearDiskCache() {
        clearDiskCacheWithCompletionHandler(nil)
    }
    
    public func clearDiskCacheWithCompletionHandler(completionHandler: (()->())?) {
        dispatch_async(ioQueue) { () -> Void in
            do {
                try self.fileManager.removeItemAtPath(self.diskCachePath)
            } catch {
            }
            do {
                try self.fileManager.createDirectoryAtPath(self.diskCachePath, withIntermediateDirectories: true, attributes: nil)
            } catch {
            }
            
            if let completionHandler = completionHandler {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    completionHandler()
                })
            }
        }
    }
    
    public func clearExpiredDiskCache() {
        clearExpiredDiskCacheWithCompletionHandler(nil)
    }
    
    public func clearExpiredDiskCacheWithCompletionHandler(completionHandler: (()->())?) {
        dispatch_async(ioQueue) { () -> Void in
            let diskCacheURL = NSURL(fileURLWithPath: self.diskCachePath)
            
            let resourceKeys = [NSURLIsDirectoryKey, NSURLContentModificationDateKey, NSURLTotalFileAllocatedSizeKey]
            let expiredDate = NSDate(timeIntervalSinceNow: -self.maxCachePeriodInSecond)
            var cachedFiles: [NSURL: [NSObject: AnyObject]] = [:]
            var URLsToDelete: [NSURL] = []
            
            var diskCacheSize: UInt = 0
            
            if let fileEnumerator = self.fileManager.enumeratorAtURL(diskCacheURL, includingPropertiesForKeys: resourceKeys, options: NSDirectoryEnumerationOptions.SkipsHiddenFiles, errorHandler: nil) {
                for fileURL in fileEnumerator.allObjects as! [NSURL] {
                    do {
                        let resourceValues = try fileURL.resourceValuesForKeys(resourceKeys)
                        
                        if let isDirectory = resourceValues[NSURLIsDirectoryKey] as? NSNumber {
                            if isDirectory.boolValue {
                                continue
                            }
                        }
                        
                        if let modificationDate = resourceValues[NSURLContentModificationDateKey] as? NSDate {
                            if modificationDate.laterDate(expiredDate) == expiredDate {
                                URLsToDelete.append(fileURL)
                                continue
                            }
                        }
                        
                        if let fileSize = resourceValues[NSURLTotalFileAllocatedSizeKey] as? NSNumber {
                            diskCacheSize += fileSize.unsignedLongValue
                            cachedFiles[fileURL] = resourceValues
                        }
                    } catch {
                    }
                }
            }
            
            for fileURL in URLsToDelete {
                do {
                    try self.fileManager.removeItemAtURL(fileURL)
                } catch {
                }
            }
            
            if self.MaxDiskCacheSize > 0 && diskCacheSize > self.MaxDiskCacheSize {
                let targetSize = self.MaxDiskCacheSize / 2
                
                let sortedFiles = cachedFiles.keysSortedByValue({ (resourceValue1, resourceValue2) -> Bool in
                    if let date1 = resourceValue1[NSURLContentModificationDateKey] as? NSDate {
                        if let date2 = resourceValue2[NSURLContentModificationDateKey] as? NSDate {
                            return date1.compare(date2) == .OrderedAscending
                        }
                    }
                    return true
                })
                
                for fileURL in sortedFiles {
                    do {
                        try self.fileManager.removeItemAtURL(fileURL)
                    } catch {
                    }
                    URLsToDelete.append(fileURL)
                    
                    if let fileSize = cachedFiles[fileURL]?[NSURLTotalFileAllocatedSizeKey] as? NSNumber {
                        diskCacheSize -= fileSize.unsignedLongValue
                    }
                    
                    if diskCacheSize < targetSize {
                        break
                    }
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                if URLsToDelete.count != 0 {
                    let cleanedHashes = URLsToDelete.map({ (url) -> String in
                        return url.lastPathComponent!
                    })
                    NSNotificationCenter.defaultCenter().postNotificationName(NirWebImageDidCleanDiskCacheNotification, object: self, userInfo: [NirWebImageDiskCacheCleanedHashKey: cleanedHashes])
                }
                
                if let completionHandler = completionHandler {
                    completionHandler()
                }
            })
        }
    }
    
    public func backgroudCleanExpiredDiskCache() {
        func endBackgroundTask(inout task: UIBackgroundTaskIdentifier) {
            UIApplication.sharedApplication().endBackgroundTask(task)
            task = UIBackgroundTaskInvalid
        }
        
        var backgroundTask: UIBackgroundTaskIdentifier!
        
        backgroundTask = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({ () -> Void in
            endBackgroundTask(&backgroundTask!)
        })
        
        clearExpiredDiskCacheWithCompletionHandler { () -> () in
            endBackgroundTask(&backgroundTask!)
        }
    }
}

public extension ImageCache {
    public struct CacheCheckResult {
        public let cached: Bool
        public let cacheType: CacheType?
    }
    
    public func isImageCachedForKey(key: String) -> CacheCheckResult {
        if memoryCache.objectForKey(key) != nil {
            return CacheCheckResult(cached: true, cacheType: .Memory)
        }
        
        let filePath = cachePathForKey(key)
        
        if fileManager.fileExistsAtPath(filePath) {
            return CacheCheckResult(cached: true, cacheType: .Disk)
        }
        
        return CacheCheckResult(cached: false, cacheType: nil)
    }
    
    public func hashForKey(key: String) -> String {
        return cacheFileNameForKey(key)
    }
    
    public func calculateDiskCacheSizeWithCompletionHandler(completionHandler: ((size: UInt) -> ())?) {
        dispatch_async(ioQueue) { () -> Void in
            let diskCacheURL = NSURL(fileURLWithPath: self.diskCachePath)
            
            let resourceKeys = [NSURLIsDirectoryKey, NSURLTotalFileAllocatedSizeKey]
            var diskCacheSize: UInt = 0
            
            if let fileEnumerator = self.fileManager.enumeratorAtURL(diskCacheURL, includingPropertiesForKeys: resourceKeys, options: NSDirectoryEnumerationOptions.SkipsHiddenFiles, errorHandler: nil) {
                for fileURL in fileEnumerator.allObjects as! [NSURL] {
                    do {
                        let resourceValues = try fileURL.resourceValuesForKeys(resourceKeys)
                        
                        if let isDirectory = resourceValues[NSURLIsDirectoryKey]?.boolValue {
                            if isDirectory {
                                continue
                            }
                        }
                        
                        if let fileSize = resourceValues[NSURLTotalFileAllocatedSizeKey] as? NSNumber {
                            diskCacheSize += fileSize.unsignedLongValue
                        }
                    } catch {
                    }
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                if let completionHandler = completionHandler {
                    completionHandler(size: diskCacheSize)
                }
            })
        }
    }
}

extension ImageCache {
    func diskImageForKey(key: String, scale: CGFloat) -> UIImage? {
        if let data = diskImageDataForKey(key) {
            return UIImage.nir_imageWithData(data, scale: scale)
        } else {
            return nil
        }
    }
    
    func diskImageDataForKey(key: String) -> NSData? {
        let filePath = cachePathForKey(key)
        return NSData(contentsOfFile: filePath)
    }
    
    func cachePathForKey(key: String) -> String {
        let fileName = cacheFileNameForKey(key)
        return (diskCachePath as NSString).stringByAppendingPathComponent(fileName)
    }
    
    func cacheFileNameForKey(key: String) -> String {
        return key.nir_MD5()
    }
}

extension UIImage {
    var nir_imageCost: Int {
        return Int(size.height * size.width * scale * scale)
    }
}

extension Dictionary {
    func keysSortedByValue(isOrderedBefore: (Value, Value) -> Bool) -> [Key] {
        var array = Array(self)
        array.sortInPlace {
            let (_, lv) = $0
            let (_, rv) = $1
            return isOrderedBefore(lv, rv)
        }
        return array.map {
            let (k, _) = $0
            return k
        }
    }
}
