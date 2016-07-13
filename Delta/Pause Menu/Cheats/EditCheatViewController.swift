//
//  EditCheatViewController.swift
//  Delta
//
//  Created by Riley Testut on 5/21/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit
import CoreData

import DeltaCore
import Roxas

protocol EditCheatViewControllerDelegate: class
{
    func editCheatViewController(_ editCheatViewController: EditCheatViewController, activateCheat cheat: Cheat, previousCheat: Cheat?) throws
    func editCheatViewController(_ editCheatViewController: EditCheatViewController, deactivateCheat cheat: Cheat)
}

private extension EditCheatViewController
{
    enum ValidationError: ErrorProtocol
    {
        case invalidCode
        case duplicateName
        case duplicateCode
    }
    
    enum Section: Int
    {
        case name
        case type
        case code
    }
}

class EditCheatViewController: UITableViewController
{
    weak var delegate: EditCheatViewControllerDelegate?
    
    var cheat: Cheat?
    var game: Game!
    var supportedCheatFormats: [CheatFormat]!
    
    private var selectedCheatFormat: CheatFormat {
        let cheatFormat = self.supportedCheatFormats[self.typeSegmentedControl.selectedSegmentIndex]
        return cheatFormat
    }
    
    private var mutableCheat: Cheat!
    private var managedObjectContext = DatabaseManager.sharedManager.backgroundManagedObjectContext()
    
    @IBOutlet private var nameTextField: UITextField!
    @IBOutlet private var typeSegmentedControl: UISegmentedControl!
    @IBOutlet private var codeTextView: CheatTextView!
}

extension EditCheatViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        var name: String!
        var type: CheatType!
        var code: String!
        
        self.managedObjectContext.performAndWait {
            
            // Main Thread context is read-only, so we either create a new cheat, or get a reference to the current cheat in a new background context
            
            if let cheat = self.cheat
            {
                self.mutableCheat = self.managedObjectContext.object(with: cheat.objectID) as? Cheat
            }
            else
            {
                self.mutableCheat = Cheat.insertIntoManagedObjectContext(self.managedObjectContext)
                self.mutableCheat.game = self.managedObjectContext.object(with: self.game.objectID) as! Game
                self.mutableCheat.type = self.supportedCheatFormats.first!.type
                self.mutableCheat.code = ""
                self.mutableCheat.name = ""
            }
            
            self.mutableCheat.enabled = true // After we save a cheat, it should be enabled
            
            name = self.mutableCheat.name
            type = self.mutableCheat.type
            code = self.mutableCheat.code.sanitized(with: self.selectedCheatFormat.allowedCodeCharacters)
        }

        
        // Update UI
        
        if name.characters.count == 0
        {
            self.title = NSLocalizedString("Cheat", comment: "")
        }
        else
        {
            self.title = name
        }
        
        self.nameTextField.text = name
        self.codeTextView.text = code
        
        self.typeSegmentedControl.removeAllSegments()
        
        for (index, format) in self.supportedCheatFormats.enumerated()
        {
            self.typeSegmentedControl.insertSegment(withTitle: format.name, at: index, animated: false)
        }
        
        if let index = self.supportedCheatFormats.index(where: { $0.type == type })
        {
            self.typeSegmentedControl.selectedSegmentIndex = index
        }
        else
        {
            self.typeSegmentedControl.selectedSegmentIndex = 0
        }
        
        self.updateCheatType(self.typeSegmentedControl)
        self.updateSaveButtonState()
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        // This matters when going from peek -> pop
        // Otherwise, has no effect because viewDidLayoutSubviews has already been called
        if self.isAppearing && !self.isPreviewing
        {
            self.nameTextField.becomeFirstResponder()
        }
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        if let superview = self.codeTextView.superview
        {
            let layoutMargins = superview.layoutMargins
            self.codeTextView.textContainerInset = layoutMargins
            
            self.codeTextView.textContainer.lineFragmentPadding = 0
        }
        
        if self.isAppearing && !self.isPreviewing
        {
            self.nameTextField.becomeFirstResponder()
        }
    }
    
    override func previewActionItems() -> [UIPreviewActionItem]
    {
        guard let cheat = self.cheat else { return [] }
        
        let copyCodeAction = UIPreviewAction(title: NSLocalizedString("Copy Code", comment: ""), style: .default) { (action, viewController) in
            UIPasteboard.general().string = cheat.code
        }
        
        let presentingViewController = self.presentingViewController!
        
        let editCheatAction = UIPreviewAction(title: NSLocalizedString("Edit", comment: ""), style: .default) { (action, viewController) in
            // Delaying until next run loop prevents self from being dismissed immediately
            DispatchQueue.main.async {
                let editCheatViewController = viewController as! EditCheatViewController
                editCheatViewController.presentWithPresentingViewController(presentingViewController)
            }
        }
        
        let deleteAction = UIPreviewAction(title: NSLocalizedString("Delete", comment: ""), style: .destructive) { [unowned self] (action, viewController) in
            self.delegate?.editCheatViewController(self, deactivateCheat: cheat)
            
            let backgroundContext = DatabaseManager.sharedManager.backgroundManagedObjectContext()
            backgroundContext.perform {
                let temporaryCheat = backgroundContext.object(with: cheat.objectID)
                backgroundContext.delete(temporaryCheat)
                backgroundContext.saveWithErrorLogging()
            }
        }
        
        let cancelDeleteAction = UIPreviewAction(title: NSLocalizedString("Cancel", comment: ""), style: .default) { (action, viewController) in
        }
        
        let deleteActionGroup = UIPreviewActionGroup(title: NSLocalizedString("Delete", comment: ""), style: .destructive, actions: [deleteAction, cancelDeleteAction])
        
        return [copyCodeAction, editCheatAction, deleteActionGroup]
    }
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: AnyObject?)
    {
        self.nameTextField.resignFirstResponder()
        self.codeTextView.resignFirstResponder()
    }
}

