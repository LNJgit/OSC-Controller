//
//  EditControlsView.swift
//  OSC Controller
//
//  Created by Lorien Nasarre on 19/2/26.
//

import SwiftUI

/// A dedicated screen inside each Layout to:
/// - Reorder controls (their "position" in the UI)
/// - Delete controls
/// - Open a full editor for each control
struct EditControlsView: View {
    @EnvironmentObject var store: ControlsStore
    let layoutID: UUID

    private var layoutIndex: Int? {
        store.state.layouts.firstIndex(where: { $0.id == layoutID })
    }

    var body: some View {
        Group {
            if let lidx = layoutIndex {
                List {
                    Section {
                        ForEach(store.state.layouts[lidx].controls.indices, id: \.self) { i in
                            let controlID = store.state.layouts[lidx].controls[i].id
                            NavigationLink {
                                EditControlView(layoutID: layoutID, controlID: controlID)
                                    .environmentObject(store)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(store.state.layouts[lidx].controls[i].name)
                                        Text(store.state.layouts[lidx].controls[i].address)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(store.state.layouts[lidx].controls[i].type.rawValue.capitalized)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { offsets in
                            let ids = offsets.map { store.state.layouts[lidx].controls[$0].id }
                            ids.forEach { store.removeControl(layoutID: layoutID, controlID: $0) }
                        }
                        // "Position" == order inside the array
                        .onMove { from, to in
                            store.state.layouts[lidx].controls.move(fromOffsets: from, toOffset: to)
                        }
                    } header: {
                        Text("Controls")
                    } footer: {
                        Text("Tip: Tap Edit to reorder. Drag handles appear on the right.")
                    }
                }
                .navigationTitle("Edit Controls")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    Text("Layout not found")
                        .font(.headline)
                }
                .foregroundStyle(.secondary)
                .padding()
            }
        }
    }
}
