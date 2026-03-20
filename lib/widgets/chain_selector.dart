import 'package:flutter/material.dart';
import 'package:location_protocol/location_protocol.dart';

/// Dropdown widget for selecting a target chain from supported chains.
class ChainSelector extends StatelessWidget {
  final int selectedChainId;
  final ValueChanged<int> onChanged;

  const ChainSelector({
    super.key,
    required this.selectedChainId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final chainIds = ChainConfig.supportedChainIds;

    return DropdownButtonFormField<int>(
      value: selectedChainId,
      decoration: const InputDecoration(
        labelText: 'Target Chain',
        border: OutlineInputBorder(),
      ),
      items: chainIds.map((id) {
        final config = ChainConfig.forChainId(id)!;
        return DropdownMenuItem(
          value: id,
          child: Text('${config.chainName} ($id)'),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}
