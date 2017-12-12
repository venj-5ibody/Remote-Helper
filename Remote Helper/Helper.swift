//
//  Helper.swift
//  Video Player
//
//  Created by Venj Chu on 15/11/2.
//  Copyright © 2015 Home. All rights reserved.
//

import UIKit
import Alamofire
import PKHUD
import Reachability
import SafariServices
import TOWebViewController

@objc
open class Helper : NSObject {
    open static let shared = Helper()

    fileprivate var sessionHeader: String = ""
    fileprivate var downloadPath: String = ""
    var reachability: Reachability? = {
        let reach = Reachability()
        try? reach?.startNotifier()
        return reach!
    }()

    //MARK: - Properties
    var useSSL:Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: RequestUseSSL) == nil {
            defaults.set(true, forKey: RequestUseSSL)
            defaults.synchronize()
            return true
        }
        else {
            return defaults.bool(forKey: RequestUseSSL)
        }
    }

    var SSL_ADD_S:String {
        return self.useSSL ? "s" : ""
    }

    var usernameAndPassword:(String, String) {
        let defaults = UserDefaults.standard
        let username = defaults.object(forKey: TransmissionUserNameKey) as? String
        let password = defaults.object(forKey: TransmissionPasswordKey) as? String
        if username != nil && password != nil {
            return (username!, password!)
        }
        else {
            return ("username", "password")
        }
    }

    var customUserAgent: String? {
        let defaults = UserDefaults.standard
        guard let ua = defaults.string(forKey: CustomRequestUserAgent) else { return nil }
        return ua
    }

    var userCellularNetwork: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: RequestUseCellularNetwork) == nil {
            defaults.set(true, forKey: RequestUseCellularNetwork)
            defaults.synchronize()
            return true
        }
        else {
            return defaults.bool(forKey: RequestUseCellularNetwork)
        }
    }

    // AD black list.
    var kittenBlackList: [String] = ["正品香烟", "中铧", "稥湮", "威信", "试抽"]

    //MARK: - Link Helpers
    func torrentsListPath() -> String {
        return "http\(self.SSL_ADD_S)://\(self.baseLink())/torrents?stats=true";
    }

    func baseLink() -> String {
        let defaults = UserDefaults.standard
        let host = defaults.string(forKey: ServerHostKey) ?? "192.168.1.1"
        let port = defaults.string(forKey: ServerPortKey) ?? "80"
        var subPath = defaults.string(forKey: ServerPathKey) ?? ""

        if subPath.last != "/" {
            subPath = "/\(String(describing: subPath))"
        }
        else {
            subPath.removeLast()
        }
        return "\(host):\(port)\(subPath)"
    }

    func fileLink(withPath path:String = "") -> String {
        let defaults = UserDefaults.standard
        let host = defaults.string(forKey: ServerHostKey) ?? "192.168.1.1"
        let port = defaults.string(forKey: ServerPortKey) ?? "80"
        let p = (path.first != "/") ? "/\(path)" : path
        return "http\(self.SSL_ADD_S)://\(host):\(port)\(p)"
    }

    func transmissionServerAddress(withUserNameAndPassword withUnP:Bool = true) -> String {
        let defaults = UserDefaults.standard
        var address: String
        if let addr = defaults.string(forKey: TransmissionAddressKey) {
            address = addr
        }
        else {
            address = "127.0.0.1:9091"
        }
        let userpass = self.usernameAndPassword
        if userpass.0.count > 0 && userpass.1.count > 0 && withUnP {
            return "http://\(userpass.0):\(userpass.1)@\(address)"
        }
        else {
            return "http://\(address)"
        }
    }

    func transmissionRPCAddress() -> String {
        return self.transmissionServerAddress(withUserNameAndPassword: false).vc_stringByAppendingPathComponents(["transmission", "rpc"])
    }

    func kittenSearchPath(withKeyword keyword: String, page: Int = 1) -> String {
        let kw = keyword.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics)
        let escapedKeyword = kw == nil ? "" : kw!
        let pageString = page == 1 ? "" : "\(page)"
        return "https://www.torrentkitty.tv/search/\(escapedKeyword)/\(pageString)"
    }

    func dbSearchPath(withKeyword keyword: String) -> String {
        let kw = keyword.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics)
        let escapedKeyword = kw == nil ? "" : kw!
        return "http\(self.SSL_ADD_S)://\(self.baseLink())/db_search?keyword=\(escapedKeyword)"
    }

    func searchPath(withKeyword keyword: String) -> String {
        return "http\(self.SSL_ADD_S)://\(self.baseLink())/search/\(keyword)"
    }
    
    func addTorrent(withName name: String, async: Bool) -> String {
        return "http\(self.SSL_ADD_S)://\(self.baseLink())/lx/\(name)/\(async ? 1 : 0)"
    }

    func hashTorrent(withName name: String) -> String{
        return "http\(self.SSL_ADD_S)://\(self.baseLink())/hash/\(name)"
    }

    //MARK: - Local Files and ImageCache Helpers
    func documentsDirectory() -> String {
        return NSSearchPathForDirectoriesInDomains(.documentationDirectory, .userDomainMask, true).first!
    }
    
    func freeDiskSpace() -> Int {
        guard let dictionary = try? FileManager.default.attributesOfFileSystem(forPath: self.documentsDirectory()) else { return 0 }
        let freeFileSystemSizeInBytes = dictionary[FileAttributeKey.systemFreeSize] as! Int
        return freeFileSystemSizeInBytes
    }

    func localFileSize() -> Int {
        var size = 0
        let documentsDirectory = self.documentsDirectory()
        guard let fileEnumerator = FileManager.default.enumerator(atPath: documentsDirectory) else { return 0 }
        for fileName in fileEnumerator {
            let filePath = documentsDirectory.vc_stringByAppendingPathComponent(fileName as! String)
            guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: filePath) else { continue }
            size += (attrs[FileAttributeKey.size] as! Int)
        }
        return size
    }

    func fileToDownload(withPath path: String) -> String {
        return self.documentsDirectory().vc_stringByAppendingPathComponent(path.vc_lastPathComponent())
    }

    func fileSizeString(withInteger integer: Int) -> String {
        return integer.fileSizeString
    }

    //MARK: - UserDefaults Helpers

    func save(_ value: Any, forKey key:String) {
        let defaults = UserDefaults.standard
        defaults.set(value, forKey: key)
        defaults.synchronize()
    }

    func appVersionString() -> String {
        let versionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let buildString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(versionString)(\(buildString))"
    }

    //MARK: - UI Related Helpers
    func mainThemeColor() -> UIColor {
        return UIColor(red:0.94, green:0.44, blue:0.19, alpha:1)
    }
    
    func showCellularHUD() -> Bool {
        guard let reachability = self.reachability else { return false }
        if !self.userCellularNetwork && reachability.connection != .wifi {
            DispatchQueue.main.async(execute: { () -> Void in
                self.showHudWithMessage(NSLocalizedString("Cellular data is turned off.", comment: "Cellular data is turned off."))
            })
            return true
        }
        return false
    }

    func showHudWithMessage(_ message: String, hideAfterDelay delay: Double = 1.0) {
        let hud = PKHUD.sharedHUD
        hud.contentView = PKHUDTextView(text: message)
        hud.show()
        hud.hide(afterDelay: delay)
    }

    @discardableResult func showHUD() -> PKHUD {
        let hud = PKHUD.sharedHUD
        hud.contentView = PKHUDProgressView()
        hud.show()
        return hud
    }

    @objc func dismissMe(_ sender: UIBarButtonItem) {
        AppDelegate.shared.window?.rootViewController?.dismiss(animated: true, completion: nil)
    }

    // Nasty method naming, just for minimum code change
    func showTorrentSearchAlertInViewController(_ viewController:UIViewController?, forKitten: Bool = false) {
        guard let viewController = viewController else { return } // Just do nothing...
        if (self.showCellularHUD()) { return }
        var title = NSLocalizedString("Search", comment: "Search")
        var message = NSLocalizedString("Please enter video serial:", comment: "Please enter video serial:")
        if forKitten {
            title = NSLocalizedString("Search Torrent Kitten", comment: "Search Torrent Kitten")
            message = NSLocalizedString("Please enter video serial (or anything):", comment: "Please enter video serial (or anything):")
        }
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.keyboardType = .default
        }
        let searchAction = UIAlertAction(title: NSLocalizedString("Search", comment: "Search"), style: .default) { _ in
            let keyword = alertController.textFields![0].text!
            let hud = self.showHUD()
            if forKitten {
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard let `self` = self else { return }
                    let url = URL(string: self.kittenSearchPath(withKeyword: keyword))!
                    if let data = try? Data(contentsOf: url) {
                        let torrents = KittenTorrent.parse(data: data)
                        if torrents.count == 0 {
                            DispatchQueue.main.async {
                                self.showHudWithMessage(NSLocalizedString("No torrent found", comment: "No torrent found"))
                            }
                            return
                        }
                        DispatchQueue.main.async {
                            let searchResultController = VPSearchResultController()
                            searchResultController.torrents = torrents
                            searchResultController.keyword = keyword
                            if let navigationController = viewController as? UINavigationController {
                                navigationController.pushViewController(searchResultController, animated: true)
                            }
                            else if let tabbarController = (UIApplication.shared.delegate as! AppDelegate).window?.rootViewController as? UITabBarController, let navigationController = tabbarController.selectedViewController as? UINavigationController {
                                navigationController.pushViewController(searchResultController, animated: true)
                            }
                            else {
                                let searchResultNavigationController = UINavigationController(rootViewController: searchResultController)
                                searchResultController.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target:self, action: #selector(Helper.dismissMe(_:)))
                                viewController.present(searchResultNavigationController, animated: true, completion: nil)
                            }
                            hud.hide()
                        }
                    }
                    else {
                        DispatchQueue.main.async { [weak self] in
                            self?.showHudWithMessage(NSLocalizedString("Connection failed.", comment: "Connection failed."))
                        }
                    }
                }
            }
            else {
                let dbSearchPath = self.dbSearchPath(withKeyword: keyword)
                let request = Alamofire.request(dbSearchPath)
                request.responseJSON(completionHandler: { [weak self] response in
                    guard let `self` = self else { return }
                    if response.result.isSuccess {
                        guard let responseObject = response.result.value as? [String: Any] else { return }
                        let success = ("\(responseObject["success"]!)" == "1")
                        if success {
                            let searchResultController = VPSearchResultController()
                            guard let torrents = responseObject["results"] as? [[String: Any]] else { return }
                            searchResultController.torrents = torrents
                            searchResultController.keyword = keyword
                            if let navigationController = viewController as? UINavigationController {
                                navigationController.pushViewController(searchResultController, animated: true)
                            }
                            else if let tabbarController = (UIApplication.shared.delegate as! AppDelegate).window?.rootViewController as? UITabBarController, let navigationController = tabbarController.selectedViewController as? UINavigationController {
                                navigationController.pushViewController(searchResultController, animated: true)
                            }
                            else {
                                let searchResultNavigationController = UINavigationController(rootViewController: searchResultController)
                                searchResultController.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target:self, action: #selector(Helper.dismissMe(_:)))
                                viewController.present(searchResultNavigationController, animated: true, completion: nil)
                            }
                            hud.hide()
                        }
                        else {
                            let errorMessage = responseObject["message"] as! String
                            DispatchQueue.main.async {
                                self.showHudWithMessage(NSLocalizedString("\(errorMessage)", comment: "\(errorMessage)"))
                            }
                        }
                    }
                    else {
                        DispatchQueue.main.async {
                            self.showHudWithMessage(NSLocalizedString("Connection failed.", comment: "Connection failed."))
                        }
                    }
                })
            }
        }
        alertController.addAction(searchAction)
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        alertController.view.tintColor = Helper.shared.mainThemeColor()
        viewController.present(alertController, animated: true, completion: nil)
    }

    //MARK: - Transmission Remote Download Helpers
    func downloadTask(_ magnet:String, toDir dir: String, completionHandler:(() -> Void)? = nil,  errorHandler:(() -> Void)? = nil) {
        let params = ["method" : "torrent-add", "arguments": ["paused" : false, "download-dir" : dir, "filename" : magnet]] as [String : Any]
        let HTTPHeaders = ["X-Transmission-Session-Id" : sessionHeader]
        //, parameters: params, encoding: .JSON, headers: HTTPHeaders
        let request = Alamofire.request(self.transmissionRPCAddress(), method: .post, parameters: params, encoding: JSONEncoding(options: []),headers: HTTPHeaders)
        request.authenticate(user: usernameAndPassword.0, password: usernameAndPassword.1).responseJSON { response in
            if response.result.isSuccess {
                let responseObject = response.result.value as! [String: Any]
                let result = responseObject["result"] as! String
                if result == "success" {
                    completionHandler?()
                }
            }
            else {
                errorHandler?()
            }
        }
    }

    func parseSessionAndAddTask(_ magnet:String, completionHandler:(() -> Void)? = nil, errorHandler:(() -> Void)? = nil) {
        let params = ["method" : "session-get"]
        let HTTPHeaders = ["X-Transmission-Session-Id" : sessionHeader]
        let request = Alamofire.request(self.transmissionRPCAddress(), method: .post, parameters: params, encoding: JSONEncoding(options: []),headers: HTTPHeaders)
        request.authenticate(user: usernameAndPassword.0, password: usernameAndPassword.1).responseJSON { [weak self] response in
            guard let `self` = self else { return }
            if response.result.isSuccess {
                let responseObject = response.result.value as! [String:Any]
                let result = responseObject["result"] as! String
                if result == "success" {
                    self.downloadPath = (responseObject["arguments"] as! [String: Any])["download-dir"] as! String
                    self.downloadTask(magnet, toDir: self.downloadPath, completionHandler: completionHandler, errorHandler: errorHandler)
                }
                else {
                    errorHandler?()
                }
            }
            else {
                if response.response?.statusCode == 409 {
                    self.sessionHeader = response.response!.allHeaderFields["X-Transmission-Session-Id"] as! String
                    let params = ["method" : "session-get"]
                    let HTTPHeaders = ["X-Transmission-Session-Id" : self.sessionHeader]
                    let request = Alamofire.request(self.transmissionRPCAddress(), method: .post, parameters: params, encoding: JSONEncoding(options: []),headers: HTTPHeaders)
                    request.authenticate(user: self.usernameAndPassword.0, password: self.usernameAndPassword.1).responseJSON { [weak self] response in
                        guard let `self` = self else { return }
                        if response.result.isSuccess {
                            let responseObject = response.result.value as! [String:Any]
                            let result = responseObject["result"] as! String
                            if result == "success" {
                                self.downloadPath = (responseObject["arguments"] as! [String: Any])["download-dir"] as! String
                                self.downloadTask(magnet, toDir: self.downloadPath, completionHandler: completionHandler, errorHandler: errorHandler)
                            }
                            else {
                                errorHandler?()
                            }
                        }
                        else {
                            let alertController = UIAlertController(title: NSLocalizedString("Error", comment:"Error"), message: NSLocalizedString("Unkown error.", comment: "Unknow error."), preferredStyle: .alert)
                            let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel, handler: nil)
                            alertController.addAction(cancelAction)
                            alertController.view.tintColor = Helper.shared.mainThemeColor()
                            AppDelegate.shared.window?.rootViewController?.present(alertController, animated: true, completion: nil)
                        }
                    }
                }
                else {
                    errorHandler?()
                }
            }
        }
    }

    func showMiDownload(for link: String, inViewController viewController: UIViewController) {
        guard let miURL = URL(string:(link)) else { return }
        if #available(iOS 9.0, *) {
            let sfVC = SFSafariViewController(url: miURL)
            sfVC.title = NSLocalizedString("Mi Remote", comment: "Mi Remote")
            sfVC.modalPresentationStyle = .formSheet
            sfVC.modalTransitionStyle = .coverVertical
            viewController.navigationController?.present(sfVC, animated: true, completion: nil)
        } else {
            // Fallback on earlier versions
            let webView = TOWebViewController(url: miURL)!
            webView.title = NSLocalizedString("Mi Remote", comment: "Mi Remote")
            webView.modalPresentationStyle = .formSheet
            webView.modalTransitionStyle = .coverVertical
            viewController.navigationController?.present(webView, animated: true, completion: nil)
        }
    }

    func transmissionDownload(for link: String) {
        self.showHUD()
        parseSessionAndAddTask(link, completionHandler: { [weak self] in
            guard let `self` = self else { return }
            self.showHudWithMessage(NSLocalizedString("Task added.", comment: "Task added."))
        }, errorHandler: {
            self.showHudWithMessage(NSLocalizedString("Transmission server error.", comment: "Transmission server error."))
        })
    }

    func canStartMiDownload() -> Bool {
        let defaults = UserDefaults.standard
        if let _ = defaults.object(forKey: MiAccountUsernameKey) as? String,
            let _ = defaults.object(forKey: MiAccountPasswordKey) as? String {
            return true
        }
        else {
            return false
        }
    }

    func miDownloadForLink(_ link: String, fallbackIn viewController: UIViewController) {
        miDownloadForLinks([link], fallbackIn: viewController)
    }

    func miDownloadForLinks(_ links: [String], fallbackIn viewController: UIViewController) {
        let defaults = UserDefaults.standard
        guard let username = defaults.object(forKey: MiAccountUsernameKey) as? String,
            let password = defaults.object(forKey: MiAccountPasswordKey) as? String
            else {
                showHudWithMessage(NSLocalizedString("Mi account not set.", comment: "Mi account not set."))
                return
            }
        let hud = Helper.shared.showHUD()
        MiDownloader(withUsername:username, password: password, links: links).loginAndFetchDeviceList(progress: { (progress) in
            switch progress {
            case .prepare:
                hud.setMessage(NSLocalizedString("Preparing...", comment: "Preparing..."))
            case .login:
                hud.setMessage(NSLocalizedString("Loging in...", comment: "Loging in..."))
            case .fetchDevice:
                hud.setMessage(NSLocalizedString("Loading Device...", comment: "Loading Device..."))
            case .download:
                hud.setMessage(NSLocalizedString("Add download...", comment: "Add download..."))
            }
        }, success: { (success) in
            switch success {
            case .added:
                hud.setMessage(NSLocalizedString("Added!", comment: "Added!"))
            case .duplicate:
                hud.setMessage(NSLocalizedString("Duplicated!", comment: "Duplicated!"))
            case .other(let code):
                hud.setMessage(NSLocalizedString("Added! Code: ", comment: "Added! Code: ") + "\(code)")
            }
            hud.hide(afterDelay: 1.0)
        }, error: { (error) in
            hud.hide()
            switch error {
            case .capchaError(let link):
                PKHUD.sharedHUD.hide()
                DispatchQueue.main.after(0.5, execute: {
                    self.showMiDownload(for: link, inViewController: viewController)
                })
            default:
                let reason = error.localizedDescription
                self.showHudWithMessage(reason)
            }
        })
    }
}


