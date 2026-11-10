import DevWidgetsCore
import SwiftUI

/// Right column of the menu bar panel: what the developer is
/// running, GitHub status and review queue, and the project
/// buttons.
struct DeveloperSection: View {
    static let CONTAINER_COUNT = 4
    static let PORT_GROUP_COUNT = 6
    static let REVIEW_COUNT = 3

    let model: DeveloperContextModel
    let handler: ActionHandler

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let context = model.latest_Context {
                ContextRow(
                    symbol_Name: "arrow.triangle.branch",
                    line: ContextPresentation.describeGit(context.git)
                )
                GitHubRow(github: context.github)
                ReviewQueueList(
                    state: context.review_Queue,
                    row_Limit: Self.REVIEW_COUNT
                )
                containerList(context.docker)
                PortList(
                    ports: context.ports,
                    row_Limit: Self.PORT_GROUP_COUNT
                )
            } else {
                ProgressView("Reading Git, Docker and ports…")
            }
            project_Buttons
        }
    }

    private func containerList(_ docker: DockerState) -> some View {
        ContainerList(docker: docker, row_Limit: Self.CONTAINER_COUNT)
        { container in
            PanelActionButton(
                action: .restart_Container(
                    container: container.identity
                ),
                handler: handler
            )
            PanelActionButton(
                action: .stop_Container(
                    container: container.identity
                ),
                handler: handler
            )
        }
    }

    private var project_Buttons: some View {
        HStack {
            Button("Choose Project…") { model.chooseProject() }
            Button("Open Project") {
                Task { await handler.perform(.open_Project) }
            }
            .disabled(model.project_URL == nil)
        }
    }
}