internal extension EditCheatViewController
{
    func presentWithPresentingViewController(_ presentingViewController: UIViewController)
    {
        let navigationController = RSTNavigationController(rootViewController: self)
        navigationController.modalPresentationStyle = .overFullScreen // Keeps PausePresentationController active to ensure layout is not messed up
        navigationController.modalPresentationCapturesStatusBarAppearance = true
        
        presentingViewController.present(navigationController, animated: true, completion: nil)
    }
}

private extension EditCheatViewController
{
    @IBAction func updateCheatName(_ sender: UITextField)
    {
        var title = sender.text ?? ""
        if title.characters.count == 0
        {
            title = NSLocalizedString("Cheat", comment: "")
        }
        
        self.title = title
        
        self.updateSaveButtonState()
    }
    
    @IBAction func updateCheatType(_ sender: UISegmentedControl)
    {
        self.codeTextView.cheatFormat = self.selectedCheatFormat
        
        UIView.performWithoutAnimation {
            self.tableView.reloadSections(IndexSet(integer: Section.type.rawValue), with: .none)
            
            // Hacky-ish workaround so we can update the footer text for the code section without causing text view to resign first responder status
            self.tableView.beginUpdates()
            
            if let footerView = self.tableView.footerView(forSection: Section.code.rawValue)
            {
                footerView.textLabel!.text = self.tableView(self.tableView, titleForFooterInSection: Section.code.rawValue)
                footerView.sizeToFit()
            }
            
            self.tableView.endUpdates()
        }
    }
    
    func updateSaveButtonState()
    {
        let isValidName = !(self.nameTextField.text ?? "").isEmpty
        let isValidCode = !self.codeTextView.text.isEmpty
        
        self.navigationItem.rightBarButtonItem?.isEnabled = isValidName && isValidCode
    }
    
