/*
See LICENSE folder for this sample’s licensing information.

Abstract:
SceneKit node giving the user hints about the status of ARKit world tracking.
 SceneKit的节点,给用户提示 ARKit世界追踪的状态.
*/

import Foundation
import ARKit

/**
 An `SCNNode` which is used to provide uses with visual cues about the status of ARKit world tracking.
 使用一个`SCNNode`来给用户提供ARKit世界追踪的状态信息.
 - Tag: FocusSquare
 */
class FocusSquare: SCNNode {
    // MARK: - Types
    
    enum State: Equatable {
        case initializing
        case detecting(hitTestResult: ARHitTestResult, camera: ARCamera?)
    }
    
    // MARK: - Configuration Properties 配置属性
    
    // Original size of the focus square in meters.
    // 聚焦框的原始尺寸,单位是米.
    static let size: Float = 0.17
    
    // Thickness of the focus square lines in meters.
    // 聚焦框的线宽,单位是米.
    static let thickness: Float = 0.018
    
    // Scale factor for the focus square when it is closed, w.r.t. the original size.
    // 当聚焦框关闭状态时的缩放因子,原始尺寸.
    static let scaleForClosedSquare: Float = 0.97
    
    // Side length of the focus square segments when it is open (w.r.t. to a 1x1 square).
    // 当聚焦框打开状态时边的长度
    static let sideLengthForOpenSegments: CGFloat = 0.2
    
    // Duration of the open/close animation
    // 开启/关闭动画的时长.
    static let animationDuration = 0.7
    
    static let primaryColor = #colorLiteral(red: 1, green: 0.8, blue: 0, alpha: 1)
    
    // Color of the focus square fill.
    // 聚焦框填充颜色.
    static let fillColor = #colorLiteral(red: 1, green: 0.9254901961, blue: 0.4117647059, alpha: 1)
    
    // MARK: - Properties 属性
    
    /// The most recent position of the focus square based on the current state.
    /// 根据当前状态,得到聚焦框最新的位置.
    var lastPosition: float3? {
        switch state {
        case .initializing: return nil
        case .detecting(let hitTestResult, _): return hitTestResult.worldTransform.translation
        }
    }
    
    var state: State = .initializing {
        didSet {
            guard state != oldValue else { return }
            
            switch state {
            case .initializing:
                displayAsBillboard()
                
            case let .detecting(hitTestResult, camera):
                if let planeAnchor = hitTestResult.anchor as? ARPlaneAnchor {
                    displayAsClosed(for: hitTestResult, planeAnchor: planeAnchor, camera: camera)
                    currentPlaneAnchor = planeAnchor
                } else {
                    displayAsOpen(for: hitTestResult, camera: camera)
                    currentPlaneAnchor = nil
                }
            }
        }
    }
    
    /// Indicates whether the segments of the focus square are disconnected.
    /// 标识,聚焦框的线段是否处于断开状态.
    private var isOpen = false
    
    /// Indicates if the square is currently being animated.
    /// 标识,聚焦框是否处于动画中.
    private var isAnimating = false
    
    /// Indicates if the square is currently changing its alignment.
    /// 标识方框是否正在改变对齐方式.
    private var isChangingAlignment = false
    
    /// The focus square's current alignment.
    /// 聚焦框当前的对齐方式.
    private var currentAlignment: ARPlaneAnchor.Alignment?
    
    /// The current plane anchor if the focus square is on a plane.
    /// 如果聚焦框是在平面上,则有当前平面锚点
    private(set) var currentPlaneAnchor: ARPlaneAnchor?
    
    /// The focus square's most recent positions.
    /// 聚焦框最新的位置.
    private var recentFocusSquarePositions: [float3] = []
    
    /// The focus square's most recent alignments.
    /// 聚焦框最新的对齐
    private(set) var recentFocusSquareAlignments: [ARPlaneAnchor.Alignment] = []
    
    /// Previously visited plane anchors.
    /// 先前访问过的平面锚点.
    private var anchorsOfVisitedPlanes: Set<ARAnchor> = []
    
    /// List of the segments in the focus square.
    /// 聚焦框中的线段列表.
    private var segments: [FocusSquare.Segment] = []
    
    /// The primary node that controls the position of other `FocusSquare` nodes.
    /// 控制其他`FocusSquare`节点位置的主节点.
    private let positioningNode = SCNNode()
    
