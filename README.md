# Handling 3D Interaction and UI Controls in Augmented Reality
# 处理虚拟现实中的3D交互和UI控制

Follow best practices for visual feedback, gesture interactions, and realistic rendering in AR experiences.

遵从AR开发的最佳实践,处理视觉反馈,手势交互,和真实感渲染.

## Overview
## 综述


Augmented reality (AR) offers new ways for users to interact with real and virtual 3D content in your app. However, many fundamental principles of human interface design are still valid. Convincing AR illusions also require careful attention to 3D asset design and rendering. The [iOS Human Interface Guidelines][0] include advice on human interface principles for AR. This project shows ways to apply those guidelines and easily create immersive, intuitive AR experiences.

虚拟现实能在你的app中给用户提供现实与虚拟3D内容的新交互方式.然而,人机界面设计的基本原则仍然不够完善.逼真的AR幻景需要同时关注3D素材和渲染两方面. [iOS人机界面指南][0]包含了AR人机界面设计原则的建议.本项目展示了如何应用这些指南来轻松创造身临其境的AR体验.

[0]:https://developer.apple.com/ios/human-interface-guidelines/technologies/augmented-reality/

This sample app provides a simple AR experience allowing a user to place one or more realistic virtual objects in their real-world environment, then arrange those objects using intuitive gestures. The app offers user interface cues to help the user understand the state of the AR experience and their options for interaction.

本示例程序提供了一个简单的AR功能,允许用户在他们的真实世界中放置一个或多个逼真的虚拟物体,还可以用直观的手势来排布这些物体.程序还提供了界面提示语来帮助用户了解AR过程的状态,及交互过程的设置.

The sections below correspond to sections in [iOS Human Interface Guidelines > Augmented Reality][0], and provide details on how this sample app implements those guidelines. For more detailed reasoning on each section, see the corresponding content in the iOS Human Interface Guidelines.

下面的章节对应于[iOS人机界面指南 > 虚拟现实][0],并详细解释了本示例程序是如何实现这些指南的.如需要各个章节更加详细的原理解释,请查看iOS人机界面指南中的对应内容.

## Getting Started
## 入门

ARKit and this sample app require iOS 11 and a device with an A9 (or later) processor. ARKit is not available in iOS Simulator.

ARKit和本示例程序需要iOS11和A9(或以上)处理器的设备.ARKit在iOS模拟器上不可用.

## Placing Virtual Objects
## 放置虚拟物体

