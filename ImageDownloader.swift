//
//  ImageDownloader.swift
//  NirWebImage
//
//  Created by Nirvana on 11/15/15.
//  Copyright © 2015 NSNirvana. All rights reserved.
//

import UIKit

public typealias ImageDownloaderProgressBlock = DownloadProgressBlock
public typealias ImageDownloaderCompletionHandler = ((image: UIImage?, error: NSError?, imageURL: NSURL?, originalData: NSData?) -> ())

public typealias RetrieveImageDownloadTask = NSURLSessionDataTask

private let defaultDownloaderName = "default"
private let downloaderBarrierName = "com.NirWebImage.ImageDownloader.Barrier"
private let imageProcessQueueName = "com.NirWebImage.ImageDownloader.Process"

public enum NirWebImageError: Int {
    case BadData = 10000
    case NotModified = 10001
    case InvalidURL = 20000
}

@objc public protocol ImageDownloaderDelegate {
    optional func imageDownloader(downloader: ImageDownloader, didDownloadImage image: UIImage, forURL: NSURL, withResponse reponse: NSURLResponse)
}

public class ImageDownloader: NSObject {
    
    class ImageFetchLoad {
        var callbacks: [CallbackPair] = []
        var responseData = NSMutableData()
        var shouldDecode = false
        var scale = NirWebImageManager.DefaultOptions.scale
    }
    
    public var requestModifier: (NSMutableURLRequest -> Void)?
    public var downloadTimeout: NSTimeInterval = 15.0
    public var trustedHosts: Set<String>?
    public var sessionConfiguration = NSURLSessionConfiguration.ephemeralSessionConfiguration()
    
    public weak var deleagte: ImageDownloaderDelegate?
    
    let barrierQueue: dispatch_queue_t
    let processQueue: dispatch_queue_t
    
    typealias CallbackPair = (progressBlock: ImageDownloaderProgressBlock?, completionHandler: ImageDownloaderCompletionHandler?)
    
    var fetchLoads: [NSURL: ImageFetchLoad] = [:]
    
    static let defaultDownloader = ImageDownloader(name: defaultDownloaderName)
    
    public init(name: String) {
        if name.isEmpty {
            fatalError()
        }
        
        barrierQueue = dispatch_queue_create(downloaderBarrierName + name, DISPATCH_QUEUE_CONCURRENT)
        processQueue = dispatch_queue_create(imageProcessQueueName + name, DISPATCH_QUEUE_SERIAL)
    }
    
    func fetchLoadForKey(key: NSURL) -> ImageFetchLoad? {
        var fetchLoad: ImageFetchLoad?
        dispatch_sync(barrierQueue) { () -> Void in
            fetchLoad = self.fetchLoads[key]
        }
        return fetchLoad
    }
}

public extension ImageDownloader {
    public func downloadImageWithURL(URL: NSURL, progressBlock: ImageDownloaderProgressBlock?, completionHandler: ImageDownloaderCompletionHandler?) {
        downloadImageWithURL(URL, options: NirWebImageManager.DefaultOptions, progressBlock: progressBlock, completionHandler: completionHandler)
    }
    
    public func downloadImageWithURL(URL: NSURL, options: NirWebImageManager.Options, progressBlock: ImageDownloaderProgressBlock?, completionHandler: ImageDownloaderCompletionHandler?) {
        downloadImageWithURL(URL,
            retrieveImageTask: nil,
            options: options,
            progressBlock: progressBlock,
            completionHandler: completionHandler)
    }
    
