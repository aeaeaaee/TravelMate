import SwiftUI

// MARK: - Public Detent Enum

/// Defines the snap points for the bottom sheet.
enum Detent: CaseIterable, Comparable {
    case peek, half, full

    // Height calculation is now centralized in the BottomSheetModifier's sheetHeight function.

    static func < (lhs: Detent, rhs: Detent) -> Bool {
        let order: [Detent: Int] = [.peek: 0, .half: 1, .full: 2]
        return order[lhs]! < order[rhs]!
    }
}

// MARK: - PreferenceKey for Content Height
/// A preference key to pass the sheet's content height up the view hierarchy.
private struct SheetContentHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - View+bottomSheet Extension

extension View {
    /// Presents a draggable, multi-detent bottom sheet.
    ///
    /// - Parameters:
    ///   - isPresented: A binding to a Boolean value that determines whether to present the sheet.
    ///   - currentDetent: A binding to the sheet's current detent state.
    ///   - onDismiss: A closure to be executed when the sheet is dismissed.
    ///   - content: A closure that returns the content of the sheet.
    func bottomSheet<Content: View>(
        isPresented: Binding<Bool>,
        currentDetent: Binding<Detent>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.modifier(BottomSheetModifier(isPresented: isPresented, currentDetent: currentDetent, onDismiss: onDismiss, sheetContent: content))
    }
}

// MARK: - BottomSheetModifier

private struct BottomSheetModifier<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var currentDetent: Detent
    let onDismiss: (() -> Void)?
    let sheetContent: () -> SheetContent

    @GestureState private var dragTranslation: CGFloat = 0
    @State private var measuredPeekHeight: CGFloat = 0 // Stores the measured height of content for .peek
    private let dragThreshold: CGFloat = 50 // Pixels to drag before state change
    private let handleHeight: CGFloat = 21 // Approx height of capsule + padding

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            ZStack {
                // Main content
                content

                if isPresented {
                    // Dimming overlay
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture { dismissSheet() }

                    // Sheet View
                    sheetView(in: geometry)
                }
            }
            .onChange(of: isPresented) { _, newValue in
                if !newValue {
                    onDismiss?()
                }
            }
        }
    }

    private func sheetView(in geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.vertical, 8)

            // Provided sheet content, with height measurement for .peek
            sheetContent()
                .background(
                    GeometryReader { contentGeometry in
                        Color.clear.preference(
                            key: SheetContentHeightPreferenceKey.self,
                            // Only report height if current detent is peek, to avoid unnecessary updates
                            // Actually, always report, and let the modifier decide when to use it.
                            value: contentGeometry.size.height
                        )
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped() // Prevents content from overflowing the rounded corners
        }
        .onPreferenceChange(SheetContentHeightPreferenceKey.self) { newHeight in
            if newHeight > 0 {
                self.measuredPeekHeight = newHeight
            }
        }
        .frame(width: geometry.size.width, height: sheetHeight(for: currentDetent, in: geometry.size))
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 10, y: -5)
        .offset(y: calculateOffsetY(containerHeight: geometry.size.height))
        .gesture(dragGesture(in: geometry))
        .transition(.move(edge: .bottom))
        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: currentDetent)
        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: dragTranslation)
    }

    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let allDetents = Detent.allCases.sorted()

                // Calculate the projected Y position of the sheet after the drag
                let currentSheetHeight = sheetHeight(for: currentDetent, in: geometry.size)
                let currentY = geometry.size.height - currentSheetHeight
                let projectedY = currentY + value.predictedEndTranslation.height

                // Find the Y position for each detent
                let detentYPositions = allDetents.map { detent in
                    geometry.size.height - sheetHeight(for: detent, in: geometry.size)
                }

                // Find the detent whose Y position is closest to the projected end position
                if let closestY = detentYPositions.min(by: { abs($0 - projectedY) < abs($1 - projectedY) }),
                   let closestIndex = detentYPositions.firstIndex(of: closestY) {
                    
                    // Check for dismissal: if dragged down far enough from the lowest detent
                    let peekHeight = sheetHeight(for: .peek, in: geometry.size)
                    let dismissThreshold = (geometry.size.height - peekHeight * 3.5)
                    // for now dismissThreshold is 529.5 while projectedY = 401 when at .half. Set to 4 for a more sensitive dragdown().

                    if projectedY > dismissThreshold {
                        dismissSheet()
                    } else {
                        currentDetent = allDetents[closestIndex]
                    }
                } else {
                    // Fallback, should not happen if detents exist
                    dismissSheet()
                }
            }
    }

    private func sheetHeight(for detent: Detent, in containerSize: CGSize) -> CGFloat {
        switch detent {
        case .peek:
            let halfHeight = containerSize.height * 0.6
            // Peek content should not make peek detent taller than a fraction of the half detent.
            let maxAllowedPeekContentHeight = min(halfHeight * 0.9, containerSize.height * 0.4)
            let cappedContentHeight = min(measuredPeekHeight, maxAllowedPeekContentHeight)
            return max(cappedContentHeight, 50) + handleHeight // Ensure a minimum visible height for peek content area

        case .half:
            return containerSize.height * 0.8

        case .full:
            return containerSize.height * 0.92
        }
    }

    private func calculateOffsetY(containerHeight: CGFloat) -> CGFloat {
        let currentSheetHeight = sheetHeight(for: currentDetent, in: CGSize(width: 0, height: containerHeight))
        let topEdgeY = containerHeight - currentSheetHeight
        return topEdgeY + dragTranslation
    }
    
    private func dismissSheet() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPresented = false
        }
        // Ensure the onDismiss callback is called
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onDismiss?()
        }
    }
}

// MARK: - Safe Collection Access

private extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