    // MARK: - Initialization 初始化
    
    override init() {
        super.init()
        opacity = 0.0
        
        /*
         The focus square consists of eight segments as follows, which can be individually animated.
         聚焦框包含了下面的八个线段,各个线段可以有单独的动画效果.
             s1  s2
             _   _
         s3 |     | s4
         
         s5 |     | s6
             -   -
             s7  s8
         */
        let s1 = Segment(name: "s1", corner: .topLeft, alignment: .horizontal)
        let s2 = Segment(name: "s2", corner: .topRight, alignment: .horizontal)
        let s3 = Segment(name: "s3", corner: .topLeft, alignment: .vertical)
        let s4 = Segment(name: "s4", corner: .topRight, alignment: .vertical)
        let s5 = Segment(name: "s5", corner: .bottomLeft, alignment: .vertical)
        let s6 = Segment(name: "s6", corner: .bottomRight, alignment: .vertical)
        let s7 = Segment(name: "s7", corner: .bottomLeft, alignment: .horizontal)
        let s8 = Segment(name: "s8", corner: .bottomRight, alignment: .horizontal)
        segments = [s1, s2, s3, s4, s5, s6, s7, s8]
        
        let sl: Float = 0.5  // segment length 线段长
        let c: Float = FocusSquare.thickness / 2 // correction to align lines perfectly 纠正线段,使其完美对齐.
        s1.simdPosition += float3(-(sl / 2 - c), -(sl - c), 0)
        s2.simdPosition += float3(sl / 2 - c, -(sl - c), 0)
        s3.simdPosition += float3(-sl, -sl / 2, 0)
        s4.simdPosition += float3(sl, -sl / 2, 0)
        s5.simdPosition += float3(-sl, sl / 2, 0)
        s6.simdPosition += float3(sl, sl / 2, 0)
        s7.simdPosition += float3(-(sl / 2 - c), sl - c, 0)
        s8.simdPosition += float3(sl / 2 - c, sl - c, 0)
        
        positioningNode.eulerAngles.x = .pi / 2 // Horizontal 水平
        positioningNode.simdScale = float3(FocusSquare.size * FocusSquare.scaleForClosedSquare)
        for segment in segments {
            positioningNode.addChildNode(segment)
        }
        positioningNode.addChildNode(fillPlane)
        
        // Always render focus square on top of other content.
        // 总是在其它内容上面渲染聚焦框.
        displayNodeHierarchyOnTop(true)
        
        addChildNode(positioningNode)
        
        // Start the focus square as a billboard.
        // 将聚焦框做为广告牌展示.(广告牌:总是以特定的面面对摄像机)
        displayAsBillboard()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("\(#function) has not been implemented")
    }
    
    // MARK: - Appearance 外观
    
    /// Hides the focus square.
    /// 隐藏聚焦框.
    func hide() {
        guard action(forKey: "hide") == nil else { return }
        
        displayNodeHierarchyOnTop(false)
        runAction(.fadeOut(duration: 0.5), forKey: "hide")
    }
    
    /// Unhides the focus square.
    /// 取消隐藏聚焦框.
    func unhide() {
        guard action(forKey: "unhide") == nil else { return }
        
        displayNodeHierarchyOnTop(true)
        runAction(.fadeIn(duration: 0.5), forKey: "unhide")
    }
    
    /// Displays the focus square parallel to the camera plane.
    /// 让聚焦框平行于摄像机平面显示.
    private func displayAsBillboard() {
        simdTransform = matrix_identity_float4x4
        eulerAngles.x = .pi / 2
        simdPosition = float3(0, 0, -0.8)
        unhide()
        performOpenAnimation()
    }

    /// Called when a surface has been detected.
    /// 当检测到表面时调用
    private func displayAsOpen(for hitTestResult: ARHitTestResult, camera: ARCamera?) {
        performOpenAnimation()
        let position = hitTestResult.worldTransform.translation
        recentFocusSquarePositions.append(position)
        updateTransform(for: position, hitTestResult: hitTestResult, camera: camera)
    }
    
