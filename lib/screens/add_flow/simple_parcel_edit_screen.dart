import 'package:flutter/material.dart';
import '../../models/seat_layout.dart';

class SimpleParcelEditScreen extends StatefulWidget {
  final LayoutCell? existing;
  final String serviceType;

  const SimpleParcelEditScreen({
    super.key,
    this.existing,
    this.serviceType = 'parcel',
  });

  @override
  State<SimpleParcelEditScreen> createState() => _SimpleParcelEditScreenState();
}

class _SimpleParcelEditScreenState extends State<SimpleParcelEditScreen> {
  late TextEditingController nameController;
  late TextEditingController lengthController;
  late TextEditingController breadthController;
  late TextEditingController heightController;
  late TextEditingController weightController;
  late TextEditingController priceController;
  late TextEditingController hsCodeController;

  String selectedType = 'Normal';

  @override
  void initState() {
    super.initState();

    // Parse existing data if editing
    String existingName = '';
    String existingLength = '';
    String existingBreadth = '';
    String existingHeight = '';
    String existingWeight = '';
    String existingPrice = '';
    String existingParcelType = 'Normal';
    String existingHSCode = '';

    if (widget.existing != null) {
      existingName = widget.existing!.seatName ?? '';
      existingPrice = widget.existing!.price?.toString() ?? '';

      // Parse dimensions from name format: "name|L:10|B:20|H:30|W:5|T:type|HS:code"
      if (existingName.contains('|')) {
        final parts = existingName.split('|');
        existingName = parts[0];

        for (var part in parts.skip(1)) {
          if (part.startsWith('L:')) existingLength = part.substring(2);
          if (part.startsWith('B:')) existingBreadth = part.substring(2);
          if (part.startsWith('H:')) existingHeight = part.substring(2);
          if (part.startsWith('W:')) existingWeight = part.substring(2);
          if (part.startsWith('T:')) {
            final typeData = part.substring(2);
            if (typeData.contains('|code:')) {
              final split = typeData.split('|code:');
              existingParcelType = split[0].substring(5);
              existingHSCode = split[1];
            } else if (typeData.startsWith('type:')) {
              existingParcelType = typeData.substring(5);
            } else {
              existingParcelType = typeData;
            }
          }
        }
      }
      selectedType = existingParcelType;
    }

    nameController = TextEditingController(text: existingName);
    lengthController = TextEditingController(text: existingLength);
    breadthController = TextEditingController(text: existingBreadth);
    heightController = TextEditingController(text: existingHeight);
    weightController = TextEditingController(text: existingWeight);
    priceController = TextEditingController(text: existingPrice);
    hsCodeController = TextEditingController(text: existingHSCode);
  }

  @override
  void dispose() {
    nameController.dispose();
    lengthController.dispose();
    breadthController.dispose();
    heightController.dispose();
    weightController.dispose();
    priceController.dispose();
    hsCodeController.dispose();
    super.dispose();
  }

  void _save() {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter compartment name')),
      );
      return;
    }

    final length = lengthController.text.trim();
    final breadth = breadthController.text.trim();
    final height = heightController.text.trim();
    final weight = weightController.text.trim();

    // Build final name with dimensions
    String finalName = name;
    if (length.isNotEmpty ||
        breadth.isNotEmpty ||
        height.isNotEmpty ||
        weight.isNotEmpty) {
      final parcelType = selectedType.isNotEmpty ? selectedType : 'Normal';
      final hsCode = hsCodeController.text.trim();

      finalName = '$name|L:$length|B:$breadth|H:$height|W:$weight';
      if (hsCode.isNotEmpty) {
        finalName = '$finalName|T:type:$parcelType|code:$hsCode';
      } else {
        finalName = '$finalName|T:type:$parcelType';
      }
    }

    final price = double.tryParse(priceController.text.trim());

    // Return data
    Navigator.pop(context, {'name': finalName, 'price': price});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Add Compartment' : 'Edit Compartment',
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Compartment Name
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Compartment Name',
              hintText: 'e.g., A1, Box 1',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Price
          TextField(
            controller: priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Price per unit',
              hintText: '100',
              border: OutlineInputBorder(),
              prefixText: '₹ ',
            ),
          ),
          const SizedBox(height: 16),

          // Section: Dimensions
          const Text(
            'Dimensions (cm)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Length, Breadth, Height, Weight in grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _buildDimensionField('Length', lengthController),
              _buildDimensionField('Breadth', breadthController),
              _buildDimensionField('Height', heightController),
              _buildDimensionField('Weight (kg)', weightController),
            ],
          ),
          const SizedBox(height: 16),

          // Section: Classification
          const Text(
            'Classification',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Parcel Type
          DropdownButtonFormField<String>(
            initialValue: selectedType,
            decoration: const InputDecoration(
              labelText: 'Parcel Type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'Normal', child: Text('Normal')),
              DropdownMenuItem(value: 'Fragile', child: Text('Fragile')),
              DropdownMenuItem(value: 'Perishable', child: Text('Perishable')),
              DropdownMenuItem(value: 'Medical', child: Text('Medical')),
              DropdownMenuItem(value: 'Hazardous', child: Text('Hazardous')),
              DropdownMenuItem(
                value: 'Live Animals',
                child: Text('Live Animals'),
              ),
            ],
            onChanged: (value) {
              setState(() => selectedType = value ?? 'Normal');
            },
          ),
          const SizedBox(height: 12),

          // HS Code
          TextField(
            controller: hsCodeController,
            decoration: const InputDecoration(
              labelText: 'HS Code (Optional)',
              hintText: 'e.g., 392310',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}