**Help people understand when to locate a surface and place an object.**
The [`FocusSquare`](x-source-tag://FocusSquare) class draws a square outline in the AR view, giving the user hints about the status of ARKit world tracking.

**帮助人们了解何时定位平面,放置物体.**
[`FocusSquare`](x-source-tag://FocusSquare)类在AR视图中绘制了一个方形轮廓,提示用户ARKit世界追踪的状态.

![Focus square UI before and after plane detection, disappearing after object selected for placement](Documentation/FocusSquareFigure.png)

The square changes size and orientation to reflect estimated scene depth, and switches between open and closed states with a prominent animation to indicate whether ARKit has detected a plane suitable for placing an object. After the user places a virtual object, the focus square disappears, remaining hidden until the user points the camera at another surface.

方形会根据估计的场景深度来改变尺寸和方向,并有动画效果改变虚线实线状态来提示用户,ARKit是否已检测到适合放置物体的平面.在用户放置虚拟物体后,聚集方形消失,直到用户将相机对准另一个平面重新出现.

**Respond appropriately when the user places an object.**
When the user chooses a virtual object to place, the sample app's [`setPosition(_:relativeTo:smoothMovement)`](x-source-tag://VirtualObjectSetPosition) method uses the [`FocusSquare`](x-source-tag://FocusSquare) object's simple heuristics to place the object at a roughly realistic position in the middle of the screen, even if ARKit hasn't yet detected a plane at that location.

**当用户放置一个物体时就适当地给出响应.**
用户选择一个虚拟物体时,即使ARKit尚未检测到平面,示例程序的[`setPosition(_:relativeTo:smoothMovement)`](x-source-tag://VirtualObjectSetPosition)方法仍可以使用[`FocusSquare`](x-source-tag://FocusSquare)对象的位置来将物体粗略地放置在屏幕中间.

``` swift
guard let cameraTransform = session.currentFrame?.camera.transform,
    let focusSquarePosition = focusSquare.lastPosition else {
    statusViewController.showMessage("CANNOT PLACE OBJECT\nTry moving left or right.")
    return
}
        
virtualObjectInteraction.selectedObject = virtualObject
virtualObject.setPosition(focusSquarePosition, relativeTo: cameraTransform, smoothMovement: false)
        
updateQueue.async {
    self.sceneView.scene.rootNode.addChildNode(virtualObject)
}
```
[View in Source](x-source-tag://PlaceVirtualObject)

This position might not be an accurate estimate of the real-world surface the user wants to place the virtual object on, but it's close enough to get the object onscreen quickly.

这个位置并不是用户想要放置的真实世界表面的精确位置,但已经很接近了,能将物体快速放置在屏幕上.

Over time, ARKit detects planes and refines its estimates of their position, calling the [`renderer(_:didAdd:for:)`][4] and [`renderer(_:didUpdate:for:)`][5] delegate methods to report results. In those methods, the sample app calls its [`adjustOntoPlaneAnchor(_:using:)`](x-source-tag://AdjustOntoPlaneAnchor) method to determine whether a previously placed virtual object is close to a detected plane. If so, that method uses a subtle animation to move the virtual object onto the plane, so that the object appears to be at the user's chosen position while benefiting from ARKit's refined estimate of the real-world surface at that position:

一段时间后,ARKit检测到了平面,并精确估计了它们的位置,会调用[`renderer(_:didAdd:for:)`][4]和[`renderer(_:didUpdate:for:)`][5]代理方法来反馈结果.在这些方法中,示例程序调用了[`adjustOntoPlaneAnchor(_:using:)`](x-source-tag://AdjustOntoPlaneAnchor)方法来确定先前放置的虚拟物体是否足够靠近探测出的平面.如果是,该方法会使用一个难以察觉的轻微动画,来将虚拟物体移动到平面上,这样物体看上去还在用户选择的位置上同时又能保持ARKit检测出的真实世界平面的精确位置:

``` swift
// Move onto the plane if it is near it (within 5 centimeters).
// 偏差在5厘米内,则移动到平面上
let verticalAllowance: Float = 0.05
let epsilon: Float = 0.001 // Do not update if the difference is less than 1 mm.
let distanceToPlane = abs(planePosition.y)
if distanceToPlane > epsilon && distanceToPlane < verticalAllowance {
    SCNTransaction.begin()
    SCNTransaction.animationDuration = CFTimeInterval(distanceToPlane * 500) // Move 2 mm per second.
    SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
    position.y = anchor.transform.columns.3.y
    SCNTransaction.commit()
}
```
[View in Source](x-source-tag://AdjustOntoPlaneAnchor)

[4]:https://developer.apple.com/documentation/arkit/arscnviewdelegate/2865794-renderer
[5]:https://developer.apple.com/documentation/arkit/arscnviewdelegate/2865799-renderer

## User Interaction with Virtual Objects
## 用户和虚拟物体的交互

**Allow people to directly interact with virtual objects using standard, familiar gestures.**
The sample app uses one-finger tap, one- and two-finger pan, and two-finger rotation gesture recognizers to let the user position and orient virtual objects. The sample code's [`VirtualObjectInteraction`](x-source-tag://VirtualObjectInteraction) class manages these gestures.

**允许用户使用他们熟悉的标准手势,和虚拟物体直接交互.**
示例程序中可以使用单指点击,单指和双指拖拽,以及双指旋转手势来操作虚拟物体.示例代码的[`VirtualObjectInteraction`](x-source-tag://VirtualObjectInteraction)类管理着这些手势.

**In general, keep interactions simple.**
When dragging a virtual object (see the [`translate(_:basedOn:infinitePlane:)`](x-source-tag://DragVirtualObject) method), the sample app restricts the object's movement to the two-dimensional plane it's placed on. Similarly, because a virtual object rests on a horizontal plane, rotation gestures (see the [`didRotate(_:)`](x-source-tag://didRotate) method) spin the object around its vertical axis only, so that the object remains on the plane.

**总之,交互应足够简单.**
当拖拽一个虚拟物体时(见[`translate(_:basedOn:infinitePlane:)`](x-source-tag://DragVirtualObject)方法),示例程序限定物体的移动只能在它被放置的二维平面上.类似的,因为虚拟物体是放置在一个水平面上,旋转手势(见[`didRotate(_:)`](x-source-tag://didRotate)方法)只能让物体绕着它的竖轴旋转,这样物体仍然会保持在平面上.

**Respond to gestures within reasonable proximity of interactive virtual objects.**
The sample code's [`objectInteracting(with:in:)`](x-source-tag://TouchTesting) method performs hit tests using the touch locations provided by gesture recognizers. By hit testing against the bounding boxes of the virtual objects, the method makes it more likely that a user touch will affect the object even if the touch location isn't on a point where the object has visible content. By performing multiple hit tests for multitouch gestures, the method makes it more likely that the user touch affects the intended object:

**允许和虚拟物体交互时,手势的合理误差.**
示例代码的[`objectInteracting(with:in:)`](x-source-tag://TouchTesting)方法使用手势识别器提供的触摸位置来执行点击测试.当点击测试遇到虚拟物体的边界盒子时,该方法让它看起来更像是用户的触摸影响了物体,即使实际的触摸位置并不在物体的可见内容上.通过为多指触摸手势执行多次点击测试,该方法让它看起来更像是用户触摸影响了实际物体:

``` swift
for index in 0..<gesture.numberOfTouches {
    let touchLocation = gesture.location(ofTouch: index, in: view)
    
    // Look for an object directly under the `touchLocation`.
    // 查找处于`touchLocation`正下方的物体
    if let object = sceneView.virtualObject(at: touchLocation) {
        return object
    }
}
        
// As a last resort look for an object under the center of the touches.
// 找不到时,查找返回多个触摸点几何中心正下方的物体
return sceneView.virtualObject(at: gesture.center(in: view))
```
[View in Source](x-source-tag://TouchTesting)

**Consider whether user-initiated object scaling is necessary.**
This AR experience places realistic virtual objects that might naturally appear in the user's environment, so preserving the intrinsic size of the objects aids realism. Therefore, the sample app doesn't add gestures or other UI to enable object scaling. Additionally, by not including a scale gesture, the sample app prevents a user from becoming confused about whether a gesture resizes an object or changes the object's distance from the camera. (If you choose to enable object scaling in your app, use a pinch gesture recognizer.)

**考虑用户发起的物体缩放是否是必须的.**
这段AR场景中,我们放置一个逼真的虚拟物体,自然地出现在用户的环境中.所以物体保持合理的尺寸会增强真实感.因此,示例程序并没有添加手势或其它UI来让物体缩放.另外,因为没有缩放手势,也可以防止用户产生疑惑:这个手势到底是缩放了物体的大小,还是改变了物体到摄像机的距离呢?(如果你想要在你的应用中添加缩放手势,应使用pinch手势识别器.)

**Be wary of potentially conflicting gestures.**
The sample code's [`ThresholdPanGesture`](x-source-tag://ThresholdPanGesture) class is a [`UIPanGestureRecognizer`][3] subclass that provides a way to delay the gesture recognizer's effect until after the gesture in progress passes a specified movement threshold. The sample code's [`touchesMoved(with:)`](x-source-tag://touchesMoved) method uses this class to let the user smoothly transition between dragging an object and rotating it during a single two-finger gesture:

**小心潜在的手势冲突.**
本示例代码中的[`ThresholdPanGesture`](x-source-tag://ThresholdPanGesture)类是一个[`UIPanGestureRecognizer`][3]的子类,它提供了一个方法来延迟手势识别器的效果,直到手势超过了一个特定的运动阈值.示例代码的[`touchesMoved(with:)`](x-source-tag://touchesMoved)方法使用了这个类,使用户能在双指拖拽物体和双指旋转物体手势之间平滑切换.

``` swift
override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesMoved(touches, with: event)
    
    let translationMagnitude = translation(in: view).length
    
    // Adjust the threshold based on the number of touches being used.
    // 根据触摸点的数目调整阈值
    let threshold = ThresholdPanGesture.threshold(forTouchCount: touches.count)
    
    if !isThresholdExceeded && translationMagnitude > threshold {
        isThresholdExceeded = true
        
        // Set the overall translation to zero as the gesture should now begin.
        // 设置全局转移为零,因为手势现在应该开始了.
        setTranslation(.zero, in: view)
    }
}
```
[View in Source](x-source-tag://touchesMoved)

[3]:https://developer.apple.com/documentation/uikit/uipangesturerecognizer

**Make sure virtual object movements are smooth.**
The sample code's [`setPosition(_:relativeTo:smoothMovement)`](x-source-tag://VirtualObjectSetPosition) method interpolates between the touch gesture locations that result in dragging an object and a history of that object's recent positions. By averaging recent positions based on distance to the camera, this method produces smooth dragging movement without causing the dragged object to lag behind the user's gesture:

**确保虚拟物体的运动是平滑的.**
本示例程序的[`setPosition(_:relativeTo:smoothMovement)`](x-source-tag://VirtualObjectSetPosition)方法会在触摸手势位置中插值,得到一个拖拽中的物体及物体最近位置的历史记录序列.根据距离摄像机的长度来对最近位置序列求平均值,这个方法就产生了平滑的拖拽移动,且不会引起拖拽物体落后于用户手势.

``` swift
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
```
[View in Source](x-source-tag://VirtualObjectSetPosition)

**Explore even more engaging methods of interaction.**
In an AR experience, a pan gesture—that is, moving one's finger across the device's screen—isn't the only natural way to drag virtual content to a new position. A user might also intuitively try holding a finger still against the screen while moving the device, effectively dragging the touch point across the AR scene.

**探索更多好用的交互方式.**
在一个AR场景中,拖拽手势并不是惟一的移动虚拟物体位置的自然交互方式.用户可能会直接用手指按住虚拟物体,然后移动手机到其它位置,也可以高效地在AR场景中拖拽触摸点.

The sample app supports this kind of gesture by calling its [`updateObjectToCurrentTrackingPosition()`](x-source-tag://updateObjectToCurrentTrackingPosition) method continually while a drag gesture is in progress, even if the gesture's touch location hasn't changed. If the device moves during a drag, that method calculates the new world position corresponding to the touch location and moves the virtual object accordingly.

本示例程序也支持这种手势,通过在拖拽手势过程中,持续调用它的[`updateObjectToCurrentTrackingPosition()`](x-source-tag://updateObjectToCurrentTrackingPosition)方法来实现,即使手势的触摸位置并没有改变.当设备在拖拽时发生移动,这个方法会计算新的世界坐标中的触摸位置,并相应地移动虚拟物体.

## Entering Augmented Reality
## 进入虚拟现实

**Indicate when initialization is occurring and involve the user.**
The sample app shows textual hints about the state of the AR session and instructions for interacting with the AR experience using a floating text view. The sample code's [`StatusViewController`](x-source-tag://StatusViewController) class manages this view, showing transient instructions that fade away after allowing the user time to read them, or important status messages that remain visible until the user corrects a problem.

**初始化过程中提示用户,并让用户参与其中.**
本示例程序以文本形式显示AR session的状态,并使用浮动文本视图展示AR交互操作的说明.示例代码中的[`StatusViewController`](x-source-tag://StatusViewController)类管理着这个视图,展示一个短暂说明并在用户读完后自动消失,或展示一个重要状态信息,一直保持可见直到用户纠正问题.

![Status view for displaying information about the session state.](Documentation/StatusViewController.png)

## Handling Problems
## 处理问题

**Allow people to reset the experience if it doesn’t meet their expectations.**
The sample app has a Reset button that's always visible in the upper-right corner of the UI, allowing a user to restart the AR experience regardless of its current state. See the [`restartExperience()`](x-source-tag://restartExperience) method in the sample code.

**当程序不满足用户期望时,允许用户重置过程.**
示例程序拥有一个重置按钮,一直在UI界面右上角处于可见状态,允许用户在任何时候重置AR体验,无视当前状态.见示例代码中的[`restartExperience()`](x-source-tag://restartExperience)方法.

**Offer AR features only on capable devices.**
The sample app requires ARKit for its core functionality, so it defines the `arkit` key in the [`UIRequiredDeviceCapabilities`][1] section of its `Info.plist` file. When deploying the built project, this key prevents installation of the app on devices that don't support ARKit.

**只在兼容设备上提供AR特性.**
示例程序要求使用ARKit来做为它的核心功能,所以它在`Info.plist`文件的[`UIRequiredDeviceCapabilities`][1]区域中定义了`arkit` key.当开发时,这个key会阻止应用在那些不支持的设备上安装.

If your app instead uses AR as a secondary feature, use the [`ARWorldTrackingConfiguration.isSupported`][2] method to determine whether to hide features that require ARKit.

如果你的应用只是用AR做为次要功能,应使用[`ARWorldTrackingConfiguration.isSupported`][2]方法来确定是否要隐藏那些需要使用ARKit的功能.

[1]:https://developer.apple.com/library/content/documentation/General/Reference/InfoPlistKeyReference/Articles/iPhoneOSKeys.html#//apple_ref/doc/uid/TP40009252-SW3
[2]:https://developer.apple.com/documentation/arkit/arconfiguration/2923553-issupported
