//
//  FallingAnimationView.swift
//  dinamicTest
//
//  Created by Takuya Okamoto on 2015/08/14.
//  Copyright (c) 2015年 Uniface. All rights reserved.
//

//http://stackoverflow.com/questions/21325057/implement-uikitdynamics-for-dragging-view-off-screen



/*

TODO:
* ✔ 落ちながら登場する感じ
* ✔ Viewを渡したら落ちてくるような感じにしたいな
* ✔ UIViewのクラスにする？
* ✔ 連続登場
* ✔ 落としたあとに戻ってくる

SHOULD FIX:
* なんか登場時ギザギザしてる

WANNA FIX:
* ドラッグ時に震えるの何とかしたい
* 凄く早く連続で落とすと残る

WANNA DO:
* ジャイロパララックス
* タップすると震える

*/


import UIKit


/* Usage

*/

public class FallingAnimationView: UIView {
    
    var willDissmissAllViews: () -> () = {}
    var didDismissAllViews:  () -> () = {}
    var didDisappearAllViews: () -> () = {}
    
    let gravityMagniture:CGFloat = 3
    let fieldMargin:CGFloat = 300

    var snapBackDistance:CGFloat = 100
    var snapBackVelocity:CGFloat = 1000000

    var animator: UIDynamicAnimator
    var animationView: UIView
    var attachmentBehavior: UIAttachmentBehavior?
    var startPoints: [CGPoint] = []
    var currentAnimationViewTags: [Int] = []
    var nextViewsList: [[UIView]] = []
    public var delayRemoveOfView: Double = 0.0
    
    public var enableToTapSuperView: Bool = true

    var allViews: [UIView] {
        get {
            return animationView.subviews.filter({ (view: AnyObject) -> Bool in
//                view.dynamicType === UIView.self
                view is UIView
            }) 
        }
    }
    var animatedViews:[UIView] {
        get {
            return allViews.filter({ (view:UIView) -> Bool in view.tag >= 0 })
        }
    }
    var staticViews:[UIView] {
        get {
            return allViews.filter({ (view:UIView) -> Bool in view.tag < 0 })
        }
    }

    var currentAnimationViews: [UIView] {
        get {
            return animatedViews.filter(isCurrentView)
        }
    }
    var unCurrentAnimationViews: [UIView] {
        get {
            return animatedViews.filter(isUnCurrentView)
        }
    }
    
    func isCurrentView(view:UIView) -> Bool {
        for currentTag in self.currentAnimationViewTags {
            if currentTag == view.tag {
                return true
            }
        }
        return false
    }
    func isUnCurrentView(view:UIView) -> Bool {
        for currentTag in self.currentAnimationViewTags {
            if currentTag == view.tag {
                return false
            }
        }
        return true
    }

    
//    func fadeOutStaticViews(#duration:NSTimeInterval) {
//        for v in self.staticViews {
//            UIView.animateWithDuration(duration) {
//                v.alpha = 0
//            }
//        }
//    }
    
