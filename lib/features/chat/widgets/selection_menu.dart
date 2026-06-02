import 'package:flutter/material.dart';

class CustomSelectionMenu extends StatefulWidget {
  final Widget child;
  final Function(String selectedText) onBranchAsk;

  const CustomSelectionMenu({
    super.key,
    required this.child,
    required this.onBranchAsk,
  });

  @override
  State<CustomSelectionMenu> createState() => _CustomSelectionMenuState();
}

class _CustomSelectionMenuState extends State<CustomSelectionMenu> {
  String _selectedText = '';

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      onSelectionChanged: (content) {
        setState(() {
          _selectedText = content?.plainText ?? '';
        });
      },
      contextMenuBuilder: (context, selectableRegionState) {
        final List<ContextMenuButtonItem> buttonItems = 
            selectableRegionState.contextMenuButtonItems;
            
        // Append custom Branch Ask Button
        buttonItems.add(
          ContextMenuButtonItem(
            label: '🌿 Branch Ask',
            onPressed: () {
              if (_selectedText.isNotEmpty) {
                widget.onBranchAsk(_selectedText);
              }
              selectableRegionState.hideToolbar();
            },
          ),
        );

        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: selectableRegionState.contextMenuAnchors,
          buttonItems: buttonItems,
        );
      },
      child: widget.child,
    );
  }
}
