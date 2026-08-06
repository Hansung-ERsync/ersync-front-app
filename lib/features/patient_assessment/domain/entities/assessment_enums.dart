enum AgeStatus {
  exact('만 나이', 'EXACT'),
  estimated('추정 나이', 'ESTIMATED'),
  unknown('확인 불가', 'UNKNOWN');

  const AgeStatus(this.label, this.apiValue);

  final String label;
  final String apiValue;
}

enum PatientSex {
  male('남성', 'MALE'),
  female('여성', 'FEMALE'),
  unknown('확인 불가', 'UNKNOWN');

  const PatientSex(this.label, this.apiValue);

  final String label;
  final String apiValue;
}

enum OccurrenceType {
  disease('질병', 'DISEASE'),
  nonDisease('비질병·외상', 'NON_DISEASE'),
  other('기타', 'OTHER'),
  unknown('확인 불가', 'UNKNOWN');

  const OccurrenceType(this.label, this.apiValue);

  final String label;
  final String apiValue;
}

enum InjuryMechanism {
  traffic('교통사고', 'TRAFFIC'),
  fall('낙상', 'FALL'),
  fallFromHeight('추락', 'FALL_FROM_HEIGHT'),
  blunt('둔상', 'BLUNT'),
  penetrating('관통상', 'PENETRATING'),
  burn('화상', 'BURN'),
  poisoning('중독', 'POISONING'),
  drowningAsphyxia('익수·질식', 'DROWNING_ASPHYXIA'),
  assaultSelfHarm('폭행·자해', 'ASSAULT_SELF_HARM'),
  machineryAgricultural('기계·농기계', 'MACHINERY_AGRICULTURAL'),
  other('기타', 'OTHER'),
  unknown('확인 불가', 'UNKNOWN');

  const InjuryMechanism(this.label, this.apiValue);

  final String label;
  final String apiValue;
}

enum InjurySite {
  headFace('두부·안면', 'HEAD_FACE'),
  neck('목', 'NECK'),
  chest('흉부', 'CHEST'),
  abdomenPelvis('복부·골반', 'ABDOMEN_PELVIS'),
  spine('척추', 'SPINE'),
  upperLimb('상지', 'UPPER_LIMB'),
  lowerLimb('하지', 'LOWER_LIMB'),
  multiple('다발성', 'MULTIPLE'),
  unknown('확인 불가', 'UNKNOWN');

  const InjurySite(this.label, this.apiValue);

  final String label;
  final String apiValue;
}

enum PatientSymptom {
  alteredConsciousness('의식 변화', 'ALTERED_CONSCIOUSNESS'),
  dyspnea('호흡곤란', 'DYSPNEA'),
  respiratoryArrest('호흡정지', 'RESPIRATORY_ARREST'),
  chestPain('흉통', 'CHEST_PAIN'),
  cardiacArrest('심정지', 'CARDIAC_ARREST'),
  suspectedStroke('뇌졸중 의심', 'SUSPECTED_STROKE'),
  seizureSyncope('경련·실신', 'SEIZURE_SYNCOPE'),
  trauma('외상', 'TRAUMA'),
  bleeding('출혈', 'BLEEDING'),
  gastrointestinal('소화기 증상', 'GASTROINTESTINAL'),
  poisoning('중독', 'POISONING'),
  burn('화상', 'BURN'),
  pregnancyDelivery('임신·분만', 'PREGNANCY_DELIVERY'),
  behavioralSelfHarm('행동·자해', 'BEHAVIORAL_SELF_HARM'),
  feverInfection('발열·감염', 'FEVER_INFECTION'),
  other('기타', 'OTHER'),
  unknown('확인 불가', 'UNKNOWN');

  const PatientSymptom(this.label, this.apiValue);

  final String label;
  final String apiValue;
}

enum ClinicalTimeStatus {
  exact('정확', 'EXACT'),
  estimated('추정', 'ESTIMATED'),
  unknown('확인 불가', 'UNKNOWN');

  const ClinicalTimeStatus(this.label, this.apiValue);

