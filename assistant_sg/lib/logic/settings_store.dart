import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/poker_models.dart';

class SettingsStore {
  static const _kSettings = "assistant_sg_settings_v2";
  static const _kProfiles = "assistant_sg_profiles_v1";

  static Future<AppSettings> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kSettings);
    if (raw == null) return AppSettings.defaults();

    try {
      final m = json.decode(raw) as Map<String, dynamic>;
      return AppSettings.fromJson(m);
    } catch (_) {
      return AppSettings.defaults();
    }
  }

  static Future<void> save(AppSettings s) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kSettings, json.encode(s.toJson()));
  }

  // ---------- PROFILES ----------
  static Future<List<StyleProfile>> loadProfiles() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kProfiles);
    if (raw == null) return <StyleProfile>[];

    try {
      final list = (json.decode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(StyleProfile.fromJson).toList();
    } catch (_) {
      return <StyleProfile>[];
    }
  }

  static Future<void> saveProfiles(List<StyleProfile> profiles) async {
    final sp = await SharedPreferences.getInstance();
    final list = profiles.map((p) => p.toJson()).toList();
    await sp.setString(_kProfiles, json.encode(list));
  }

  static StyleProfile styleFromSettings(AppSettings s, String name) {
    return StyleProfile(
      name: name,
      preset: s.preset,
      openRaisePctByPos: List<double>.from(s.openRaisePctByPos),
      callBufferEarly: s.callBufferEarly,
      callBufferLate: s.callBufferLate,
      preflopRaiseEqBase: s.preflopRaiseEqBase,
      preflopRaiseEqPerOpp: s.preflopRaiseEqPerOpp,
      preflopCallEqBase: s.preflopCallEqBase,
      preflopCallEqPerOpp: s.preflopCallEqPerOpp,
      postflopNoBetRaiseEq: s.postflopNoBetRaiseEq,
      postflopNoBetCallEq: s.postflopNoBetCallEq,
    );
  }

  static AppSettings applyStyleToSettings(AppSettings s, StyleProfile p) {
    return s.copyWith(
      preset: p.preset,
      openRaisePctByPos: List<double>.from(p.openRaisePctByPos),
      callBufferEarly: p.callBufferEarly,
      callBufferLate: p.callBufferLate,
      preflopRaiseEqBase: p.preflopRaiseEqBase,
      preflopRaiseEqPerOpp: p.preflopRaiseEqPerOpp,
      preflopCallEqBase: p.preflopCallEqBase,
      preflopCallEqPerOpp: p.preflopCallEqPerOpp,
      postflopNoBetRaiseEq: p.postflopNoBetRaiseEq,
      postflopNoBetCallEq: p.postflopNoBetCallEq,
    );
  }

  static Future<void> upsertProfile(String name, AppSettings s) async {
    final profiles = await loadProfiles();
    final idx = profiles.indexWhere((p) => p.name.toLowerCase() == name.toLowerCase());
    final newP = styleFromSettings(s, name);

    if (idx >= 0) {
      profiles[idx] = newP;
    } else {
      profiles.add(newP);
    }
    await saveProfiles(profiles);
  }
}
