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
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        } detail: {
            VStack(spacing: 20) {
                Text("NeuroViews 2.0")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Advanced AI Camera Interface")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                if #available(iOS 15.0, macOS 12.0, *) {
                    NavigationLink("Open Advanced Camera") {
                        AdvancedCameraView()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button("Open Advanced Camera") {
                        print("🚀 Advanced Camera requires iOS 15.0+")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(true)
                }
                
                Text("Week 13: Advanced UI/UX Implementation")
                    .font(.caption)
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
                
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
