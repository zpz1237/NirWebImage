//
//  UIButton+NirWebImage.swift
//  NirWebImage
//
//  Created by Nirvana on 11/23/15.
//  Copyright © 2015 NSNirvana. All rights reserved.
//

import UIKit

public extension UIButton {
    
    public func nir_setImageWithResource(resource: Resource,
        forState state: UIControlState) -> RetrieveImageTask
    {
        return nir_setImageWithResource(resource, forState: state, placeholderImage: nil, optionsInfo: nil, progressBlock: nil, completionHandler: nil)
    }
    
    public func nir_setImageWithURL(URL: NSURL,
        forState state: UIControlState) -> RetrieveImageTask
    {
        return nir_setImageWithURL(URL, forState: state, placeholderImage: nil, optionsInfo: nil, progressBlock: nil, completionHandler: nil)
    }
    
    public func nir_setImageWithResource(resource: Resource,
        forState state: UIControlState,
        placeholderImage: UIImage?) -> RetrieveImageTask
    {
        return nir_setImageWithResource(resource, forState: state, placeholderImage: placeholderImage, optionsInfo: nil, progressBlock: nil, completionHandler: nil)
    }
    
    public func nir_setImageWithURL(URL: NSURL,
        forState state: UIControlState,
        placeholderImage: UIImage?) -> RetrieveImageTask
    {
        return nir_setImageWithURL(URL, forState: state, placeholderImage: placeholderImage, optionsInfo: nil, progressBlock: nil, completionHandler: nil)
    }

    public func nir_setImageWithResource(resource: Resource,
        forState state: UIControlState,
        placeholderImage: UIImage?,
        optionsInfo: NirWebImageOptionsInfo?) -> RetrieveImageTask
    {
        return nir_setImageWithResource(resource, forState: state, placeholderImage: placeholderImage, optionsInfo: optionsInfo, progressBlock: nil, completionHandler: nil)
    }
    
    public func nir_setImageWithURL(URL: NSURL,
        forState state: UIControlState,
        placeholderImage: UIImage?,
        optionsInfo: NirWebImageOptionsInfo?) -> RetrieveImageTask
    {
        return nir_setImageWithURL(URL, forState: state, placeholderImage: placeholderImage, optionsInfo: optionsInfo, progressBlock: nil, completionHandler: nil)
    }

    public func nir_setImageWithResource(resource: Resource,
        forState state: UIControlState,
        placeholderImage: UIImage?,
        optionsInfo: NirWebImageOptionsInfo?,
        completionHandler: CompletionHandler?) -> RetrieveImageTask
    {
        return nir_setImageWithResource(resource, forState: state, placeholderImage: placeholderImage, optionsInfo: optionsInfo, progressBlock: nil, completionHandler: completionHandler)
    }

    public func nir_setImageWithURL(URL: NSURL,
        forState state: UIControlState,
        placeholderImage: UIImage?,
        optionsInfo: NirWebImageOptionsInfo?,
        completionHandler: CompletionHandler?) -> RetrieveImageTask
    {
        return nir_setImageWithURL(URL, forState: state, placeholderImage: placeholderImage, optionsInfo: optionsInfo, progressBlock: nil, completionHandler: completionHandler)
    }
    
