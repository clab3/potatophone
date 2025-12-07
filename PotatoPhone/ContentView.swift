//
//  ContentView.swift
//  PotatoPhone
//
//  Created by Henry Clabby on 9/25/25.
//

import SwiftUI
import SwiftData

import ContactsUI

// TODO: BUG! When I'm opening the timezone editor, it sometimes briefly disappears
// TODO: BUG! If the contact at the top of the list has multiple FT addresses, the bubble does
// not expand to fix them
// TODO: Improve info on why you need to share your contacts and which option you should pick
// TODO: Show birthdays?
// TODO: It would be nice if the timezone search bar was visible by default
// TODO: More easily mark as caught up
// TODO: If we're going to show birthday in the Edit contact sheet, maybe we should show the other contact info too (phone numbers, emails) and just make it obvious that while they cannot be edited in the app, they can be edited in Contacts
// TODO: It's a bit weird how after I add a new contact, I have to search for them to find and edit their details

struct ContentView: View {
    @Environment(\.modelContext) var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: [
        SortDescriptor(\Contact.lastContacted),
        SortDescriptor(\Contact.identifier),
    ]) var contacts: [Contact]

    @State private var showingContactPicker = false
    @State private var selectedNewContact: CNContact?

    @State private var callInProgress = false
    @State private var shouldShowCatchUpPrompt = false
    // TODO: I may need to save this to the context whenever I change it
    // and maybe the above?
    @State private var lastCalledContactPair: ContactPair?
    
    @State private var contactToEdit: Contact?

    var body: some View {
        VStack {
            HStack {
                Text("Contacts")
                    .font(.headline)
                Spacer()
                Button(action: showContactPicker) {
                    Image(systemName: "plus")
                }
                .sheet(isPresented: $showingContactPicker) {
                    ContactPicker { contact in
                        selectedNewContact = contact
                    }
                }
            }
            .onChange(of: selectedNewContact) {
                if let contact = selectedNewContact {
                    let identifier = contact.identifier
                    addContact(identifier: identifier)
                }
            }
            .padding()
            Rectangle() // dividing line
                .frame(height: 1)
                .foregroundColor(.gray)

            let validContactPairs = getValidContactPairs(contacts: contacts)

            if validContactPairs.isEmpty {
                Text("No contacts added yet!")
            } else {
                List(validContactPairs) { pair in
                    ContactCell(contact: pair.contact, cnContact: pair.cnContact, contactToEdit: $contactToEdit) {
                        // Callback body
                        lastCalledContactPair = pair
                        callInProgress = true
                    }
                }
                .listStyle(PlainListStyle())
            }
            Spacer()
        }
        // TODO: This doesn't make any sense if lastCalledContactPair is nil
        .alert(
            "Did you catch up with \(lastCalledContactPair?.cnContact.givenName ?? "them") \(lastCalledContactPair?.cnContact.familyName ?? "")?",
            isPresented: $shouldShowCatchUpPrompt
        ) {
            Button("Yes") {
                lastCalledContactPair?.contact.lastContacted = Date.now
            }
            Button("No", role: .cancel) {
                // No op
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Detect when user returns to the app
            if newPhase == .active, callInProgress {
                callInProgress = false
                shouldShowCatchUpPrompt = true
            }
        }
        .sheet(item: $contactToEdit) { contact in
            UpdateContactSheet(contact: contact, cnContact: contact.fetchCNContact())
        }
    }

    private func showContactPicker() {
        showingContactPicker = true
    }
    
    private func addContact(identifier: String) {
        let newContact = Contact(identifier: identifier)
        context.insert(newContact)
    }
    
    private func getValidContactPairs(contacts: [Contact]) -> [ContactPair] {
        var contactPairs: [ContactPair] = []
        for contact in contacts {
            if let cnContact: CNContact = contact.tryFetchCNContact() {
                contactPairs.append(ContactPair(contact: contact, cnContact: cnContact))
            }
        }
        return contactPairs
    }

}


struct ContactPair: Identifiable {
    var id: Contact.ID { contact.id }
    let contact: Contact
    let cnContact: CNContact
}


// This entire struct is from ChatGPT
struct ContactPicker: UIViewControllerRepresentable {
    // A callback so you can use the selected contact in your SwiftUI view
    var onSelect: (CNContact) -> Void
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        var onSelect: (CNContact) -> Void
        
        init(onSelect: @escaping (CNContact) -> Void) {
            self.onSelect = onSelect
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onSelect(contact)
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            // Do nothing (or handle cancel if you want)
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .modelContainer(for: Contact.self, inMemory: true) // inMemory avoids creating a file DB
    }
}
