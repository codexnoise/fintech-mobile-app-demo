import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_sdui_engine/nexo_sdui_engine.dart';

/// Rutas que el servidor puede pedir abrir (allowlist del parser).
const sduiAllowedRoutes = {
  NexoRoutes.home,
  NexoRoutes.accounts,
  NexoRoutes.transferNew,
  NexoRoutes.assistant,
};

/// Micro-apps registradas en la app.
const sduiAllowedMicroApps = {'travel_insurance'};

/// Traduce una acción SDUI (ya validada por el allowlist) a navegación.
void dispatchSduiAction(BuildContext context, SduiAction action) {
  switch (action) {
    case NavigateAction(route: NexoRoutes.home):
      context.go(NexoRoutes.home);
    case NavigateAction(:final route):
      context.push(route);
    case OpenMicroAppAction(:final appId):
      context.push(NexoRoutes.microApp(appId));
    case OpenAssistantAction(:final promptId):
      context.push(
        Uri(
          path: NexoRoutes.assistant,
          queryParameters: {'promptId': ?promptId},
        ).toString(),
      );
  }
}
