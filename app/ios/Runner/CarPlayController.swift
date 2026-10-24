import CarPlay
import CoreLocation
import MapKit
import UIKit

/// Drives the CarPlay UI for one connection: map template + bar/map buttons,
/// search / saved places / nearby / voice lists, trip preview and
/// turn-by-turn navigation. Everything runs on the main thread.
final class CarPlayController: NSObject {
  private enum Mode { case browse, preview, navigating }

  private let ic: CPInterfaceController
  private let window: CPWindow
  private let map = CarMapViewController()
  private let mapTemplate = CPMapTemplate()
  private let locationManager = CLLocationManager()
  private let voice = CarVoice()
  private let services = CarServices.shared
  private var store: CarStore { CarStore.shared }
  private var observers: [NSObjectProtocol] = []

  private var mode = Mode.browse
  private var following = true
  private var isPanning = false
  private var lastLocation: CLLocation?
  private var lastBearing = 0.0
  /// Destination to preview as soon as the first location fix arrives.
  private var awaitingLocationFor: CarPlace?

  // Trip preview
  private var previewRoute: CarRoute?
  private var previewPlace: CarPlace?

  // Navigation
  private var session: CPNavigationSession?
  private var navTrip: CPTrip?
  private var navPlace: CarPlace?
  private var navigator: CarNavigator?
  private var maneuvers: [Int: CPManeuver] = [:]
  private var shownManeuvers: [Int] = []
  private var rerouting = false
  private var lastRerouteAt: Date?

  // Lists
  private var searchTask: URLSessionDataTask?
  private var searchSeq = 0
  private var pendingSearch: (([CPListItem]) -> Void)?
  private var lastSearchItems: [CPListItem] = []
  private weak var voiceTemplate: CPListTemplate?

  private var locale: String { store.state.locale }
  private var imperial: Bool { store.state.imperial }
  private func t(_ key: CarText) -> String { CarStrings.t(key, locale) }

  init(interfaceController: CPInterfaceController, window: CPWindow) {
    ic = interfaceController
    self.window = window
    super.init()
  }

  // MARK: Lifecycle

  func start() {
    window.rootViewController = map
    map.onAppearanceChange = { [weak self] in self?.applyStyle() }

    mapTemplate.mapDelegate = self
    mapTemplate.automaticallyHidesNavigationBar = false
    mapTemplate.guidanceBackgroundColor = UIColor(red: 0.09, green: 0.11, blue: 0.16, alpha: 1)
    configureButtons()
    applyStyle()

    let nc = NotificationCenter.default
    observers.append(nc.addObserver(forName: CarStore.didChange, object: nil, queue: .main) { [weak self] _ in
      self?.storeChanged()
    })
    observers.append(nc.addObserver(forName: CarStore.previewRequested, object: nil, queue: .main) { [weak self] note in
      if let place = note.object as? CarPlace { self?.preview(place) }
    })

    startLocation()

    ic.setRootTemplate(mapTemplate, animated: false) { [weak self] _, _ in
      guard let self = self else { return }
      if !self.store.hasSynced {
        self.showAlert(self.t(.setupTitle))
      } else if !self.store.state.premium {
        self.showAlert(self.t(.proTitle))
      } else if let pending = self.store.takePendingPreview() {
        self.preview(pending)
      }
    }
  }

  func stop() {
    observers.forEach { NotificationCenter.default.removeObserver($0) }
    observers.removeAll()
    locationManager.stopUpdatingLocation()
    locationManager.delegate = nil
    searchTask?.cancel()
    voice.stop()
    session = nil
    navigator = nil
  }

  private func storeChanged() {
    applyStyle()
    configureButtons()
    voiceTemplate?.updateSections(voiceSections())
    if store.state.muted { voice.stop() }
  }

  /// Light/dark style: "always dark" setting or the car's appearance.
  private func applyStyle() {
    let dark = store.state.alwaysDark
      || ic.carTraitCollection.userInterfaceStyle == .dark
      || map.traitCollection.userInterfaceStyle == .dark
    map.apply(styleURL: store.styleURL(dark: dark), icons: store.icons(dark: dark))
  }

