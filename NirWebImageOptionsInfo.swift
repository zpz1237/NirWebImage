//
//  NirWebImageOptionsInfo.swift
//  NirWebImage
//
//  Created by Nirvana on 11/22/15.
//  Copyright © 2015 NSNirvana. All rights reserved.
//

import Foundation

public typealias NirWebImageOptionsInfo = [NirWebImageOptionsInfoItem]

public enum NirWebImageOptionsInfoItem {
    case Options(NirWebImageOptions)
    case TargetCache(ImageCache)
    case Downloader(ImageDownloader)
    case Transition(ImageTransition)
}

func ==(a: NirWebImageOptionsInfoItem, b: NirWebImageOptionsInfoItem) -> Bool {
    switch (a, b) {
    case (.Options(_), .Options(_)): return true
    case (.TargetCache(_), .TargetCache(_)): return true
    case (.Downloader(_), .Downloader(_)): return true
    case (.Transition(_), .Transition(_)): return true
    default: return false
    }
}

extension CollectionType where Generator.Element == NirWebImageOptionsInfoItem {
    func nir_findFirstMatch(target: Generator.Element) -> Generator.Element? {
        
        let index = indexOf {
            e in
            return e == target
        }
        
        return (index != nil) ? self[index!] : nil
    }
}