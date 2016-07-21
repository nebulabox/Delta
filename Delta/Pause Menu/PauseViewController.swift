//
//  PauseViewController.swift
//  Delta
//
//  Created by Riley Testut on 1/30/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore

class PauseViewController: UIViewController, PauseInfoProviding
{
    var emulatorCore: EmulatorCore? {
        didSet {
            self.updatePauseItems()
        }
    }
    
    var pauseItems: [PauseItem] {
        return [self.saveStateItem, self.loadStateItem, self.cheatCodesItem, self.sustainButtonsItem, self.fastForwardItem].flatMap { $0 }
    }
    
    /// Pause Items
    private(set) var saveStateItem: PauseItem?
    private(set) var loadStateItem: PauseItem?
    private(set) var cheatCodesItem: PauseItem?
    private(set) var sustainButtonsItem: PauseItem?
    private(set) var fastForwardItem: PauseItem?
    
    /// PauseInfoProviding
    var pauseText: String?
    
    private var pauseNavigationController: UINavigationController!
    
    /// UIViewController
    override var preferredContentSize: CGSize {
        set { }
        get
        {
            var preferredContentSize = self.pauseNavigationController.topViewController?.preferredContentSize ?? CGSize.zero
            if preferredContentSize.height > 0
            {
                preferredContentSize.height += self.pauseNavigationController.navigationBar.bounds.height
            }
            
            return preferredContentSize
        }
    }
    
    override var navigationController: UINavigationController? {
        return self.pauseNavigationController
    }
}

extension PauseViewController
{
    override func preferredStatusBarStyle() -> UIStatusBarStyle
    {
        return .lightContent
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        // Ensure navigation bar is always positioned correctly despite being outside the navigation controller's view
        self.pauseNavigationController.navigationBar.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.pauseNavigationController.navigationBar.bounds.height)
    }
    
    override func targetViewController(forAction action: Selector, sender: AnyObject?) -> UIViewController?
    {
        return self.pauseNavigationController
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: AnyObject?)
    {
        guard let identifier = segue.identifier else { return }
        
        switch identifier
        {
        case "embedNavigationController":
            self.pauseNavigationController = segue.destinationViewController as! UINavigationController
            self.pauseNavigationController.navigationBar.tintColor = UIColor.deltaLightPurpleColor()
            self.pauseNavigationController.view.backgroundColor = UIColor.clear()
            
            let pauseMenuViewController = self.pauseNavigationController.topViewController as! PauseMenuViewController
            pauseMenuViewController.items = self.pauseItems
            
            // Keep navigation bar outside the UIVisualEffectView's
            self.view.addSubview(self.pauseNavigationController.navigationBar)

        default: break
        }
    }
}

private extension PauseViewController
{
    func updatePauseItems()
    {
        self.saveStateItem = nil
        self.loadStateItem = nil
        self.cheatCodesItem = nil
        self.sustainButtonsItem = nil
        self.fastForwardItem = nil
        
        guard self.emulatorCore != nil else { return }
        
        self.saveStateItem = PauseItem(image: UIImage(named: "SaveSaveState")!, text: NSLocalizedString("Save State", comment: ""), action: { _ in })
        self.loadStateItem = PauseItem(image: UIImage(named: "LoadSaveState")!, text: NSLocalizedString("Load State", comment: ""), action: {  _ in })
        self.cheatCodesItem = PauseItem(image: UIImage(named: "SmallPause")!, text: NSLocalizedString("Cheat Codes", comment: ""), action: { _ in })
        self.sustainButtonsItem = PauseItem(image: UIImage(named: "SmallPause")!, text: NSLocalizedString("Sustain Buttons", comment: ""), action: { _ in })
        self.fastForwardItem = PauseItem(image: UIImage(named: "FastForward")!, text: NSLocalizedString("Fast Forward", comment: ""), action: { _ in })
    }
}
