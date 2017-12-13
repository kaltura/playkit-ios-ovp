// ===================================================================================================
// Copyright (C) 2017 Kaltura Inc.
//
// Licensed under the AGPLv3 license, unless a different license for a 
// particular library is specified in the applicable library path.
//
// You may obtain a copy of the License at
// https://www.gnu.org/licenses/agpl-3.0.html
// ===================================================================================================

import UIKit
import SwiftyJSON

class OVPList: OVPBaseObject {
    var objects: [OVPBaseObject]?
    
    let objectsKey = "objects"
    
    init(objects: [OVPBaseObject]?) {
        self.objects = objects
    }
    required init?(json: Any) {
        let jsonObject = JSON(json)
        if let objects = jsonObject[objectsKey].array {
            var parsedObjects: [OVPBaseObject] = [OVPBaseObject]()
            for object in objects {
                if let ovpObject = OVPResponseParser.parse(data: object.dictionaryObject) {
                    parsedObjects.append(ovpObject)
                }
            }
            self.objects = parsedObjects
        }
    }
}
