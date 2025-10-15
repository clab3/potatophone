//
//  ContactList.swift
//  PotatoPhone
//
//  Created by Henry Clabby on 10/3/25.
//

import Foundation
import SwiftData


@Model
class ContactList {
    var contacts: List
    
    init(contacts: List) {
        self.contacts = contacts
    }
}
