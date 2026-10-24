// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class LEs extends L {
  LEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Overworld';

  @override
  String get tagline => 'Tu mundo, al estilo videojuego.';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancelar';

  @override
  String get close => 'Cerrar';

  @override
  String get done => 'Listo';

  @override
  String get save => 'Guardar';

  @override
  String get saveChanges => 'Guardar cambios';

  @override
  String get delete => 'Eliminar';

  @override
  String get edit => 'Editar';

  @override
  String get retry => 'Reintentar';

  @override
  String get next => 'Siguiente';

  @override
  String get skip => 'Omitir';

  @override
  String get continueLabel => 'Continuar';

  @override
  String get loading => 'Cargando…';

  @override
  String get unknownLocation => 'Ubicación desconocida';

  @override
  String get somethingWrong => 'Algo salió mal';

  @override
  String get obGetStartedTitle => 'Convierte tu ciudad en un mapa de juego';

  @override
  String get obGetStartedBody =>
      'Elige un mundo, entra y recorre calles reales con estilo.';

  @override
  String get obStart => 'Empezar';

  @override
  String get obGenresTitle => '¿A qué te gusta jugar?';

  @override
  String get obGenresBody =>
      'Elige algunos y te sugeriremos mundos que te encantarán.';

  @override
  String get obHeardTitle => '¿Cómo nos conociste?';

  @override
  String get obHeardStore => 'Tienda de apps';

  @override
  String get obHeardTikTok => 'TikTok';

  @override
  String get obHeardYouTube => 'YouTube';

  @override
  String get obHeardInstagram => 'Instagram';

  @override
  String get obHeardFacebook => 'Facebook';

  @override
  String get obHeardGoogle => 'Google';

  @override
  String get obHeardFriend => 'Un amigo';

  @override
  String get obHeardOther => 'Otro';

  @override
  String get obRatingTitle => '¿Te gusta el viaje?';

  @override
  String get obRatingBody =>
      'Una valoración rápida ayuda a otros jugadores a descubrir Overworld.';

  @override
  String get obRateNow => 'Valorar Overworld';

  @override
  String get obNotNow => 'Ahora no';

  @override
  String get obCarTitle => 'Llévalo a la carretera';

  @override
  String get obCarBodyIos =>
      'Navega con CarPlay y la voz de personaje que prefieras.';

  @override
  String get obCarBodyAndroid =>
      'Navega con Android Auto y la voz de personaje que prefieras.';

  @override
  String get obListenVoice => 'Escuchar';

  @override
  String get obStopVoice => 'Detener';

  @override
  String get obLocationTitle => 'Todo listo';

  @override
  String get obLocationBody =>
      'Overworld usa tu ubicación para mostrarte dónde estás y guiarte. Se queda en tu dispositivo y nunca se vende.';

  @override
  String get obAllowLocation => 'Permitir ubicación';

  @override
  String get obSkipLocation => 'Continuar sin ubicación';

  @override
  String get mapSelectTitle => 'Elige tu mundo';

  @override
  String get mapSelectStart => 'Empezar a explorar';

  @override
  String get proBadge => 'PRO';

  @override
  String get freeBadge => 'GRATIS';

  @override
  String get variantLight => 'CLARO';

  @override
  String get variantDark => 'OSCURO';

  @override
  String get unlockAllMaps => 'Desbloquear todos los mapas';

  @override
  String get lockedTitle => 'Este mapa está bloqueado';

  @override
  String lockedBody(String name) {
    return 'Desbloquea $name y todos los demás mundos con Overworld Pro.';
  }

  @override
  String get lockedCta => 'Desbloquear mapa';

  @override
  String get lockedUseFree => 'Usar un mapa gratis';

  @override
  String get railSearch => 'Buscar';

  @override
  String get railChangeMap => 'Cambiar mapa';

  @override
  String get railNearby => 'Buscar cerca';

  @override
  String get railSaved => 'Lugares guardados';

  @override
  String get railHome => 'Ir a casa';

  @override
  String get railRecenter => 'Mostrar mi ubicación';

  @override
  String get railSettings => 'Ajustes';

  @override
  String get railCompass => 'Orientar al norte';

  @override
  String get railAppearance => 'Cambiar claro/oscuro';

  @override
  String get setHomeFirst => 'Primero guarda un lugar como Casa';

  @override
  String get searchHint => 'Busca lugares o direcciones';

  @override
  String get recent => 'Recientes';

  @override
  String get clearHistory => 'Borrar';

  @override
  String get findNearby => 'Buscar cerca';

  @override
  String get noResultsTitle => 'Sin resultados';

  @override
  String get noResultsBody => 'Prueba a buscar otra cosa.';

  @override
  String get searchUnavailable => 'La búsqueda no está disponible ahora mismo.';

  @override
  String get nearbyEmpty => 'No hay nada cerca';

  @override
  String get catRestaurant => 'Restaurantes';

  @override
  String get catFastFood => 'Comida rápida';

  @override
  String get catCafe => 'Cafeterías';

  @override
  String get catFuel => 'Gasolineras';

  @override
  String get catCharging => 'Puntos de carga';

  @override
  String get catParking => 'Aparcamientos';

  @override
  String get catHotel => 'Hoteles';

  @override
  String get catSupermarket => 'Supermercados';

  @override
  String get catPharmacy => 'Farmacias';

  @override
  String get catHospital => 'Hospitales';

  @override
  String get catSubway => 'Estaciones de metro';

  @override
  String get catBank => 'Bancos';

  @override
  String get getDirections => 'Cómo llegar';

  @override
  String get savePlace => 'Guardar';

  @override
  String get savedLabel => 'Guardado';

  @override
  String get call => 'Llamar';

  @override
  String get website => 'Sitio web';

  @override
  String get share => 'Compartir';

  @override
  String get pinnedLocation => 'Ubicación marcada';

  @override
  String distanceAway(String distance) {
    return 'A $distance';
  }

  @override
  String get setAsHome => 'Establecer como casa';

  @override
  String get editorNewTitle => 'Guardar ubicación';

  @override
  String get editorEditTitle => 'Editar ubicación';

  @override
  String get nameLabel => 'Nombre';

  @override
  String get namePlaceholder => 'Casa, trabajo, la mejor hamburguesa…';

  @override
  String get iconLabel => 'Icono';

  @override
  String get homeToggle => 'Esta es mi casa';

  @override
  String get deletePlace => 'Eliminar ubicación';

  @override
  String deleteConfirm(String name) {
    return '¿Eliminar «$name»?';
  }

  @override
  String get savedTitle => 'Lugares guardados';

  @override
  String get savedEmptyTitle => 'Aún no hay lugares guardados';

  @override
  String get savedEmptyBody =>
      'Mantén pulsado el mapa o guarda un resultado de búsqueda para tenerlo aquí.';

  @override
  String get routeTitle => 'Ruta';

  @override
  String get fromMyLocation => 'Mi ubicación';

  @override
  String get startNow => 'Iniciar ya';

  @override
  String get endRoute => 'Finalizar ruta';

  @override
  String get arrival => 'Llegada';

  @override
  String get routeError => 'No se encontró una ruta hasta allí.';

  @override
  String get needLocationForRoute =>
      'Activa la ubicación para obtener indicaciones.';

  @override
  String get thenLabel => 'Luego';

  @override
  String get rerouting => 'Recalculando…';

  @override
  String get arrivedTitle => 'Has llegado';

  @override
  String get arrivedBody => 'Misión cumplida.';

  @override
  String get mute => 'Silenciar voz';

  @override
  String get unmute => 'Activar voz';

  @override
  String get minShort => 'min';

  @override
  String get hourShort => 'h';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get premiumBannerTitle => 'Overworld Pro';

  @override
  String get premiumBannerBody => 'Desbloquea todos los mapas y voces.';

  @override
  String get premiumBannerCta => 'Hazte Pro';

  @override
  String get proActive => 'Pro está activo. ¡Gracias por tu apoyo!';

  @override
  String get sectionMap => 'Mapa';

  @override
  String get sectionNavigation => 'Navegación';

  @override
  String get sectionApp => 'App';

  @override
  String get sectionSupport => 'Soporte';

  @override
  String get sectionLegal => 'Legal';

  @override
  String get appearance => 'Apariencia';

  @override
  String get appearanceAuto => 'Según el mapa';

  @override
  String get appearanceLight => 'Claro';

  @override
  String get appearanceDark => 'Oscuro';

  @override
  String get appIcon => 'Icono de la app';

  @override
  String get distanceUnits => 'Unidades de distancia';

  @override
  String get kilometers => 'Kilómetros';

  @override
  String get miles => 'Millas';

  @override
  String get voice => 'Voz de navegación';

  @override
  String get carSettingsIos => 'CarPlay';

  @override
  String get carSettingsAndroid => 'Android Auto';

  @override
  String get rateUs => 'Valóranos';

  @override
  String get shareApp => 'Compartir Overworld';

  @override
  String get community => 'Únete a la comunidad';

  @override
  String get contactUs => 'Contáctanos';

  @override
  String get restorePurchases => 'Restaurar compras';

  @override
  String get privacy => 'Política de privacidad';

  @override
  String get terms => 'Condiciones de uso';

  @override
  String get cleanData => 'Borrar mis datos';

  @override
  String get cleanDataTitle => '¿Borrar tus datos?';

  @override
  String get cleanDataBody =>
      'Se eliminarán los lugares guardados, el historial de búsqueda y las preferencias de este dispositivo. Las compras no se verán afectadas.';

  @override
  String get cleanDataConfirm => 'Borrar datos';

  @override
  String get dataCleaned => 'Tus datos se han borrado';

  @override
  String get unitChanged => 'Unidad de distancia cambiada';

  @override
  String versionLabel(String version) {
    return 'Versión $version';
  }

  @override
  String get shareText =>
      '¡Estoy explorando mi ciudad como un mapa de videojuego con Overworld!';

  @override
  String get carTitle => 'Pantalla del coche';

  @override
  String get carLightStyle => 'Estilo de mapa claro';

  @override
  String get carDarkStyle => 'Estilo de mapa oscuro';

  @override
  String get carAlwaysDark => 'Preferir siempre el modo oscuro';

  @override
  String get currentlyActive => 'Activo ahora';

  @override
  String get carUpdated => 'Estilo de mapa del coche actualizado';

  @override
  String get appIconTitle => 'Icono de la app';

  @override
  String get iconChanged => 'Icono de la app cambiado';

  @override
  String get iconFailed => 'No se pudo cambiar el icono de la app';

  @override
  String get iconUnsupported => 'Tu dispositivo no permite cambiar el icono';

  @override
  String get voiceTitle => 'Voz de navegación';

  @override
  String get voicePreview => 'Probar';

  @override
  String get contactTitle => 'Contáctanos';

  @override
  String get contactEmail => 'Tu correo';

  @override
  String get contactEmailHint => 'tu@ejemplo.com';

  @override
  String get contactMessage => 'Mensaje';

  @override
  String get contactMessageHint => 'Cuéntanos qué pasa…';

  @override
  String get contactSend => 'Enviar';

  @override
  String get contactErrorEmpty => 'Rellena los dos campos.';

  @override
  String get contactErrorEmail => 'Introduce un correo electrónico válido.';

  @override
  String get contactSentTitle => '¡Gracias por escribirnos!';

  @override
  String get contactSentBody =>
      'Tu mensaje está listo en tu app de correo. Te responderemos pronto.';

  @override
  String get paywallTitle => 'Desbloquea todos los mundos';

  @override
  String get paywallFeatureMaps => 'Los 15 mapas al estilo videojuego';

  @override
  String get paywallFeatureVoices => 'Todas las voces de personajes';

  @override
  String get paywallFeatureCar => 'CarPlay y Android Auto';

  @override
  String get paywallFeatureUpdates => 'Nuevos mundos en cuanto salgan';

  @override
  String get planWeekly => 'Semanal';

  @override
  String get planMonthly => 'Mensual';

  @override
  String get planYearly => 'Anual';

  @override
  String get planLifetime => 'De por vida';

  @override
  String get bestValue => 'Mejor precio';

  @override
  String get freeTrial => 'Prueba gratis';

  @override
  String get oneTimePurchase => 'Pago único';

  @override
  String get billedWeekly => 'Facturación semanal';

  @override
  String get billedMonthly => 'Facturación mensual';

  @override
  String get billedYearly => 'Facturación anual';

  @override
  String get restore => 'Restaurar';

  @override
  String get purchaseSuccessTitle => '¡Te damos la bienvenida a Pro!';

  @override
  String get purchaseSuccessBody =>
      'Ya tienes todos los mapas y voces desbloqueados.';

  @override
  String get purchaseFailed =>
      'No se pudo completar la compra. Inténtalo de nuevo.';

  @override
  String get purchasePending => 'Tu compra está pendiente de aprobación.';

  @override
  String get restoreNone => 'No se encontraron compras anteriores.';

  @override
  String get restoreDone => 'Compras restauradas';

  @override
  String get storeUnavailable => 'La tienda no está disponible ahora mismo.';

  @override
  String get autoRenew =>
      'Las suscripciones se renuevan automáticamente salvo que se cancelen al menos 24 horas antes del final del periodo. Gestiónalas en los ajustes de tu cuenta.';

  @override
  String get updateTitle => 'Actualización necesaria';

  @override
  String get updateBody =>
      'Actualiza a la última versión para seguir usando Overworld.';

  @override
  String get updateCta => 'Actualizar ahora';

  @override
  String get locationOff => 'La localización está desactivada';

  @override
  String get locationDenied => 'El acceso a la ubicación está desactivado';

  @override
  String get openSettings => 'Abrir Ajustes';

  @override
  String get currentLocationNotFound =>
      'No se pudo encontrar tu ubicación actual.';

  @override
  String get addedToSaved => 'Añadido a lugares guardados';

  @override
  String get placeUpdated => 'Ubicación actualizada';

  @override
  String get placeDeleted => 'Ubicación eliminada';

  @override
  String get homeSet => 'Casa establecida';
}