    public func nir_setImageWithResource(resource: Resource,
        forState state: UIControlState,
        placeholderImage: UIImage?,
        optionsInfo: NirWebImageOptionsInfo?,
        progressBlock: DownloadProgressBlock?,
        completionHandler: CompletionHandler?) -> RetrieveImageTask
    {
        setImage(placeholderImage, forState: state)
        nir_setWebURL(resource.downloadURL, forState: state)
        let task = NirWebImageManager.sharedManager.retrieveImageWithResource(resource, optionsInfo: optionsInfo, progressBlock: { (receivedSize, totalSize) -> () in
            if let progressBlock = progressBlock {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    progressBlock(receivedSize: receivedSize, totalSize: totalSize)
                })
            }
            }) {[weak self] (image, error, cacheType, imageURL) -> () in
                
                dispatch_async_safely_main_queue {
                    if let sSelf = self {
                        if (imageURL == sSelf.nir_webURLForState(state) && image != nil) {
                            sSelf.setImage(image, forState: state)
                        }
                        completionHandler?(image: image, error: error, CacheType: cacheType, imageURL: imageURL)
                    }
                }
        }
        
        return task
    }
    
    public func nir_setImageWithURL(URL: NSURL,
        forState state: UIControlState,
        placeholderImage: UIImage?,
        optionsInfo: NirWebImageOptionsInfo?,
        progressBlock: DownloadProgressBlock?,
        completionHandler: CompletionHandler?) -> RetrieveImageTask
    {
        return nir_setImageWithResource(Resource(downloadURL: URL),
            forState: state,
            placeholderImage: placeholderImage,
            optionsInfo: optionsInfo,
            progressBlock: progressBlock,
            completionHandler: completionHandler)
    }
}

private var lastURLKey: Void?
public extension UIButton {
    public func nir_webURLForState(state: UIControlState) -> NSURL? {
        return nir_webURLs[NSNumber(unsignedLong:state.rawValue)] as? NSURL
    }
    
    private func nir_setWebURL(URL: NSURL, forState state: UIControlState) {
        nir_webURLs[NSNumber(unsignedLong:state.rawValue)] = URL
    }
    
    private var nir_webURLs: NSMutableDictionary {
        get {
            var dictionary = objc_getAssociatedObject(self, &lastURLKey) as? NSMutableDictionary
            if dictionary == nil {
                dictionary = NSMutableDictionary()
                nir_setWebURLs(dictionary!)
            }
            return dictionary!
        }
    }
    
