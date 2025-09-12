//
//  DataManager.swift
//  NeuroViews 2.0
//
//  Created by molinesMAC on 12/9/25.
//

import SwiftUI
import SwiftData
import OSLog

/// Gestor especializado para el manejo seguro de datos SwiftData
@Observable
final class DataManager {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.neuroviews.app", category: "DataManager")
    private var modelContainer: ModelContainer
    private var mainContext: ModelContext
    
    // MARK: - Initialization
    
    init() {
        // Inicializar el contenedor con configuración robusta
        let container = Self.createContainer()
        self.modelContainer = container
        self.mainContext = container.mainContext
        
        // Configurar el contexto principal
        configureMainContext()
    }
    
    // MARK: - Container Creation
    
    private static func createContainer() -> ModelContainer {
        let schema = Schema([Item.self])
        
        // Crear directorio personalizado para evitar problemas de permisos
        let storeURL = Self.createStoreURL()
        
        let configuration = ModelConfiguration(
            storeURL.lastPathComponent.replacingOccurrences(of: ".sqlite", with: ""),
            schema: schema,
            url: storeURL
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            Logger(subsystem: "com.neuroviews.app", category: "DataManager").info("✅ ModelContainer creado exitosamente en: \(storeURL)")
            return container
        } catch {
            Logger(subsystem: "com.neuroviews.app", category: "DataManager").error("❌ Error creando ModelContainer: \(error)")
            
            // Fallback a contenedor en memoria
            do {
                let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                let fallbackContainer = try ModelContainer(for: schema, configurations: [fallbackConfig])
                Logger(subsystem: "com.neuroviews.app", category: "DataManager").warning("⚠️ Usando contenedor en memoria como fallback")
                return fallbackContainer
            } catch {
                fatalError("No se pudo crear ni el contenedor principal ni el fallback: \(error)")
            }
        }
    }
    
    /// Crear URL personalizada para el store que evite problemas de permisos
    private static func createStoreURL() -> URL {
        // Usar el directorio Documents que siempre tiene permisos de escritura
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let storeURL = documentsPath.appendingPathComponent("NeuroViews.sqlite")
        
        // Asegurar que el directorio padre existe
        let parentDir = storeURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            do {
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
                Logger(subsystem: "com.neuroviews.app", category: "DataManager").info("📁 Directorio creado: \(parentDir)")
            } catch {
                Logger(subsystem: "com.neuroviews.app", category: "DataManager").error("❌ Error creando directorio: \(error)")
            }
        }
        
        return storeURL
    }
    
    // MARK: - Context Configuration
    
    private func configureMainContext() {
        // Configurar el contexto para mejor rendimiento y manejo de errores
        mainContext.autosaveEnabled = true
        
        logger.info("🔧 Contexto principal configurado")
    }
    
    // MARK: - Data Operations
    
    /// Insertar un nuevo Item de forma segura
    func insertItem(_ item: Item) async throws {
        await MainActor.run {
            mainContext.insert(item)
        }
        
        try await saveContext()
        logger.info("✅ Item insertado")
    }
    
    /// Eliminar un Item de forma segura
    func deleteItem(_ item: Item) async throws {
        await MainActor.run {
            mainContext.delete(item)
        }
        
        try await saveContext()
        logger.info("🗑️ Item eliminado")
    }
    
    /// Guardar el contexto de forma segura con reintentos
    func saveContext() async throws {
        let maxRetries = 3
        var currentRetry = 0
        
        while currentRetry < maxRetries {
            do {
                try await MainActor.run {
                    try mainContext.save()
                }
                logger.info("💾 Contexto guardado exitosamente")
                return
            } catch {
                currentRetry += 1
                logger.warning("⚠️ Error guardando contexto (intento \(currentRetry)/\(maxRetries)): \(error)")
                
                if currentRetry >= maxRetries {
                    logger.error("❌ Falló el guardado después de \(maxRetries) intentos")
                    throw DataManagerError.saveFailedAfterRetries(error)
                }
                
                // Esperar antes del siguiente intento
                try await Task.sleep(nanoseconds: UInt64(currentRetry * 500_000_000)) // 0.5s * retry
            }
        }
    }
    
    /// Obtener todos los items de forma segura
    func fetchAllItems() async -> [Item] {
        do {
            let descriptor = FetchDescriptor<Item>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            
            let items = try await MainActor.run {
                try mainContext.fetch(descriptor)
            }
            
            logger.info("📋 Obtenidos \(items.count) items")
            return items
        } catch {
            logger.error("❌ Error obteniendo items: \(error)")
            return []
        }
    }
    
    /// Verificar la salud del store de datos
    func checkStoreHealth() async -> Bool {
        do {
            // Intentar una operación simple de fetch
            var descriptor = FetchDescriptor<Item>()
            descriptor.fetchLimit = 1
            
            _ = try await MainActor.run {
                try mainContext.fetch(descriptor)
            }
            
            logger.info("✅ Store de datos en buen estado")
            return true
        } catch {
            logger.error("❌ Problemas detectados en el store de datos: \(error)")
            return false
        }
    }
    
    // MARK: - Recovery Methods
    
    /// Intentar recuperar el store de datos
    func attemptStoreRecovery() async throws {
        logger.info("🔄 Iniciando recuperación del store de datos")
        
        // Crear un nuevo contenedor
        let newContainer = Self.createContainer()
        
        // Actualizar referencias
        self.modelContainer = newContainer
        self.mainContext = newContainer.mainContext
        
        // Reconfigurar el contexto
        configureMainContext()
        
        logger.info("✅ Recuperación del store completada")
    }
    
    // MARK: - Accessors
    
    var container: ModelContainer {
        modelContainer
    }
    
    var context: ModelContext {
        mainContext
    }
}

// MARK: - Error Types

enum DataManagerError: LocalizedError {
    case saveFailedAfterRetries(Error)
    case contextNotAvailable
    case storeCorrupted
    
    var errorDescription: String? {
        switch self {
        case .saveFailedAfterRetries(let underlyingError):
            return "No se pudo guardar después de múltiples intentos: \(underlyingError.localizedDescription)"
        case .contextNotAvailable:
            return "El contexto de datos no está disponible"
        case .storeCorrupted:
            return "El almacén de datos está corrupto y necesita ser recreado"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .saveFailedAfterRetries:
            return "Intenta reiniciar la aplicación o verificar el espacio disponible en el dispositivo"
        case .contextNotAvailable:
            return "Reinicia la aplicación para reinicializar el contexto de datos"
        case .storeCorrupted:
            return "Los datos pueden necesitar ser recreados. Contacta con soporte técnico si el problema persiste"
        }
    }
}