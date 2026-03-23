import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ReownService {
  ReownAppKitModal? _appKitModal;

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

  bool get isAvailable => _projectId.isNotEmpty;

  bool get isInitialized => _appKitModal != null;

  String get _projectId {
    if (!dotenv.isInitialized) return '';
    return dotenv.env['REOWN_PROJECT_ID'] ?? '';
  }

  ReownAppKitModal? _modalIfReady() {
    if (!isAvailable || _appKitModal == null) return null;
    return _appKitModal;
  }

  ReownAppKitModal _requireModal() {
    final modal = _modalIfReady();
    if (modal == null) {
      throw StateError('ReownService unavailable');
    }
    return modal;
  }
  
  Future<void> initialize(BuildContext context) async {
    try {
      if (!isAvailable || _appKitModal != null) return;
      
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
            universal: 'https://github.com/DecentralizedGeo',
          ),
        ),
      );
      await modal.init();
      _appKitModal = modal;
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

    return modal.session?.getAddress('eip155');
  }

  String get currentAddress {
    return _appKitModal?.session?.getAddress('eip155') ?? '';
  }

  String get currentChainId {
    final chainIdStr = resolveRequestChainId(
      sessionChainId: _appKitModal?.session?.chainId,
      selectedChainId: _appKitModal?.selectedChain?.chainId,
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

    final sessionTopic = modal.session?.topic ?? '';
    final address = modal.session?.getAddress('eip155') ?? '';
    
    final response = await modal.request(
      topic: sessionTopic,
      chainId: resolveRequestChainId(
        sessionChainId: modal.session?.chainId,
        selectedChainId: modal.selectedChain?.chainId,
      ),
      request: SessionRequestParams(
        method: 'personal_sign',
        params: [message, address],
      ),
    );
    
    if (response == null) {
      throw StateError('ReownService unavailable');
    }
    
    return response.toString();
  }

  Future<EIP712Signature> signTypedData(BuildContext context, Map<String, dynamic> typedData) async {
    final modal = _requireModal();

    if (!modal.isConnected) {
      await modal.openModalView(); 
    }
    
    if (!modal.isConnected) {
      throw StateError('ReownService unavailable');
    }

    final sessionTopic = modal.session?.topic ?? '';
    final address = modal.session?.getAddress('eip155') ?? '';

    final response = await modal.request(
      topic: sessionTopic,
      chainId: resolveRequestChainId(
        sessionChainId: modal.session?.chainId,
        selectedChainId: modal.selectedChain?.chainId,
      ),
      request: SessionRequestParams(
        method: 'eth_signTypedData_v4',
        params: [address, typedData],
      ),
    );
    
    if (response == null) {
      throw StateError('ReownService unavailable');
    }
    
    return EIP712Signature.fromHex(response.toString());
  }

  Future<String?> sendTransaction(BuildContext context, Map<String, dynamic> txRequest) async {
    final modal = _requireModal();

    if (!modal.isConnected) {
      await modal.openModalView(); 
    }
    
    if (!modal.isConnected) {
      throw StateError('ReownService unavailable');
    }

    final sessionTopic = modal.session?.topic ?? '';
    final chainId = resolveRequestChainId(
      sessionChainId: modal.session?.chainId,
      selectedChainId: modal.selectedChain?.chainId,
    );

    final response = await modal.request(
      topic: sessionTopic,
      chainId: chainId,
      request: SessionRequestParams(
        method: 'eth_sendTransaction',
        params: [txRequest],
      ),
    );
    
    if (response == null) {
      throw StateError('ReownService unavailable');
    }
    
    return response.toString();
  }
}
