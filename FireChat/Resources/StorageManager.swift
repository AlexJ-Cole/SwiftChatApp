//
//  StorageManager.swift
//  FireChat
//
//  Created by Alex Cole on 9/28/20.
//

import Foundation
import FirebaseStorage

final class StorageManager {
    static let shared = StorageManager()
    
    private let storage = Storage.storage().reference()
    
    public typealias UploadPictureCompletion = (Result<String, Error>) -> Void
    
    ///Uploads picture to Firebase storage and returns a completion with URL String to download
    public func uploadProfilePicture(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        storage.child("images/\(fileName)").putData(data, metadata: nil) { metaData, error in
            guard error == nil else {
                print("Failed to upload data to firebase for profile picture")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self.storage.child("images/\(fileName)").downloadURL() { url, error in
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
    
    ///Upload image that will be sent in conversation message
    public func uploadMessagePhoto(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
        storage.child("message_images/\(fileName)").putData(data, metadata: nil) { metaData, error in
            guard error == nil else {
                print("Failed to upload data to firebase for message picture")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self.storage.child("message_images/\(fileName)").downloadURL() { url, error in
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
    
    public enum StorageErrors: Error {
        case failedToUpload
        case failedToGetDownloadURL
    }
    
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
