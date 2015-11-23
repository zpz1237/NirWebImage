//
//  NirWebImageManager.swift
//  NirWebImage
//
//  Created by Nirvana on 11/15/15.
//  Copyright © 2015 NSNirvana. All rights reserved.
//

import UIKit

public typealias DownloadProgressBlock = ((receivedSize: Int64, totalSize: Int64) -> ())
public typealias CompletionHandler = ((image: UIImage?, error: NSError?, CacheType: CacheType, imageURL: NSURL?) -> ())

public class RetrieveImageTask {
    var cancelled: Bool = false
    
    //Image数据的两个来源
    var diskRetrieveTask: RetrieveImageDiskTask?
    var downloadTask: RetrieveImageDownloadTask?
    
    //任务取消设标志位
    public func cancel() {
        if let diskRetrieveTask = diskRetrieveTask {
            dispatch_block_cancel(diskRetrieveTask)
        }
        
        if let downloadTask = downloadTask {
            downloadTask.cancel()
        }
        
        cancelled = true
    }
}

public let NirWebImageErrorDomain = "com.NirWebImage.Error"

public class NirWebImageManager {
    //控制下载和缓存行为
    public typealias Options = (forceRefresh: Bool, lowPriority: Bool, cacheMemoryOnly: Bool, shouldDecode: Bool, queue: dispatch_queue_t!, scale: CGFloat)
    public static let OptionsNone: Options = (forceRefresh: false, lowPriority: false, cacheMemoryOnly: false, shouldDecode: false, queue: dispatch_get_main_queue(), scale: 1.0)
    public static var DefaultOptions: Options = OptionsNone
    
    //生成单例
    public static let sharedManager = NirWebImageManager()
    
    public var cache: ImageCache
    public var downloader: ImageDownloader

    public init() {
        cache = ImageCache.defaultCache
        downloader = ImageDownloader.defaultDownloader
    }
    
    public func retrieveImageWithResource(resource: Resource,
        optionsInfo: NirWebImageOptionsInfo?,
        progressBlock: DownloadProgressBlock?,
        completionHandler: CompletionHandler?) -> RetrieveImageTask
    {
        let task = RetrieveImageTask()
        
        // There is a bug in Swift compiler which prevents to write `let (options, targetCache) = parseOptionsInfo(optionsInfo)`
        // It will cause a compiler error.
        let parsedOptions = parseOptionsInfo(optionsInfo)
        let (options, targetCache, downloader) = (parsedOptions.0, parsedOptions.1, parsedOptions.2)
        
        if options.forceRefresh {
            downloadAndCacheImageWithURL(resource.downloadURL,
                forKey: resource.cacheKey,
                retrieveImageTask: task,
                progressBlock: progressBlock,
                completionHandler: completionHandler,
                options: options,
                targetCache: targetCache,
                downloader: downloader)
        } else {
            let diskTaskCompletionHandler: CompletionHandler = { (image, error, cacheType, imageURL) -> () in
                // Break retain cycle created inside diskTask closure below
                task.diskRetrieveTask = nil
                completionHandler?(image: image, error: error, CacheType: cacheType, imageURL: imageURL)
            }
            let diskTask = targetCache.retrieveImageForKey(resource.cacheKey, options: options, completionHandler: { (image, cacheType) -> () in
                if image != nil {
                    diskTaskCompletionHandler(image: image, error: nil, CacheType:cacheType, imageURL: resource.downloadURL)
                } else {
                    self.downloadAndCacheImageWithURL(resource.downloadURL,
                        forKey: resource.cacheKey,
                        retrieveImageTask: task,
                        progressBlock: progressBlock,
                        completionHandler: diskTaskCompletionHandler,
                        options: options,
                        targetCache: targetCache,
                        downloader: downloader)
                }
            })
            task.diskRetrieveTask = diskTask
        }
        
        return task
    }
    
