import SwiftUI
import WidgetKit

@main
struct DumboWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DumboLiveActivity()
        TodayWidget()
    }
}
