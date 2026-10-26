//
//  StudyStreakWidgetBundle.swift
//  StudyStreakWidget
//
//  Created by Student3 on 2026-10-26.
//

import WidgetKit
import SwiftUI

@main
struct StudyStreakWidgetBundle: WidgetBundle {
    var body: some Widget {
        StudyStreakWidget()
        StudyStreakWidgetControl()
        StudyStreakWidgetLiveActivity()
    }
}
