import 'package:flutter/material.dart';

// Collapsible card widget, for journal viewer

class CollapsibleCard extends StatefulWidget {
  static Future<void> _doNothing(bool isCollapsed) async {}
  const CollapsibleCard(
      {required this.title,
      required this.content,
      this.actions,
      this.onCollapseToggle = _doNothing,
      this.initiallyCollapsed = true,
      Key? key})
      : super(key: key);
  final Widget title, content;
  final bool initiallyCollapsed;
  final Widget? actions;
  final Future<void> Function(bool isCollapsed) onCollapseToggle;

  @override
  _CollapsibleCardState createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<CollapsibleCard> {
  bool _isCollapsed = true;

  @override
  void initState() {
    super.initState();
    _isCollapsed = widget.initiallyCollapsed;
  }

  Widget _padHorizontally(Widget w) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: w,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
	  color: Colors.transparent,
      child: Column(children: [
        _padHorizontally(Row(children: [
          Expanded(child: widget.title),
          IconButton(
              icon: Icon(_isCollapsed ? Icons.expand_more : Icons.expand_less),
              onPressed: () async {
                widget.onCollapseToggle(!_isCollapsed);
                setState(() => _isCollapsed = !_isCollapsed);
              })
        ])),
        if (!_isCollapsed) _padHorizontally(widget.content),
        if (!_isCollapsed && widget.actions != null)
          _padHorizontally(widget.actions!),
      ]),
    );
  }
}
