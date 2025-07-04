import SwiftUI
import MapKit

// For MapItem only. MapFeature has its own icon system.
/// Utility helpers for displaying Point-of-Interest category glyphs and colors in a single place.
/// Use `iconName(for:)` to get an appropriate SF Symbol and `backgroundColor(for:)` to get the
/// matching tint.  You can also build a ready-to-use glyph view with `glyph(for:size:)`.
struct POINameAndIcon {
    static func POIIconName(for category: MKPointOfInterestCategory?) -> String {
        switch category {
        case .airport: return "airplane"
        case .amusementPark: return "gamecontroller"
        case .aquarium: return "globe"
        case .atm: return "creditcard.fill"
        case .bakery: return "birthday.cake.fill"
        case .bank: return "building.columns.fill"
        case .beach: return "beach.umbrella.fill"
        case .cafe: return "cup.and.saucer.fill"
        case .campground: return "tent.fill"
        case .carRental: return "car.fill"
        case .evCharger: return "bolt.car.fill"
        case .fireStation: return "flame.fill"
        case .fitnessCenter: return "figure.run"
        case .foodMarket: return "cart.fill"
        case .gasStation: return "fuelpump.fill"
        case .hospital: return "cross.case.fill"
        case .hotel: return "bed.double.fill"
        case .laundry: return "tshirt.fill"
        case .library: return "books.vertical.fill"
        case .marina: return "sailboat.fill"
        case .movieTheater: return "film.fill"
        case .museum: return "building.columns.fill"
        case .musicVenue: return "music.note"
        case .nationalPark: return "tree.fill"
        case .nightlife: return "music.mic"
        case .park: return "leaf.fill"
        case .parking: return "p.circle.fill"
        case .pharmacy: return "pills.fill"
        case .planetarium: return "telescope"
        case .police: return "shield.lefthalf.filled"
        case .postOffice: return "envelope.fill"
        case .publicTransport: return "bus.fill"
        case .restaurant: return "fork.knife"
        case .restroom: return "figure.dress.line.vertical.figure"
        case .school: return "graduationcap.fill"
        case .stadium: return "sportscourt.fill"
        case .store: return "storefront.fill"
        case .theater: return "theatermasks.fill"
        case .university: return "building.columns.fill"
        case .winery: return "wineglass.fill"
        case .zoo: return "tortoise.fill"
        default: return "mappin.and.ellipse"
        }
    }

    static func POIIconBackgroundColor(for category: MKPointOfInterestCategory?) -> Color {
        switch category {
        case .bakery, .cafe, .restaurant: return .orange
        case .campground, .park, .nationalPark, .stadium: return .green
        case .library, .school, .university: return .brown
        case .airport, .publicTransport, .gasStation: return .blue
        case .hotel: return .purple
        case .fireStation, .hospital, .pharmacy: return .red
        case .store: return .yellow
        case .beach, .fitnessCenter: return .cyan
        case .foodMarket: return .yellow
        case .atm, .bank, .carRental, .police : return .grey
        case .amusementPark, .aquarium, .museum, .musicVenue, .planetarium, .theater,.winery, .zoo: return .pink
        default: return .secondary
        }
    }

    /// Human-readable name for a POI category.
    static func POIName(for category: MKPointOfInterestCategory?) -> String {
        switch category {
        case .airport: return "Airport"
        case .amusementPark: return "Amusement Park"
        case .aquarium: return "Aquarium"
        case .atm: return "ATM"
        case .bakery: return "Bakery"
        case .bank: return "Bank"
        case .beach: return "Beach"
        case .cafe: return "Cafe"
        case .campground: return "Campground"
        case .carRental: return "Car Rental"
        case .evCharger: return "EV Charger"
        case .fireStation: return "Fire Station"
        case .fitnessCenter: return "Fitness Center"
        case .foodMarket: return "Food Market"
        case .gasStation: return "Gas Station"
        case .hospital: return "Hospital"
        case .hotel: return "Hotel"
        case .laundry: return "Laundry"
        case .library: return "Library"
        case .marina: return "Marina"
        case .movieTheater: return "Movie Theater"
        case .museum: return "Museum"
        case .musicVenue: return "Music Venue"
        case .nationalPark: return "National Park"
        case .nightlife: return "Nightlife"
        case .park: return "Park"
        case .parking: return "Parking"
        case .pharmacy: return "Pharmacy"
        case .planetarium: return "Planetarium"
        case .police: return "Police"
        case .postOffice: return "Post Office"
        case .publicTransport: return "Public Transport"
        case .restaurant: return "Restaurant"
        case .restroom: return "Restroom"
        case .school: return "School"
        case .stadium: return "Stadium"
        case .store: return "Store"
        case .theater: return "Theater"
        case .university: return "University"
        case .winery: return "Winery"
        case .zoo: return "Zoo"
        default: return "Location"
        }
    }

    /// Convenience builder that returns a glyph inside a colored circular background.
    @ViewBuilder
    static func POIIcon(for category: MKPointOfInterestCategory?, size: CGFloat = 22) -> some View {
        ZStack {
            Circle()
                .fill(POIIconBackgroundColor(for: category))
                .frame(width: size, height: size)
            Image(systemName: POIIconName(for: category))
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(.white)
        }
    }
}
