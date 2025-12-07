//
//  ContactCell.swift
//  PotatoPhone
//
//  Created by Henry Clabby on 12/7/25.
//

import SwiftUI

import ContactsUI

struct ContactCell: View {
    let contact: Contact
    let cnContact: CNContact
    @Binding var contactToEdit: Contact?
    var onCallStarted: (() -> Void)?  // callback to parent
    
    @State private var showPhoneList = false
    @State private var showFTList = false
    
    var localTimeString: String {
        if contact.timeZoneID != NoneTZ {
            if let timeZone = TimeZone(identifier: contact.timeZoneID) {
                let formatter = DateFormatter()
                formatter.timeZone = timeZone
                formatter.dateFormat = "h:mm a" // e.g., "3:45 PM"
                
                return "Local: \(formatter.string(from: Date()))"
            }
            // TODO: Else error handling for bad timeZoneID
        }
        return ""
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Text("\(cnContact.givenName) \(cnContact.familyName)")
                        .font(.headline)
                    if !localTimeString.isEmpty {
                        Text(localTimeString)
                    }
                }
                

                let lastContactedText = contact.lastContacted == .distantPast
                    ? "Never"
                    : contact.lastContacted.formatted(date: .numeric, time: .omitted)
                Text("Caught up: \(lastContactedText)")
            }
            Spacer() // Right align the buttons
            
            Button(action: {
                contactToEdit = contact
            }) {
                Image(systemName: "pencil")
                    .foregroundColor(/*@START_MENU_TOKEN@*/.blue/*@END_MENU_TOKEN@*/)
            }
            .buttonStyle(.plain)
                
            // Phone Call Button
            let phoneNumbers = cnContact.phoneNumbers
            let callButtonColor: Color = phoneNumbers.isEmpty ? .gray : .green
            Button(action: {
                showPhoneList = true
            }) {
                Image(systemName: "phone")
                    .foregroundColor(callButtonColor)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showPhoneList, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    if phoneNumbers.isEmpty {
                        Text("No phone numbers found for this contact. Try adding one in the Contacts app!")
                            .font(.footnote)
                            .lineLimit(3)
                    } else {
                        ForEach(Array(phoneNumbers.enumerated()), id: \.element.value.stringValue) { index, number in
                            Button(action: {
                                callPhoneNumber(number.value.stringValue)
                            }) {
                                Text(number.value.stringValue)
                                    .foregroundColor(.blue)
                                    .padding(.vertical, 4)
                            }
                                
                            // Add dividers between the phone numbers
                            if index < phoneNumbers.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
                .padding()
                .presentationCompactAdaptation(.none) // prevents full-screen on iPhone
            }
            
            // FaceTime Video Button
            let ftStringURLPairs = getFTStringURLPairs()
            
            // TODO: a lot of copy pasta from the phone button
            let ftButtonColor: Color = ftStringURLPairs.isEmpty ? .gray : .green
            Button(action: {
                showFTList = true
            }) {
                Image(systemName: "video")
                    .foregroundColor(ftButtonColor)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showFTList, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    if ftStringURLPairs.isEmpty {
                        Text("No valid FaceTime addresses found for this contact. Try adding one in the Contacts app!")
                            .font(.footnote)
                            .lineLimit(3)
                    } else {
                        ForEach(Array(ftStringURLPairs.enumerated()), id: \.offset) { index, pair in
                            Button(action: {
                                startFaceTime(url: pair.url)
                            }) {
                                Text(pair.ftString)
                                    .foregroundColor(.blue)
                                    .padding(.vertical, 4)
                            }
                            
                            // Add dividers between the phone numbers
                            if index < ftStringURLPairs.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
                .padding()
                .presentationCompactAdaptation(.none) // prevents full-screen on iPhone
            }
        }
    }
    
    func getFacetimeURL(phoneNumber: String) -> URL? {
        // 1. Try phone numbers first
        let digits = phoneNumber.filter("0123456789".contains) // strip formatting
        if let url = URL(string: "facetime://\(digits)") {
            return url
        }
        return nil
    }
        
    func getFacetimeURL(emailAddress: String) -> URL? {
        if let url = URL(string: "facetime://\(emailAddress)") {
                return url
        }
        return nil
    }
        
    func getFTStringURLPairs() -> [(ftString: String, url: URL)] {
        let phoneNumberStrings = cnContact.phoneNumbers.map { $0.value.stringValue }
        let emailStrings = cnContact.emailAddresses.map { $0.value as String}
        var ftStringURLPairs: [(ftString: String, url: URL)] = []
        for phoneNumberString in phoneNumberStrings {
            if let url = getFacetimeURL(phoneNumber: phoneNumberString) {
                ftStringURLPairs.append((phoneNumberString, url))
            }
        }
        for emailString in emailStrings {
            if let url = getFacetimeURL(emailAddress: emailString) {
                ftStringURLPairs.append((emailString, url))
            }
        }
        
        return ftStringURLPairs
    }
    
    func callPhoneNumber(_ number: String) {
        if let url = URL(string: "tel://\(number)"),
           UIApplication.shared.canOpenURL(url) {
            onCallStarted?()  // Notify parent
            UIApplication.shared.open(url)
        }
        else {
            // TODO: Actually do something here
            // Also, why is this not working? bc I'm testing?
            print("Cannot call tel://\(number)")
        }
    }
        
    func startFaceTime(url: URL) {
        if UIApplication.shared.canOpenURL(url) {
            onCallStarted?()  // Notify parent
            UIApplication.shared.open(url)
        }
        else {
            // TODO: Something cool
            print("Cannot call \(url)")
        }
    }
    
}