    @IBAction func saveCheat(_ sender: UIBarButtonItem)
    {
        self.mutableCheat.managedObjectContext?.performAndWait {
            
            self.mutableCheat.name = self.nameTextField.text ?? ""
            self.mutableCheat.type = self.selectedCheatFormat.type
            self.mutableCheat.code = self.codeTextView.text.formatted(with: self.selectedCheatFormat)
            
            do
            {
                try self.validateCheat(self.mutableCheat)
                self.mutableCheat.managedObjectContext?.saveWithErrorLogging()
                self.performSegue(withIdentifier: "unwindEditCheatSegue", sender: sender)
            }
            catch ValidationError.invalidCode
            {
                self.presentErrorAlert(title: NSLocalizedString("Invalid Code", comment: ""), message: NSLocalizedString("Please make sure you typed the cheat code in correctly and try again.", comment: "")) {
                    self.codeTextView.becomeFirstResponder()
                }
            }
            catch ValidationError.duplicateCode
            {
                self.presentErrorAlert(title: NSLocalizedString("Duplicate Code", comment: ""), message: NSLocalizedString("A cheat already exists with this code. Please type in a different code and try again.", comment: "")) {
                    self.codeTextView.becomeFirstResponder()
                }
            }
            catch ValidationError.duplicateName
            {
                self.presentErrorAlert(title: NSLocalizedString("Duplicate Name", comment: ""), message: NSLocalizedString("A cheat already exists with this name. Please rename this cheat and try again.", comment: "")) {
                    self.nameTextField.becomeFirstResponder()
                }
            }
            catch let error as NSError
            {
                print(error)
            }
        }
    }
    
    func validateCheat(_ cheat: Cheat) throws
    {
        let name = cheat.name!
        let code = cheat.code
        
        // Find all cheats that are for the same game, don't have the same identifier as the current cheat, but have either the same name or code
        let predicate = Predicate(format: "%K == %@ AND %K != %@ AND (%K == %@ OR %K == %@)", Cheat.Attributes.game.rawValue, cheat.game, Cheat.Attributes.identifier.rawValue, cheat.identifier, Cheat.Attributes.code.rawValue, code, Cheat.Attributes.name.rawValue, name)
        
        let cheats = Cheat.instancesWithPredicate(predicate, inManagedObjectContext: self.managedObjectContext, type: Cheat.self)
        for cheat in cheats
        {
            if cheat.name == name
            {
                throw ValidationError.duplicateName
            }
            else if cheat.code == code
            {
                throw ValidationError.duplicateCode
            }
        }
        
        do
        {
            try self.delegate?.editCheatViewController(self, activateCheat: cheat, previousCheat: self.cheat)
        }
        catch
        {
            throw ValidationError.invalidCode
        }
    }
    
    @IBAction func textFieldDidEndEditing(_ sender: UITextField)
    {
        sender.resignFirstResponder()
    }
    
    func presentErrorAlert(title: String, message: String, handler: ((Void) -> Void)?)
    {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: { action in
                handler?()
            }))
            self.present(alertController, animated: true, completion: nil)
        }
    }
}

extension EditCheatViewController
{
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String?
    {
        switch Section(rawValue: section)!
        {
        case .name: return super.tableView(tableView, titleForFooterInSection: section)
            
        case .type:
            let title = String.localizedStringWithFormat("Code format is %@.", self.selectedCheatFormat.format)
            return title
            
        case .code:
            let containsSpaces = self.selectedCheatFormat.format.contains(" ")
            let containsDashes = self.selectedCheatFormat.format.contains("-")
            
            switch (containsSpaces, containsDashes)
            {
            case (true, false): return NSLocalizedString("Spaces will be inserted automatically as you type.", comment: "")
            case (false, true): return NSLocalizedString("Dashes will be inserted automatically as you type.", comment: "")
            case (true, true): return NSLocalizedString("Spaces and dashes will be inserted automatically as you type.", comment: "")
            case (false, false): return NSLocalizedString("Code will be formatted automatically as you type.", comment: "")
            }
        }
    }
}

extension EditCheatViewController: UITextViewDelegate
{
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool
    {
        defer { self.updateSaveButtonState() }
        
        guard text != "\n" else
        {
            textView.resignFirstResponder()
            return false
        }
        
        let sanitizedText = text.sanitized(with: self.selectedCheatFormat.allowedCodeCharacters)
        
        guard sanitizedText != text else { return true }
        
        // We need to manually add back the attributes when manually modifying the underlying text storage
        // Otherwise, pasting text into an empty text view will result in the wrong font being used
        let attributedString = AttributedString(string: sanitizedText, attributes: textView.typingAttributes)
        textView.textStorage.replaceCharacters(in: range, with: attributedString)
        
        // We must add attributedString.length, not range.length, in case the attributed string's length differs
        textView.selectedRange = NSRange(location: range.location + attributedString.length, length: 0)
        
        return false
    }
}