    /// Called when a plane has been detected.
    /// 当检测到平面时调用.
    private func displayAsClosed(for hitTestResult: ARHitTestResult, planeAnchor: ARPlaneAnchor, camera: ARCamera?) {
        performCloseAnimation(flash: !anchorsOfVisitedPlanes.contains(planeAnchor))
        anchorsOfVisitedPlanes.insert(planeAnchor)
        let position = hitTestResult.worldTransform.translation
        recentFocusSquarePositions.append(position)
        updateTransform(for: position, hitTestResult: hitTestResult, camera: camera)
    }
    
    // MARK: Helper Methods 工具方法

    /// Update the transform of the focus square to be aligned with the camera.
    /// 更新聚焦框的变换矩阵,总是对齐摄像机.
    private func updateTransform(for position: float3, hitTestResult: ARHitTestResult, camera: ARCamera?) {
        // Average using several most recent positions.
        // 使用几个最近的位置求平均值.
        recentFocusSquarePositions = Array(recentFocusSquarePositions.suffix(10))
        
        // Move to average of recent positions to avoid jitter.
        // 移动到最近位置的平均值片,以避免抖动.
        let average = recentFocusSquarePositions.reduce(float3(0), { $0 + $1 }) / Float(recentFocusSquarePositions.count)
        self.simdPosition = average
        self.simdScale = float3(scaleBasedOnDistance(camera: camera))
        
        // Correct y rotation of camera square.
        // 纠正摄像机的y轴旋转
        guard let camera = camera else { return }
        let tilt = abs(camera.eulerAngles.x)
        let threshold1: Float = .pi / 2 * 0.65
        let threshold2: Float = .pi / 2 * 0.75
        let yaw = atan2f(camera.transform.columns.0.x, camera.transform.columns.1.x)
        var angle: Float = 0
        
        switch tilt {
        case 0..<threshold1:
            angle = camera.eulerAngles.y
            
        case threshold1..<threshold2:
            let relativeInRange = abs((tilt - threshold1) / (threshold2 - threshold1))
            let normalizedY = normalize(camera.eulerAngles.y, forMinimalRotationTo: yaw)
            angle = normalizedY * (1 - relativeInRange) + yaw * relativeInRange
            
        default:
            angle = yaw
        }
        
        if state != .initializing {
            updateAlignment(for: hitTestResult, yRotationAngle: angle)
        }
    }
    
    private func updateAlignment(for hitTestResult: ARHitTestResult, yRotationAngle angle: Float) {
        // Abort if an animation is currently in progress.
        // 当前动画进行中,则中止.
        if isChangingAlignment {
            return
        }
        
        var shouldAnimateAlignmentChange = false
        
        let tempNode = SCNNode()
        tempNode.simdRotation = float4(0, 1, 0, angle)
        
        // Determine current alignment
        var alignment: ARPlaneAnchor.Alignment?
        if let planeAnchor = hitTestResult.anchor as? ARPlaneAnchor {
            alignment = planeAnchor.alignment
        } else if hitTestResult.type == .estimatedHorizontalPlane {
            alignment = .horizontal
        } else if hitTestResult.type == .estimatedVerticalPlane {
            alignment = .vertical
        }
        
        // add to list of recent alignments
        if alignment != nil {
            recentFocusSquareAlignments.append(alignment!)
        }
        
        // Average using several most recent alignments.
        recentFocusSquareAlignments = Array(recentFocusSquareAlignments.suffix(20))
        
        let horizontalHistory = recentFocusSquareAlignments.filter({ $0 == .horizontal }).count
        let verticalHistory = recentFocusSquareAlignments.filter({ $0 == .vertical }).count
        
        // Alignment is same as most of the history - change it
        // 对齐方式和历史中的大部分相同--改变它
        if alignment == .horizontal && horizontalHistory > 15 ||
            alignment == .vertical && verticalHistory > 10 ||
            hitTestResult.anchor is ARPlaneAnchor {
            if alignment != currentAlignment {
                shouldAnimateAlignmentChange = true
                currentAlignment = alignment
                recentFocusSquareAlignments.removeAll()
            }
        } else {
            // Alignment is different than most of the history - ignore it
            // 对齐方式和历史中的大部分不同--忽略它.
            alignment = currentAlignment
            return
        }
        
        if alignment == .vertical {
            tempNode.simdOrientation = hitTestResult.worldTransform.orientation
            shouldAnimateAlignmentChange = true
        }
        
        // Change the focus square's alignment
        if shouldAnimateAlignmentChange {
            performAlignmentAnimation(to: tempNode.simdOrientation)
        } else {
            simdOrientation = tempNode.simdOrientation
        }
    }
    
