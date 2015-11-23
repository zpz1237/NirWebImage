//
//  UIImageView+NirWebImage.swift
//  NirWebImage
//
//  Created by Nirvana on 11/22/15.
//  Copyright © 2015 NSNirvana. All rights reserved.
//

import UIKit

public extension UIImageView {
    public func nir_setImageWithResource(resource: Resource) -> RetrieveImageTask {
        return nir_setImageWithResource(resource, placeholderImage: nil, optionsInfo: nil, progressBlock: nil, completionHandler: nil)
    }
    
    public func nir_setImageWithURL(URL: NSURL) -> RetrieveImageTask {
        return nir_setImageWithURL(URL, placeholderImage: nil, optionsInfo: nil, progressBlock: nil, completionHandler: nil)
    }
    
    public func nir_setImageWithResource(resource: Resource, placeholderImage: UIImage?) -> RetrieveImageTask {
        return nir_setImageWithResource(resource, placeholderImage: placeholderImage, optionsInfo: nil, progressBlock: nil, completionHandler: nil)
    }
    
    public func nir_setImageWithURL(URL: NSURL, placeholderImage: UIImage?) -> RetrieveImageTask {
        return nir_setImageWithURL(URL, placeholderImage: placeholderImage, optionsInfo: nil, progressBlock: nil, completionHandler: nil)
    }
    
    public func nir_setImageWithResource(resource: Resource, placeholderImage: UIImage?, optionsInfo: NirWebImageOptionsInfo?) -> RetrieveImageTask {
        return nir_setImageWithResource(resource, placeholderImage: placeholderImage, optionsInfo: optionsInfo, progressBlock: nil, completionHandler: nil)
    }
    
    public func nir_setImageWithURL(URL: NSURL, placeholderImage: UIImage?, optionsInfo: NirWebImageOptionsInfo?) -> RetrieveImageTask {
        return nir_setImageWithURL(URL, placeholderImage: placeholderImage, optionsInfo: optionsInfo, progressBlock: nil, completionHandler: nil)
    }
    
    public func nir_setImageWithResource(resource: Resource, placeholderImage: UIImage?, optionsInfo: NirWebImageOptionsInfo?, completionHandler: CompletionHandler?) -> RetrieveImageTask {
        return nir_setImageWithResource(resource, placeholderImage: placeholderImage, optionsInfo: optionsInfo, progressBlock: nil, completionHandler: completionHandler)
    }
    
    public func nir_setImageWithURL(URL: NSURL, placeholderImage: UIImage?, optionsInfo: NirWebImageOptionsInfo?, completionHandler: CompletionHandler?) -> RetrieveImageTask
    {
        return nir_setImageWithURL(URL, placeholderImage: placeholderImage, optionsInfo: optionsInfo, progressBlock: nil, completionHandler: completionHandler)
    }
    
    public func nir_setImageWithResource(resource: Resource, placeholderImage: UIImage?, optionsInfo: NirWebImageOptionsInfo?, progressBlock: DownloadProgressBlock?, completionHandler: CompletionHandler?) -> RetrieveImageTask {
        let showIndicatorWhenLoading = nir_showIndicatorWhenLoading
        var indicator: UIActivityIndicatorView? = nil
        if showIndicatorWhenLoading {
            indicator = nir_indicator
            indicator?.hidden = false
            indicator?.startAnimating()
        }
        
        image = placeholderImage
        
        nir_setWebURL(resource.downloadURL)
        let task = NirWebImageManager.sharedManager.retrieveImageWithResource(resource, optionsInfo: optionsInfo, progressBlock: { (receivedSize, totalSize) -> () in
            if let progressBlock = progressBlock {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    progressBlock(receivedSize: receivedSize, totalSize: totalSize)
                    
                })
            }
            }, completionHandler: {[weak self] (image, error, cacheType, imageURL) -> () in
                
                dispatch_async_safely_main_queue {
                    if let sSelf = self where imageURL == sSelf.nir_webURL && image != nil {
                        
                        if let transitionItem = optionsInfo?.nir_findFirstMatch(.Transition(.None)),
                            case .Transition(let transition) = transitionItem {
                                
                                UIView.transitionWithView(sSelf, duration: 0.0, options: [], animations: { () -> Void in
                                    indicator?.stopAnimating()
                                    }, completion: { (finished) -> Void in
                                        UIView.transitionWithView(sSelf, duration: transition.duration,
                                            options: transition.animationOptions, animations:
                                            { () -> Void in
                                                transition.animations?(sSelf, image!)
                                            }, completion: {
                                                finished in
                                                transition.completion?(finished)
                                                completionHandler?(image: image, error: error, CacheType: cacheType, imageURL: imageURL)
                                        })
                                })
                        } else {
                            indicator?.stopAnimating()
                            sSelf.image = image;
                            completionHandler?(image: image, error: error, CacheType: cacheType, imageURL: imageURL)
                        }
                    } else {
                        completionHandler?(image: image, error: error, CacheType: cacheType, imageURL: imageURL)
                    }
                }
            })
        
        return task
    }
    
    public func nir_setImageWithURL(URL: NSURL,
        placeholderImage: UIImage?,
        optionsInfo: NirWebImageOptionsInfo?,
        progressBlock: DownloadProgressBlock?,
        completionHandler: CompletionHandler?) -> RetrieveImageTask
    {
        return nir_setImageWithResource(Resource(downloadURL: URL),
            placeholderImage: placeholderImage,
            optionsInfo: optionsInfo,
            progressBlock: progressBlock,
            completionHandler: completionHandler)
    }
}

private var lastURLKey: Void?
private var indicatorKey: Void?
private var showIndicatorWhenLoadingKey: Void?

public extension UIImageView {
    public var nir_webURL: NSURL? {
        get {
            return objc_getAssociatedObject(self, &lastURLKey) as? NSURL
        }
    }
    
    public func nir_setWebURL(URL: NSURL) {
        objc_setAssociatedObject(self, &lastURLKey, URL, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    public var nir_showIndicatorWhenLoading: Bool {
        get {
            if let result = objc_getAssociatedObject(self, &showIndicatorWhenLoadingKey) as? NSNumber {
                return result.boolValue
            } else {
                return false
            }
        }
        set {
            if nir_showIndicatorWhenLoading == newValue {
                return
            } else {
                if newValue {
                    let indicator = UIActivityIndicatorView(activityIndicatorStyle:.Gray)
                    indicator.center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds))
                    
                    indicator.autoresizingMask = [.FlexibleLeftMargin, .FlexibleRightMargin, .FlexibleBottomMargin, .FlexibleTopMargin]
                    indicator.hidden = true
                    indicator.hidesWhenStopped = true
                    
                    self.addSubview(indicator)
                    
                    nir_setIndicator(indicator)
                } else {
                    nir_indicator?.removeFromSuperview()
                    nir_setIndicator(nil)
                }
                
                objc_setAssociatedObject(self, &showIndicatorWhenLoadingKey, NSNumber(bool: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
    public var nir_indicator: UIActivityIndicatorView? {
        get {
            return objc_getAssociatedObject(self, &indicatorKey) as? UIActivityIndicatorView
        }
    }
    
    private func nir_setIndicator(indicator: UIActivityIndicatorView?) {
        objc_setAssociatedObject(self, &indicatorKey, indicator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}