//
//  StudyStreakWidgetLiveActivity.swift
//  StudyStreakWidget
//
//  Created by Student3 on 2026-10-26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct StudyStreakWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct StudyStreakWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyStreakWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension StudyStreakWidgetAttributes {
    fileprivate static var preview: StudyStreakWidgetAttributes {
        StudyStreakWidgetAttributes(name: "World")
    }
}

extension StudyStreakWidgetAttributes.ContentState {
    fileprivate static var smiley: StudyStreakWidgetAttributes.ContentState {
        StudyStreakWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: StudyStreakWidgetAttributes.ContentState {
         StudyStreakWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: StudyStreakWidgetAttributes.preview) {
   StudyStreakWidgetLiveActivity()
} contentStates: {
    StudyStreakWidgetAttributes.ContentState.smiley
    StudyStreakWidgetAttributes.ContentState.starEyes
}