    private func nir_setWebURLs(URLs: NSMutableDictionary) {
        objc_setAssociatedObject(self, &lastURLKey, URLs, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

public extension UIButton {
    public func nir_setBackgroundImageWithResource(resource: Resource,
        forState state: UIControlState) -> RetrieveImageTask
    {
        return nir_setBackgroundImageWithResource(resource, forState: state, placeholderImage: nil, optionsInfo: nil, progressBlock: nil, completionHandler: nil)
    }
    
    public func nir_setBackgroundImageWithURL(URL: NSURL,
        forState state: UIControlState) -> RetrieveImageTask
    {
        return nir_setBackgroundImageWithURL(URL, forState: state, placeholderImage: nil, optionsInfo: nil, progressBlock: nil, completionHandler: nil)
    }
    
    public func nir_setBackgroundImageWithResource(resource: Resource,
        forState state: UIControlState,
        placeholderImage: UIImage?) -> RetrieveImageTask
    {
        return nir_setBackgroundImageWithResource(resource, forState: state, placeholderImage: placeholderImage, optionsInfo: nil, progressBlock: nil, completionHandler: nil)
    }
    
    public func nir_setBackgroundImageWithURL(URL: NSURL,
        forState state: UIControlState,
        placeholderImage: UIImage?) -> RetrieveImageTask
    {
        return nir_setBackgroundImageWithURL(URL, forState: state, placeholderImage: placeholderImage, optionsInfo: nil, progressBlock: nil, completionHandler: nil)
    }
    
    public func nir_setBackgroundImageWithResource(resource: Resource,
        forState state: UIControlState,
        placeholderImage: UIImage?,
        optionsInfo: NirWebImageOptionsInfo?) -> RetrieveImageTask
    {
        return nir_setBackgroundImageWithResource(resource, forState: state, placeholderImage: placeholderImage, optionsInfo: optionsInfo, progressBlock: nil, completionHandler: nil)
    }
    
    public func nir_setBackgroundImageWithURL(URL: NSURL,
        forState state: UIControlState,
        placeholderImage: UIImage?,
        optionsInfo: NirWebImageOptionsInfo?) -> RetrieveImageTask
    {
        return nir_setBackgroundImageWithURL(URL, forState: state, placeholderImage: placeholderImage, optionsInfo: optionsInfo, progressBlock: nil, completionHandler: nil)
    }
    
    public func nir_setBackgroundImageWithResource(resource: Resource,
        forState state: UIControlState,
        placeholderImage: UIImage?,
        optionsInfo: NirWebImageOptionsInfo?,
        completionHandler: CompletionHandler?) -> RetrieveImageTask
    {
        return nir_setBackgroundImageWithResource(resource, forState: state, placeholderImage: placeholderImage, optionsInfo: optionsInfo, progressBlock: nil, completionHandler: completionHandler)
    }
    
    public func nir_setBackgroundImageWithURL(URL: NSURL,
        forState state: UIControlState,
        placeholderImage: UIImage?,
        optionsInfo: NirWebImageOptionsInfo?,
        completionHandler: CompletionHandler?) -> RetrieveImageTask
    {
        return nir_setBackgroundImageWithURL(URL, forState: state, placeholderImage: placeholderImage, optionsInfo: optionsInfo, progressBlock: nil, completionHandler: completionHandler)
    }
    
    public func nir_setBackgroundImageWithResource(resource: Resource,
        forState state: UIControlState,
        placeholderImage: UIImage?,
        optionsInfo: NirWebImageOptionsInfo?,
        progressBlock: DownloadProgressBlock?,
        completionHandler: CompletionHandler?) -> RetrieveImageTask
    {
        setBackgroundImage(placeholderImage, forState: state)
        nir_setBackgroundWebURL(resource.downloadURL, forState: state)
        let task = NirWebImageManager.sharedManager.retrieveImageWithResource(resource, optionsInfo: optionsInfo, progressBlock: { (receivedSize, totalSize) -> () in
            if let progressBlock = progressBlock {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    progressBlock(receivedSize: receivedSize, totalSize: totalSize)
                })
            }
            }) { [weak self] (image, error, cacheType, imageURL) -> () in
                dispatch_async_safely_main_queue {
                    if let sSelf = self {
                        if (imageURL == sSelf.nir_backgroundWebURLForState(state) && image != nil) {
                            sSelf.setBackgroundImage(image, forState: state)
                        }
                        completionHandler?(image: image, error: error, CacheType: cacheType, imageURL: imageURL)
                    }
                }
        }
        
        return task
    }
    
    public func nir_setBackgroundImageWithURL(URL: NSURL,
        forState state: UIControlState,
        placeholderImage: UIImage?,
        optionsInfo: NirWebImageOptionsInfo?,
        progressBlock: DownloadProgressBlock?,
        completionHandler: CompletionHandler?) -> RetrieveImageTask
    {
        return nir_setBackgroundImageWithResource(Resource(downloadURL: URL),
            forState: state,
            placeholderImage: placeholderImage,
            optionsInfo: optionsInfo,
            progressBlock: progressBlock,
            completionHandler: completionHandler)
    }
}

private var lastBackgroundURLKey: Void?
public extension UIButton {
    /**
     Get the background image URL binded to this button for a specified state.
     
     - parameter state: The state that uses the specified background image.
     
     - returns: Current URL for background image.
     */
    public func nir_backgroundWebURLForState(state: UIControlState) -> NSURL? {
        return nir_backgroundWebURLs[NSNumber(unsignedLong:state.rawValue)] as? NSURL
    }
    
    private func nir_setBackgroundWebURL(URL: NSURL, forState state: UIControlState) {
        nir_backgroundWebURLs[NSNumber(unsignedLong:state.rawValue)] = URL
    }
    
    private var nir_backgroundWebURLs: NSMutableDictionary {
        get {
            var dictionary = objc_getAssociatedObject(self, &lastBackgroundURLKey) as? NSMutableDictionary
            if dictionary == nil {
                dictionary = NSMutableDictionary()
                nir_setBackgroundWebURLs(dictionary!)
            }
            return dictionary!
        }
    }
    
    private func nir_setBackgroundWebURLs(URLs: NSMutableDictionary) {
        objc_setAssociatedObject(self, &lastBackgroundURLKey, URLs, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}