    private func normalize(_ angle: Float, forMinimalRotationTo ref: Float) -> Float {
        // Normalize angle in steps of 90 degrees such that the rotation to the other angle is minimal
        // 将角度值规范化到90度这内,这样旋转到其他角度总是最小值.
        var normalized = angle
        while abs(normalized - ref) > .pi / 4 {
            if angle > ref {
                normalized -= .pi / 2
            } else {
                normalized += .pi / 2
            }
        }
        return normalized
    }

    /**
     Reduce visual size change with distance by scaling up when close and down when far away.
     当远离时,根据距离来缩放视觉上的尺寸.
     These adjustments result in a scale of 1.0x for a distance of 0.7 m or less
     (estimated distance when looking at a table), and a scale of 1.2x
     for a distance 1.5 m distance (estimated distance when looking at the floor).
     调整后的结果是:距离0.7米左右(大约是当注视一张桌子时的距离)时缩放倍数1.0x,距离1.5米左右(大约是当注视地板时的距离)时缩放倍数1.2x
     */
    private func scaleBasedOnDistance(camera: ARCamera?) -> Float {
        guard let camera = camera else { return 1.0 }

        let distanceFromCamera = simd_length(simdWorldPosition - camera.transform.translation)
        if distanceFromCamera < 0.7 {
            return distanceFromCamera / 0.7
        } else {
            return 0.25 * distanceFromCamera + 0.825
        }
    }
    
    // MARK: Animations 动画
    
    private func performOpenAnimation() {
        guard !isOpen, !isAnimating else { return }
        isOpen = true
        isAnimating = true

        // Open animation 打开动画
        SCNTransaction.begin()
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        SCNTransaction.animationDuration = FocusSquare.animationDuration / 4
        positioningNode.opacity = 1.0
        for segment in segments {
            segment.open()
        }
        SCNTransaction.completionBlock = {
            self.positioningNode.runAction(pulseAction(), forKey: "pulse")
            // This is a safe operation because `SCNTransaction`'s completion block is called back on the main thread.
            // 这是个线程安全的操作,因为`SCNTransaction`的completion block是在主线程调用的.
            self.isAnimating = false
        }
        SCNTransaction.commit()
        
        // Add a scale/bounce animation.
        // 添加一个缩放/弹簧效果动画
        SCNTransaction.begin()
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        SCNTransaction.animationDuration = FocusSquare.animationDuration / 4
        positioningNode.simdScale = float3(FocusSquare.size)
        SCNTransaction.commit()
    }

    private func performCloseAnimation(flash: Bool = false) {
        guard isOpen, !isAnimating else { return }
        isOpen = false
        isAnimating = true
        
        positioningNode.removeAction(forKey: "pulse")
        positioningNode.opacity = 1.0
        
        // Close animation 关闭动画
        SCNTransaction.begin()
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        SCNTransaction.animationDuration = FocusSquare.animationDuration / 2
        positioningNode.opacity = 0.99
        SCNTransaction.completionBlock = {
            SCNTransaction.begin()
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
            SCNTransaction.animationDuration = FocusSquare.animationDuration / 4
            for segment in self.segments {
                segment.close()
            }
            SCNTransaction.completionBlock = { self.isAnimating = false }
            SCNTransaction.commit()
        }
        SCNTransaction.commit()
        
        // Scale/bounce animation
        // 缩放/弹簧效果动画
        positioningNode.addAnimation(scaleAnimation(for: "transform.scale.x"), forKey: "transform.scale.x")
        positioningNode.addAnimation(scaleAnimation(for: "transform.scale.y"), forKey: "transform.scale.y")
        positioningNode.addAnimation(scaleAnimation(for: "transform.scale.z"), forKey: "transform.scale.z")
        
        if flash {
            let waitAction = SCNAction.wait(duration: FocusSquare.animationDuration * 0.75)
            let fadeInAction = SCNAction.fadeOpacity(to: 0.25, duration: FocusSquare.animationDuration * 0.125)
            let fadeOutAction = SCNAction.fadeOpacity(to: 0.0, duration: FocusSquare.animationDuration * 0.125)
            fillPlane.runAction(SCNAction.sequence([waitAction, fadeInAction, fadeOutAction]))
            
            let flashSquareAction = flashAnimation(duration: FocusSquare.animationDuration * 0.25)
            for segment in segments {
                segment.runAction(.sequence([waitAction, flashSquareAction]))
            }
         }
    }
    