  // MARK: Buttons

  private func configureButtons() {
    let muted = store.state.muted
    let mute = barButton(muted ? "speaker.slash.fill" : "speaker.wave.2.fill") { [weak self] in self?.toggleMute() }

    if isPanning {
      mapTemplate.leadingNavigationBarButtons = [textButton(t(.done)) { [weak self] in
        self?.mapTemplate.dismissPanningInterface(animated: true)
      }]
      mapTemplate.trailingNavigationBarButtons = []
    } else {
      switch mode {
      case .browse:
        mapTemplate.leadingNavigationBarButtons = [
          barButton("magnifyingglass") { [weak self] in self?.showSearch() },
          barButton("star.fill") { [weak self] in self?.showSaved() },
        ]
        mapTemplate.trailingNavigationBarButtons = [
          barButton("mappin.and.ellipse") { [weak self] in self?.showCategories() },
          barButton(muted ? "speaker.slash.fill" : "speaker.wave.2.fill") { [weak self] in self?.showVoice() },
        ]
      case .preview:
        mapTemplate.leadingNavigationBarButtons = [textButton(t(.cancel)) { [weak self] in self?.cancelPreview() }]
        mapTemplate.trailingNavigationBarButtons = []
      case .navigating:
        mapTemplate.leadingNavigationBarButtons = [textButton(t(.end)) { [weak self] in self?.endNavigation() }]
        mapTemplate.trailingNavigationBarButtons = [mute]
      }
    }

    let recenter = mapButton("location.fill") { [weak self] in self?.recenter() }
    recenter.isHidden = following
    mapTemplate.mapButtons = [
      mapButton("plus") { [weak self] in self?.map.zoom(by: 1) },
      mapButton("minus") { [weak self] in self?.map.zoom(by: -1) },
      mapButton("arrow.up.and.down.and.arrow.left.and.right") { [weak self] in
        self?.mapTemplate.showPanningInterface(animated: true)
      },
      recenter,
    ]
  }

  private func barButton(_ symbol: String, _ action: @escaping () -> Void) -> CPBarButton {
    CPBarButton(image: CarSymbols.image(symbol, pointSize: 20, weight: .semibold)) { _ in action() }
  }

  private func textButton(_ title: String, _ action: @escaping () -> Void) -> CPBarButton {
    CPBarButton(title: title) { _ in action() }
  }

  private func mapButton(_ symbol: String, _ action: @escaping () -> Void) -> CPMapButton {
    let b = CPMapButton { _ in action() }
    b.image = CarSymbols.image(symbol, pointSize: 20, weight: .semibold)
    return b
  }

  private func recenter() {
    following = true
    configureButtons()
    if let l = lastLocation {
      let navigating = mode == .navigating
      map.follow(l.coordinate, bearing: navigating ? lastBearing : 0, navigating: navigating)
    }
  }

  private func toggleMute() {
    store.setMuted(!store.state.muted) // posts didChange → storeChanged()
  }

  // MARK: Alerts / gating

  private func showAlert(_ title: String) {
    let alert = CPAlertTemplate(titleVariants: [title], actions: [
      CPAlertAction(title: t(.ok), style: .cancel) { [weak self] _ in
        self?.ic.dismissTemplate(animated: true, completion: nil)
      },
    ])
    if ic.presentedTemplate != nil {
      ic.dismissTemplate(animated: false) { [weak self] _, _ in
        self?.ic.presentTemplate(alert, animated: true, completion: nil)
      }
    } else {
      ic.presentTemplate(alert, animated: true, completion: nil)
    }
  }

  /// Navigation features need a synced snapshot and Overworld Pro.
  private func requirePro() -> Bool {
    if !store.hasSynced {
      showAlert(t(.setupTitle))
      return false
    }
    if !store.state.premium {
      showAlert(t(.proTitle))
      return false
    }
    return true
  }

  // MARK: Lists

