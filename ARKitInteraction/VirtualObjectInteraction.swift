/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Coordinates movement and gesture interactions with virtual objects.
 虚拟物体的坐标移动和手势交互.
*/

import UIKit
import ARKit

/// - Tag: VirtualObjectInteraction
class VirtualObjectInteraction: NSObject, UIGestureRecognizerDelegate {
    
    /// Developer setting to translate assuming the detected plane extends infinitely.
    /// 开发者设置,假设检测到的平面是无限扩展的
    let translateAssumingInfinitePlane = true
    
    /// The scene view to hit test against when moving virtual content.
    /// 当移动虚拟内容时,用命中测试去测试的场景视图
    let sceneView: VirtualObjectARView
    
    /**
     The object that has been most recently intereacted with.
     The `selectedObject` can be moved at any time with the tap gesture.
     最近发生交互操作的物体.`selectedObject`可以在任何时候被点击手势移动
     */
    var selectedObject: VirtualObject?
    
    /// The object that is tracked for use by the pan and rotation gestures.
    /// 被拖拽或旋转手势操作的物体
    private var trackedObject: VirtualObject? {
        didSet {
            guard trackedObject != nil else { return }
            selectedObject = trackedObject
        }
    }
    
    /// The tracked screen position used to update the `trackedObject`'s position in `updateObjectToCurrentTrackingPosition()`.
    /// 被追踪的屏幕位置,用来在`updateObjectToCurrentTrackingPosition()`中更新`trackedObject`的位置.
    private var currentTrackingPosition: CGPoint?

