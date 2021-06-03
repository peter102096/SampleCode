//
//  FileManager.swift
//  CameraControl
//
//  Created by PeterLin on 2021/4/20.
//

import UIKit
import Alamofire
import Photos

class CustomFileManager: NSObject {
    static let shared: CustomFileManager = CustomFileManager()
    
    private let sharedSession: Session = {
        let manager = ServerTrustManager(evaluators: ["192.168.0.1": DisabledTrustEvaluator()])
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = 30
        return Session(configuration: configuration, serverTrustManager: manager)
    }()
    
    weak var delegate: DownloadDelegate?
    
    weak var viewController: UIViewController?
    
    func setVC(_ vc: UIViewController) {
        self.viewController = vc
    }
    
    func downloadMedia(isPhoto: Bool, link: URL, completion: @escaping (Bool) -> Void) {
        print("downloadMedia link : \(link)")
        let destination: (URL, HTTPURLResponse) -> (URL, DownloadRequest.Options) = {
            tempUrl, response in
            
            let option = DownloadRequest.Options()
            let finalUrl: URL
            if isPhoto {
                finalUrl = tempUrl.deletingPathExtension().appendingPathExtension(link.pathExtension)
            } else {
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                finalUrl = documentsURL.appendingPathComponent("\(response.suggestedFilename!)")
            }
            return (finalUrl, option)
        }
        
        sharedSession.download(link, to: destination).response(completionHandler: {
            [unowned self] response in
            guard response.error == nil, let destinationUrl = response.fileURL else {
                completion(false)
                print("response.error != nil")
                return
            }
            if isPhoto {
                savePhoto(photoFileUrl: destinationUrl, completion: completion)
            } else {
                print("download Video finish")
                completion(true)
//                saveVideo(videoFileUrl: destinationUrl, completion: completion)
            }
        })
    }
    
    func downloadMedias(isPhoto: Bool, links: [String], completion: @escaping (Bool) -> Void) {
        print("downloadMedias link : \(links)")
        guard let downloadUrl = URL(string: links.first!) else {
            print("downloadUrl.first != nil")
            completion(false)
            return
        }
        if links.count > 0 {
            let destination: (URL, HTTPURLResponse) -> (URL, DownloadRequest.Options) = {
                tempUrl, response in
                
                let option = DownloadRequest.Options()
                let finalUrl: URL
                if isPhoto {
                    finalUrl = tempUrl.deletingPathExtension().appendingPathExtension(downloadUrl.pathExtension)
                } else {
                    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    finalUrl = documentsURL.appendingPathComponent("\(response.suggestedFilename!)")
                }
                
//                let finalUrl = tempUrl.deletingPathExtension().appendingPathExtension(downloadUrl.pathExtension)
                return (finalUrl, option)
            }
            
            sharedSession.download(links.first!, to: destination).response(completionHandler: {
                [unowned self] response in
                guard response.error == nil, let destinationUrl = response.fileURL else {
                    completion(false)
                    return
                }
                if isPhoto {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: destinationUrl)
                    }, completionHandler: { successed, error in
                        guard error == nil, successed else {
                            completion(false)
                            return
                        }
                        print("Photo is saved!")
                        downloadFinish(isPhoto: isPhoto, links: links, completion: completion)
                    })
                } else {
                    print("download Video finish")
                    downloadFinish(isPhoto: isPhoto, links: links, completion: completion)
                }
            })
        }
    }
    
    private func downloadFinish(isPhoto: Bool, links: [String], completion: @escaping (Bool) -> Void) {
        print("目前總數 : \(links.count)")
        var downloadLinks = links
        downloadLinks.removeFirst()
        print("剩餘 : \(downloadLinks.count)")
        if downloadLinks.count > 0 {
            delegate?.currentCount(downloadLinks.count)
            downloadMedias(isPhoto: isPhoto, links: downloadLinks, completion: completion)
        } else {
            completion(true)
        }
    }
    
    private func savePhoto(photoFileUrl: URL, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: photoFileUrl)
        }, completionHandler: { successed, error in
            guard error == nil, successed else {
                completion(false)
                return
            }
            print("Photo is saved!")
            completion(true)
        })
    }
}
