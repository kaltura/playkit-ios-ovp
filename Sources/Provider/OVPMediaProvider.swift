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
import SwiftyXMLParser
import KalturaNetKit
import PlayKit

@objc public class OVPMediaProvider: NSObject {
    
    enum OVPMediaProviderError: PKError {
        case invalidParam(paramName: String)
        case invalidKS
        case invalidParams
        case invalidResponse
        case currentlyProcessingOtherRequest
        case serverError(code:String, message:String)
        
        public static let domain = "com.kaltura.playkit.ovp.error.OVPMediaProvider"
        
        public static let serverErrorCodeKey = "code"
        public static let serverErrorMessageKey = "message"
        
        public var code: Int {
            switch self {
            case .invalidParam: return 0
            case .invalidKS: return 1
            case .invalidParams: return 2
            case .invalidResponse: return 3
            case .currentlyProcessingOtherRequest: return 4
            case .serverError: return 5
            }
        }
        
        public var errorDescription: String {
            
            switch self {
            case .invalidParam(let param): return "Invalid input param: \(param)"
            case .invalidKS: return "Invalid input ks"
            case .invalidParams: return "Invalid input params"
            case .invalidResponse: return "Response data is empty"
            case .currentlyProcessingOtherRequest: return "Currently Processing Other Request"
            case .serverError(let code, let message): return "Server Error code: \(code), \n message: \(message)"
            }
        }
        
        public var userInfo: [String: Any] {
            switch self {
            case .serverError(let code, let message): return [PKErrorKeys.MediaEntryProviderServerErrorCodeKey: code,
                                                              PKErrorKeys.MediaEntryProviderServerErrorMessageKey: message]
            default:
                return [String: Any]()
            }
        }
    }
    
    @objc public var ks: String?
    @objc public var baseUrl: String?
    @objc public var partnerId: NSNumber?
    @objc public var entryId: String?
    @objc public var uiconfId: NSNumber?
    @objc public var referrer: String?
    public var executor: RequestExecutor?
    
    private var apiBaseUrl: String {
        return (baseUrl ?? "") + "/api_v3"
    }
    
    public override init() {}
    
   
    /// Required parameter
    ///
    /// - Parameter ks: ks obtained from the application
    /// - Returns: Self
    @discardableResult
    @nonobjc public func set(ks: String?) -> Self {
        self.ks = ks
        return self
    }
    
    /// Required parameter
    ///
    /// - Parameter baseUrl: server url
    /// - Returns: Self
    @discardableResult
    @nonobjc public func set(baseUrl: String?) -> Self {
        self.baseUrl = baseUrl
        return self
    }
    
    /// Required parameter
    ///
    /// - Parameter partnerId
    /// - Returns: Self
    @discardableResult
    @nonobjc public func set(partnerId: Int64?) -> Self {
        self.partnerId = NSNumber.init(value: partnerId ?? -1)
        return self
    }
    
    /**
     entryId - entry which we need to play
     */
    @discardableResult
    @nonobjc public func set(entryId: String?) -> Self {
        self.entryId = entryId
        return self
    }
    
    /**
     uiconfId - UI Configuration id
     */
    @discardableResult
    @nonobjc public func set(uiconfId: NSNumber?) -> Self {
        self.uiconfId = uiconfId
        return self
    }
    
    
    /// set the provider referrer
    ///
    /// - Parameter referrer: the app referrer
    /// - Returns: Self
    @discardableResult
    @nonobjc public func set(referrer: String?) -> Self {
        self.referrer = referrer
        return self
    }
    
    /**
     executor - which resposible for the network, it can be set to
     */
    @discardableResult
    @nonobjc public func set(executor: RequestExecutor?) -> Self {
        self.executor = executor
        return self
    }
    
