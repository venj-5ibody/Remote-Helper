//
//  KittenTorrent.swift
//  TestApp
//
//  Created by Venj Chu on 16/11/23.
//  Copyright © 2016. All rights reserved.
//

import Foundation
import Fuzi

struct KittenTorrent {
    var title: String
    var magnet: String
    var dateString: String
    var size: String
    var maxPage: Int = 1
    var date: Date {
        let c = dateString.components(separatedBy: "-")
        let defaultDate = Date().addingTimeInterval(-157680000) // Default to 5 years ago if string is not parsable.
        if c.count < 3 { return defaultDate }
        var dc = DateComponents()
        dc.year = Int(c[0]) ?? 2013
        dc.month = Int(c[1]) ?? 1
        dc.day = Int(c[2]) ?? 1
        return dc.date ?? defaultDate
    }

    static func parse(data: Data) -> [KittenTorrent] {
        var results : [KittenTorrent] = []

        do {
            let doc = try HTMLDocument(data: data)

            var page = 1
            doc.css("div.pagination a").forEach {
                let pageString = $0.stringValue
                let i = Int(pageString) ?? page
                if page < i {
                    page = i
                }
            }

            for row in doc.css("#archiveResult tr") {
                guard let title = row.css("td.name") .first?.stringValue else { continue }
                // Filter based on ad black list.
                if Helper.shared.kittenBlackList.filter({ title.contains($0) }).count > 0 { continue }
                // Filter out no result
                if title.contains("No result - ") { continue }
                let size = row.css("td.size") .first?.stringValue ??  ""
                let date = row.css("td.date") .first?.stringValue ??  ""
                let magnet = row.css("td.action a").filter{ $0.attr("rel") == "magnet" }.first?.attr("href") ?? ""
                let torrent = KittenTorrent(title: title, magnet: magnet, dateString: date, size: size, maxPage: page)
                results.append(torrent)
            }
        } catch let error {
            print(error.localizedDescription)
        }

        return results
    }

}
