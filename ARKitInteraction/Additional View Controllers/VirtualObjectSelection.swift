/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Popover view controller for choosing virtual objects to place in the AR scene.
 弹出控制器,用来在AR场景中选择虚拟物体来放置.
*/

import UIKit
import ARKit

// MARK: - ObjectCell 列表的cell

class ObjectCell: UITableViewCell {
    static let reuseIdentifier = "ObjectCell"
    
    @IBOutlet weak var objectTitleLabel: UILabel!
    @IBOutlet weak var objectImageView: UIImageView!
    @IBOutlet weak var vibrancyView: UIVisualEffectView!
    
    var modelName = "" {
        didSet {
            objectTitleLabel.text = modelName.capitalized
            objectImageView.image = UIImage(named: modelName)
        }
    }
}

// MARK: - VirtualObjectSelectionViewControllerDelegate

/// A protocol for reporting which objects have been selected.
/// 物体被选择或反选时的代理协议
protocol VirtualObjectSelectionViewControllerDelegate: class {
    func virtualObjectSelectionViewController(_ selectionViewController: VirtualObjectSelectionViewController, didSelectObject: VirtualObject)
    func virtualObjectSelectionViewController(_ selectionViewController: VirtualObjectSelectionViewController, didDeselectObject: VirtualObject)
}

/// A custom table view controller to allow users to select `VirtualObject`s for placement in the scene.
/// 自定义tableView控制器,允许用户在场景中选择`VirtualObject`来放置.
class VirtualObjectSelectionViewController: UITableViewController {
    
    /// The collection of `VirtualObject`s to select from.
    /// `VirtualObject`集合.
    var virtualObjects = [VirtualObject]()
    
    /// The rows of the currently selected `VirtualObject`s.
    /// 当前已被选中的`VirtualObject`.
    var selectedVirtualObjectRows = IndexSet()
    
    /// The rows of the 'VirtualObject's that are currently allowed to be placed.
    var enabledVirtualObjectRows = Set<Int>()
    
    weak var delegate: VirtualObjectSelectionViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.separatorEffect = UIVibrancyEffect(blurEffect: UIBlurEffect(style: .light))
    }
    
    override func viewWillLayoutSubviews() {
        preferredContentSize = CGSize(width: 250, height: tableView.contentSize.height)
    }
    
    func updateObjectAvailability(for planeAnchor: ARPlaneAnchor?) {
        var newEnabledVirtualObjectRows = Set<Int>()
        for (row, object) in VirtualObject.availableObjects.enumerated() {
            // Enable row if item can be placed at the current location
            if object.isPlacementValid(on: planeAnchor) {
                newEnabledVirtualObjectRows.insert(row)
            }
            // Enable row always if item is already placed, in order to allow the user to remove it.
            if selectedVirtualObjectRows.contains(row) {
                newEnabledVirtualObjectRows.insert(row)
            }
        }
        
        // Only reload changed rows
        let changedRows = newEnabledVirtualObjectRows.symmetricDifference(enabledVirtualObjectRows)
        enabledVirtualObjectRows = newEnabledVirtualObjectRows
        let indexPaths = changedRows.map { row in IndexPath(row: row, section: 0) }

        DispatchQueue.main.async {
            self.tableView.reloadRows(at: indexPaths, with: .automatic)
        }
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellIsEnabled = enabledVirtualObjectRows.contains(indexPath.row)
        guard cellIsEnabled else { return }
        
        let object = virtualObjects[indexPath.row]
        
        // Check if the current row is already selected, then deselect it.
        // 检查当前行是否已被选中,已选中则取消选中.
        if selectedVirtualObjectRows.contains(indexPath.row) {
            delegate?.virtualObjectSelectionViewController(self, didDeselectObject: object)
        } else {
            delegate?.virtualObjectSelectionViewController(self, didSelectObject: object)
        }

        dismiss(animated: true, completion: nil)
    }
        
    // MARK: - UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return virtualObjects.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ObjectCell.reuseIdentifier, for: indexPath) as? ObjectCell else {
            fatalError("Expected `\(ObjectCell.self)` type for reuseIdentifier \(ObjectCell.reuseIdentifier). Check the configuration in Main.storyboard.")
        }
        
        cell.modelName = virtualObjects[indexPath.row].modelName

        if selectedVirtualObjectRows.contains(indexPath.row) {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        
        let cellIsEnabled = enabledVirtualObjectRows.contains(indexPath.row)
        if cellIsEnabled {
            cell.vibrancyView.alpha = 1.0
        } else {
            cell.vibrancyView.alpha = 0.1
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didHighlightRowAt indexPath: IndexPath) {
        let cellIsEnabled = enabledVirtualObjectRows.contains(indexPath.row)
        guard cellIsEnabled else { return }

        let cell = tableView.cellForRow(at: indexPath)
        cell?.backgroundColor = UIColor.lightGray.withAlphaComponent(0.5)
    }
    
    override func tableView(_ tableView: UITableView, didUnhighlightRowAt indexPath: IndexPath) {
        let cellIsEnabled = enabledVirtualObjectRows.contains(indexPath.row)
        guard cellIsEnabled else { return }

        let cell = tableView.cellForRow(at: indexPath)
        cell?.backgroundColor = .clear
    }
}
