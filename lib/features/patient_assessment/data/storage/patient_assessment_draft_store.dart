import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/assessment_enums.dart';
import '../../domain/entities/patient_assessment_draft.dart';

abstract interface class PatientAssessmentDraftStore {
  Future<PatientAssessmentDraft?> read();

  Future<void> write(PatientAssessmentDraft draft);

  Future<void> clear();
}

class SecurePatientAssessmentDraftStore implements PatientAssessmentDraftStore {
  SecurePatientAssessmentDraftStore({
    required String accountId,
    FlutterSecureStorage? storage,
  }) : _key = 'ersync.patient-assessment-draft.$accountId',
       _storage = storage ?? const FlutterSecureStorage();

  final String _key;
  final FlutterSecureStorage _storage;

  @override
  Future<PatientAssessmentDraft?> read() async {
    final String? encoded = await _storage.read(key: _key);
    if (encoded == null) {
      return null;
    }
    try {
      return _decodeDraft(
        Map<String, Object?>.from(jsonDecode(encoded) as Map<dynamic, dynamic>),
      );
    } on Object {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(PatientAssessmentDraft draft) {
    return _storage.write(key: _key, value: jsonEncode(_encodeDraft(draft)));
  }

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class InMemoryPatientAssessmentDraftStore
    implements PatientAssessmentDraftStore {
  PatientAssessmentDraft? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<PatientAssessmentDraft?> read() async => value;

  @override
  Future<void> write(PatientAssessmentDraft draft) async => value = draft;
}

Map<String, Object?> _encodeDraft(PatientAssessmentDraft draft) {
  return <String, Object?>{
    'assessmentProtocolVersion': draft.assessmentProtocolVersion,
    'preKtasStandardVersion': draft.preKtasStandardVersion,
    'clientRequestKey': draft.clientRequestKey,
    'sceneAddress': draft.sceneAddress,
    'latitude': draft.latitude,
    'longitude': draft.longitude,
    'locationSource': draft.locationSource,
    'callbackContact': draft.callbackContact,
    'ageStatus': draft.ageStatus?.name,
    'ageYears': draft.ageYears,
    'sex': draft.sex?.name,
    'occurrenceType': draft.occurrenceType?.name,
    'occurrenceDetail': draft.occurrenceDetail,
    'mechanism': draft.mechanism?.name,
    'injurySites': draft.injurySites
        .map((InjurySite value) => value.name)
        .toList(),
    'primarySymptom': draft.primarySymptom?.name,
    'primarySymptomDetail': draft.primarySymptomDetail,
    'secondarySymptoms': draft.secondarySymptoms
        .map((PatientSymptom value) => value.name)
        .toList(),
    'onsetTimeStatus': draft.onsetTimeStatus?.name,
    'onsetAt': draft.onsetAt?.toIso8601String(),
    'classificationStatus': draft.classificationStatus?.name,
    'preKtasLevel': draft.preKtasLevel,
    'exceptionReason': draft.exceptionReason?.name,
    'exceptionDetail': draft.exceptionDetail,
    'avpu': draft.avpu?.name,
    'unassessableReason': draft.unassessableReason?.name,
    'unassessableDetail': draft.unassessableDetail,
    'assessedAt': draft.assessedAt.toIso8601String(),
    'observedAt': draft.observedAt.toIso8601String(),
    'vitals': <String, Object?>{
      for (final MapEntry<VitalType, VitalReadingDraft> entry
          in draft.vitals.entries)
        entry.key.name: <String, Object?>{
          'state': entry.value.state?.name,
          'value': entry.value.value,
          'secondaryValue': entry.value.secondaryValue,
          'unavailableReason': entry.value.unavailableReason?.name,
          'unavailableReasonDetail': entry.value.unavailableReasonDetail,
        },
    },
    'measuredAt': draft.measuredAt.toIso8601String(),
    'treatments': draft.treatments
        .map((TreatmentType value) => value.name)
        .toList(),
    'treatmentEntries': <String, Object?>{
      for (final MapEntry<TreatmentType, TreatmentEntryDraft> entry
          in draft.treatmentEntries.entries)
        entry.key.name: <String, Object?>{
          'attemptResult': entry.value.attemptResult?.name,
          'details': entry.value.details,
        },
    },
    'performedAt': draft.performedAt.toIso8601String(),
    'glucoseMgDl': draft.glucoseMgDl,
    'leftPupil': draft.leftPupil?.name,
    'rightPupil': draft.rightPupil?.name,
    'medicalHistory': draft.medicalHistory,
    'allergies': draft.allergies,
    'medications': draft.medications,
    'isolationConcern': draft.isolationConcern,
    'enteredAt': draft.enteredAt.toIso8601String(),
  };
}

PatientAssessmentDraft _decodeDraft(Map<String, Object?> json) {
  final Map<String, Object?> rawVitals = _map(json['vitals']);
  final Map<String, Object?> rawTreatmentEntries = _map(
    json['treatmentEntries'],
  );
  return PatientAssessmentDraft(
    assessmentProtocolVersion: _string(json, 'assessmentProtocolVersion'),
    preKtasStandardVersion: _string(json, 'preKtasStandardVersion'),
    clientRequestKey: _string(json, 'clientRequestKey'),
    sceneAddress: _string(json, 'sceneAddress'),
    latitude: _number(json, 'latitude'),
    longitude: _number(json, 'longitude'),
    locationSource: _string(json, 'locationSource'),
    callbackContact: _string(json, 'callbackContact'),
    ageStatus: _enumValue(AgeStatus.values, json['ageStatus']),
    ageYears: (json['ageYears'] as num?)?.toInt(),
    sex: _enumValue(PatientSex.values, json['sex']),
    occurrenceType: _enumValue(OccurrenceType.values, json['occurrenceType']),
    occurrenceDetail: json['occurrenceDetail'] as String? ?? '',
    mechanism: _enumValue(InjuryMechanism.values, json['mechanism']),
    injurySites: _enumSet(InjurySite.values, json['injurySites']),
    primarySymptom: _enumValue(PatientSymptom.values, json['primarySymptom']),
    primarySymptomDetail: json['primarySymptomDetail'] as String? ?? '',
    secondarySymptoms: _enumSet(
      PatientSymptom.values,
      json['secondarySymptoms'],
    ),
    onsetTimeStatus: _enumValue(
      ClinicalTimeStatus.values,
      json['onsetTimeStatus'],
    ),
    onsetAt: _nullableDate(json['onsetAt']),
    classificationStatus: _enumValue(
      ClassificationStatus.values,
      json['classificationStatus'],
    ),
    preKtasLevel: (json['preKtasLevel'] as num?)?.toInt(),
    exceptionReason: _enumValue(
      EmergencyExceptionReason.values,
      json['exceptionReason'],
    ),
    exceptionDetail: json['exceptionDetail'] as String? ?? '',
    avpu: _enumValue(AvpuLevel.values, json['avpu']),
    unassessableReason: _enumValue(
      UnassessableReason.values,
      json['unassessableReason'],
    ),
    unassessableDetail: json['unassessableDetail'] as String? ?? '',
    assessedAt: _date(json, 'assessedAt'),
    observedAt: _date(json, 'observedAt'),
    vitals: <VitalType, VitalReadingDraft>{
      for (final MapEntry<String, Object?> entry in rawVitals.entries)
        _requiredEnumValue(VitalType.values, entry.key): _decodeVital(
          _map(entry.value),
        ),
    },
    measuredAt: _date(json, 'measuredAt'),
    treatments: _enumSet(TreatmentType.values, json['treatments']),
    treatmentEntries: <TreatmentType, TreatmentEntryDraft>{
      for (final MapEntry<String, Object?> entry in rawTreatmentEntries.entries)
        _requiredEnumValue(TreatmentType.values, entry.key):
            _decodeTreatmentEntry(_map(entry.value)),
    },
    performedAt: _date(json, 'performedAt'),
    glucoseMgDl: (json['glucoseMgDl'] as num?)?.toInt(),
    leftPupil: _enumValue(PupilResponse.values, json['leftPupil']),
    rightPupil: _enumValue(PupilResponse.values, json['rightPupil']),
    medicalHistory: json['medicalHistory'] as String? ?? '',
    allergies: json['allergies'] as String? ?? '',
    medications: json['medications'] as String? ?? '',
    isolationConcern: json['isolationConcern'] as bool?,
    enteredAt: _date(json, 'enteredAt'),
  );
}

VitalReadingDraft _decodeVital(Map<String, Object?> json) {
  return VitalReadingDraft(
    state: _enumValue(MeasurementState.values, json['state']),
    value: (json['value'] as num?)?.toDouble(),
    secondaryValue: (json['secondaryValue'] as num?)?.toDouble(),
    unavailableReason: _enumValue(
      MeasurementUnavailableReason.values,
      json['unavailableReason'],
    ),
    unavailableReasonDetail: json['unavailableReasonDetail'] as String? ?? '',
  );
}

TreatmentEntryDraft _decodeTreatmentEntry(Map<String, Object?> json) {
  return TreatmentEntryDraft(
    attemptResult: _enumValue(
      TreatmentAttemptResult.values,
      json['attemptResult'],
    ),
    details: _map(json['details']).map(
      (String key, Object? value) =>
          MapEntry<String, String>(key, value?.toString() ?? ''),
    ),
  );
}

Map<String, Object?> _map(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : const <String, Object?>{};

String _string(Map<String, Object?> json, String key) => json[key] as String;

double _number(Map<String, Object?> json, String key) =>
    (json[key] as num).toDouble();

DateTime _date(Map<String, Object?> json, String key) =>
    DateTime.parse(_string(json, key));

DateTime? _nullableDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

T? _enumValue<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) {
    return null;
  }
  for (final T value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return null;
}

T _requiredEnumValue<T extends Enum>(List<T> values, Object? name) {
  final T? value = _enumValue(values, name);
  if (value == null) {
    throw const FormatException('Unknown enum value');
  }
  return value;
}

Set<T> _enumSet<T extends Enum>(List<T> values, Object? raw) {
  if (raw is! List) {
    return <T>{};
  }
  return raw
      .map((Object? value) => _enumValue(values, value))
      .whereType<T>()
      .toSet();
}