    init(frame:CGRect, snapBackDistance: CGFloat = 100, snapBackVelocity: CGFloat = 1000000) {
        self.animationView = UIView()
        self.animator = UIDynamicAnimator(referenceView: animationView)
        self.snapBackDistance = snapBackDistance
        self.snapBackVelocity = snapBackVelocity
        super.init(frame:frame)
        animationView.frame = CGRect(x: 0, y: 0, width: self.frame.size.width + fieldMargin*2, height: self.frame.size.height + fieldMargin*2)
        animationView.center = self.center
        self.addSubview(animationView)
     
        enableTapGesture()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
    // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

    func spawn(views:[UIView]) {
        //refresh
        currentAnimationViewTags = []
        animator.removeAllBehaviors()
        fallAndRemove(animatedViews)
        //fixMargin
        for v in views {
            v.frame.x = v.frame.x + fieldMargin
            v.frame.y = v.frame.y + fieldMargin
        }
        // make it draggable
        for v in views {
//            dev_makeLine(v)
            v.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(FallingAnimationView.didDrag(_:))))
            v.tag = startPoints.count
            startPoints.append(v.center)
            currentAnimationViewTags.append(v.tag)
        }
        // lift up
        let upDist:CGFloat = calcHideUpDistance(views)
        for v in views {
            v.frame.y = v.frame.y - upDist
            animationView.addSubview(v)
        }
        //drop
        collisionAll()
        snap(views)
    }
    
    func spawnNextViews() {
        let views = nextViewsList.removeAtIndex(0)
        spawn(views)
    }
    

    func didDrag(gesture: UIPanGestureRecognizer) {
        let gestureView = gesture.view!
        if gesture.state == UIGestureRecognizerState.Began {
            self.animator.removeAllBehaviors()
            collisionAll()
            snapAll()
            fallAndRemove(unCurrentAnimationViews)
            // drag start
            let gripPoint: CGPoint = gesture.locationInView(gestureView)
            let offsetFromCenter: UIOffset = UIOffsetMake(
                gripPoint.x - gestureView.bounds.size.width  / 2.0,
                gripPoint.y - gestureView.bounds.size.height / 2.0
            )
            let anchorPoint: CGPoint = gesture.locationInView(gestureView.superview)
            attachmentBehavior = UIAttachmentBehavior(item: gestureView, offsetFromCenter: offsetFromCenter, attachedToAnchor: anchorPoint)
            self.animator.addBehavior(attachmentBehavior!)
        }
        else if gesture.state == UIGestureRecognizerState.Changed {
            // drag move
            let touchPoint: CGPoint = gesture.locationInView(gestureView.superview)
            attachmentBehavior?.anchorPoint = touchPoint
        }
        else if gesture.state == UIGestureRecognizerState.Ended {
            disableTapGesture()
            self.animator.removeAllBehaviors()
            collisionAll()
            // judge if fall
            let touchPoint: CGPoint = gesture.locationInView(gestureView.superview)
            let movedDistance = distance(from: startPoints[gestureView.tag], to: touchPoint)
            let velocity = gesture.velocityInView(self.animationView.superview)
            let speed = velocity.x * velocity.x + velocity.y * velocity.y
            if movedDistance < snapBackDistance && speed < 1000000 {// not fall
                let snap = UISnapBehavior(item: gestureView, snapToPoint: startPoints[gestureView.tag])
                self.animator.addBehavior(snap)
            }
            else {
                if nextViewsList.count != 0 {//next
                    spawnNextViews()
                }
                else {// fall
                    // velocity
                    let pushBehavior = UIPushBehavior(items: [gestureView], mode: UIPushBehaviorMode.Instantaneous)
                    let velocity: CGPoint = gesture.velocityInView(gestureView.superview)
                    pushBehavior.pushDirection = CGVectorMake((velocity.x / 900), (velocity.y / 900))
                    self.animator.addBehavior(pushBehavior)
                    
                    disableDragGesture()
                    fallAndRemoveAll()
                }
            }
        }
    }
    
    func onTapSuperView() {
        if enableToTapSuperView {
            animator.removeAllBehaviors()
            disableTapGesture()
            if nextViewsList.count != 0 {//next
                spawnNextViews()
            }
            else {
                disableDragGesture()
                fallAndRemoveAll()
            }
        }
    }
    
    func fallAndRemoveAll() {
        fallAndRemove(animatedViews)
        if nextViewsList.count == 0 {
            //ここでフェードアウト
            disableTapGesture()
            self.willDissmissAllViews()
        }
    }

    
    // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    // MARK: behaviors
    func collisionAll() {
        let collisionBehavior = UICollisionBehavior(items: animatedViews)
        collisionBehavior.translatesReferenceBoundsIntoBoundary = true//❓
        self.animator.addBehavior(collisionBehavior)
    }
    
    func snapAll() {
        snap(currentAnimationViews)
    }
    func snap(views:[UIView]) {
        for v in views {
            let snap = UISnapBehavior(item: v, snapToPoint: startPoints[v.tag])
            self.animator.addBehavior(snap)
        }
    }
    
    func fallAndRemove(views:[UIView]) {
        let gravity = UIGravityBehavior(items: views)
        gravity.magnitude = gravityMagniture
        gravity.action = { [weak self] in
            self?.removeBehaviorIfNeeded()
            if let condition = self?.inSuperView {
                let disappearableViews = views.filter { condition($0) == false }
                for v in disappearableViews {
                    self?.removeViewAndCheck(v)
                }
                if let av = self?.animatedViews {
                    if av.filter(condition).count <= 0 {
                        self?.didDisappearAllViews()
                        self?.didDisappearAllViews = { _ in }
                    }
                }
            }
        }
        self.animator.addBehavior(gravity)
    }

    func inSuperView(v: UIView) -> Bool {
        if v.superview == nil {
            return false
        }
        if v.frame.top >= (v.superview!.bounds.bottom - fieldMargin) {
            return false
        }
        else if v.frame.right <= (v.superview!.bounds.left + fieldMargin) {
            return false
        }
        else if v.frame.left >= (v.superview!.bounds.right - fieldMargin) {
            return false
        }
        return true
    }

    func removeViewAndCheck(view: UIView?) {
        after(delayRemoveOfView, then: { [weak self] _ in
            view?.removeFromSuperview()
            if let condition = self?.inSuperView, let views = self?.animatedViews {
                if views.filter(condition).count <= 0 {
                    self?.didDismissAllViews()
                    self?.didDismissAllViews = { _ in }
                }
            }
        })
        removeBehaviorIfNeeded()
    }
    
    func removeBehaviorIfNeeded() {
        if animatedViews.count == 0 {
            animator.removeAllBehaviors()
            didDismissAllViews()
        }
    }

    // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    // MARK: Util
    func disableDragGesture() {
        // remove event
        for v in allViews {
            if let recognizers = v.gestureRecognizers {
                for recognizer in recognizers {
                    v.removeGestureRecognizer(recognizer)
                }
            }
        }
    }
    
    func enableTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(FallingAnimationView.onTapSuperView))
        self.addGestureRecognizer(tapGesture)
    }
    
    func forceDismiss() {
        for v in animatedViews {
            v.removeFromSuperview()
        }
        didDismissAllViews()
        didDismissAllViews = { _ in }
    }
    
    func disableTapGesture() {
        if let recognizers = self.gestureRecognizers {
            for recognizer in recognizers {
                self.removeGestureRecognizer(recognizer)
            }
        }

        NSTimer.schedule(delay: 0.5) { [weak self] (timer) in
            self?.enableTapGesture()
        }
    }

    func dev_makeLine(v: UIView) {
        let lineView = UIView(frame: v.frame)
        lineView.backgroundColor = UIColor.clearColor()
        lineView.layer.borderColor = UIColor.blueColor().colorWithAlphaComponent(0.2).CGColor
        lineView.layer.borderWidth = 1
        lineView.tag = -1
        animationView.addSubview(lineView)
    }
    
    func calcHideUpDistance(views:[UIView])->CGFloat {
        var minimumTop:CGFloat = CGFloat(HUGE)
        for view in views {
            if view.frame.y < minimumTop {
                minimumTop = view.frame.y
            }
        }
        return minimumTop
    }
    
    func distance(from from:CGPoint, to:CGPoint) -> CGFloat {
        let xDist = (to.x - from.x)
        let yDist = (to.y - from.y)
        return sqrt((xDist * xDist) + (yDist * yDist))
    }
    
    func after(seconds: Double, then: () -> ()) {
        let delay = seconds * Double(NSEC_PER_SEC)
        let time  = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
        dispatch_after(time, dispatch_get_main_queue(), then)
    }
}