    /**
     Get an image with `URL.absoluteString` as the key.
     If KingfisherOptions.None is used as `options`, Kingfisher will seek the image in memory and disk first.
     If not found, it will download the image at URL and cache it with `URL.absoluteString` value as its key.
     
     If you need to specify the key other than `URL.absoluteString`, please use resource version of this API with `resource.cacheKey` set to what you want.
     
     These default behaviors could be adjusted by passing different options. See `KingfisherOptions` for more.
     
     - parameter URL:               The image URL.
     - parameter optionsInfo:       A dictionary could control some behaviors. See `KingfisherOptionsInfo` for more.
     - parameter progressBlock:     Called every time downloaded data changed. This could be used as a progress UI.
     - parameter completionHandler: Called when the whole retrieving process finished.
     
     - returns: A `RetrieveImageTask` task object. You can use this object to cancel the task.
     */
    public func retrieveImageWithURL(URL: NSURL,
        optionsInfo: NirWebImageOptionsInfo?,
        progressBlock: DownloadProgressBlock?,
        completionHandler: CompletionHandler?) -> RetrieveImageTask
    {
        return retrieveImageWithResource(Resource(downloadURL: URL), optionsInfo: optionsInfo, progressBlock: progressBlock, completionHandler: completionHandler)
    }
    
    func downloadAndCacheImageWithURL(URL: NSURL,
        forKey key: String,
        retrieveImageTask: RetrieveImageTask,
        progressBlock: DownloadProgressBlock?,
        completionHandler: CompletionHandler?,
        options: Options,
        targetCache: ImageCache,
        downloader: ImageDownloader)
    {
        downloader.downloadImageWithURL(URL, retrieveImageTask: retrieveImageTask, options: options, progressBlock: { (receivedSize, totalSize) -> () in
            progressBlock?(receivedSize: receivedSize, totalSize: totalSize)
            }) { (image, error, imageURL, originalData) -> () in
                
                if let error = error where error.code == NirWebImageError.NotModified.rawValue {
                    // Not modified. Try to find the image from cache.
                    // (The image should be in cache. It should be guaranteed by the framework users.)
                    targetCache.retrieveImageForKey(key, options: options, completionHandler: { (cacheImage, cacheType) -> () in
                        completionHandler?(image: cacheImage, error: nil, CacheType: cacheType, imageURL: URL)
                        
                    })
                    return
                }
                
                if let image = image, originalData = originalData {
                    targetCache.storeImage(image, originalData: originalData, forKey: key, toDisk: !options.cacheMemoryOnly, completionHandler: nil)
                }
                
                completionHandler?(image: image, error: error, CacheType: .None, imageURL: URL)
        }
    }
    
    func parseOptionsInfo(optionsInfo: NirWebImageOptionsInfo?) -> (Options, ImageCache, ImageDownloader) {
        var options = NirWebImageManager.DefaultOptions
        var targetCache = self.cache
        var targetDownloader = self.downloader
        
        guard let optionsInfo = optionsInfo else {
            return (options, targetCache, targetDownloader)
        }
        
        if let optionsItem = optionsInfo.nir_findFirstMatch(.Options(.None)), case .Options(let optionsInOptionsInfo) = optionsItem {
            
            let queue = optionsInOptionsInfo.contains(NirWebImageOptions.BackgroundCallback) ? dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) : NirWebImageManager.DefaultOptions.queue
            let scale = optionsInOptionsInfo.contains(NirWebImageOptions.ScreenScale) ? UIScreen.mainScreen().scale : NirWebImageManager.DefaultOptions.scale
            
            options = (forceRefresh: optionsInOptionsInfo.contains(NirWebImageOptions.ForceRefresh),
                lowPriority: optionsInOptionsInfo.contains(NirWebImageOptions.LowPriority),
                cacheMemoryOnly: optionsInOptionsInfo.contains(NirWebImageOptions.CacheMemoryOnly),
                shouldDecode: optionsInOptionsInfo.contains(NirWebImageOptions.BackgroundDecode),
                queue: queue, scale: scale)
        }
        
        if let optionsItem = optionsInfo.nir_findFirstMatch(.TargetCache(self.cache)), case .TargetCache(let cache) = optionsItem {
            targetCache = cache
        }
        
        if let optionsItem = optionsInfo.nir_findFirstMatch(.Downloader(self.downloader)), case .Downloader(let downloader) = optionsItem {
            targetDownloader = downloader
        }
        
        return (options, targetCache, targetDownloader)
    }
}
