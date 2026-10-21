//
//  StudyStreakApp.swift
//  StudyStreak
//
//  Created by Student3 on 2026-10-16.
//

import FirebaseCore
import GoogleSignIn
import SwiftData
import SwiftUI

@main
struct StudyStreakApp: App {
    @State private var session: AppSession
    @State private var persistence = LocalPersistence()

    init() {
        if FirebaseApp.app() == nil,
           let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: path) {
            FirebaseApp.configure(options: options)
        }
        _session = State(initialValue: AppSession())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = persistence.container {
                    ContentView()
                        .environment(session)
                        .modelContainer(container)
                } else {
                    ContentUnavailableView {
                        Label("Couldn’t open your study data", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text("Your saved data hasn’t been removed. Please try again.")
                    } actions: {
                        Button("Try Again") { persistence.load() }
                    }
                }
            }
            .onOpenURL { url in
                _ = GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
