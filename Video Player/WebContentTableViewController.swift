//
//  WebContentTableViewController.swift
//  Video Player
//
//  Created by 朱文杰 on 15/11/4.
//  Copyright © 2015年 Home. All rights reserved.
//

import UIKit
import SDWebImage
import LTHPasscodeViewController
import MBProgressHUD
import TOWebViewController
import MWPhotoBrowser
import InAppSettingsKit

class WebContentTableViewController: UITableViewController, IASKSettingsDelegate, UIPopoverPresentationControllerDelegate {
    private let CellIdentifier = "WebContentTableViewCell"

    var webViewController:TOWebViewController!
    var settingsViewController: IASKAppSettingsViewController!
    var sheet: UIActionSheet!
    var mwPhotos: [MWPhoto]!
    var addresses: [String] = [] {
        didSet {
            saveAddresses()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Addresses", comment: "Addresses")
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: CellIdentifier)
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "addAddress")
        readAddresses()
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("More", comment: "More"), style: .Plain, target: self, action: "showActionSheet")

        let defaults = NSUserDefaults.standardUserDefaults()
        if !defaults.boolForKey(ServerSetupDone) {
            self.showSettings()
        }

        // Revert back to old UITableView behavior
        if #available(iOS 9.0, *) {
            tableView.cellLayoutMarginsFollowReadableWidth = false
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.addresses.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(CellIdentifier, forIndexPath: indexPath)
        let address = self.addresses[indexPath.row]
        cell.textLabel?.text = address
        return cell
    }

    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            addresses.removeAtIndex(indexPath.row)
            saveAddresses()
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        }
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath:NSIndexPath) -> Bool {
        return true
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        if AppDelegate.shared().showCellularHUD() { return }
        let urlString = self.addresses[indexPath.row]
        webViewController = TOWebViewController(URLString: urlString)
        webViewController.showUrlWhileLoading = false
        webViewController.hidesBottomBarWhenPushed = true
        webViewController.urlRequest.cachePolicy = .ReturnCacheDataElseLoad
        webViewController.additionalBarButtonItems = [UIBarButtonItem(barButtonSystemItem: .Search, target: self, action: "fetchHTMLAndParse")]
        navigationController?.pushViewController(webViewController, animated: true)
    }

    //MARK: - UIPopoverPresentationControllerDelegate
    func prepareForPopoverPresentation(popoverPresentationController: UIPopoverPresentationController) {
        popoverPresentationController.barButtonItem = navigationItem.leftBarButtonItem
    }

    //MARK: - InAppSettingsKit Delegates
    func settingsViewControllerDidEnd(sender: IASKAppSettingsViewController!) {
        navigationController?.dismissViewControllerAnimated(true) {
            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.setBool(true, forKey: ServerSetupDone)
            sender.synchronizeSettings()
        }
    }

    func settingsViewController(sender: IASKAppSettingsViewController!, buttonTappedForSpecifier specifier: IASKSpecifier!) {
        if specifier.key() == PasscodeLockConfig {
            if LTHPasscodeViewController.doesPasscodeExist() {
                LTHPasscodeViewController.sharedUser().showForEnablingPasscodeInViewController(sender, asModal: false)
            }
            else {
                LTHPasscodeViewController.sharedUser().showForDisablingPasscodeInViewController(sender, asModal: false)
            }
        }
        else if specifier.key() == ClearCacheNowKey {
            let hud = MBProgressHUD.showHUDAddedTo(sender.navigationController?.view, animated: true)
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
                SDImageCache.sharedImageCache().clearDisk()
                let defaults = NSUserDefaults.standardUserDefaults()
                let localFileSize = Helper.defaultHelper.fileSizeString(withInteger: Helper.defaultHelper.localFileSize())
                defaults.setObject(localFileSize, forKey: LocalFileSize)
                defaults.synchronize()
                sender.synchronizeSettings()
                dispatch_async(dispatch_get_main_queue()) {
                    hud.hide(true)
                    AppDelegate.shared().showHudWithMessage(NSLocalizedString("Cache Cleared!", comment: "Cache Cleared!"), inView: sender.navigationController?.view)
                    sender.tableView.reloadData()
                }
            }
        }
        else if specifier.key() == VerifyXunleiKey {
            let api = HYXunleiLixianAPI()
            api.logOut()
            let hud = MBProgressHUD.showHUDAddedTo(sender.navigationController?.view, animated: true)
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
                let xunleiAccount = Helper.defaultHelper.xunleiUsernameAndPassword
                if api.loginWithUsername(xunleiAccount[0], password: xunleiAccount[1], isPasswordEncode: false) {
                    dispatch_async(dispatch_get_main_queue()) {
                        hud.hide(true)
                        AppDelegate.shared().showHudWithMessage(NSLocalizedString("Logged in.", comment: "Logged in.") , inView: sender.navigationController?.view)
                    }
                }
                else {
                    dispatch_async(dispatch_get_main_queue()) {
                        hud.hide(true)
                        AppDelegate.shared().showHudWithMessage(NSLocalizedString("Username or password error.", comment: "Username or password error.") , inView: sender.navigationController?.view)
                    }
                }
            }
        }
    }

    //MARK: - Action
    func fetchHTMLAndParse() {
        guard let html = webViewController.webView.stringByEvaluatingJavaScriptFromString("document.body.innerHTML") else { return }
        processHTML(html)
    }

    func addAddress() {
        let alertController = UIAlertController(title: NSLocalizedString("Add address", comment: "Add address"), message: NSLocalizedString("Please input an address:", comment: "Please input an address:"), preferredStyle: .Alert)
        alertController.addTextFieldWithConfigurationHandler { (textField) in
            textField.keyboardType = .URL
            textField.clearButtonMode = .WhileEditing
            textField.text = "http://"
        }
        let saveAction = UIAlertAction(title: NSLocalizedString("Save", comment:"Save"), style: .Default) { [unowned self] _ in
            let address = alertController.textFields![0].text!
            guard let _ = NSURL(string: address) else { return }
            self.addresses.append(address)
            self.saveAddresses()
            let indexPath = NSIndexPath(forRow: self.addresses.count - 1, inSection: 0)
            self.tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
        }
        alertController.addAction(saveAction)
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .Cancel, handler: nil)
        alertController.addAction(cancelAction)
        presentViewController(alertController, animated: true, completion: nil)
    }

    func showActionSheet() {
        let sheet = UIAlertController(title: NSLocalizedString("Please select your operation", comment: "Please select your operation"), message: nil, preferredStyle: .ActionSheet)
        let transmissionAction = UIAlertAction(title: NSLocalizedString("Transmission", comment: "Transmission"), style: .Default) { [unowned self] _ in
            self.showTransmission()
        }
        sheet.addAction(transmissionAction)
        let settingsAction = UIAlertAction(title: NSLocalizedString("Settings", comment: "Settings"), style: .Default) { [unowned self] _ in
            self.showSettings()
        }
        sheet.addAction(settingsAction)
        let searchAction = UIAlertAction(title: NSLocalizedString("Torrent Search", comment: "Torrent Search"), style: .Default) { [unowned self] _ in
            self.torrentSearch()
        }
        sheet.addAction(searchAction)
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .Cancel, handler: nil)
        sheet.addAction(cancelAction)
        sheet.popoverPresentationController?.delegate = self
        presentViewController(sheet, animated: true) {
            sheet.popoverPresentationController?.passthroughViews = nil
        }
    }
    
    func saveAddresses() {
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setObject(addresses, forKey: "VPAddresses")
        defaults.synchronize()
    }

    func readAddresses() {
        let defaults = NSUserDefaults.standardUserDefaults()
        guard let addrs = defaults.objectForKey("VPAddresses") as? [String] else {
            addresses = []
            return
        }
        self.addresses = addrs
    }

    func showSettings() {
        let defaults = NSUserDefaults.standardUserDefaults()
        let cacheSizeInBytes = SDImageCache.sharedImageCache().getSize()
        let cacheSize = Helper.defaultHelper.fileSizeString(withInteger: Int(cacheSizeInBytes)) // Maybe problematic on 32-bit system
        defaults.setObject(cacheSize, forKey: ImageCacheSizeKey)
        let status = LTHPasscodeViewController.doesPasscodeExist() ? NSLocalizedString("On", comment: "On") : NSLocalizedString("Off", comment:"Off")
        defaults.setObject(status, forKey: PasscodeLockStatus)
        let localFileSize = Helper.defaultHelper.fileSizeString(withInteger: Helper.defaultHelper.localFileSize())
        defaults.setObject(localFileSize, forKey: LocalFileSize)
        let deviceFreeSpace = Helper.defaultHelper.fileSizeString(withInteger: Helper.defaultHelper.freeDiskSpace())
        defaults.setObject(deviceFreeSpace, forKey: DeviceFreeSpace)
        defaults.synchronize()

        settingsViewController = IASKAppSettingsViewController(style: .Grouped)
        settingsViewController.delegate = self
        settingsViewController.showCreditsFooter = false
        let settingsNavigationController = UINavigationController(rootViewController: settingsViewController)
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
            settingsViewController.modalPresentationStyle = .FormSheet
        }
        dispatch_async(dispatch_get_main_queue()) { [unowned self] in
            self.presentViewController(settingsNavigationController, animated: true, completion: nil)
        }
    }

    func showTransmission() {
        if AppDelegate.shared().showCellularHUD() { return }
        let link = Helper.defaultHelper.transmissionServerAddress()
        let transmissionWebViewController = TOWebViewController(URLString: link)
        transmissionWebViewController.urlRequest.cachePolicy = .ReloadIgnoringLocalCacheData
        transmissionWebViewController.title = "Transmission"
        transmissionWebViewController.showUrlWhileLoading = false
        let transmissionNavigationController = UINavigationController(rootViewController: transmissionWebViewController)
        dispatch_async(dispatch_get_main_queue()) { [unowned self] in
            self.presentViewController(transmissionNavigationController, animated:true, completion: nil)
        }
    }

    //MARK: - Helper
    func torrentSearch() {
        AppDelegate.shared().showTorrentSearchAlertInNavigationController(navigationController)
    }

    func processHTML(html: String) {
        var validAddresses: Set<String> = []
        let patterns = ["magnet:\\?[^\"'<]+", "ed2k://[^\"'&<]+", "thunder://[^\"'&<]+"]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .CaseInsensitive) else { continue }
            regex.enumerateMatchesInString(html, options: [], range: NSRange(location: 0, length: html.characters.count), usingBlock: { (result, _, _) -> Void in
                if let nsRange = result?.range {
                    if let range = html.rangeFromNSRange(nsRange) {
                        let link = html.substringWithRange(range)
                        validAddresses.insert(link)
                    }
                }
            })
        }
        if validAddresses.count <= 0 {
            AppDelegate.shared().showHudWithMessage(NSLocalizedString("No downloadable link.", comment: "No downloadable link."), inView: self.navigationController?.view)
        }
        else {
            let linksViewController = ValidLinksTableViewController()
            linksViewController.validLinks = [String](validAddresses)
            navigationController?.pushViewController(linksViewController, animated: true)
        }
    }
}