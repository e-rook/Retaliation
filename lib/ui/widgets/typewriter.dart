import 'dart:async';
import 'package:flutter/material.dart';

/// A reusable typewriter-style text widget.
/// - Reveals text character-by-character at [charDelay].
/// - First tap while animating reveals all remaining text.
/// - Next tap (when finished) invokes [onDone].
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;
  final Duration charDelay;
  final VoidCallback? onDone;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.center,
    this.maxLines,
    this.charDelay = const Duration(milliseconds: 50),
    this.onDone,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  late final Characters _chars;
  late int _index; // number of grapheme clusters to show
  Timer? _timer;

  bool get _finished => _index >= _chars.length;

  @override
  void initState() {
    super.initState();
    _initFor(widget.text);
  }

  @override
  void didUpdateWidget(covariant TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _initFor(widget.text);
    }
  }

  void _initFor(String text) {
    _timer?.cancel();
    _chars = text.characters;
    _index = _chars.isEmpty ? 0 : 1; // start with first glyph like Swift
    if (_chars.isNotEmpty) {
      _timer = Timer.periodic(widget.charDelay, (_) => _tick());
    } else {
      _index = 0;
    }
    setState(() {});
  }

  void _tick() {
    if (!mounted) return;
    if (_index < _chars.length) {
      setState(() {
        _index++;
      });
    } else {
      _timer?.cancel();
    }
  }

  void _handleTap() {
    if (!_finished) {
      setState(() {
        _index = _chars.length;
      });
      _timer?.cancel();
    } else {
      widget.onDone?.call();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String visible = _chars.take(_index).toString();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: Text(
        visible,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        overflow: widget.maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible,
        style: widget.style ?? const TextStyle(
          fontFamily: 'Courier',
          color: Colors.red,
        ),
      ),
    );
  }
}

/// Full-screen overlay variant similar to the SpriteKit background/label pair.
/// Draws a transparent touch layer and positions the typewriter text.
class TypewriterOverlay extends StatelessWidget {
  final String text;
  final VoidCallback? onDone;
  final Alignment alignment;
  final EdgeInsetsGeometry padding;
  final double? maxWidth;
  final TextStyle? style;

  const TypewriterOverlay({
    super.key,
    required this.text,
    this.onDone,
    this.alignment = Alignment.topCenter,
    this.padding = const EdgeInsets.only(top: 24, left: 16, right: 16),
    this.maxWidth,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final textWidget = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? MediaQuery.of(context).size.width),
      child: TypewriterText(
        text: text,
        onDone: onDone,
        style: style ?? const TextStyle(fontFamily: 'Courier', color: Colors.red, fontSize: 16),
        textAlign: TextAlign.center,
        maxLines: 24,
      ),
    );

    return IgnorePointer(
      ignoring: false,
      child: Container(
        color: const Color(0x00000000),
        width: double.infinity,
        height: double.infinity,
        alignment: alignment,
        padding: padding,
        child: textWidget,
      ),
    );
  }
}
