import CoreLocation
import UIKit
#if canImport(MapLibre)
import MapLibre
#endif

/// Root view controller of the CarPlay window: a MapLibre map rendering the
/// synced game style, plus the app's GeoJSON overlays (route, destination,
/// user puck). CarPlay templates draw on top of it.
final class CarMapViewController: UIViewController {
  /// Called when the car switches between light and dark appearance.
  var onAppearanceChange: (() -> Void)?

  private var styleURL: URL?
  private var icons: [String: UIImage] = [:]
  private var user: (coordinate: CLLocationCoordinate2D, bearing: Double)?
  private var routeLine: [CLLocationCoordinate2D] = []
  private var destination: CLLocationCoordinate2D?
  private var didInitialZoom = false

  #if canImport(MapLibre)
  private var mapView: MLNMapView!
  private var styleLoaded = false
  #endif

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    #if canImport(MapLibre)
    let map = MLNMapView(frame: view.bounds, styleURL: styleURL)
    map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    map.delegate = self
    map.showsUserLocation = false
    map.logoView.isHidden = true
    map.compassView.isHidden = true
    map.zoomLevel = 3
    view.addSubview(map)
    mapView = map
    #endif
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
      onAppearanceChange?()
    }
  }

  // MARK: Public API (main thread)

  /// Sets the style (file URL of the synced JSON) and the images it uses.
  func apply(styleURL url: URL?, icons: [String: UIImage]) {
    self.icons = icons
    #if canImport(MapLibre)
    guard isViewLoaded, let map = mapView else {
      styleURL = url
      return
    }
    if url != styleURL {
      styleURL = url
      styleLoaded = false
      if let url = url { map.styleURL = url }
    } else if styleLoaded, let style = map.style {
      addImages(to: style)
    }
    #else
    styleURL = url
    #endif
  }

  func setUser(_ coordinate: CLLocationCoordinate2D, bearing: Double) {
    user = (coordinate, bearing)
    #if canImport(MapLibre)
    updateUserSource()
    #endif
  }

  func setRoute(_ line: [CLLocationCoordinate2D], destination: CLLocationCoordinate2D?) {
    routeLine = line
    self.destination = destination
    #if canImport(MapLibre)
    updateRouteSources()
    #endif
  }

  /// Camera tracking: center on `coordinate`; while navigating, rotate with
  /// `bearing` and tilt.
  func follow(_ coordinate: CLLocationCoordinate2D, bearing: Double, navigating: Bool) {
    #if canImport(MapLibre)
    guard let map = mapView else { return }
    if !didInitialZoom || map.zoomLevel < 10 {
      didInitialZoom = true
      map.setCenter(coordinate, zoomLevel: navigating ? 16.5 : 15.5, direction: navigating ? bearing : 0, animated: false)
    }
    let cam = map.camera
    cam.centerCoordinate = coordinate
    cam.heading = navigating ? bearing : 0
    cam.pitch = navigating ? 45 : 0
    map.setCamera(cam, withDuration: 0.9, animationTimingFunction: CAMediaTimingFunction(name: .linear))
    #endif
  }

  func zoom(by delta: Double) {
    #if canImport(MapLibre)
    guard let map = mapView else { return }
    map.setZoomLevel(min(20, max(2, map.zoomLevel + delta)), animated: true)
    #endif
  }

  /// Moves the map by a fraction of the view size (panning buttons).
  func pan(dx: CGFloat, dy: CGFloat) {
    #if canImport(MapLibre)
    guard let map = mapView else { return }
    let b = map.bounds
    let target = CGPoint(x: b.midX + dx * b.width * 0.3, y: b.midY + dy * b.height * 0.3)
    map.setCenter(map.convert(target, toCoordinateFrom: map), animated: true)
    #endif
  }

  /// Fits `coordinates` into the free area next to the trip preview card.
  func frame(_ coordinates: [CLLocationCoordinate2D]) {
    #if canImport(MapLibre)
    guard let map = mapView, coordinates.count >= 2 else { return }
    let flat = map.camera
    flat.pitch = 0
    flat.heading = 0
    map.setCamera(flat, animated: false)
    let safe = view.safeAreaInsets
    let pad = UIEdgeInsets(top: safe.top + 30, left: safe.left + view.bounds.width * 0.4,
                           bottom: safe.bottom + 30, right: safe.right + 30)
    map.setVisibleCoordinates(coordinates, count: UInt(coordinates.count), edgePadding: pad, animated: true)
    #endif
  }
}

#if canImport(MapLibre)
extension CarMapViewController: MLNMapViewDelegate {
  func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
    styleLoaded = true
    addImages(to: style)
    updateUserSource()
    updateRouteSources()
  }

  func mapViewDidFailLoadingMap(_ mapView: MLNMapView, withError error: Error) {
    NSLog("Overworld CarPlay: map failed to load: \(error)")
  }

  private func addImages(to style: MLNStyle) {
    for (name, image) in icons {
      style.setImage(image, forName: name)
    }
  }

  private func shapeSource(_ id: String) -> MLNShapeSource? {
    guard styleLoaded else { return nil }
    return mapView?.style?.source(withIdentifier: id) as? MLNShapeSource
  }

  private func updateUserSource() {
    guard let source = shapeSource("app-user") else { return }
    guard let u = user else {
      source.shape = MLNShapeCollectionFeature(shapes: [])
      return
    }
    let f = MLNPointFeature()
    f.coordinate = u.coordinate
    f.attributes = ["bearing": u.bearing]
    source.shape = f
  }

  private func updateRouteSources() {
    if let source = shapeSource("app-route") {
      if routeLine.count >= 2 {
        source.shape = MLNPolylineFeature(coordinates: routeLine, count: UInt(routeLine.count))
      } else {
        source.shape = MLNShapeCollectionFeature(shapes: [])
      }
    }
    if let source = shapeSource("app-dest") {
      if let d = destination {
        let f = MLNPointFeature()
        f.coordinate = d
        source.shape = f
      } else {
        source.shape = MLNShapeCollectionFeature(shapes: [])
      }
    }
  }
}
#endif
