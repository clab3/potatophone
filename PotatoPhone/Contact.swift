//
//  Contact.swift
//  PotatoPhone
//
//  Created by Henry Clabby on 10/3/25.
//

import Foundation
import SwiftData

import ContactsUI

@Model
class Contact {
    @Attribute(.unique) var identifier: String
    var lastContacted: Date
    var timeZoneID: String?
    
    init(identifier: String) {
        self.identifier = identifier
        self.lastContacted = Date.distantPast
        self.timeZoneID = nil
    }
    
    func tryFetchCNContact() -> CNContact? {
        let store = CNContactStore()
        let keysToFetch = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey
        ] as [CNKeyDescriptor]
        
        do {
            return try store.unifiedContact(withIdentifier: self.identifier, keysToFetch: keysToFetch)
        } catch {
            // TODO: error handling
            print("Failed to fetch contact: \(error)")
            return nil
        }
    }
    
    func fetchCNContact() -> CNContact {
        guard let cnContact = tryFetchCNContact() else {
            fatalError("CNContact could not be fetched")
        }
        return cnContact
    }
}
