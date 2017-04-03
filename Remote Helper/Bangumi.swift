//
//  Resource.swift
//  Remote Helper
//
//  Created by 朱文杰 on 2017/4/2.
//  Copyright © 2017年 Home. All rights reserved.
//

import Foundation
import Fuzi

struct Bangumi {
    var title: String
    var links: [String]

    static func parse(data: Data, isGBK: Bool = false) -> Bangumi? {
        guard let html = isGBK ? data.stringFromGB18030Data() : String(data: data, encoding: .utf8) else { return nil }
        do {
            let doc = try HTMLDocument(string: html)
            let title = doc.css("div.title_all h1").first?.stringValue ?? NSLocalizedString("Unknown Title", comment: "Unknown Title")
            var links: [String] = []
            doc.css("div.co_content8 table td a").forEach({ (element) in
                guard let link = element["href"] else { return }
                links.append(link)
            })

            let bangumi = Bangumi(title: title, links: links)
            return bangumi
        } catch let error {
            print(error.localizedDescription)
        }

        return nil
    }
}