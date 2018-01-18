/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Contains `ThresholdPanGesture` - a custom `UIPanGestureRecognizer` to track a translation threshold for panning.
 自定义`UIPanGestureRecognizer`类,追踪拖拽手势的平移阈值
*/

import UIKit.UIGestureRecognizerSubclass

/**
 A custom `UIPanGestureRecognizer` to track when a translation threshold has been exceeded
 and panning should begin.
 自定义`UIPanGestureRecognizer`类,确定何时超过平移阈值,拖拽开始.
 - Tag: ThresholdPanGesture
 */
class ThresholdPanGesture: UIPanGestureRecognizer {
    
    /// Indicates whether the currently active gesture has exceeeded the threshold.
    /// 指示当前活跃手势是否超过了阈值
    private(set) var isThresholdExceeded = false
    
    /// Observe when the gesture's `state` changes to reset the threshold.
    /// 监听手势的`state`变化,以重设阈值
    override var state: UIGestureRecognizerState {
        didSet {
            switch state {
            case .began, .changed:
                break
                
            default:
                // Reset threshold check.
                // 重设阈值标识
                isThresholdExceeded = false
            }
        }
    }
    
    /// Returns the threshold value that should be used dependent on the number of touches.
    /// 根据触摸点数目,返回阈值数目
    private static func threshold(forTouchCount count: Int) -> CGFloat {
        switch count {
        case 1: return 30
            
        // Use a higher threshold for gestures using more than 1 finger. This gives other gestures priority.
        // 超过一个手指时,使用更高的阈值.这样给其他手势更高优先级.
        default: return 60
        }
    }
    
    /// - Tag: touchesMoved
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        let translationMagnitude = translation(in: view).length
        
        // Adjust the threshold based on the number of touches being used.
        // 根据触摸点数调整阈值.
        let threshold = ThresholdPanGesture.threshold(forTouchCount: touches.count)
        
        if !isThresholdExceeded && translationMagnitude > threshold {
            isThresholdExceeded = true
            
            // Set the overall translation to zero as the gesture should now begin.
            // 当手势开始作用时,将平移值设为零.
            setTranslation(.zero, in: view)
        }
    }
}
