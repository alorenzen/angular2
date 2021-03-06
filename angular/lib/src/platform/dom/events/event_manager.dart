import 'package:angular/src/core/di.dart' show Injectable, Inject, OpaqueToken;
import 'package:angular/src/core/zone/ng_zone.dart' show NgZone;

const OpaqueToken EVENT_MANAGER_PLUGINS = OpaqueToken('EventManagerPlugins');

@Injectable()
class EventManager {
  final NgZone _zone;
  List<EventManagerPlugin> _plugins;
  Map<String, EventManagerPlugin> _eventToPlugin;
  EventManager(@Inject(EVENT_MANAGER_PLUGINS) List<EventManagerPlugin> plugins,
      this._zone) {
    for (int i = 0, len = plugins.length; i < len; i++) {
      plugins[i].manager = this;
    }
    this._plugins = plugins;
    _eventToPlugin = <String, EventManagerPlugin>{};
  }
  Function addEventListener(
    dynamic element,
    String eventName,
    void callback(event),
  ) {
    var plugin = this._findPluginFor(eventName);
    return plugin.addEventListener(element, eventName, callback);
  }

  NgZone getZone() => _zone;

  EventManagerPlugin _findPluginFor(String eventName) {
    EventManagerPlugin plugin = _eventToPlugin[eventName];
    if (plugin != null) return plugin;
    var plugins = this._plugins;
    for (var i = plugins.length - 1; i >= 0; i--) {
      plugin = plugins[i];
      if (plugin.supports(eventName)) {
        _eventToPlugin[eventName] = plugin;
        return plugin;
      }
    }
    throw StateError('No event manager plugin found for event $eventName');
  }
}

abstract class EventManagerPlugin {
  EventManager manager;

  /// Whether this plugin should handle the event.
  bool supports(String eventName);

  /// Adds an event listener on [element] on [eventName].
  ///
  /// Calls [callback] when the event occurs.
  ///
  /// Returns a function, when called, cancels the event listener.
  Function addEventListener(
    dynamic element,
    String eventName,
    void callback(event),
  ) =>
      throw UnsupportedError('Not supported');

  @Deprecated('No longer supported by the event plugin system')
  Function addGlobalEventListener(
    dynamic element,
    String eventName,
    void callback(event),
  ) =>
      throw UnsupportedError('Not supported');
}
