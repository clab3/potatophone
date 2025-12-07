//
//  UpdateContactSheet.swift
//  PotatoPhone
//
//  Created by Henry Clabby on 12/7/25.
//

import SwiftUI

import ContactsUI

struct UpdateContactSheet: View {
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    
    @Bindable var contact: Contact
    var cnContact: CNContact
    
    var body: some View {
        // This avoids having a trailing space if there is no last name
        let contactName = cnContact.familyName.isEmpty ? "\(cnContact.givenName)" : "\(cnContact.givenName) \(cnContact.familyName)"
        NavigationStack {
            VStack {
                Text(contactName)
                .font(.headline)
                .padding()

                Form {
                    // Last contacted
                    Section {
                        if contact.lastContacted != .distantPast {
                            DatePicker("Last Contacted", selection: Binding(
                                get: { contact.lastContacted },
                                set: { contact.lastContacted = $0 }
                            ), displayedComponents: .date)
                            
                            Button("Clear Date") {
                                contact.lastContacted = Date.distantPast
                            }
                        } else {
                            Button("Last Contacted: None") {
                                contact.lastContacted = Date()  // Set default when user taps
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    // Time Zone
                    Section {
                        NavigationLink(destination: TimeZoneSelectionSheet(selectedTimeZoneID: $contact.timeZoneID)) {
                            let city = contact.timeZoneID.split(separator: "/").last!.replacingOccurrences(of: "_", with: " ")
                            HStack {
                                Text("Time Zone: \(city)")
                                Spacer()
                            }
                        }
                    }
                    // Delete Contact
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Text("Delete Contact")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(
                "Delete Contact",
                isPresented: $showingDeleteConfirmation,
                actions: {
                    Button("Yes", role: .destructive) {
                        context.delete(contact)
                        dismiss()
                    }
                    Button("No", role: .cancel) { }
                },
                message: {
                    Text("Are you sure you want to delete \(contactName)’s contact?")
                })
        }
    }
}
