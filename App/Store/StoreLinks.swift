import Foundation

/// Enlaces públicos del producto. Sustituye los placeholders antes de publicar.
enum StoreLinks {
    /// Sitio en GitHub Pages (Settings → Pages → rama master, carpeta /docs).
    static let website = URL(string: "https://ericmargay.github.io/Personal_Limits/")!
    static let privacyPolicy = URL(string: "https://ericmargay.github.io/Personal_Limits/privacy.html")!
    static let terms = URL(string: "https://ericmargay.github.io/Personal_Limits/terms.html")!
    static let support = URL(string: "https://ericmargay.github.io/Personal_Limits/support.html")!
    static let firmware = URL(string: "https://github.com/ericmargay/Personal_Limits/tree/master/firmware")!
    /// Tienda Etsy con el módulo ESP32 montado. Cambia por la URL real de tu tienda.
    static let etsyShop = URL(string: "https://www.etsy.com/shop/PersonalLimits")!
    /// Ficha en la App Store (rellena cuando esté publicada).
    static let appStore: URL? = nil
}
