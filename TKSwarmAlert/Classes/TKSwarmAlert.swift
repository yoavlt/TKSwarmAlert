//
//  SWAlert.swift
//  SWAlertView
//
//  Created by Takuya Okamoto on 2015/08/18.
//  Copyright (c) 2015年 Uniface. All rights reserved.
//

import UIKit


public class TKSwarmAlert {
    
    public var durationOfPreventingTapBackgroundArea: NSTimeInterval = 0
    public var didDissmissAllViews: ()->Void = {}

    private var staticViews: [UIView] = []
    public var animationView: FallingAnimationView?
    public var blurView: TKSWBackgroundView?
    public let type: TKSWBackgroundType
    
    public init(backgroundType: TKSWBackgroundType = .Blur) {
        self.type = backgroundType
    }
    
    public func addNextViews(views:[UIView]) {
        self.animationView?.nextViewsList.append(views)
    }
    
    public func addSubStaticView(view:UIView) {
        view.tag = -1
        self.staticViews.append(view)
    }
    
    public func show(views:[UIView], snapBackDistance: CGFloat = 100) {
        let window:UIWindow? = UIApplication.sharedApplication().keyWindow
        if window != nil {
            let frame:CGRect = window!.bounds
            blurView = TKSWBackgroundView(frame: frame, type: type)
            animationView = FallingAnimationView(frame: frame, snapBackDistance: snapBackDistance)
            
            if durationOfPreventingTapBackgroundArea > 0 {
                animationView?.enableToTapSuperView = false
                NSTimer.schedule(delay: durationOfPreventingTapBackgroundArea) { [weak self] _ in
                    self?.animationView?.enableToTapSuperView = true
                }
            }
            
            let showDuration:NSTimeInterval = 0.2

            for staticView in staticViews {
                let originalAlpha = staticView.alpha
                staticView.alpha = 0
                animationView?.addSubview(staticView)
                UIView.animateWithDuration(showDuration) {
                    staticView.alpha = originalAlpha
                }
            }
            window!.addSubview(blurView!)
            window!.addSubview(animationView!)
            blurView?.show(duration:showDuration) {
                self.spawn(views)
            }

            animationView?.willDissmissAllViews = {
                let fadeOutDuration:NSTimeInterval = 0.2
                for v in self.staticViews {
                    UIView.animateWithDuration(fadeOutDuration) {
                        v.alpha = 0
                    }
                }
                UIView.animateWithDuration(fadeOutDuration) {
                    self.blurView?.alpha = 0
                }
            }
            animationView?.didDismissAllViews = {
                self.animationView?.removeFromSuperview()
                self.didDissmissAllViews()
            }
            animationView?.didDisappearAllViews = {
                self.animationView?.userInteractionEnabled = false
                self.blurView?.removeFromSuperview()
                for staticView in self.staticViews {
                    staticView.alpha = 1
                }
            }
        }
    }
    
    public func dismiss() {
        self.animationView?.forceDismiss()
        self.animationView?.removeFromSuperview()
        self.blurView?.removeFromSuperview()
    }
    
    public func spawn(views:[UIView]) {
        self.animationView?.spawn(views)
    }
}