    internal func downloadImageWithURL(URL: NSURL, retrieveImageTask: RetrieveImageTask?, options: NirWebImageManager.Options, progressBlock: ImageDownloaderProgressBlock?, completionHandler: ImageDownloaderCompletionHandler?) {
        if let retrieveImageTask = retrieveImageTask where retrieveImageTask.cancelled{
            return
        }
        
        let timeout = self.downloadTimeout == 0.0 ? 15.0 : self.downloadTimeout
        
        let request = NSMutableURLRequest(URL: URL, cachePolicy: .ReloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.HTTPShouldUsePipelining = true
        
        self.requestModifier?(request)
        
        if request.URL == nil {
            completionHandler?(image: nil, error: NSError(domain: NirWebImageErrorDomain, code: NirWebImageError.InvalidURL.rawValue, userInfo: nil), imageURL: nil, originalData: nil)
            return
        }
        
        setupProgressBlock(progressBlock, completionHandler: completionHandler, forURL: request.URL!) { (session, fetchLoad) -> Void in
            let task = session.dataTaskWithRequest(request)
            task.priority = options.lowPriority ? NSURLSessionTaskPriorityLow : NSURLSessionTaskPriorityDefault
            task.resume()
            
            fetchLoad.shouldDecode = options.shouldDecode
            fetchLoad.scale = options.scale
            
            retrieveImageTask?.downloadTask = task
        }
    }
    
    internal func setupProgressBlock(progressBlock: ImageDownloaderProgressBlock?, completionHandler: ImageDownloaderCompletionHandler?, forURL URL: NSURL, started: ((NSURLSession, ImageFetchLoad) -> Void)) {
        dispatch_barrier_sync(barrierQueue) { () -> Void in
            var create = false
            var loadObjectForURL = self.fetchLoads[URL]
            if loadObjectForURL == nil {
                create = true
                loadObjectForURL = ImageFetchLoad()
            }
            
            let callbackPair = (progressBlock: progressBlock, completionHandler: completionHandler)
            loadObjectForURL!.callbacks.append(callbackPair)
            self.fetchLoads[URL] = loadObjectForURL!
            
            if create {
                let session = NSURLSession(configuration: self.sessionConfiguration, delegate: self, delegateQueue:NSOperationQueue.mainQueue())
                started(session, loadObjectForURL!)
            }
        }
    }
    
    func cleanForURL(URL: NSURL) {
        dispatch_barrier_sync(barrierQueue) { () -> Void in
            self.fetchLoads.removeValueForKey(URL)
            return
        }
    }
}

extension ImageDownloader: NSURLSessionDataDelegate {
    public func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveResponse response: NSURLResponse, completionHandler: (NSURLSessionResponseDisposition) -> Void) {
        completionHandler(NSURLSessionResponseDisposition.Allow)
    }
    
    public func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
        if let URL = dataTask.originalRequest?.URL, fetchLoad = fetchLoadForKey(URL) {
            fetchLoad.responseData.appendData(data)
            
            for callbackPair in fetchLoad.callbacks {
                callbackPair.progressBlock?(receivedSize: Int64(fetchLoad.responseData.length), totalSize: dataTask.response!.expectedContentLength)
            }
        }
    }
    
    private func callBackWithImage(image: UIImage?, error: NSError?, imageURL: NSURL, originalData: NSData?) {
        if let callbackPairs = fetchLoadForKey(imageURL)?.callbacks {
            self.cleanForURL(imageURL)
            
            for callbackPair in callbackPairs {
                callbackPair.completionHandler?(image: image, error: error, imageURL: imageURL, originalData: originalData)
            }
        }
    }
    
    public func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        if let URL = task.originalRequest?.URL {
            if let error = error {
                callBackWithImage(nil, error: error, imageURL: URL, originalData: nil)
            } else {
                dispatch_async(processQueue, { () -> Void in
                    if let fetchLoad = self.fetchLoadForKey(URL) {
                        if let image = UIImage.nir_imageWithData(fetchLoad.responseData, scale: fetchLoad.scale) {
                            self.deleagte?.imageDownloader?(self, didDownloadImage: image, forURL: URL, withResponse: task.response!)
                            
                            if fetchLoad.shouldDecode {
                                self.callBackWithImage(image.nir_decodeImage(), error: error, imageURL: URL, originalData: fetchLoad.responseData)
                            } else {
                                self.callBackWithImage(image, error: error, imageURL: URL, originalData: fetchLoad.responseData)
                            }
                        } else {
                            if let res = task.response as? NSHTTPURLResponse where res.statusCode == 304 {
                                self.callBackWithImage(nil, error: NSError(domain: NirWebImageErrorDomain, code: NirWebImageError.NotModified.rawValue, userInfo: nil), imageURL: URL, originalData: nil)
                                return
                            }
                            
                            self.callBackWithImage(nil, error: NSError(domain: NirWebImageErrorDomain, code: NirWebImageError.BadData.rawValue, userInfo: nil), imageURL: URL, originalData: nil)
                        }
                    } else {
                        self.callBackWithImage(nil, error: NSError(domain: NirWebImageErrorDomain, code: NirWebImageError.BadData.rawValue, userInfo: nil), imageURL: URL, originalData: nil)
                    }
                })
            }
        }
    }
    
    public func URLSession(session: NSURLSession, didReceiveChallenge challenge: NSURLAuthenticationChallenge, completionHandler: (NSURLSessionAuthChallengeDisposition, NSURLCredential?) -> Void) {
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let trustedHosts = trustedHosts where trustedHosts.contains(challenge.protectionSpace.host) {
                let credential = NSURLCredential(forTrust: challenge.protectionSpace.serverTrust!)
                completionHandler(.UseCredential, credential)
                return
            }
        }
        
        completionHandler(.PerformDefaultHandling, nil)
    }
    
}