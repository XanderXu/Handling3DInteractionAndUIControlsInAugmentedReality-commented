/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Utility functions and type extensions used throughout the projects.
 项目中用到的工具函数和类扩展
*/

import Foundation
import ARKit

// MARK: - float4x4 extensions

extension float4x4 {
    /**
     Treats matrix as a (right-hand column-major convention) transform matrix
     and factors out the translation component of the transform.
     将一个矩阵(右手主序)视为平移矩阵,获取其平移组件.
    */
    var translation: float3 {
        let translation = columns.3
        return float3(translation.x, translation.y, translation.z)
    }
}

// MARK: - CGPoint extensions

extension CGPoint {
    /// Extracts the screen space point from a vector returned by SCNView.projectPoint(_:).
    /// 根据SCNView.projectPoint(_:)返回的一个向量,获取屏幕的空间点.<AR中的世界坐标,通过projectPoint(_:)投影到屏幕球面上,再得到屏幕二维坐标>
	init(_ vector: SCNVector3) {
		x = CGFloat(vector.x)
		y = CGFloat(vector.y)
	}

    /// Returns the length of a point when considered as a vector. (Used with gesture recognizers.)
    /// 将点的位置视为一个向量,返回其长度.(用在手势识别中)
    var length: CGFloat {
		return sqrt(x * x + y * y)
	}
}
