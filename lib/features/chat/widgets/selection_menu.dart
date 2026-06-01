import 'package:flutter/material.dart';

class CustomSelectionMenu extends StatelessWidget {
  final Widget child;
  final Function(String selectedText) onBranchAsk;

  const CustomSelectionMenu({
    super.key,
    required this.child,
    required this.onBranchAsk,
  });

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      contextMenuBuilder: (context, selectableRegionState) {
        final List<ContextMenuButtonItem> buttonItems = 
            selectableRegionState.contextMenuButtonItems;
            
        // Append custom Branch Ask Button
        buttonItems.add(
          ContextMenuButtonItem(
            label: '🌿 Branch Ask',
            onPressed: () {
              final selection = selectableRegionState.currentSelection;
              if (selection != null) {
                onBranchAsk(selection.plainText);
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
      child: child,
    );
  }
}