    init(sceneView: VirtualObjectARView) {
        self.sceneView = sceneView
        super.init()
        
        let panGesture = ThresholdPanGesture(target: self, action: #selector(didPan(_:)))
        panGesture.delegate = self
        
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(didRotate(_:)))
        rotationGesture.delegate = self
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
        
        // Add gestures to the `sceneView`.
        // 添加手势到`sceneView`
        sceneView.addGestureRecognizer(panGesture)
        sceneView.addGestureRecognizer(rotationGesture)
        sceneView.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Gesture Actions 手势动作
    
    @objc
    func didPan(_ gesture: ThresholdPanGesture) {
        switch gesture.state {
        case .began:
            // Check for interaction with a new object.
            // 检查交互物体
            if let object = objectInteracting(with: gesture, in: sceneView) {
                trackedObject = object
            }
            
        case .changed where gesture.isThresholdExceeded:
            guard let object = trackedObject else { return }
            let translation = gesture.translation(in: sceneView)
            
            let currentPosition = currentTrackingPosition ?? CGPoint(sceneView.projectPoint(object.position))
            
            // The `currentTrackingPosition` is used to update the `selectedObject` in `updateObjectToCurrentTrackingPosition()`.
            // `currentTrackingPosition`用来在`updateObjectToCurrentTrackingPosition()`中更新`selectedObject`
            currentTrackingPosition = CGPoint(x: currentPosition.x + translation.x, y: currentPosition.y + translation.y)

            gesture.setTranslation(.zero, in: sceneView)
            
        case .changed:
            // Ignore changes to the pan gesture until the threshold for displacment has been exceeded.
            // 忽略拖拽手势的变化,直到位移超过阈值
            break
            
        default:
            // Clear the current position tracking.
            // 消除当前位置追踪
            currentTrackingPosition = nil
            trackedObject = nil
        }
    }

    /**
     If a drag gesture is in progress, update the tracked object's position by
     converting the 2D touch location on screen (`currentTrackingPosition`) to
     3D world space.
     This method is called per frame (via `SCNSceneRendererDelegate` callbacks),
     allowing drag gestures to move virtual objects regardless of whether one
     drags a finger across the screen or moves the device through space.
     如果一个拖拽手势正在处理中,则通过转换屏幕上的2D触摸位置(`currentTrackingPosition`)到3D世界空间中来更新被追踪物体的位置.
     该方法每帧都被调用(通过`SCNSceneRendererDelegate`回调),允许拖拽手势任意移动物体,不论是在屏幕上划动手指还是在空间移动设备.
     - Tag: updateObjectToCurrentTrackingPosition
     */
    @objc
    func updateObjectToCurrentTrackingPosition() {
        guard let object = trackedObject, let position = currentTrackingPosition else { return }
        translate(object, basedOn: position, infinitePlane: translateAssumingInfinitePlane)
    }

    /// - Tag: didRotate
    @objc
    func didRotate(_ gesture: UIRotationGestureRecognizer) {
        guard gesture.state == .changed else { return }
        
        /*
         - Note:
          For looking down on the object (99% of all use cases), we need to subtract the angle.
          To make rotation also work correctly when looking from below the object one would have to
          flip the sign of the angle depending on whether the object is above or below the camera...
         一般我们是俯视物体的(99%的情况下),所以旋转时需要减去一个角度,朝负方向旋转.
         为了让仰视物体时旋转方向也是正确的,我们需要根据摄像机相对物体的高低来反转角度的正负号.
         */
        trackedObject?.eulerAngles.y -= Float(gesture.rotation)
        
        gesture.rotation = 0
    }
    
    @objc
    func didTap(_ gesture: UITapGestureRecognizer) {
        let touchLocation = gesture.location(in: sceneView)
        
        if let tappedObject = sceneView.virtualObject(at: touchLocation) {
            // Select a new object.
            // 选择一个新物体
            selectedObject = tappedObject
        } else if let object = selectedObject {
            // Teleport the object to whereever the user touched the screen.
            // 将物体传送到用户触摸屏幕的地方.
            translate(object, basedOn: touchLocation, infinitePlane: false)
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow objects to be translated and rotated at the same time.
        // 允许物体被同时平移和旋转.
        return true
    }

    /// A helper method to return the first object that is found under the provided `gesture`s touch locations.
    /// 工具方法,返回`gesture`触摸位置下的第一个物体.
    /// - Tag: TouchTesting
    private func objectInteracting(with gesture: UIGestureRecognizer, in view: ARSCNView) -> VirtualObject? {
        for index in 0..<gesture.numberOfTouches {
            let touchLocation = gesture.location(ofTouch: index, in: view)
            
            // Look for an object directly under the `touchLocation`.
            // 查找`touchLocation`正下方的物体.
            if let object = sceneView.virtualObject(at: touchLocation) {
                return object
            }
        }
        
        // As a last resort look for an object under the center of the touches.
        // 最后都没找到时,查找多个触摸点中心正下方的物体.
        return sceneView.virtualObject(at: gesture.center(in: view))
    }
    
    // MARK: - Update object position 更新物体位置

    /// - Tag: DragVirtualObject
    private func translate(_ object: VirtualObject, basedOn screenPos: CGPoint, infinitePlane: Bool) {
        guard let cameraTransform = sceneView.session.currentFrame?.camera.transform,
            let (position, _, isOnPlane) = sceneView.worldPosition(fromScreenPosition: screenPos,
                                                                   objectPosition: object.simdPosition,
                                                                   infinitePlane: infinitePlane) else { return }
        
        /*
         Plane hit test results are generally smooth. If we did *not* hit a plane,
         smooth the movement to prevent large jumps.
         平面的命中测试结果是相当平滑的.如果我们*没有*碰到平面,则需要平滑移动,防止大的跳动.
         */
        object.setPosition(position, relativeTo: cameraTransform, smoothMovement: !isOnPlane)
    }
}

/// Extends `UIGestureRecognizer` to provide the center point resulting from multiple touches.
/// 扩展`UIGestureRecognizer`,得到多点触摸的中心点.
extension UIGestureRecognizer {
    func center(in view: UIView) -> CGPoint {
        let first = CGRect(origin: location(ofTouch: 0, in: view), size: .zero)

        let touchBounds = (1..<numberOfTouches).reduce(first) { touchBounds, index in
            return touchBounds.union(CGRect(origin: location(ofTouch: index, in: view), size: .zero))
        }

        return CGPoint(x: touchBounds.midX, y: touchBounds.midY)
    }
}