    private func performAlignmentAnimation(to newOrientation: simd_quatf) {
        isChangingAlignment = true
        SCNTransaction.begin()
        SCNTransaction.completionBlock = {
            self.isChangingAlignment = false
        }
        SCNTransaction.animationDuration = 0.5
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        simdOrientation = newOrientation
        SCNTransaction.commit()
    }
    
    // MARK: Convenience Methods
    
    private func scaleAnimation(for keyPath: String) -> CAKeyframeAnimation {
        let scaleAnimation = CAKeyframeAnimation(keyPath: keyPath)
        
        let easeOut = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        let easeInOut = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        let linear = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        
        let size = FocusSquare.size
        let ts = FocusSquare.size * FocusSquare.scaleForClosedSquare
        let values = [size, size * 1.15, size * 1.15, ts * 0.97, ts]
        let keyTimes: [NSNumber] = [0.00, 0.25, 0.50, 0.75, 1.00]
        let timingFunctions = [easeOut, linear, easeOut, easeInOut]
        
        scaleAnimation.values = values
        scaleAnimation.keyTimes = keyTimes
        scaleAnimation.timingFunctions = timingFunctions
        scaleAnimation.duration = FocusSquare.animationDuration
        
        return scaleAnimation
    }
    
    /// Sets the rendering order of the `positioningNode` to show on top or under other scene content.
    /// 设置`positioningNode`的渲染顺序,以便在场景内容的上方或下方显示.
    func displayNodeHierarchyOnTop(_ isOnTop: Bool) {
        // Recursivley traverses the node's children to update the rendering order depending on the `isOnTop` parameter.
        // 递归遍历节点的子节点,根据`isOnTop`参数来更新渲染顺序.
        func updateRenderOrder(for node: SCNNode) {
            node.renderingOrder = isOnTop ? 2 : 0
            
            for material in node.geometry?.materials ?? [] {
                material.readsFromDepthBuffer = !isOnTop
            }
            
            for child in node.childNodes {
                updateRenderOrder(for: child)
            }
        }
        
        updateRenderOrder(for: positioningNode)
    }

    private lazy var fillPlane: SCNNode = {
        let correctionFactor = FocusSquare.thickness / 2 // correction to align lines perfectly 纠正线段对齐的偏差
        let length = CGFloat(1.0 - FocusSquare.thickness * 2 + correctionFactor)
        
        let plane = SCNPlane(width: length, height: length)
        let node = SCNNode(geometry: plane)
        node.name = "fillPlane"
        node.opacity = 0.0

        let material = plane.firstMaterial!
        material.diffuse.contents = FocusSquare.fillColor
        material.isDoubleSided = true
        material.ambient.contents = UIColor.black
        material.lightingModel = .constant
        material.emission.contents = FocusSquare.fillColor

        return node
    }()
}

// MARK: - Animations and Actions 动画和动作

private func pulseAction() -> SCNAction {
    let pulseOutAction = SCNAction.fadeOpacity(to: 0.4, duration: 0.5)
    let pulseInAction = SCNAction.fadeOpacity(to: 1.0, duration: 0.5)
    pulseOutAction.timingMode = .easeInEaseOut
    pulseInAction.timingMode = .easeInEaseOut
    
    return SCNAction.repeatForever(SCNAction.sequence([pulseOutAction, pulseInAction]))
}

private func flashAnimation(duration: TimeInterval) -> SCNAction {
    let action = SCNAction.customAction(duration: duration) { (node, elapsedTime) -> Void in
        // animate color from HSB 48/100/100 to 48/30/100 and back
        // 动画颜色,从HSB 48/100/100 到 48/30/100,来回变化.
        let elapsedTimePercentage = elapsedTime / CGFloat(duration)
        let saturation = 2.8 * (elapsedTimePercentage - 0.5) * (elapsedTimePercentage - 0.5) + 0.3
        if let material = node.geometry?.firstMaterial {
            material.diffuse.contents = UIColor(hue: 0.1333, saturation: saturation, brightness: 1.0, alpha: 1.0)
        }
    }
    return action
}

