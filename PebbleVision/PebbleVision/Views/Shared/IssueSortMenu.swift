// IssueSortMenu.swift
// PebbleVision

import SwiftUI

struct IssueSortMenu: View {
    @Binding var sortField: IssueSortField
    @Binding var sortAscending: Bool

    var body: some View {
        Menu {
            ForEach(IssueSortField.allCases, id: \.self) { field in
                Button {
                    if sortField == field {
                        sortAscending.toggle()
                    } else {
                        sortField = field
                        sortAscending = true
                    }
                } label: {
                    Label {
                        Text(field.rawValue)
                    } icon: {
                        if sortField == field {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Sort by \(sortField.rawValue) (\(sortAscending ? "ascending" : "descending"))")
    }
}
