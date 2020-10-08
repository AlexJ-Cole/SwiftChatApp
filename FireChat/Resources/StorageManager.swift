//
//  StorageManager.swift
//  FireChat
//
//  Created by Alex Cole on 9/28/20.
//

import Foundation
import FirebaseStorage

/// Allows you to get, fetch, and upload files to Firebase Storage
final class StorageManager {
    static let shared = StorageManager()
    
    private init() {}
    
    private let storage = Storage.storage().reference()
    
    public typealias UploadPictureCompletion = (Result<String, Error>) -> Void
    
    ///Uploads picture to Firebase storage and returns string representing its download URL
    /// - Parameter data: Data of picture to upload, preferably pngData
    /// - Parameter fileName: Name of file to save image to, needs to be unique
    /// - Parameter completion: Async closure to return result holding string representing download URL for image
    public func uploadProfilePicture(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        storage.child("images/\(fileName)").putData(data, metadata: nil) { [weak self] metaData, error in
            guard error == nil else {
                print("Failed to upload data to firebase for profile picture")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self?.storage.child("images/\(fileName)").downloadURL() { url, error in
                guard let url = url else {
                    print("Failed to get download url")
                    completion(.failure(StorageErrors.failedToGetDownloadURL))
                    return
                }
                
                let urlString = url.absoluteString
                print("download url returned : \(urlString)")
                completion(.success(urlString))
            }
        }
    }
    
    ///Upload image that will be sent in a conversation message
    /// - Parameter data: Image data, preferably pngData
    /// - Parameter fileName: Name of file to save image to, needs to be unique
    /// - Parameter completion: Async closure to return result holding string representing download URL for image
    public func uploadMessagePhoto(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        storage.child("message_images/\(fileName)").putData(data, metadata: nil) { [weak self] metaData, error in
            guard error == nil else {
                print("Failed to upload data to firebase for message picture")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self?.storage.child("message_images/\(fileName)").downloadURL() { url, error in
                guard let url = url else {
                    print("Failed to get download url for message image")
                    completion(.failure(StorageErrors.failedToGetDownloadURL))
                    return
                }
                
                let urlString = url.absoluteString
                print("download url returned : \(urlString)")
                completion(.success(urlString))
            }
        }
    }
    
    ///Upload video that will be sent in conversation message
    /// - Parameter fileUrl: URL pointing to target video that is to be uploaded
    /// - Parameter fileName: Name of file to save video to, needs to be unique
    /// - Parameter completion: Async closure returning result holding string representing download URL for video
    public func uploadMessageVideo(with fileUrl: URL, fileName: String, completion: @escaping UploadPictureCompletion) {
        //Convert video URL to data object since ios13 changed fileURLs for videos selecetd using library
        //  This is only necessary in order to upload videos from the photo library, camera functions fine when we
        //  use putFile and the video URL instead of putData and the data object
        let metadata = StorageMetadata()
        metadata.contentType = "video/quicktime"
        guard let videoData = NSData(contentsOf: fileUrl) as Data? else {
            return
        }
        
        //Store video file
        storage.child("message_videos/\(fileName)").putData(videoData, metadata: metadata) { [weak self] metaData, error in
            guard error == nil else {
                print("Failed to upload video file to firebase for message video")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self?.storage.child("message_videos/\(fileName)").downloadURL() { url, error in
                guard let url = url else {
                    print("Failed to get download url for message video")
                    completion(.failure(StorageErrors.failedToGetDownloadURL))
                    return
                }
                
                
                
                let urlString = url.absoluteString
                print("download url returned for message video: \(urlString)")
                completion(.success(urlString))
            }
        }
    }

    public enum StorageErrors: Error {
        case failedToUpload
        case failedToGetDownloadURL
    }
    
    /// Fetches download URL for data at `path`
    /// - Parameter path: Path pointing to target data
    /// - Parameter completion: Async closure to return result holding the download URL for given path
    public func downloadURL(for path: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let reference = storage.child(path)
        reference.downloadURL(completion: { url, error in
            guard let url = url, error == nil else {
                completion(.failure(StorageErrors.failedToGetDownloadURL))
                return
            }
            
            completion(.success(url))
        })
    }
}
