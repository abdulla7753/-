import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Section header used in side panels.
class PanelSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  const PanelSection({super.key, required this.title, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text(title,
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
            ),
            ?trailing,
          ]),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

/// Numeric text field that commits on submit / focus loss, with range clamping.
class NumberField extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double? min;
  final double? max;
  final int decimals;
  final String? suffix;
  final bool enabled;
  final String? helper;
  const NumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min,
    this.max,
    this.decimals = 0,
    this.suffix,
    this.enabled = true,
    this.helper,
  });

  @override
  State<NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<NumberField> {
  late final TextEditingController _text = TextEditingController(text: _fmt(widget.value));
  final _focus = FocusNode();

  String _fmt(double v) => v.toStringAsFixed(widget.decimals);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(NumberField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _fmt(widget.value) != _text.text) _text.text = _fmt(widget.value);
  }

  void _commit() {
    final parsed = double.tryParse(_text.text.replaceAll(',', '.').replaceAll('٫', '.'));
    if (parsed == null) {
      _text.text = _fmt(widget.value);
      return;
    }
    var v = parsed;
    if (widget.min != null && v < widget.min!) v = widget.min!;
    if (widget.max != null && v > widget.max!) v = widget.max!;
    _text.text = _fmt(v);
    if (v != widget.value) widget.onChanged(v);
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: _text,
        focusNode: _focus,
        enabled: widget.enabled,
        keyboardType: TextInputType.numberWithOptions(decimal: widget.decimals > 0, signed: (widget.min ?? 0) < 0),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,٫\-]'))],
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(
          labelText: widget.label,
          suffixText: widget.suffix,
          helperText: widget.helper,
          helperMaxLines: 3,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _commit(),
      ),
    );
  }
}

/// Compact integer stepper (e.g. number of lanes).
class StepperField extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const StepperField({super.key, required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 28,
            child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

/// KPI tile: label, big value, optional confidence interval line.
class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String? sub;
  final Color? accent;
  const MetricTile({super.key, required this.label, required this.value, this.unit, this.sub, this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: accent ?? theme.colorScheme.primary, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text.rich(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            TextSpan(children: [
              TextSpan(text: value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              if (unit != null) TextSpan(text: ' $unit', style: theme.textTheme.bodySmall),
            ]),
            textDirection: TextDirection.ltr,
          ),
          if (sub != null)
            Text(sub!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                textDirection: TextDirection.ltr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Widget? action;
  const InfoBanner({super.key, required this.icon, required this.text, required this.color, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
          ?action,
        ],
      ),
    );
  }
}
