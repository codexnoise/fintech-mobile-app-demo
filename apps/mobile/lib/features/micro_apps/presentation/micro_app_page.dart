import 'package:flutter/material.dart';
import 'package:nexo_core/nexo_core.dart';
import 'package:nexo_design_system/nexo_design_system.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../domain/micro_app.dart';

enum _Status { loading, ready, error }

/// Host de una micro-app en un WebView endurecido: allowlist de host, bridge
/// con nonce y token de contexto (nunca la sesión del banco).
class MicroAppPage extends StatefulWidget {
  const MicroAppPage({
    required this.app,
    required this.fetchToken,
    required this.apiBase,
    super.key,
  });

  final MicroApp app;
  final Future<Result<String>> Function(String appId) fetchToken;
  final String apiBase;

  @override
  State<MicroAppPage> createState() => _MicroAppPageState();
}

class _MicroAppPageState extends State<MicroAppPage> {
  WebViewController? _controller;
  _Status _status = _Status.loading;
  String _error = '';
  String? _token;
  String? _nonce;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    setState(() => _status = _Status.loading);
    final result = await widget.fetchToken(widget.app.id);
    if (!mounted) return;
    switch (result) {
      case Err(:final failure):
        return _fail(switch (failure) {
          ServiceUnavailableFailure() =>
            '${widget.app.title} no está disponible por ahora. Intenta en '
                'unos minutos.',
          _ => failure.userMessage,
        });
      case Ok(:final value):
        _token = value;
    }

    // Canal y política de navegación activos ANTES de cargar la página.
    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.addJavaScriptChannel(
      'NexoBridge',
      onMessageReceived: (m) => _onMessage(m.message),
    );
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          return uri != null && isNavigationAllowed(widget.app, uri)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
        onPageFinished: (_) {
          if (mounted && _status == _Status.loading) {
            setState(() => _status = _Status.ready);
          }
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame ?? true) {
            _fail('No pudimos cargar ${widget.app.title}.');
          }
        },
      ),
    );
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      await platform.setAllowFileAccess(false);
      await platform.setAllowContentAccess(false);
    }
    await controller.loadRequest(widget.app.url);
    if (mounted) setState(() => _controller = controller);
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _status = _Status.error;
      _error = message;
    });
  }

  Future<void> _onMessage(String raw) async {
    final message = parseBridgeMessage(raw, expectedNonce: _nonce);
    switch (message) {
      case null:
        return; // Fuera de contrato: se ignora.
      case BridgeReady():
        final token = _token;
        if (token == null) return;
        _nonce = newNonce();
        await _controller?.runJavaScript(
          contextScript(nonce: _nonce!, token: token, apiBase: widget.apiBase),
        );
      case BridgeQuoteAccepted():
        await _showQuote(message);
        if (mounted) Navigator.of(context).pop();
      case BridgeClose():
        if (mounted) Navigator.of(context).pop();
      case BridgeError():
        _fail('${widget.app.title} reportó un problema. Intenta de nuevo.');
    }
  }

  Future<void> _showQuote(BridgeQuoteAccepted quote) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cotización recibida'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Plan ${quote.plan == 'plus' ? 'Plus' : 'Básico'}'),
          const SizedBox(height: NexoSpacing.xs),
          MoneyText(
            Money(quote.priceCents),
            semanticsPrefix: 'Precio',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: NexoSpacing.xs),
          Text(
            'Cotización referencial de ${widget.app.title}. Nexo no realiza '
            'ningún cobro.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    // No dejar sesión ni datos del aliado en el dispositivo.
    WebViewCookieManager().clearCookies();
    _controller
      ?..clearCache()
      ..clearLocalStorage();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: Text(widget.app.title)),
      body: switch (_status) {
        _Status.error => Padding(
          padding: const EdgeInsets.all(NexoSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StatusBanner.error(_error),
              const SizedBox(height: NexoSpacing.md),
              OutlinedButton.icon(
                onPressed: _open,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        _ => Stack(
          children: [
            if (controller != null) WebViewWidget(controller: controller),
            if (_status == _Status.loading)
              const Center(
                child: CircularProgressIndicator(semanticsLabel: 'Cargando'),
              ),
          ],
        ),
      },
    );
  }
}
