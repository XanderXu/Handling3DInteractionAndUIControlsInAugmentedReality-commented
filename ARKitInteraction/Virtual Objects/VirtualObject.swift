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
    
    /// Resets the objects poisition smoothing.
    /// 平滑地重设物体位置.
    func reset() {
        recentVirtualObjectDistances.removeAll()
    }
	
    /**
     Set the object's position based on the provided position relative to the `cameraTransform`.
     If `smoothMovement` is true, the new position will be averaged with previous position to
     avoid large jumps.
     根据`cameraTransform`中获取的位置,来设置物体的位置.
     如果`smoothMovement`是true,新的位置将会和先前的位置求平均值,以避免大的跳动.
     
     - Tag: VirtualObjectSetPosition
     */
    func setPosition(_ newPosition: float3, relativeTo cameraTransform: matrix_float4x4, smoothMovement: Bool) {
        let cameraWorldPosition = cameraTransform.translation
        var positionOffsetFromCamera = newPosition - cameraWorldPosition
        
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
    }
    
    /// - Tag: AdjustOntoPlaneAnchor
    func adjustOntoPlaneAnchor(_ anchor: ARPlaneAnchor, using node: SCNNode) {
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

        return fileEnumerator.flatMap { element in
            let url = element as! URL

            guard url.pathExtension == "scn" else { return nil }

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

extension Collection where Iterator.Element == Float, IndexDistance == Int {
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
