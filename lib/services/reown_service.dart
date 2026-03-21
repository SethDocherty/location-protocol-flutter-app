import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:location_protocol/location_protocol.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ReownService {
  late ReownAppKitModal appKitModal;
  
  Future<void> initialize(BuildContext context) async {
    try {
      final projectId = dotenv.isInitialized ? (dotenv.env['REOWN_PROJECT_ID'] ?? '') : '';
      if (projectId.isEmpty) return; // Skip in tests or if missing
      
      appKitModal = ReownAppKitModal(
        context: context,
        projectId: projectId,
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
      await appKitModal.init();
    } catch (e) {
      debugPrint('Reown initialization error: $e');
    }
  }

  Future<String?> connectAndGetAddress() async {
    if (!appKitModal.isConnected) {
      await appKitModal.openModalView(); 
    }
    
    if (!appKitModal.isConnected) {
      return null;
    }

    return appKitModal.session!.getAddress('eip155');
  }

  String get currentAddress {
    return appKitModal.session!.getAddress('eip155') ?? '';
  }

  String get currentChainId {
    final chainIdStr = appKitModal.selectedChain?.chainId ?? 'eip155:11155111';
    return chainIdStr.split(':').last;
  }

  Future<String> personalSign(BuildContext context, String message) async {
    if (!appKitModal.isConnected) {
      await appKitModal.openModalView(); 
    }
    
    if (!appKitModal.isConnected) {
      throw Exception('User cancelled connection');
    }

    final sessionTopic = appKitModal.session!.topic ?? '';
    final address = appKitModal.session!.getAddress('eip155') ?? '';
    
    final response = await appKitModal.request(
      topic: sessionTopic,
      chainId: appKitModal.selectedChain?.chainId ?? 'eip155:11155111',
      request: SessionRequestParams(
        method: 'personal_sign',
        params: [message, address],
      ),
    );
    
    if (response == null) {
      throw Exception('Signing cancelled or failed');
    }
    
    return response.toString();
  }

  Future<EIP712Signature> signTypedData(BuildContext context, Map<String, dynamic> typedData) async {
    if (!appKitModal.isConnected) {
      await appKitModal.openModalView(); 
    }
    
    if (!appKitModal.isConnected) {
      throw Exception('User cancelled connection');
    }

    final sessionTopic = appKitModal.session!.topic ?? '';
    final address = appKitModal.session!.getAddress('eip155') ?? '';

    final response = await appKitModal.request(
      topic: sessionTopic,
      chainId: appKitModal.selectedChain?.chainId ?? 'eip155:11155111',
      request: SessionRequestParams(
        method: 'eth_signTypedData_v4',
        params: [address, typedData],
      ),
    );
    
    if (response == null) {
      throw Exception('Signing cancelled or failed');
    }
    
    return EIP712Signature.fromHex(response.toString());
  }
}
