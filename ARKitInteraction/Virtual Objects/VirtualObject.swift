/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A `SCNReferenceNode` subclass for virtual objects placed into the AR scene.
 `SCNReferenceNode`子类,用来在AR场景中放置虚拟物体.
*/

import Foundation
import SceneKit
import ARKit

class VirtualObject: SCNReferenceNode {
    
    /// The model name derived from the `referenceURL`.
    /// 从`referenceURL`得到的模型名称.
    var modelName: String {
        return referenceURL.lastPathComponent.replacingOccurrences(of: ".scn", with: "")
    }
    
    /// Use average of recent virtual object distances to avoid rapid changes in object scale.
    /// 使用不久前虚拟物体距离的平均值,以避免在物体范围内快速变动.
    private var recentVirtualObjectDistances = [Float]()
    
    /// Allowed alignments for the virtual object
    var allowedAlignments: [ARPlaneAnchor.Alignment] {
        if modelName == "sticky note" {
            return [.horizontal, .vertical]
        } else if modelName == "painting" {
            return [.vertical]
        } else {
            return [.horizontal]
        }
    }
    
    /// Current alignment of the virtual object
    var currentAlignment: ARPlaneAnchor.Alignment = .horizontal
    
    /// Whether the object is currently changing alignment
    private var isChangingAlignment: Bool = false
    
    /// For correct rotation on horizontal and vertical surfaces, roate around
    /// local y rather than world y. Therefore rotate first child node instead of self.
    /// 对于水平表面和竖直表面的旋转来说,绕本地坐标y轴旋转,而不是世界坐标的y轴.因此旋转第一个节点而不是自己.
    var objectRotation: Float {
        get {
            return childNodes.first!.eulerAngles.y
        }
        set (newValue) {
            var normalized = newValue.truncatingRemainder(dividingBy: 2 * .pi)
            normalized = (normalized + 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
            if normalized > .pi {
                normalized -= 2 * .pi
            }
            childNodes.first!.eulerAngles.y = normalized
            if currentAlignment == .horizontal {
                rotationWhenAlignedHorizontally = normalized
            }
        }
    }
    
    /// Remember the last rotation for horizontal alignment
    var rotationWhenAlignedHorizontally: Float = 0
    
    /// The object's corresponding ARAnchor
    var anchor: ARAnchor?
    
    /// Resets the object's position smoothing.
    func reset() {
        recentVirtualObjectDistances.removeAll()
    }
    
    // MARK: - Helper methods to determine supported placement options
    
    func isPlacementValid(on planeAnchor: ARPlaneAnchor?) -> Bool {
        if let anchor = planeAnchor {
            return allowedAlignments.contains(anchor.alignment)
        }
        return true
    }
    
    /**
     Set the object's position based on the provided position relative to the `cameraTransform`.
     If `smoothMovement` is true, the new position will be averaged with previous position to
     avoid large jumps.
     根据`cameraTransform`中获取的位置,来设置物体的位置.
     如果`smoothMovement`是true,新的位置将会和先前的位置求平均值,以避免大的跳动.
     
     - Tag: VirtualObjectSetPosition
     */
    func setTransform(_ newTransform: float4x4,
                      relativeTo cameraTransform: float4x4,
                      smoothMovement: Bool,
                      alignment: ARPlaneAnchor.Alignment,
                      allowAnimation: Bool) {
        let cameraWorldPosition = cameraTransform.translation
        var positionOffsetFromCamera = newTransform.translation - cameraWorldPosition
        
        // Limit the distance of the object from the camera to a maximum of 10 meters.
        // 限制物体到摄像机的距离的最大值为10米.
        if simd_length(positionOffsetFromCamera) > 10 {
            positionOffsetFromCamera = simd_normalize(positionOffsetFromCamera)
            positionOffsetFromCamera *= 10
        }
        
        /*
         Compute the average distance of the object from the camera over the last ten
         updates. Notice that the distance is applied to the vector from
         the camera to the content, so it affects only the percieved distance to the
         object. Averaging does _not_ make the content "lag".
         计算摄像机到物体平均距离的最近十次更新.注意距离向量是从摄像机到内容的,所以它只影响到物体的认知距离.求平均值不会让内容产生滞后.
         */
        if smoothMovement {
            let hitTestResultDistance = simd_length(positionOffsetFromCamera)
            
            // Add the latest position and keep up to 10 recent distances to smooth with.
            // 添加最新位置,保留10个最近的距离以平滑进入.
            recentVirtualObjectDistances.append(hitTestResultDistance)
            recentVirtualObjectDistances = Array(recentVirtualObjectDistances.suffix(10))
            
            let averageDistance = recentVirtualObjectDistances.average!
            let averagedDistancePosition = simd_normalize(positionOffsetFromCamera) * averageDistance
            simdPosition = cameraWorldPosition + averagedDistancePosition
        } else {
            simdPosition = cameraWorldPosition + positionOffsetFromCamera
        }
        
        updateAlignment(to: alignment, transform: newTransform, allowAnimation: allowAnimation)
    }
    
    // MARK: - Setting the object's alignment
    
    func updateAlignment(to newAlignment: ARPlaneAnchor.Alignment, transform: float4x4, allowAnimation: Bool) {
        if isChangingAlignment {
            return
        }
        
        // Only animate if the alignment has changed.
        // 当对齐方式改变时才执行动画.
        let animationDuration = (newAlignment != currentAlignment && allowAnimation) ? 0.5 : 0
        
        var newObjectRotation: Float?
        switch (newAlignment, currentAlignment) {
        case (.horizontal, .horizontal):
            // When placement remains horizontal, alignment doesn't need to be changed
            // (unlike for vertical, where the surface's world-y-rotation might be different).
            // 当放置方式保持水平,对齐方式无需改变(不像竖直时,平面的y轴旋转是不同的)
            return
        case (.horizontal, .vertical):
            // When changing to horizontal placement, restore the previous horizontal rotation.
            // 当变为水平放置时,储存先前的水平旋转状态.
            newObjectRotation = rotationWhenAlignedHorizontally
        case (.vertical, .horizontal):
            // When changing to vertical placement, reset the object's rotation (y-up).
            newObjectRotation = 0.0001
        default:
            break
        }
        
        currentAlignment = newAlignment
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = animationDuration
        SCNTransaction.completionBlock = {
            self.isChangingAlignment = false
        }
        
        isChangingAlignment = true
        
        // Use the filtered position rather than the exact one from the transform.
        // 使用过滤后的位置,不要用直接从transform中获取的值.
        var mutableTransform = transform
        mutableTransform.translation = simdWorldPosition
        simdTransform = mutableTransform
        
        if newObjectRotation != nil {
            objectRotation = newObjectRotation!
        }
        
        SCNTransaction.commit()
    }
    
    /// - Tag: AdjustOntoPlaneAnchor
    func adjustOntoPlaneAnchor(_ anchor: ARPlaneAnchor, using node: SCNNode) {
        // Test if the alignment of the plane is compatible with the object's allowed placement
        // 测试平面的对齐方式是否和物体放置方式兼容.
        if !allowedAlignments.contains(anchor.alignment) {
            return
        }
        
        // Get the object's position in the plane's coordinate system.
        // 得到物体在平面坐标系统中的位置.
        let planePosition = node.convertPosition(position, from: parent)
        
        // Check that the object is not already on the plane.
        // 检查物体是否已经在平面上了.
        guard planePosition.y != 0 else { return }
        
        // Add 10% tolerance to the corners of the plane.
        // 给平面的边角添加10%的偏差.
        let tolerance: Float = 0.1
        
        let minX: Float = anchor.center.x - anchor.extent.x / 2 - anchor.extent.x * tolerance
        let maxX: Float = anchor.center.x + anchor.extent.x / 2 + anchor.extent.x * tolerance
        let minZ: Float = anchor.center.z - anchor.extent.z / 2 - anchor.extent.z * tolerance
        let maxZ: Float = anchor.center.z + anchor.extent.z / 2 + anchor.extent.z * tolerance
        
        guard (minX...maxX).contains(planePosition.x) && (minZ...maxZ).contains(planePosition.z) else {
            return
        }
        
        // Move onto the plane if it is near it (within 5 centimeters).
        // 当接近平面时(5厘米内),则移动到平面上.
        let verticalAllowance: Float = 0.05
        let epsilon: Float = 0.001 // Do not update if the difference is less than 1 mm. 当差异小于1毫米时不再更新.
        let distanceToPlane = abs(planePosition.y)
        if distanceToPlane > epsilon && distanceToPlane < verticalAllowance {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = CFTimeInterval(distanceToPlane * 500) // Move 2 mm per second.每秒移动2毫米
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
            position.y = anchor.transform.columns.3.y
            updateAlignment(to: anchor.alignment, transform: simdWorldTransform, allowAnimation: false)
            SCNTransaction.commit()
        }
    }
}

extension VirtualObject {
    // MARK: Static Properties and Methods 静态属性和方法
    
