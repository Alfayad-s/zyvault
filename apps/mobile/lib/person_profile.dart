import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePhoto {
  ProfilePhoto._();

  static const key = 'profile_photo';
  static final current = ValueNotifier<String?>(null);

  static Future<void> load() async {
    final saved = (await SharedPreferences.getInstance()).getString(key);
    current.value = saved != null && File(saved).existsSync() ? saved : null;
  }

  static Future<void> remember(String path) async {
    await (await SharedPreferences.getInstance()).setString(key, path);
    current.value = path;
  }

  static Future<void> clear() async {
    final path = current.value;
    if (path != null && File(path).existsSync()) await File(path).delete();
    await (await SharedPreferences.getInstance()).remove(key);
    current.value = null;
  }
}

class PersonProfile {
  const PersonProfile({
    this.name = '',
    this.age,
    this.working = false,
    this.salaryRupees,
    this.payday,
    this.startedOn,
  });

  final String name;
  final int? age;
  final bool working;
  final int? salaryRupees;
  final int? payday;
  final String? startedOn;

  static const empty = PersonProfile();
  static final current = ValueNotifier<PersonProfile>(empty);

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    PersonProfile profile = empty;
    final raw = preferences.getString('person_profile');
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) profile = PersonProfile.fromJson(decoded);
      } catch (_) {}
    }
    if (profile.startedOn == null) {
      final today = DateTime.now();
      final month = today.month.toString().padLeft(2, '0');
      final day = today.day.toString().padLeft(2, '0');
      profile = PersonProfile(
        name: profile.name,
        age: profile.age,
        working: profile.working,
        salaryRupees: profile.salaryRupees,
        payday: profile.payday,
        startedOn: '${today.year}-$month-$day',
      );
      await profile.save();
      return;
    }
    current.value = profile;
  }

  Future<void> save() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('person_profile', jsonEncode(toJson()));
    current.value = this;
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'age': age,
    'working': working,
    'salaryRupees': salaryRupees,
    'payday': payday,
    'startedOn': startedOn,
  };

  factory PersonProfile.fromJson(Map<String, dynamic> json) {
    final age = json['age'];
    final salary = json['salaryRupees'];
    final payday = json['payday'];
    final started = json['startedOn'];
    return PersonProfile(
      name: json['name'] as String? ?? '',
      age: age is num ? age.toInt() : null,
      working: json['working'] == true,
      salaryRupees: salary is num ? salary.toInt() : null,
      payday: payday is num && payday >= 1 && payday <= 31 ? payday.toInt() : null,
      startedOn: started is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(started) ? started : null,
    );
  }
}

String formatStarted(String iso) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final parts = iso.split('-');
  if (parts.length != 3) return iso;
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (month == null || day == null || month < 1 || month > 12) return iso;
  return '$day ${months[month - 1]} ${parts[0]}';
}

String paydayLabel(int day) {
  if (day >= 11 && day <= 13) return '${day}th';
  return switch (day % 10) {
    1 => '${day}st',
    2 => '${day}nd',
    3 => '${day}rd',
    _ => '${day}th',
  };
}
