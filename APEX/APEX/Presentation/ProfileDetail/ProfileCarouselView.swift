import SwiftUI

/// 명함/이미지 슬라이더(페이지 인디케이터 포함)
/// 나중에 필요: 확대/공유 액션, 다중 이미지 지원, Lazy loading
struct ProfileCarouselView: View {
    let images: [Image]
    @Binding var currentPage: Int

    private let corner: CGFloat = 12

    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(images.indices, id: \.self) { idx in
                images[idx]
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                    .tag(idx)
            }
        }
        .frame(height: 160)
        .tabViewStyle(.page(indexDisplayMode: .automatic))
    }
}

#Preview {
    struct P: View {
        @State var page = 0
        var body: some View {
            ProfileCarouselView(images: [Image("ProfileS")], currentPage: $page)
        }
    }
    return P()
}