  /// `selectable: false` for search results, which are picked through the
  /// CPSearchTemplateDelegate instead of the item handler.
  private func placeItem(_ place: CarPlace, symbol: String, selectable: Bool = true) -> CPListItem {
    var detail: [String] = []
    if let here = lastLocation?.coordinate {
      detail.append(CarUnits.format(CarGeo.distance(here, place.coordinate), imperial: imperial, locale: locale))
    }
    if let a = place.address, !a.isEmpty { detail.append(a) }
    let title = place.name.isEmpty && place.isHome ? t(.home) : place.name
    let item = CPListItem(text: title, detailText: detail.isEmpty ? nil : detail.joined(separator: " · "),
                          image: CarSymbols.image(symbol, "mappin"))
    item.userInfo = place
    guard selectable else { return item }
    item.handler = { [weak self] _, completion in
      completion()
      self?.ic.popToRootTemplate(animated: true, completion: nil)
      self?.preview(place)
    }
    return item
  }

  private var maxItems: Int { max(1, Int(CPListTemplate.maximumItemCount)) }

  private func showSaved() {
    guard requirePro() else { return }
    let places = store.state.places
    let ordered = places.filter { $0.isHome } + places.filter { !$0.isHome }
    var sections: [CPListSection] = []
    let favs = ordered.prefix(maxItems).map { placeItem($0, symbol: $0.isHome ? "house.fill" : "star.fill") }
    if !favs.isEmpty {
      sections.append(CPListSection(items: favs, header: t(.saved), sectionIndexTitle: nil))
    }
    let recent = store.state.history.prefix(max(0, maxItems - favs.count)).map { placeItem($0, symbol: "clock") }
    if !recent.isEmpty {
      sections.append(CPListSection(items: recent, header: t(.recent), sectionIndexTitle: nil))
    }
    let tpl = CPListTemplate(title: t(.saved), sections: sections)
    tpl.emptyViewTitleVariants = [t(.noFavorites)]
    tpl.emptyViewSubtitleVariants = [t(.noFavoritesDetail)]
    ic.pushTemplate(tpl, animated: true, completion: nil)
  }

  private func showCategories() {
    guard requirePro() else { return }
    let items: [CPListItem] = CarCategory.all.map { cat in
      let item = CPListItem(text: t(cat.title), detailText: nil, image: CarSymbols.image(cat.symbol, "mappin"))
      item.accessoryType = .disclosureIndicator
      item.handler = { [weak self] _, completion in
        guard let self = self else { completion(); return }
        self.loadNearby(cat, completion: completion)
      }
      return item
    }
    ic.pushTemplate(CPListTemplate(title: t(.nearby), sections: [CPListSection(items: items)]),
                    animated: true, completion: nil)
  }

  private func loadNearby(_ cat: CarCategory, completion: @escaping () -> Void) {
    guard let here = lastLocation?.coordinate else {
      completion()
      showAlert(t(.noLocation))
      return
    }
    services.nearby(amenity: cat.amenity, center: here, language: locale) { [weak self] result in
      completion()
      guard let self = self else { return }
      switch result {
      case .success(let places):
        let items = places.prefix(self.maxItems).map { self.placeItem($0, symbol: cat.symbol) }
        let tpl = CPListTemplate(title: self.t(cat.title), sections: [CPListSection(items: items)])
        tpl.emptyViewTitleVariants = [self.t(.noResults)]
        self.ic.pushTemplate(tpl, animated: true, completion: nil)
      case .failure:
        self.showAlert(self.t(.genericError))
      }
    }
  }

  private func showSearch() {
    guard requirePro() else { return }
    lastSearchItems = historyItems(selectable: false)
    pendingSearch = nil
    let tpl = CPSearchTemplate()
    tpl.delegate = self
    ic.pushTemplate(tpl, animated: true, completion: nil)
  }

  private func historyItems(selectable: Bool = true) -> [CPListItem] {
    store.state.history.prefix(maxItems).map { placeItem($0, symbol: "clock", selectable: selectable) }
  }

  private func showVoice() {
    let tpl = CPListTemplate(title: t(.voice), sections: voiceSections())
    voiceTemplate = tpl
    ic.pushTemplate(tpl, animated: true, completion: nil)
  }

