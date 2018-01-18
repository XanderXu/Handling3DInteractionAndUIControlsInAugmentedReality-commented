/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A type which loads and tracks virtual objects.
 用来加载并追踪虚拟物体.
*/

import Foundation
import ARKit

/**
 Loads multiple `VirtualObject`s on a background queue to be able to display the
 objects quickly once they are needed.
 在后台队列中加载多个`VirtualObject`,在需要展示物体的时候能快速显示出来.
*/
class VirtualObjectLoader {
	private(set) var loadedObjects = [VirtualObject]()
    
    private(set) var isLoading = false
	
	// MARK: - Loading object 加载物体

    /**
     Loads a `VirtualObject` on a background queue. `loadedHandler` is invoked
     on a background queue once `object` has been loaded.
     在后台队列中加载一个`VirtualObject`.当`object`加载完成时,`loadedHandler`将会在后台线程被调用.
    */
    func loadVirtualObject(_ object: VirtualObject, loadedHandler: @escaping (VirtualObject) -> Void) {
        isLoading = true
		loadedObjects.append(object)
		
		// Load the content asynchronously.
        // 异步加载内容.
        DispatchQueue.global(qos: .userInitiated).async {
            object.reset()
            object.load()

            self.isLoading = false
            loadedHandler(object)
        }
	}
    
    // MARK: - Removing Objects 移除物体
    
    func removeAllVirtualObjects() {
        // Reverse the indicies so we don't trample over indicies as objects are removed.
        // 反转索引序号,这样移除物体时索引序号不用改变.
        for index in loadedObjects.indices.reversed() {
            removeVirtualObject(at: index)
        }
    }
    
    func removeVirtualObject(at index: Int) {
        guard loadedObjects.indices.contains(index) else { return }
        
        loadedObjects[index].removeFromParentNode()
        loadedObjects.remove(at: index)
    }
}
