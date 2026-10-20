import 'package:finance_track/person_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _field = Color(0xFF2C2C2E);
const _lime = Color(0xFFC8F57A);
const _ink = Color(0xFF17310C);

class PersonEditScreen extends StatefulWidget {
  const PersonEditScreen({super.key, required this.profile});

  final PersonProfile profile;

  @override
  State<PersonEditScreen> createState() => _PersonEditScreenState();
}

class _PersonEditScreenState extends State<PersonEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _salary;
  late var _working = widget.profile.working;
  late int? _payday = widget.profile.payday;
  late DateTime _started;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _name = TextEditingController(text: profile.name);
    _age = TextEditingController(text: profile.age?.toString() ?? '');
    _salary = TextEditingController(text: profile.salaryRupees?.toString() ?? '');
    _started = DateTime.tryParse(profile.startedOn ?? '') ?? DateTime.now();
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _salary.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final age = int.tryParse(_age.text.trim());
    if (_age.text.trim().isNotEmpty && (age == null || age < 1 || age > 120)) {
      _say('Enter an age from 1 to 120');
      return;
    }
    final salaryText = _salary.text.replaceAll(',', '').trim();
    final salary = int.tryParse(salaryText);
    if (_working && salaryText.isNotEmpty && (salary == null || salary < 1)) {
      _say('Enter the monthly salary in rupees');
      return;
    }
    setState(() => _saving = true);
    await PersonProfile(
      name: _name.text.trim(),
      age: age,
      working: _working,
      salaryRupees: _working && salary != null && salary > 0 ? salary : null,
      payday: _working ? _payday : null,
      startedOn:
          '${_started.year}-${_started.month.toString().padLeft(2, '0')}-${_started.day.toString().padLeft(2, '0')}',
    ).save();
    if (mounted) Navigator.of(context).pop();
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _box(label: 'Name', child: _input(_name, 'Your name')),
          const SizedBox(height: 14),
          _box(
            label: 'Since started',
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _started,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _started = picked);
              },
              child: InputDecorator(
                decoration: _decoration('The day you started'),
                child: Text(
                  formatStarted(
                    '${_started.year}-${_started.month.toString().padLeft(2, '0')}-${_started.day.toString().padLeft(2, '0')}',
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _box(
            label: 'Age',
            child: _input(_age, 'Age', digits: true),
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _working,
            onChanged: (value) => setState(() => _working = value),
            title: const Text('Working', style: TextStyle(color: Colors.white)),
            subtitle: Text(
              _working ? 'You have a monthly salary' : 'Not working right now',
              style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
            ),
            activeThumbColor: _ink,
            activeTrackColor: _lime,
          ),
          if (_working) ...[
            const SizedBox(height: 8),
            _box(
              label: 'Monthly salary',
              child: _input(_salary, 'Amount in rupees', digits: true),
            ),
            const SizedBox(height: 14),
            _box(
              label: 'Date you get it',
              child: DropdownButtonFormField<int>(
                initialValue: _payday,
                dropdownColor: _field,
                decoration: _decoration('Day of the month'),
                items: [
                  for (var day = 1; day <= 31; day++)
                    DropdownMenuItem(value: day, child: Text(paydayLabel(day))),
                ],
                onChanged: (day) => setState(() => _payday = day),
              ),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: _lime,
                foregroundColor: _ink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(_saving ? 'Saving' : 'Save'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _box({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _input(TextEditingController controller, String hint, {bool digits = false}) {
    return TextField(
      controller: controller,
      keyboardType: digits ? TextInputType.number : TextInputType.name,
      inputFormatters: digits ? [FilteringTextInputFormatter.digitsOnly] : null,
      style: const TextStyle(color: Colors.white),
      decoration: _decoration(hint),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
      filled: true,
      fillColor: _field,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );
  }
}
