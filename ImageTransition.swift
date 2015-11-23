//
//  ImageTransition.swift
//  NirWebImage
//
//  Created by Nirvana on 11/22/15.
//  Copyright © 2015 NSNirvana. All rights reserved.
//

import UIKit

public enum ImageTransition {
    case None
    case Fade(NSTimeInterval)
    
    case FlipFromLeft(NSTimeInterval)
    case FlipFromRight(NSTimeInterval)
    case FlipFromTop(NSTimeInterval)
    case FlipFromBottom(NSTimeInterval)
    
    case Custom(duration: NSTimeInterval,
        options: UIViewAnimationOptions,
        animations: ((UIImageView, UIImage) -> Void)?,
        completion: ((Bool) -> Void)?)
    
    var duration: NSTimeInterval {
        switch self {
        case .None:                          return 0
        case .Fade(let duration):            return duration
            
        case .FlipFromLeft(let duration):    return duration
        case .FlipFromRight(let duration):   return duration
        case .FlipFromTop(let duration):     return duration
        case .FlipFromBottom(let duration):  return duration
            
        case .Custom(let duration, _, _, _): return duration
        }
    }
    
    var animationOptions: UIViewAnimationOptions {
        switch self {
        case .None:                         return .TransitionNone
        case .Fade(_):                      return .TransitionCrossDissolve
            
        case .FlipFromLeft(_):              return .TransitionFlipFromLeft
        case .FlipFromRight(_):             return .TransitionFlipFromRight
        case .FlipFromTop(_):               return .TransitionFlipFromTop
        case .FlipFromBottom(_):            return .TransitionFlipFromBottom
            
        case .Custom(_, let options, _, _): return options
        }
    }
    
    var animations: ((UIImageView, UIImage) -> Void)? {
        switch self {
        case .Custom(_, _, let animations, _): return animations
        default: return {$0.image = $1}
        }
    }
    
    var completion: ((Bool) -> Void)? {
        switch self {
        case .Custom(_, _, _, let completion): return completion
        default: return nil
        }
    }
}