  final String label;
  final String apiValue;
}

enum ClassificationStatus {
  completed('Pre-KTAS 분류 완료', 'COMPLETED'),
  emergencyUnfinished('긴급 전송 예외', 'EMERGENCY_UNFINISHED');

  const ClassificationStatus(this.label, this.apiValue);

  final String label;
  final String apiValue;
}

enum EmergencyExceptionReason {
  cprInProgress('CPR 진행 중', 'CPR_IN_PROGRESS'),
  sceneDanger('현장 위험', 'SCENE_DANGER'),
  insufficientAssessmentTime('평가 시간 부족', 'INSUFFICIENT_ASSESSMENT_TIME'),
  other('기타', 'OTHER');

  const EmergencyExceptionReason(this.label, this.apiValue);

  final String label;
  final String apiValue;
}

enum AvpuLevel {
  alert('명료', 'A'),
  verbal('언어 반응', 'V'),
  pain('통증 반응', 'P'),
  unresponsive('무반응', 'U'),
  unassessable('평가 불가', 'UNASSESSABLE');

  const AvpuLevel(this.label, this.apiValue);

  final String label;
  final String apiValue;
}

enum UnassessableReason {
  sceneDanger('현장 위험', 'SCENE_DANGER'),
  patientInaccessible('환자 접근 불가', 'PATIENT_INACCESSIBLE'),
  other('기타', 'OTHER');

  const UnassessableReason(this.label, this.apiValue);

  final String label;
  final String apiValue;
}

enum VitalType {
  bloodPressure('혈압', 'mmHg', 1),
  pulse('맥박', 'bpm', 1),
  respiratoryRate('호흡수', '/min', 1),
  temperature('체온', '°C', 0.1),
  oxygenSaturation('산소포화도', '%', 1);

  const VitalType(this.label, this.unit, this.step);

  final String label;
  final String unit;
  final double step;
}

enum MeasurementState {
  value('측정값', 'VALUE'),
  unavailable('측정 불가', 'MEASUREMENT_UNAVAILABLE'),
  refused('환자 거부', 'PATIENT_REFUSED');

  const MeasurementState(this.label, this.apiValue);

  final String label;
  final String apiValue;
}

enum MeasurementUnavailableReason {
  patientCondition('환자 상태', 'PATIENT_CONDITION'),
  sceneDanger('현장 위험', 'SCENE_DANGER'),
  injurySite('손상 부위', 'INJURY_SITE'),
  deviceError('장비 오류', 'DEVICE_ERROR'),
  other('기타', 'OTHER');

  const MeasurementUnavailableReason(this.label, this.apiValue);

  final String label;
  final String apiValue;
}

enum TreatmentType {
  none('처치 없음', 'NONE'),
  oxygen('산소 투여', 'OXYGEN'),
  airway('기도 확보', 'AIRWAY'),
  cpr('CPR', 'CPR'),
  defibrillationAed('제세동·AED', 'DEFIBRILLATION_AED'),
  ivFluid('정맥로·수액', 'IV_FLUID'),
  medication('약물 투여', 'MEDICATION'),
  bleedingWound('출혈·상처 처치', 'BLEEDING_WOUND'),
  immobilization('고정', 'IMMOBILIZATION'),
  ecg('심전도', 'ECG'),
  warmingCooling('보온·냉각', 'WARMING_COOLING'),
  delivery('분만 처치', 'DELIVERY'),
  other('기타', 'OTHER');

  const TreatmentType(this.label, this.apiValue);

  final String label;
  final String apiValue;
}

enum TreatmentAttemptResult {
  success('성공', 'SUCCESS'),
  failure('실패', 'FAILURE'),
  ongoing('진행 중', 'ONGOING'),
  notApplicable('해당 없음', 'NOT_APPLICABLE');

  const TreatmentAttemptResult(this.label, this.apiValue);

  final String label;
  final String apiValue;
}

enum PupilResponse {
  normal('정상'),
  sluggish('둔함'),
  fixed('고정'),
  unassessable('확인 불가');

  const PupilResponse(this.label);

  final String label;
}