    public func loadMedia(callback: @escaping (PKMediaEntry?, Error?) -> Void){
        guard let ks = self.ks else {
            PKLog.debug("Proivder must have ks")
            callback(nil, OVPMediaProviderError.invalidParam(paramName: "ks"))
            return
        }
        guard let _ = self.baseUrl else {
            PKLog.debug("Proivder must have baseUrl")
            callback(nil, OVPMediaProviderError.invalidParam(paramName: "baseUrl"))
            return
        }
        // entryId is requierd
        guard let entryId = self.entryId else {
            PKLog.debug("Proivder must have entryId")
            callback(nil, OVPMediaProviderError.invalidParam(paramName: "entryId"))
            return
        }
        
        let mrb = KalturaMultiRequestBuilder(url: apiBaseUrl)?.setOVPBasicParams()
        
        // Request for Entry data
        let listRequest = OVPBaseEntryService.list(baseURL: apiBaseUrl, ks: ks, entryID: entryId)
        
        // Request for Entry playback data in order to build sources to play
        let getPlaybackContext =  OVPBaseEntryService.getPlaybackContext(baseURL: apiBaseUrl, ks: ks, entryID: entryId, referrer: referrer)
        
        let metadataRequest = OVPBaseEntryService.metadata(baseURL: apiBaseUrl, ks: ks, entryID: entryId)
        
        guard let req1 = listRequest, let req2 = getPlaybackContext, let req3 = metadataRequest else {
            callback(nil, OVPMediaProviderError.invalidParams)
            return
        }
        
        //Building the multi request
        mrb?.add(request: req1)
            .add(request: req2)
            .add(request: req3)
            .set(completion: { (dataResponse: Response) in
                
                guard let data = dataResponse.data else {
                    PKLog.debug("didn't get response data")
                    callback(nil, OVPMediaProviderError.invalidResponse)
                    return
                }
                
                let responses: [OVPBaseObject] = OVPMultiResponseParser.parse(data: data)
                
                // At leat we need to get response of Entry and Playback, on anonymous we will have additional startWidgetSession call
                guard responses.count == 3 else {
                    PKLog.debug("didn't get response for all requests")
                    callback(nil, OVPMediaProviderError.invalidResponse)
                    return
                }
                
                let metaData: OVPBaseObject = responses[responses.count-1]
                let contextDataResponse: OVPBaseObject = responses[responses.count-2]
                let mainResponse: OVPBaseObject = responses[responses.count-3]
                
                guard let mainResponseData = mainResponse as? OVPList,
                    let entry = mainResponseData.objects?.last as? OVPEntry,
                    let contextData = contextDataResponse as? OVPPlaybackContext,
                    let sources = contextData.sources,
                    let metadataListObject = metaData as? OVPList,
                    let metadataList = metadataListObject.objects as? [OVPMetadata]
                    else {
                        PKLog.debug("Response is not containing Entry info or playback data")
                        callback(nil, OVPMediaProviderError.invalidResponse)
                        return
                }
                
                if let context = contextDataResponse as? OVPPlaybackContext {
                    if (context.hasBlockAction() != nil) {
                        if let error = context.hasErrorMessage() {
                            callback(nil, OVPMediaProviderError.serverError(code: error.code ?? "", message: error.message ?? ""))
                        } else{
                            callback(nil, OVPMediaProviderError.serverError(code: "Blocked", message: "Blocked"))
                        }
                        return
                    }
                }
                
                var mediaSources: [PKMediaSource] = [PKMediaSource]()
                sources.forEach { (source: OVPSource) in
                    //detecting the source type
                    let format = FormatsHelper.getMediaFormat(format: source.format, hasDrm: source.drm != nil)
                    //If source type is not supported source will not be created
                    guard format != .unknown else { return }
                    
                    let playURL: URL? = self.playbackURL(source: source)
                    guard let url = playURL else {
                        PKLog.error("failed to create play url from source, discarding source:\(entry.id),\(source.deliveryProfileId), \(source.format)")
                        return
                    }
                    
                    let drmData = self.buildDRMParams(drm: source.drm)
                    
                    //creating media source with the above data
                    let mediaSource: PKMediaSource = PKMediaSource(id: "\(entry.id)_\(String(source.deliveryProfileId))")
                    mediaSource.drmData = drmData
                    mediaSource.contentUrl = url
                    mediaSource.mediaFormat = format
                    mediaSources.append(mediaSource)
                }
                
                let metaDataItems = self.getMetadata(metadataList: metadataList)
                
                let mediaEntry: PKMediaEntry = PKMediaEntry(id: entry.id)
                mediaEntry.duration = entry.duration
                mediaEntry.sources = mediaSources
                mediaEntry.metadata = metaDataItems
                mediaEntry.tags = entry.tags
                callback(mediaEntry, nil)
            })
        
        if let request = mrb?.build() {
            (executor ?? USRExecutor.shared).send(request: request)
        } else {
            callback(nil, OVPMediaProviderError.invalidParams)
        }
    }
    
    private func getMetadata(metadataList: [OVPMetadata]) -> [String: String] {
        var metaDataItems = [String: String]()

        for meta in metadataList {
            do {
                if let metaXML = meta.xml {
                    let xml = try XML.parse(metaXML)
                    if let allNodes = xml["metadata"].all{
                        for element in allNodes {
                            for dataElement in element.childElements {
                                metaDataItems[dataElement.name] = dataElement.text
                            }
                        }
                    }
                }
            } catch {
                PKLog.error("Error occur while trying to parse metadata XML")
            }
        }
        
        return metaDataItems
    }
    
    // Creating the drm data based on scheme
    private func buildDRMParams(drm: [OVPDRM]?) -> [DRMParams]? {
        
        let drmData = drm?.flatMap({ (drm: OVPDRM) -> DRMParams? in
            
            guard let schemeName = drm.scheme  else {
                return nil
            }
            
            let scheme = self.convertScheme(name: schemeName)
            var drmData: DRMParams? = nil
            
            switch scheme {
            case .fairplay :
                guard let certifictae = drm.certificate, let licenseURL = drm.licenseURL else { return nil }
                drmData = FairPlayDRMParams(licenseUri: licenseURL, scheme:scheme, base64EncodedCertificate: certifictae)
            default:
                drmData = DRMParams(licenseUri: drm.licenseURL, scheme: scheme)
                
            }
            
            return drmData
        })
        
        return drmData
    }
    
    // building the url with the SourceBuilder class
    private func playbackURL(source: OVPSource) -> URL? {
        
        let formatType = FormatsHelper.getMediaFormat(format: source.format, hasDrm: source.drm != nil)
        var playURL: URL? = nil
        if let flavors =  source.flavors,
            flavors.count > 0 {
            
            let sourceBuilder: SourceBuilder = SourceBuilder()
                .set(baseURL: baseUrl)
                .set(format: source.format)
                .set(entryId: entryId)
                .set(uiconfId: uiconfId?.int64Value)
                .set(flavors: source.flavors)
                .set(partnerId: partnerId?.int64Value)
                .set(sourceProtocol: source.protocols?.last)
                .set(fileExtension: formatType.fileExtension)
                .set(ks: ks)
            playURL = sourceBuilder.build()
        }
        else {
            playURL = source.url
        }
        
        return playURL
    }
    
    public func cancel(){
        
    }
    
    public func convertScheme(name: String) -> DRMParams.Scheme {
    
        switch (name) {
        case "drm.WIDEVINE_CENC":
            return .widevineCenc;
        case "drm.PLAYREADY_CENC":
            return .playreadyCenc
        case "widevine.WIDEVINE":
            return .widevineClassic
        case "fairplay.FAIRPLAY":
            return .fairplay
        default:
            return .unknown
        }
    }
}







