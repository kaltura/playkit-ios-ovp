//
//  PhoenixAnonymousSession.swift
//  KalturaPlayer
//
//  Created by Vadik on 29/11/2017.
//

import Foundation
import KalturaNetKit
import PlayKit
import SwiftyJSON

public enum OVPWidgetSessionError: PKError {
    case unableToParseData(data: Any)
    
    public static let domain = "com.kaltura.playkit.ovp.error.OVPWidgetSession"
    
    public var userInfo: [String : Any] {
        return [:]
    }
    
    public var code: Int {
        return 0
    }
    
    public var errorDescription: String {
        switch self {
        case .unableToParseData(let data):
            return "Unable to parse object (data: \(String(describing: data)))"
        }
    }
}

@objc public class OVPWidgetSession : NSObject {
    @objc public class func get(baseUrl: String, partnerId: Int64, completion: @escaping (String?, Error?) -> Void) {
        if let b = OVPSessionService.startWidgetSession(baseURL: baseUrl + "/api_v3", partnerId: partnerId) {
            b.setOVPBasicParams()
            b.set(completion: { (response) in
                if let error = response.error {
                    completion(nil, error)
                } else {
                    guard let responseData = response.data else { return }
                    if let widgetSession = OVPMultiResponseParser.parseSingleItem(json: JSON(responseData)) as? OVPStartWidgetSessionResponse {
                        completion(widgetSession.ks, nil)
                    } else {
                        completion(nil, OVPWidgetSessionError.unableToParseData(data: responseData).asNSError)
                    }
                }
            })
            USRExecutor.shared.send(request: b.build())
        }
    }
}

