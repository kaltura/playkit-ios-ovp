// ===================================================================================================
// Copyright (C) 2017 Kaltura Inc.
//
// Licensed under the AGPLv3 license, unless a different license for a
// particular library is specified in the applicable library path.
//
// You may obtain a copy of the License at
// https://www.gnu.org/licenses/agpl-3.0.html
// ===================================================================================================

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
