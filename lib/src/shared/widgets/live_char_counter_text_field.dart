import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LiveCharCounterTextField extends StatelessWidget {
  final TextEditingController controller;
  final int? maxLength;
  final String? hintText;
  final TextInputType? keyboardType;
  final Function(String)? onChanged;
  final String? labelText;
  final int? maxLines;
  final bool enabled;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;

  const LiveCharCounterTextField({
    super.key,
    required this.controller,
    this.maxLength,
    this.hintText,
    this.keyboardType,
    this.onChanged,
    this.labelText,
    this.maxLines = 1,
    this.enabled = true,
    this.textInputAction,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          enabled: enabled,
          textInputAction: textInputAction,
          validator: validator,
          inputFormatters: maxLength != null
              ? [LengthLimitingTextInputFormatter(maxLength!)]
              : [],
          decoration: InputDecoration(
            hintText: hintText,
            labelText: labelText,
            border: const OutlineInputBorder(),
            counterText: '', // Hide default counter
          ),
          onChanged: (value) {
            // Trigger rebuild to update counter
            if (onChanged != null) {
              onChanged!(value);
            }
            // Force rebuild by calling setState on parent if needed
            (context as Element).markNeedsBuild();
          },
        ),
        if (maxLength != null) ...[
          const SizedBox(height: 4),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              final currentLength = value.text.length;
              final isNearLimit = currentLength >= (maxLength! * 0.8);
              final isAtLimit = currentLength >= maxLength!;

              return Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$currentLength/$maxLength',
                  style: TextStyle(
                    fontSize: 12,
                    color: isAtLimit
                        ? Colors.red
                        : isNearLimit
                            ? Colors.orange
                            : Colors.grey.shade600,
                    fontWeight: isAtLimit ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
