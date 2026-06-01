import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract class ReownModalAdapter {
  bool get isConnected;
  String? get sessionChainId;
  String? get selectedChainId;
  String get sessionTopic;
  String get address;

  Future<void> openModalView();
  Future<void> selectChain(String chainId);
  Future<Object?> request({
    required String topic,
    required String chainId,
    required String method,
    required List<dynamic> params,
  });
}

class ReownAppKitModalAdapter implements ReownModalAdapter {
  final ReownAppKitModal modal;

  ReownAppKitModalAdapter(this.modal);

  @override
  bool get isConnected => modal.isConnected;

  @override
  String get address => modal.session?.getAddress('eip155') ?? '';

  @override
  String? get selectedChainId => modal.selectedChain?.chainId;

  @override
  String? get sessionChainId => modal.session?.chainId;

  @override
  String get sessionTopic => modal.session?.topic ?? '';

  @override
  Future<void> openModalView() => modal.openModalView();

  @override
  Future<Object?> request({
    required String topic,
    required String chainId,
    required String method,
    required List<dynamic> params,
  }) {
    return modal.request(
      topic: topic,
      chainId: chainId,
      request: SessionRequestParams(method: method, params: params),
    );
  }

  @override
  Future<void> selectChain(String chainId) async {
    final namespace = NamespaceUtils.getNamespaceFromChain(chainId);
    final networkId = ReownAppKitModalNetworks.getIdFromChain(chainId);
    final networkInfo = ReownAppKitModalNetworks.getNetworkInfo(
      namespace,
      networkId,
    );
    if (networkInfo != null) {
      await modal.selectChain(networkInfo, switchChain: true);
    }
  }
}

class ReownService {
  ReownModalAdapter? _modalAdapter;
  final String? _projectIdOverride;

  ReownService({
    ReownModalAdapter? modalAdapter,
    String? projectIdOverride,
  })  : _modalAdapter = modalAdapter,
        _projectIdOverride = projectIdOverride;

  static const String appScheme = 'locationprotocol';

  static String resolveRequestChainId({
    required String? sessionChainId,
    String? selectedChainId,
  }) {
    if (sessionChainId != null && sessionChainId.isNotEmpty) {
      return sessionChainId;
    }
    if (selectedChainId != null && selectedChainId.isNotEmpty) {
      return selectedChainId;
    }
    return 'eip155:11155111';
  }

  bool get isAvailable => _projectId.isNotEmpty || _modalAdapter != null;

  bool get isInitialized => _modalAdapter != null;

  String get _projectId {
    if (_projectIdOverride != null) return _projectIdOverride;
    if (!dotenv.isInitialized) return '';
    return dotenv.env['REOWN_PROJECT_ID'] ?? '';
  }

  ReownModalAdapter? _modalIfReady() {
    if (!isAvailable || _modalAdapter == null) return null;
    return _modalAdapter;
  }

  ReownModalAdapter _requireModal() {
    final modal = _modalIfReady();
    if (modal == null) {
      throw StateError('ReownService unavailable');
    }
    return modal;
  }
  
  Future<void> initialize(BuildContext context) async {
    try {
      if (!isAvailable || _modalAdapter != null) return;
      
      final modal = ReownAppKitModal(
        context: context,
        projectId: _projectId,
        metadata: const PairingMetadata(
          name: 'Location Protocol',
          description: 'Sign location attestations',
          url: 'https://github.com/DecentralizedGeo',
          icons: ['https://decentralizedgeo.org/static/media/logo.4745e76c17791ca44053.jpg'],
          redirect: Redirect(
            native: 'locationprotocol://',
            linkMode: false,
          ),
        ),
      );
      await modal.init();
      _modalAdapter = ReownAppKitModalAdapter(modal);
    } catch (e) {
      debugPrint('Reown initialization error: $e');
    }
  }

  Future<String?> connectAndGetAddress() async {
    final modal = _modalIfReady();
    if (modal == null) {
      return null;
    }
    
    if (!modal.isConnected) {
      await modal.openModalView(); 
    }
    
    if (!modal.isConnected) {
      return null;
    }

    return modal.address.isEmpty ? null : modal.address;
  }

  Future<String> _syncChainForRequest(
    ReownModalAdapter modal, {
    String? targetChainId,
  }) async {
    final desiredChainId = targetChainId ?? modal.selectedChainId;
    if (desiredChainId == null || desiredChainId.isEmpty) {
      return resolveRequestChainId(
        sessionChainId: modal.sessionChainId,
        selectedChainId: modal.selectedChainId,
      );
    }

    final currentSessionChainId = modal.sessionChainId;
    if (currentSessionChainId != null && currentSessionChainId != desiredChainId) {
      await modal.selectChain(desiredChainId);
    }

    return desiredChainId;
  }

  String get currentAddress {
    return _modalAdapter?.address ?? '';
  }

  String get currentChainId {
    final chainIdStr = resolveRequestChainId(
      sessionChainId: _modalAdapter?.sessionChainId,
      selectedChainId: _modalAdapter?.selectedChainId,
    );
    return chainIdStr.split(':').last;
  }

  Future<String> personalSign(BuildContext context, String message) async {
    final modal = _requireModal();

    if (!modal.isConnected) {
      await modal.openModalView(); 
    }
    
    if (!modal.isConnected) {
      throw StateError('ReownService unavailable');
    }

    final sessionTopic = modal.sessionTopic;
    final address = modal.address;
    
    final response = await modal.request(
      topic: sessionTopic,
      chainId: resolveRequestChainId(
        sessionChainId: modal.sessionChainId,
        selectedChainId: modal.selectedChainId,
      ),
      method: 'personal_sign',
      params: [message, address],
    );
    
    if (response == null) {
      throw StateError('ReownService unavailable');
    }
    
    return response.toString();
  }

  Future<EIP712Signature> signTypedData(
    BuildContext context,
    Map<String, dynamic> typedData, {
    String? targetChainId,
  }) async {
    final modal = _requireModal();

    if (!modal.isConnected) {
      await modal.openModalView(); 
    }
    
    if (!modal.isConnected) {
      throw StateError('ReownService unavailable');
    }

    final sessionTopic = modal.sessionTopic;
    final address = modal.address;
    final chainId = await _syncChainForRequest(
      modal,
      targetChainId: targetChainId,
    );

    final response = await modal.request(
      topic: sessionTopic,
      chainId: chainId,
      method: 'eth_signTypedData_v4',
      params: [address, typedData],
    );
    
    if (response == null) {
      throw StateError('ReownService unavailable');
    }
    
    return EIP712Signature.fromHex(response.toString());
  }

  Future<String?> sendTransaction(
    BuildContext context,
    Map<String, dynamic> txRequest, {
    String? targetChainId,
  }) async {
    final modal = _requireModal();

    if (!modal.isConnected) {
      await modal.openModalView(); 
    }
    
    if (!modal.isConnected) {
      throw StateError('ReownService unavailable');
    }

    final sessionTopic = modal.sessionTopic;
    final chainId = await _syncChainForRequest(
      modal,
      targetChainId: targetChainId,
    );

    final response = await modal.request(
      topic: sessionTopic,
      chainId: chainId,
      method: 'eth_sendTransaction',
      params: [txRequest],
    );
    
    if (response == null) {
      throw StateError('ReownService unavailable');
    }
    
    return response.toString();
  }
}
