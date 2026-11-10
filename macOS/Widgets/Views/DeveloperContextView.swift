import DevWidgetsCore
import SwiftUI
import WidgetKit

/// Medium: Git and GitHub on the left, Docker and ports on the
/// right. Large: the same stacked, with the review queue, more
/// containers and ports. Containers have stop buttons (and, in the
/// large size, restart buttons); the Git row opens the project.
struct DeveloperContextView: View {
    static let MEDIUM_CONTAINER_COUNT = 1
    static let MEDIUM_PORT_GROUP_COUNT = 3
    static let LARGE_CONTAINER_COUNT = 3
    static let LARGE_PORT_GROUP_COUNT = 4
    static let LARGE_REVIEW_COUNT = 2

    @LayoutFamily private var widget_Family

    let context: DeveloperContext
    let armed_Action: WidgetAction?

    var body: some View {
        if widget_Family == .systemLarge {
            large_Layout
        } else {
            medium_Layout
        }
    }

    /// Sections share the full height, like the system calendar.
    private var large_Layout: some View {
        VStack(alignment: .leading, spacing: 0) {
            project_Rows
            Spacer(minLength: 8)
            ReviewQueueList(
                state: context.review_Queue,
                row_Limit: Self.LARGE_REVIEW_COUNT
            )
            Spacer(minLength: 8)
            containerList(row_Limit: Self.LARGE_CONTAINER_COUNT)
            Spacer(minLength: 8)
            PortList(
                ports: context.ports,
                row_Limit: Self.LARGE_PORT_GROUP_COUNT
            )
        }
    }

    private var medium_Layout: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                project_Rows
                Spacer(minLength: 6)
                ContextRow(
                    symbol_Name: ReviewQueueList.SYMBOL_NAME,
                    line: ReviewQueuePresentation.describe(
                        context.review_Queue
                    )
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 0) {
                containerList(row_Limit: Self.MEDIUM_CONTAINER_COUNT)
                Spacer(minLength: 6)
                PortList(
                    ports: context.ports,
                    row_Limit: Self.MEDIUM_PORT_GROUP_COUNT
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var project_Rows: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                ContextRow(
                    symbol_Name: "arrow.triangle.branch",
                    line: ContextPresentation.describeGit(context.git)
                )
                Spacer(minLength: 4)
                Button(intent: OpenProjectIntent()) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open project")
            }
            GitHubRow(github: context.github)
        }
    }

    private func containerList(row_Limit: Int) -> some View {
        ContainerList(
            docker: context.docker,
            row_Limit: row_Limit,
            accessory: containerButtons
        )
    }

    /// Restart only fits the large size's wider rows.
    @ViewBuilder
    private func containerButtons(
        _ container: ContainerUsage
    )
        -> some View
    {
        if widget_Family == .systemLarge {
            WidgetActionButton(
                container: container.identity,
                restarts: true,
                armed_Action: armed_Action
            )
        }
        WidgetActionButton(
            container: container.identity,
            restarts: false,
            armed_Action: armed_Action
        )
    }
}
