//
//  StudyStreakApp.swift
//  StudyStreak
//
//  Created by Student3 on 2026-10-16.
//

import FirebaseCore
import GoogleSignIn
import SwiftUI

@main
struct StudyStreakApp: App {
    @State private var session: AppSession

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
            ContentView()
                .environment(session)
                .onOpenURL { url in
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
