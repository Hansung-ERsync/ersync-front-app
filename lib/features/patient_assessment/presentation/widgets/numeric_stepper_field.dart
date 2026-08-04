import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

class NumericStepperField extends StatefulWidget {
  const NumericStepperField({
    super.key,
    required this.semanticLabel,
    required this.value,
    required this.step,
    required this.min,
    required this.max,
    required this.fallbackValue,
    required this.onChanged,
    this.inputKey,
    this.decimalPlaces = 0,
    this.unit,
  });

  final String semanticLabel;
  final double? value;
  final double step;
  final double min;
  final double max;
  final double fallbackValue;
  final ValueChanged<double?> onChanged;
  final Key? inputKey;
  final int decimalPlaces;
  final String? unit;

  @override
  State<NumericStepperField> createState() => _NumericStepperFieldState();
}

class _NumericStepperFieldState extends State<NumericStepperField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant NumericStepperField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final double? editingValue = double.tryParse(_controller.text);
    final bool editingSameValue =
        _focusNode.hasFocus &&
        ((editingValue == null && widget.value == null) ||
            (editingValue != null && widget.value == editingValue));
    if (!editingSameValue) {
      final String formatted = _format(widget.value);
      if (_controller.text != formatted) {
        _controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      child: Row(
        children: <Widget>[
          _StepButton(
            icon: Icons.remove_rounded,
            tooltip: '${widget.semanticLabel} 감소',
            onPressed: () => _adjust(-widget.step),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: widget.inputKey,
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.numberWithOptions(
                decimal: widget.decimalPlaces > 0,
              ),
              textInputAction: TextInputAction.done,
              selectAllOnFocus: true,
              inputFormatters: <TextInputFormatter>[
                _RangeNumberFormatter(
                  min: widget.min,
                  max: widget.max,
                  decimalPlaces: widget.decimalPlaces,
                ),
              ],
              decoration: InputDecoration(
                isDense: true,
                hintText: '직접 입력',
                suffixText: widget.unit,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
              ),
              onChanged: (String text) {
                widget.onChanged(text.isEmpty ? null : double.tryParse(text));
              },
              onTapOutside: (_) => _focusNode.unfocus(),
            ),
          ),
          const SizedBox(width: 8),
          _StepButton(
            icon: Icons.add_rounded,
            tooltip: '${widget.semanticLabel} 증가',
            onPressed: () => _adjust(widget.step),
          ),
        ],
      ),
    );
  }

  void _adjust(double delta) {
    final double adjusted = widget.value == null
        ? widget.fallbackValue.clamp(widget.min, widget.max)
        : (widget.value! + delta).clamp(widget.min, widget.max);
    final double normalized = double.parse(
      adjusted.toStringAsFixed(widget.decimalPlaces),
    );
    widget.onChanged(normalized);
  }

  String _format(double? value) {
    if (value == null) {
      return '';
    }
    return widget.decimalPlaces == 0
        ? value.round().toString()
        : value.toStringAsFixed(widget.decimalPlaces);
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 19),
      style: IconButton.styleFrom(
        minimumSize: const Size.square(44),
        tapTargetSize: MaterialTapTargetSize.padded,
        side: const BorderSide(color: AppColors.border),
      ),
    );
  }
}

class _RangeNumberFormatter extends TextInputFormatter {
  _RangeNumberFormatter({
    required this.min,
    required this.max,
    required this.decimalPlaces,
  });

  final double min;
  final double max;
  final int decimalPlaces;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }
    final String decimalPart = decimalPlaces == 0
        ? ''
        : r'(?:\.[0-9]{0,' + decimalPlaces.toString() + r'})?';
    final RegExp pattern = RegExp(r'^[0-9]+' + decimalPart + r'$');
    final double? parsed = double.tryParse(newValue.text);
    if (!pattern.hasMatch(newValue.text) ||
        parsed == null ||
        parsed < min ||
        parsed > max) {
      return oldValue;
    }
    return newValue;
  }
}
