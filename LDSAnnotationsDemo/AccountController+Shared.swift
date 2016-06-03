//
//  AccountController.swift
//  LDSAnnotationsDemo
//
//  Created by Stephan Heilner on 6/3/16.
//  Copyright © 2016 Hilton Campbell. All rights reserved.
//

import Foundation
import LDSAnnotations

extension AccountController {
    
    static let sharedController = AccountController()
    
    func annotationStoreForUsername(username: String) -> AnnotationStore? {
        let storeName = String(format: "%@.sqlite", username)
        return AnnotationStore(path: NSFileManager.privateDocumentsURL.URLByAppendingPathComponent(storeName).path)
    }
    
}
