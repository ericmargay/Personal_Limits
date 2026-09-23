import GoogleMobileAds
import SwiftUI

/// Hueco para el banner adaptativo al pie de la pantalla. Solo pide anuncios
/// cuando el consentimiento lo permite y el SDK está iniciado.
struct AdBannerSlot: View {
    @Environment(AdsManager.self) private var ads
    @State private var width: CGFloat = 0

    var body: some View {
        if ads.isReady {
            let adSize = largeAnchoredAdaptiveBanner(width: max(width, 320))
            AdBannerView(adSize: adSize)
                .frame(height: adSize.size.height)
                .frame(maxWidth: .infinity)
                .background(.bar)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.width
                } action: { newWidth in
                    width = newWidth
                }
        }
    }
}

struct AdBannerView: UIViewRepresentable {
    let adSize: AdSize

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = AdsConfig.bannerUnitID
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        // Al rotar o cambiar de ancho se pide un banner del tamaño nuevo.
        guard banner.adSize.size != adSize.size else { return }
        banner.adSize = adSize
        banner.load(Request())
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {}

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            #if DEBUG
            print("[Ads] banner no recibido: \(error.localizedDescription)")
            #endif
        }
    }
}
