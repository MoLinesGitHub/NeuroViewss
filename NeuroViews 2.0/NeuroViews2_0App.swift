//
//  NeuroViews_2_0App.swift
//  NeuroViews 2.0
//
//  Created by molinesMAC on 11/9/25.
//

import SwiftUI
import SwiftData
import OSLog

@main
struct NeuroViews2_0App: App {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.neuroviews.app", category: "App")
    @State private var dataManager = DataManager()
    
    // MARK: - App Lifecycle
    
    init() {
        logger.info("🚀 NeuroViews 2.0 iniciando...")
        
        // Configurar logging para SwiftData en desarrollo
        #if DEBUG
        UserDefaults.standard.set(true, forKey: "SQLDebugEnabled")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(dataManager)
                .onAppear {
                    Task {
                        await checkDataStoreHealth()
                    }
                }
        }
        .modelContainer(dataManager.container)
    }
    
    // MARK: - Health Check
    
    /// Verificar la salud del almacén de datos al inicio
    private func checkDataStoreHealth() async {
        logger.info("🔍 Verificando salud del almacén de datos...")
        
        let isHealthy = await dataManager.checkStoreHealth()
        
        if !isHealthy {
            logger.warning("⚠️ Detectados problemas en el almacén de datos, intentando recuperación...")
            
            do {
                try await dataManager.attemptStoreRecovery()
                logger.info("✅ Recuperación del almacén completada")
            } catch {
                logger.error("❌ Falló la recuperación del almacén: \(error)")
                // En producción, podrías mostrar un alert al usuario
            }
        }
    }
}