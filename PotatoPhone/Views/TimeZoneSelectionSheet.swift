//
//  TimeZoneSelectionSheet.swift
//  PotatoPhone
//
//  Created by Henry Clabby on 12/7/25.
//

import SwiftUI

struct TimeZoneSelectionSheet: View {
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
