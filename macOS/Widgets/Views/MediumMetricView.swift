import SwiftUI

/// Featured metric on the left, three companions as rows that
/// share the full height on the right.
struct MediumMetricView: View {
    let featured: MetricPresentation
    let others: [MetricPresentation]

    var body: some View {
        HStack(spacing: 16) {
            SmallMetricView(presentation: featured)
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(others, id: \.kind) { presentation in
                    MetricRow(presentation: presentation)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
