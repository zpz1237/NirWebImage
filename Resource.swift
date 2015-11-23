//
//  Resource.swift
//  NirWebImage
//
//  Created by Nirvana on 11/22/15.
//  Copyright © 2015 NSNirvana. All rights reserved.
//

import Foundation

public struct Resource {
    public let cacheKey: String
    public let downloadURL: NSURL
    
    public init(downloadURL: NSURL, cacheKey: String? = nil) {
        self.downloadURL = downloadURL
        self.cacheKey = cacheKey ?? downloadURL.absoluteString
    }
}