  private func voiceSections() -> [CPListSection] {
    let muted = store.state.muted
    let toggle = CPListItem(text: t(.voiceGuidance), detailText: muted ? t(.voiceOff) : t(.voiceOn),
                            image: CarSymbols.image(muted ? "speaker.slash.fill" : "speaker.wave.2.fill"))
    toggle.handler = { [weak self] _, completion in
      self?.toggleMute()
      completion()
    }
    let persona = CPListItem(text: t(.voiceCharacter), detailText: store.state.voice.name,
                             image: CarSymbols.image("person.wave.2", "person.crop.circle"))
    persona.handler = { [weak self] _, completion in
      completion()
      guard let self = self else { return }
      self.voice.speak(CarPhrases.sample(locale: self.locale), interrupt: true)
    }
    return [CPListSection(items: [toggle, persona])]
  }

  // MARK: Trip preview

  private func preview(_ place: CarPlace) {
    guard requirePro() else { return }
    if mode == .navigating { endNavigation() }
    if mode == .preview { cancelPreview() }
    guard let origin = lastLocation?.coordinate else {
      switch locationManager.authorizationStatus {
      case .denied, .restricted: showAlert(t(.noLocation))
      default: awaitingLocationFor = place
      }
      return
    }
    services.route(from: origin, to: place.coordinate) { [weak self] result in
      guard let self = self else { return }
      switch result {
      case .success(let route):
        self.showPreview(route, place: place, origin: origin)
      case .failure(let error):
        self.showAlert(error is CarServiceError ? self.t(.noRoute) : self.t(.genericError))
      }
    }
  }

  private func showPreview(_ route: CarRoute, place: CarPlace, origin: CLLocationCoordinate2D) {
    guard mode != .navigating else { return }
    previewRoute = route
    previewPlace = place
    mode = .preview
    following = false
    configureButtons()
    map.setRoute(route.geometry, destination: place.coordinate)
    map.frame(route.geometry)

    let originItem = MKMapItem(placemark: MKPlacemark(coordinate: origin))
    let destItem = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
    destItem.name = place.name
    let summary = "\(CarUnits.duration(route.durationS, locale: locale)) · \(CarUnits.format(route.distanceM, imperial: imperial, locale: locale))"
    let choice = CPRouteChoice(summaryVariants: [summary],
                               additionalInformationVariants: [place.address ?? place.name],
                               selectionSummaryVariants: [summary])
    let trip = CPTrip(origin: originItem, destination: destItem, routeChoices: [choice])
    let text = CPTripPreviewTextConfiguration(startButtonTitle: t(.go), additionalRoutesButtonTitle: nil,
                                              overviewButtonTitle: t(.overview))
    mapTemplate.showTripPreviews([trip], textConfiguration: text)
    mapTemplate.updateEstimates(estimates(route.distanceM, route.durationS), for: trip)
  }

  private func cancelPreview() {
    mapTemplate.hideTripPreviews()
    previewRoute = nil
    previewPlace = nil
    mode = .browse
    map.setRoute([], destination: nil)
    recenter()
  }

  private func estimates(_ meters: Double, _ seconds: Double) -> CPTravelEstimates {
    CPTravelEstimates(distanceRemaining: CarUnits.measurement(meters, imperial: imperial),
                      timeRemaining: max(0, seconds.isFinite ? seconds : 0))
  }

  // MARK: Navigation

  private func startNavigation(trip: CPTrip, route: CarRoute, place: CarPlace) {
    previewRoute = nil
    previewPlace = nil
    mode = .navigating
    following = true
    navTrip = trip
    navPlace = place
    navigator = CarNavigator(route: route)
    maneuvers = [:]
    shownManeuvers = []
    session = mapTemplate.startNavigationSession(for: trip)
    configureButtons()
    map.setRoute(route.geometry, destination: place.coordinate)
    if let l = lastLocation {
      handleNavigation(l)
    } else if route.steps.count > 1 {
      shownManeuvers = [1]
      session?.upcomingManeuvers = [maneuver(at: 1)]
    }
  }

