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
                
            // Phone Call Button
            let phoneNumbers = cnContact.phoneNumbers
            let callButtonColor: Color = phoneNumbers.isEmpty ? .gray : .green
            Button(action: {
                showPhoneList = true
            }) {
                Image(systemName: "phone")
                    .foregroundColor(callButtonColor)
            }
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
                        NavigationLink(destination: TimeZoneSelectionView(selectedTimeZoneID: $contact.timeZoneID)) {
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


struct TimeZoneSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTimeZoneID: String
    @State private var searchText = ""

    // Note: This is inefficient as it creates the list twice. Not sure if it matters
    private let allTimeZoneIDs: [String] = [NoneTZ] + TimeZone.knownTimeZoneIdentifiers
        .filter { $0.contains("/") }
        .sorted {
            $0.split(separator: "/").last!.localizedCompare($1.split(separator: "/").last!) == .orderedAscending
        }

    var filteredTimeZones: [String] {
        if searchText.isEmpty { return allTimeZoneIDs }
        return allTimeZoneIDs.filter { id in
            let city = id.split(separator: "/").last!.replacingOccurrences(of: "_", with: " ")
            return city.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List(filteredTimeZones, id: \.self) { id in
            let city = id.split(separator: "/").last!.replacingOccurrences(of: "_", with: " ")
            HStack {
                Text(city)
                Spacer()
                if id == selectedTimeZoneID {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedTimeZoneID = id
                dismiss()
            }
        }
        .searchable(text: $searchText, prompt: "Search cities")
        .navigationTitle("Select Time Zone")
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .modelContainer(for: Contact.self, inMemory: true) // inMemory avoids creating a file DB
    }
}
