//
//  ContentView.swift
//  NeuroViews 2.0
//
//  Created by molinesMAC on 11/9/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(DataManager.self) private var dataManager
    @Query private var items: [Item]

    var body: some View {
        NavigationView {
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
                                   value: "Week 15: Testing & Quality Assurance ✅", 
                                   comment: "Current week status"))
                    .font(.caption)
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
                    .accessibilityLabel(NSLocalizedString("status.accessibility", 
                                                        value: "Current status: Week 15, Testing and Quality Assurance completed", 
                                                        comment: "Accessibility label for status"))
                
                // Botón de prueba para verificar SwiftData
                Button("Test SwiftData") {
                    Task {
                        await testSwiftDataOperations()
                    }
                }
                .buttonStyle(.bordered)
                
                // Mostrar contador de items
                Text("Items almacenados: \(items.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("NeuroViews")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
        }
#if os(iOS)
        .navigationViewStyle(StackNavigationViewStyle())
#endif
    }

    // MARK: - SwiftData Test Operations
    
    /// Función de prueba para verificar que SwiftData funciona correctamente
    private func testSwiftDataOperations() async {
        do {
            // Crear un nuevo item de prueba
            let testItem = Item(timestamp: Date(), title: "Item de prueba - \(Date().formatted())")
            
            // Insertarlo usando nuestro DataManager
            try await dataManager.insertItem(testItem)
            
            print("✅ Item de prueba creado exitosamente")
            
            // Opcional: eliminar items antiguos para mantener la base de datos limpia
            await cleanupOldTestItems()
            
        } catch {
            print("❌ Error en operación de prueba: \(error)")
        }
    }
    
    /// Limpiar items de prueba antiguos (mantener solo los últimos 5)
    private func cleanupOldTestItems() async {
        let allItems = await dataManager.fetchAllItems()
        
        // Si hay más de 5 items, eliminar los más antiguos
        if allItems.count > 5 {
            let itemsToDelete = Array(allItems.suffix(allItems.count - 5))
            
            for item in itemsToDelete {
                do {
                    try await dataManager.deleteItem(item)
                } catch {
                    print("⚠️ Error eliminando item antiguo: \(error)")
                }
            }
        }
    }
    
    // MARK: - Legacy Methods (mantenidos por compatibilidad)

    private func addItem() {
        Task {
            let newItem = Item(timestamp: Date(), title: "Item manual")
            try? await dataManager.insertItem(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        Task {
            for index in offsets {
                try? await dataManager.deleteItem(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
        .environment(DataManager())
}