  private func handleNavigation(_ fix: CLLocation) {
    guard let nav = navigator else { return }
    let p = nav.update(fix)
    lastBearing = p.bearingDeg
    map.setUser(p.snapped, bearing: p.bearingDeg)
    if following { map.follow(p.snapped, bearing: p.bearingDeg, navigating: true) }

    for cue in nav.cues(for: p, speedMps: max(0, fix.speed)) {
      voice.speak(CarPhrases.phrase(for: cue, imperial: imperial, locale: locale))
    }
    if p.arrived {
      arrive()
      return
    }
    updateGuidance(p)
    if p.offRoute { reroute(from: fix) }
  }

  private func maneuver(at index: Int) -> CPManeuver {
    if let m = maneuvers[index] { return m }
    let m = CPManeuver()
    if let step = navigator?.route.steps[safe: index] {
      m.instructionVariants = CarPhrases.instructions(for: step, locale: locale)
      m.symbolImage = CarSymbols.maneuver(step.kind)
      if let prev = navigator?.route.steps[safe: index - 1] {
        m.initialTravelEstimates = estimates(prev.distanceM, prev.durationS)
      }
    }
    m.userInfo = index
    maneuvers[index] = m
    return m
  }

  private func updateGuidance(_ p: CarProgress) {
    guard let session = session, let trip = navTrip, let route = navigator?.route,
          let next = p.nextStepIndex else { return }
    var indices = [next]
    if let f = p.followingStepIndex { indices.append(f) }
    if indices != shownManeuvers {
      shownManeuvers = indices
      session.upcomingManeuvers = indices.map { maneuver(at: $0) }
    }
    let avgSpeed = route.durationS > 0 ? max(1, route.distanceM / route.durationS) : 10
    session.updateEstimates(estimates(p.distanceToNextM, p.distanceToNextM / avgSpeed), for: maneuver(at: next))
    mapTemplate.updateEstimates(estimates(p.remainingM, p.remainingS), for: trip)
  }

  private func reroute(from fix: CLLocation) {
    guard !rerouting, let place = navPlace else { return }
    if let last = lastRerouteAt, Date().timeIntervalSince(last) < 10 { return }
    rerouting = true
    lastRerouteAt = Date()
    let phrase = CarPhrases.reroute(locale: locale)
    session?.pauseTrip(for: .rerouting, description: phrase)
    shownManeuvers = []
    voice.speak(phrase)
    let heading: Double? = fix.course >= 0 ? fix.course : nil
    services.route(from: fix.coordinate, to: place.coordinate, headingDeg: heading) { [weak self] result in
      guard let self = self else { return }
      self.rerouting = false
      guard self.mode == .navigating, self.navPlace == place else { return }
      if case .success(let route) = result {
        self.navigator = CarNavigator(route: route)
        self.maneuvers = [:]
        self.shownManeuvers = []
        self.map.setRoute(route.geometry, destination: place.coordinate)
      }
      // On failure keep guiding on the old route; the next off-route streak
      // retries after the cooldown. Either way refresh the cards (resumes the trip).
      if let l = self.lastLocation { self.handleNavigation(l) }
    }
  }

  private func arrive() {
    session?.finishTrip()
    resetNavigation()
    showAlert(t(.arrived))
  }

  private func endNavigation() {
    session?.cancelTrip()
    resetNavigation()
  }

  private func resetNavigation() {
    session = nil
    navigator = nil
    navTrip = nil
    navPlace = nil
    maneuvers = [:]
    shownManeuvers = []
    rerouting = false
    mode = .browse
    map.setRoute([], destination: nil)
    recenter()
  }

  // MARK: Location

  private func startLocation() {
    locationManager.delegate = self
    locationManager.activityType = .automotiveNavigation
    locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
    locationManager.distanceFilter = kCLDistanceFilterNone
    locationManager.pausesLocationUpdatesAutomatically = false
    let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
    if modes.contains("location") {
      locationManager.allowsBackgroundLocationUpdates = true
    }
    authorizationChanged()
  }

  private func authorizationChanged() {
    switch locationManager.authorizationStatus {
    case .notDetermined:
      locationManager.requestWhenInUseAuthorization()
    case .authorizedAlways, .authorizedWhenInUse:
      locationManager.startUpdatingLocation()
    default:
      break
    }
  }
}

// MARK: - CLLocationManagerDelegate