    /// Loads all the model objects within `Models.scnassets`.
    /// 加载`Models.scnassets`中的所有物体模型.
    static let availableObjects: [VirtualObject] = {
        let modelsURL = Bundle.main.url(forResource: "Models.scnassets", withExtension: nil)!

        let fileEnumerator = FileManager().enumerator(at: modelsURL, includingPropertiesForKeys: [])!

        return fileEnumerator.compactMap { element in
            let url = element as! URL

            guard url.pathExtension == "scn" && !url.path.contains("lighting") else { return nil }

            return VirtualObject(url: url)
        }
    }()
    
    /// Returns a `VirtualObject` if one exists as an ancestor to the provided node.
    /// 返回包含传入节点的`VirtualObject`.
    static func existingObjectContainingNode(_ node: SCNNode) -> VirtualObject? {
        if let virtualObjectRoot = node as? VirtualObject {
            return virtualObjectRoot
        }
        
        guard let parent = node.parent else { return nil }
        
        // Recurse up to check if the parent is a `VirtualObject`.
        // 向上递归检查,看父节点是否是一个`VirtualObject`.
        return existingObjectContainingNode(parent)
    }
}

extension Collection where Element == Float, Index == Int {
    /// Return the mean of a list of Floats. Used with `recentVirtualObjectDistances`.
    /// 返回Floats列表的平均数.用在recentVirtualObjectDistances`.
    var average: Float? {
        guard !isEmpty else {
            return nil
        }

        let sum = reduce(Float(0)) { current, next -> Float in
            return current + next
        }

        return sum / Float(count)
    }
}
