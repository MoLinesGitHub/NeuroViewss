//
//  ContentView.swift
//  NeuroViews 2.0
//
//  Created by molinesMAC on 11/9/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                    } label: {
                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                }
                .onDelete(perform: deleteItems)
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    Button(action: addItem) {
                        Label(NSLocalizedString("add.item", 
                                               value: "Add Item", 
                                               comment: "Button to add new item"), systemImage: "plus")
                    }
                    .accessibilityLabel(NSLocalizedString("add.item", 
                                                        value: "Add Item", 
                                                        comment: "Button to add new item"))
                    .accessibilityHint("Adds a new item to the list")
                }
            }
        } detail: {
            VStack(spacing: 20) {
                Text(NSLocalizedString("main.title", 
                                   value: "NeuroViews 2.0", 
                                   comment: "Application main title"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)
                
                Text(NSLocalizedString("main.subtitle", 
                                     value: "Advanced AI Camera Interface", 
                                     comment: "Application subtitle"))
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                if #available(iOS 15.0, macOS 12.0, *) {
                    NavigationLink(NSLocalizedString("open.camera.button", 
                                                   value: "Open Advanced Camera", 
                                                   comment: "Button to open advanced camera")) {
                        AdvancedCameraView()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityHint(NSLocalizedString("start.camera.hint", 
                                                       value: "Double tap to begin advanced camera interface with AI guidance", 
                                                       comment: "Accessibility hint for camera button"))
                } else {
                    Button(NSLocalizedString("open.camera.button", 
                                           value: "Open Advanced Camera", 
                                           comment: "Button to open advanced camera")) {
                        print("🚀 Advanced Camera requires iOS 15.0+")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(true)
                    .accessibilityLabel(NSLocalizedString("open.camera.button", 
                                                        value: "Open Advanced Camera", 
                                                        comment: "Button to open advanced camera"))
                    .accessibilityHint("Requires iOS 15.0 or later. Feature not available on this device.")
                }
                
                Text(NSLocalizedString("week.status", 
                                   value: "Week 14: Accessibility & Localization ✅", 
                                   comment: "Current week status"))
                    .font(.caption)
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
                    .accessibilityLabel(NSLocalizedString("status.accessibility", 
                                                        value: "Current status: Week 14, Accessibility and Localization completed", 
                                                        comment: "Accessibility label for status"))
                
                Spacer()
            }
            .padding()
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