extension CarPlayController: CLLocationManagerDelegate {
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    DispatchQueue.main.async { [weak self] in self?.authorizationChanged() }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let fix = locations.last, fix.horizontalAccuracy >= 0 else { return }
    DispatchQueue.main.async { [weak self] in self?.handleFix(fix) }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    NSLog("Overworld CarPlay: location error \(error)")
  }

  private func handleFix(_ fix: CLLocation) {
    lastLocation = fix
    if mode == .navigating, navigator != nil {
      handleNavigation(fix)
    } else {
      if fix.course >= 0 && fix.speed > 1 { lastBearing = fix.course }
      map.setUser(fix.coordinate, bearing: lastBearing)
      if following { map.follow(fix.coordinate, bearing: 0, navigating: false) }
    }
    if let place = awaitingLocationFor {
      awaitingLocationFor = nil
      preview(place)
    }
  }
}

// MARK: - CPMapTemplateDelegate

extension CarPlayController: CPMapTemplateDelegate {
  func mapTemplate(_ mapTemplate: CPMapTemplate, selectedPreviewFor trip: CPTrip, using routeChoice: CPRouteChoice) {
    if let r = previewRoute {
      mapTemplate.updateEstimates(estimates(r.distanceM, r.durationS), for: trip)
    }
  }

  func mapTemplate(_ mapTemplate: CPMapTemplate, startedTrip trip: CPTrip, using routeChoice: CPRouteChoice) {
    mapTemplate.hideTripPreviews()
    guard let route = previewRoute, let place = previewPlace else { return }
    startNavigation(trip: trip, route: route, place: place)
  }

  func mapTemplateDidCancelNavigation(_ mapTemplate: CPMapTemplate) {
    // The system ended the session (e.g. another navigation app started).
    resetNavigation()
  }

  func mapTemplateDidShowPanningInterface(_ mapTemplate: CPMapTemplate) {
    isPanning = true
    following = false
    configureButtons()
  }

  func mapTemplateDidDismissPanningInterface(_ mapTemplate: CPMapTemplate) {
    isPanning = false
    configureButtons()
  }

  func mapTemplate(_ mapTemplate: CPMapTemplate, panWith direction: CPMapTemplate.PanDirection) {
    var dx: CGFloat = 0
    var dy: CGFloat = 0
    if direction.contains(.left) { dx -= 1 }
    if direction.contains(.right) { dx += 1 }
    if direction.contains(.up) { dy -= 1 }
    if direction.contains(.down) { dy += 1 }
    if following {
      following = false
      configureButtons()
    }
    map.pan(dx: dx, dy: dy)
  }
}

// MARK: - CPSearchTemplateDelegate

extension CarPlayController: CPSearchTemplateDelegate {
  func searchTemplate(_ searchTemplate: CPSearchTemplate, updatedSearchText searchText: String,
                      completionHandler: @escaping ([CPListItem]) -> Void) {
    // Answer a superseded request right away (with the last results) so
    // every completion handler runs exactly once, in order.
    searchTask?.cancel()
    searchTask = nil
    pendingSearch?(lastSearchItems)
    pendingSearch = nil
    searchSeq += 1
    let seq = searchSeq
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard query.count >= 2 else {
      completionHandler(historyItems(selectable: false))
      return
    }
    pendingSearch = completionHandler
    searchTask = services.search(query, near: lastLocation?.coordinate) { [weak self] result in
      guard let self = self, seq == self.searchSeq, let done = self.pendingSearch else { return }
      self.pendingSearch = nil
      self.searchTask = nil
      switch result {
      case .success(let places):
        let items = places.prefix(self.maxItems).map { self.placeItem($0, symbol: "mappin", selectable: false) }
        self.lastSearchItems = items
        done(items)
      case .failure:
        done(self.lastSearchItems)
      }
    }
  }

  func searchTemplate(_ searchTemplate: CPSearchTemplate, selectedResult item: CPListItem,
                      completionHandler: @escaping () -> Void) {
    completionHandler()
    guard let place = item.userInfo as? CarPlace else { return }
    ic.popToRootTemplate(animated: true, completion: nil)
    preview(place)
  }
}

private extension Array {
  subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
