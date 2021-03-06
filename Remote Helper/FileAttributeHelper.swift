//
//  FileAttributeHelper.swift
//  Video Player
//
//  Created by Venj Chu on 15/11/2.
//  Copyright © 2015年 Home. All rights reserved.
//

import Foundation

@available(iOS 5.1, *)
open class FileAttributeHelper {
    @objc
    class func haveSkipBackupAttributeForItemAtURL(_ url: URL) -> Bool {
        if FileManager.default.fileExists(atPath: url.absoluteString) { return true } // Treat as true if file not exists.
        var result: AnyObject?
        do {
            try (url as NSURL).getResourceValue(&result, forKey: URLResourceKey.isExcludedFromBackupKey)
            guard let _ = result else { return true }  // treat as true if result value is not set properly.
            return result!.boolValue
        }
        catch _ { return true } // Treat as true if read attributes error.
    }

    @objc
    class func addSkipBackupAttributeToItemAtURL(_ url: URL) -> Bool {
        if haveSkipBackupAttributeForItemAtURL(url) { return true }
        do {
            try (url as NSURL).setResourceValue(true, forKey: URLResourceKey.isExcludedFromBackupKey)
        }
        catch _ {
            // do nothing if failed, just return true
            print("Error excluding \(url.lastPathComponent) from backup.")
        }
        return true
    }
}
