//
//  OVPResponseParser.swift
//  PlayKitOVP
//
//  Created by Vadim Kononov on 10/12/2017.
//

import Foundation
import SwiftyJSON

public class OVPResponseParser: NSObject {
    public static func parse(data: Any?) -> OVPBaseObject? {
        if let data = data, let objectType = OVPObjectMapper.classByJsonObject(json: data) {
            return objectType.init(json: data)
        } else {
            return nil
        }
    }
}
