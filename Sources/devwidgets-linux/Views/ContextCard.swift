import CGtk
import DevWidgetsCore
import DevWidgetsPresentation
import Foundation

/// The large context widget: Git, GitHub, review queue, running
/// containers (restart, stop) and listening ports.
final class ContextCard {
    static let REQUEST_LIMIT = 2
    static let CONTAINER_LIMIT = 2
    static let PORT_GROUP_LIMIT = 3

    let widget = Widgets.makeBox(vertical: true, spacing: 8)
    private let handlers: CardHandlers
    private let time_Label = Widgets.makeLabel(classes: ["secondary"])
    private let rows_Box = Widgets.makeBox(vertical: true, spacing: 7)
    private var shown_Context: DeveloperContext?

    init(handlers: CardHandlers) {
        self.handlers = handlers
        Widgets.addClasses(widget, ["widget-card"])
        Widgets.fix(widget, size: .large)
        let header = Widgets.makeBox(vertical: false, spacing: 6)
        let title_Label = Widgets.makeLabel(
            "Developer context",
            classes: ["card-title"]
        )
        Widgets.expand(title_Label, horizontally: true)
        Widgets.append(
            Widgets.makeIcon("system-run-symbolic"),
            title_Label,
            time_Label,
            to: header
        )
        Widgets.append(header, rows_Box, to: widget)
        Widgets.append(
            Widgets.makeLabel("Reading…", classes: ["secondary"]),
            to: rows_Box
        )
    }

    /// Rebuilds the rows only when something besides the time
    /// changed, so a click is not lost every ten seconds.
    func update(_ context: DeveloperContext) {
        Widgets.setText(
            time_Label,
            ContextRows.describeTime(context.captured_At)
        )
        guard !Self.isSameContent(shown_Context, context) else {
            return
        }
        shown_Context = context
        Widgets.removeChildren(rows_Box)
        appendProject(context)
        appendReviews(context.review_Queue)
        appendContainers(context.docker)
        appendPorts(context.ports)
    }

    static func isSameContent(
        _ old_Context: DeveloperContext?,
        _ new_Context: DeveloperContext
    ) -> Bool {
        guard let old_Context else { return false }
        return old_Context.git == new_Context.git
            && old_Context.github == new_Context.github
            && old_Context.review_Queue == new_Context.review_Queue
            && old_Context.docker == new_Context.docker
            && old_Context.ports == new_Context.ports
    }

    private func appendProject(_ context: DeveloperContext) {
        let open_Button = Buttons.makeIconButton(
            "folder-open-symbolic",
            tooltip_Text: "Open the project folder"
        ) { [handlers] in handlers.request(.open_Project) }
        appendRow(
            ContextPresentation.describeGit(context.git),
            icon_Name: "document-open-recent-symbolic",
            trailing: open_Button
        )
        let page_Button = GitHubPresentation.findPage(context.github)
            .map { page_URL in
                Buttons.makeIconButton(
                    "web-browser-symbolic",
                    tooltip_Text: "Open on GitHub"
                ) { [handlers] in handlers.open(page_URL) }
            }
        appendRow(
            GitHubPresentation.describe(context.github),
            icon_Name: "emblem-shared-symbolic",
            trailing: page_Button
        )
    }

    private func appendReviews(_ queue: ReviewQueueState) {
        appendRow(
            ReviewQueuePresentation.describe(queue),
            icon_Name: "mail-unread-symbolic"
        )
        let requests = ReviewQueuePresentation.listRequests(
            queue,
            limit: Self.REQUEST_LIMIT
        )
        for request in requests {
            let line = ReviewQueuePresentation.describeRequest(
                request
            )
            let label = Widgets.makeLabel(
                "\(line.title)  \(line.detail_Text)",
                classes: ["caption", "indented"]
            )
            Widgets.append(label, to: rows_Box)
        }
    }

    private func appendContainers(_ docker: DockerState) {
        appendRow(
            ContextPresentation.describeDocker(docker),
            icon_Name: "application-x-executable-symbolic"
        )
        let containers = docker.listBusiest(
            limit: Self.CONTAINER_LIMIT
        )
        for container in containers {
            Widgets.append(makeContainerRow(container), to: rows_Box)
        }
    }

    private func makeContainerRow(
        _ container: ContainerUsage
    ) -> WidgetPointer {
        let row = Widgets.makeBox(vertical: false, spacing: 4)
        let usage_Text =
            container.cpu_Fraction.map(
                MetricFormatting.describeCoreShare
            ) ?? MetricPresentation.UNAVAILABLE_VALUE_TEXT
        let name_Label = Widgets.makeLabel(
            "\(container.identity.name)  \(usage_Text)",
            classes: ["caption", "indented"]
        )
        Widgets.expand(name_Label, horizontally: true)
        Widgets.append(name_Label, to: row)
        let identity = container.identity
        for action in [
            WidgetAction.restart_Container(container: identity),
            .stop_Container(container: identity),
        ] {
            Widgets.append(makeActionButton(action), to: row)
        }
        return row
    }

    private func makeActionButton(
        _ action: WidgetAction
    ) -> WidgetPointer {
        Buttons.makeIconButton(
            ActionIcons.name(action),
            tooltip_Text: "\(action.title)…"
        ) { [handlers] in handlers.request(action) }
    }

    private func appendPorts(_ ports: [ListeningPort]) {
        let groups = ContextPresentation.groupPorts(ports)
        Widgets.append(
            ContextRows.makeCaption("Listening ports"),
            to: rows_Box
        )
        guard !groups.isEmpty else {
            appendCaption("None", classes: ["secondary"])
            return
        }
        for group in groups.prefix(Self.PORT_GROUP_LIMIT) {
            appendCaption(
                "\(group.owner_Name)  \(group.ports_Text)",
                classes: []
            )
        }
    }

    private func appendCaption(_ text: String, classes: [String]) {
        Widgets.append(
            Widgets.makeLabel(text, classes: ["caption"] + classes),
            to: rows_Box
        )
    }

    private func appendRow(
        _ line: ContextLine,
        icon_Name: String,
        trailing: WidgetPointer? = nil
    ) {
        Widgets.append(
            ContextRows.makeRow(
                line,
                icon_Name: icon_Name,
                trailing: trailing
            ),
            to: rows_Box
        )
    }
}
