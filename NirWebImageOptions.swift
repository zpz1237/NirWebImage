//
//  NirWebImageOptions.swift
//  NirWebImage
//
//  Created by Nirvana on 11/22/15.
//  Copyright © 2015 NSNirvana. All rights reserved.
//

import Foundation

public struct NirWebImageOptions : OptionSetType {
    
    public let rawValue: UInt
    
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    public static let None = NirWebImageOptions(rawValue: 0)
    
    public static let LowPriority = NirWebImageOptions(rawValue: 1 << 0)
    
    public static var ForceRefresh = NirWebImageOptions(rawValue: 1 << 1)
    
    public static var CacheMemoryOnly = NirWebImageOptions(rawValue: 1 << 2)
    
    public static var BackgroundDecode = NirWebImageOptions(rawValue: 1 << 3)
    
    public static var BackgroundCallback = NirWebImageOptions(rawValue: 1 << 4)
    
    public static var ScreenScale = NirWebImageOptions(rawValue: 1 << 5)
}

