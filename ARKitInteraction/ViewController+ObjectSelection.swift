/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Methods on the main view controller for handling virtual object loading and movement
 处理虚拟物体的加载和移动
*/

import UIKit
import ARKit

extension ViewController: VirtualObjectSelectionViewControllerDelegate {
    /**
     Adds the specified virtual object to the scene, placed at the world-space position
     estimated by a hit test from the center of the screen.
     添加虚拟物体到场景中,放在在根据屏幕中心命中测试点在真实世界中的估计位置处.
     - Tag: PlaceVirtualObject
     */
    func placeVirtualObject(_ virtualObject: VirtualObject) {
        guard focusSquare.state != .initializing else {
            statusViewController.showMessage("CANNOT PLACE OBJECT\nTry moving left or right.")
            if let controller = objectsViewController {
                virtualObjectSelectionViewController(controller, didDeselectObject: virtualObject)
            }
            return
        }
        
        virtualObjectInteraction.translate(virtualObject, basedOn: screenCenter, infinitePlane: false, allowAnimation: false)
        virtualObjectInteraction.selectedObject = virtualObject
        
        updateQueue.async {
            self.sceneView.scene.rootNode.addChildNode(virtualObject)
            self.sceneView.addOrUpdateAnchor(for: virtualObject)
        }
    }
    
    // MARK: - VirtualObjectSelectionViewControllerDelegate
    
    func virtualObjectSelectionViewController(_: VirtualObjectSelectionViewController, didSelectObject object: VirtualObject) {
        virtualObjectLoader.loadVirtualObject(object, loadedHandler: { [unowned self] loadedObject in
            self.sceneView.prepare([object], completionHandler: { _ in
                DispatchQueue.main.async {
                    self.hideObjectLoadingUI()
                    self.placeVirtualObject(loadedObject)
                    loadedObject.isHidden = false
                }
            })
        })

        displayObjectLoadingUI()
    }
    
    func virtualObjectSelectionViewController(_: VirtualObjectSelectionViewController, didDeselectObject object: VirtualObject) {
        guard let objectIndex = virtualObjectLoader.loadedObjects.index(of: object) else {
            fatalError("Programmer error: Failed to lookup virtual object in scene.")
        }
        virtualObjectLoader.removeVirtualObject(at: objectIndex)
        virtualObjectInteraction.selectedObject = nil
        if let anchor = object.anchor {
            session.remove(anchor: anchor)
        }
    }

    // MARK: Object Loading UI

    func displayObjectLoadingUI() {
        // Show progress indicator.
        spinner.startAnimating()
        
        addObjectButton.setImage(#imageLiteral(resourceName: "buttonring"), for: [])

        addObjectButton.isEnabled = false
        isRestartAvailable = false
    }

    func hideObjectLoadingUI() {
        // Hide progress indicator.
        spinner.stopAnimating()

        addObjectButton.setImage(#imageLiteral(resourceName: "add"), for: [])
        addObjectButton.setImage(#imageLiteral(resourceName: "addPressed"), for: [.highlighted])

        addObjectButton.isEnabled = true
        isRestartAvailable = true
    }
}
