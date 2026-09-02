import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../services/app_settings_service.dart';
import '../app_theme.dart';

class DynamicFormFieldBuilder {
  static Widget buildField({
    required BuildContext context,
    required AppCustomInputField field,
    required bool isDark,
    required Map<String, TextEditingController> controllers,
    required Map<String, dynamic> dynamicValues,
    required void Function(void Function()) setModalState,
    Widget? customWidgetOverride,
  }) {
    if (customWidgetOverride != null) {
      return customWidgetOverride;
    }

    final fieldLabel = '${field.label}${field.isRequired ? ' *' : ''}';

    switch (field.type) {
      case InputFieldType.date:
        final currentDate = dynamicValues[field.id] is DateTime
            ? dynamicValues[field.id] as DateTime
            : DateTime.now();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: currentDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setModalState(() {
                  dynamicValues[field.id] = picked;
                });
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: fieldLabel,
                labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                prefixIcon: const Icon(Icons.calendar_month_outlined, color: kAccent),
              ),
              child: Text(
                DateFormat('dd MMMM yyyy', 'id').format(currentDate),
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white : kTextDark),
              ),
            ),
          ),
        );

      case InputFieldType.dropdown:
      case InputFieldType.select:
        final options = field.options;
        if (options.isNotEmpty) {
          String? selectedValue = dynamicValues[field.id]?.toString();
          if (selectedValue == null || !options.contains(selectedValue)) {
            selectedValue = options.first;
            dynamicValues[field.id] = selectedValue;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              value: selectedValue,
              decoration: InputDecoration(
                labelText: fieldLabel,
                labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                prefixIcon: const Icon(Icons.list_alt_rounded, color: kAccent),
              ),
              items: options.map((opt) => DropdownMenuItem(
                value: opt,
                child: Text(opt, style: TextStyle(color: isDark ? Colors.white : kTextDark)),
              )).toList(),
              onChanged: (val) {
                if (val != null) {
                  setModalState(() {
                    dynamicValues[field.id] = val;
                  });
                }
              },
            ),
          );
        }
        // Fallback jika tidak ada opsi dropdown, render sebagai text field
        controllers.putIfAbsent(field.id, () => TextEditingController(text: dynamicValues[field.id]?.toString() ?? ''));
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: controllers[field.id],
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: fieldLabel,
              hintText: field.placeholder.isNotEmpty ? field.placeholder : null,
              labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              prefixIcon: const Icon(Icons.edit_note_rounded, color: kAccent),
            ),
            onChanged: (val) => dynamicValues[field.id] = val,
          ),
        );

      case InputFieldType.number:
        controllers.putIfAbsent(field.id, () => TextEditingController(text: dynamicValues[field.id]?.toString() ?? ''));
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: controllers[field.id],
            keyboardType: TextInputType.number,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: fieldLabel,
              hintText: field.placeholder.isNotEmpty ? field.placeholder : '0',
              labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              prefixIcon: const Icon(Icons.numbers_rounded, color: kAccent),
            ),
            onChanged: (val) => dynamicValues[field.id] = val,
          ),
        );

      case InputFieldType.file:
        final currentFilePath = dynamicValues[field.id]?.toString() ?? '';
        final hasFile = currentFilePath.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                Icon(hasFile ? Icons.attach_file_rounded : Icons.cloud_upload_outlined, color: kAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(fieldLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
                      const SizedBox(height: 2),
                      Text(
                        hasFile ? currentFilePath.split(Platform.pathSeparator).last : (field.placeholder.isNotEmpty ? field.placeholder : 'Pilih file dokumen/lampiran'),
                        style: TextStyle(fontSize: 13, color: hasFile ? (isDark ? Colors.white : kTextDark) : (isDark ? Colors.white38 : Colors.black38)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      final result = await FilePicker.pickFiles();
                      if (result != null && result.files.isNotEmpty) {
                        final path = result.files.first.path;
                        if (path != null) {
                          setModalState(() {
                            dynamicValues[field.id] = path;
                          });
                        }
                      }
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: Text(hasFile ? 'Ganti' : 'Pilih'),
                  style: TextButton.styleFrom(
                    foregroundColor: kAccent,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                if (hasFile)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                    onPressed: () {
                      setModalState(() {
                        dynamicValues[field.id] = '';
                      });
                    },
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        );

      case InputFieldType.text:
        controllers.putIfAbsent(field.id, () => TextEditingController(text: dynamicValues[field.id]?.toString() ?? ''));
        final isMultiline = field.id.contains('desk') || field.id.contains('hasil') || field.id.contains('eval') || field.id.contains('ket');

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: controllers[field.id],
            maxLines: isMultiline ? 3 : 1,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: fieldLabel,
              hintText: field.placeholder.isNotEmpty ? field.placeholder : null,
              labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              prefixIcon: Icon(
                isMultiline ? Icons.description_outlined : Icons.text_fields_rounded,
                color: kAccent,
              ),
            ),
            onChanged: (val) => dynamicValues[field.id] = val,
          ),
        );
    }
  }
}
