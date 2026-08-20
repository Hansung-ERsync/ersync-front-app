class ParamedicProfileInputValidator {
  const ParamedicProfileInputValidator._();

  static final RegExp _controlCharacters = RegExp(
    r'[\u0000-\u001F\u007F-\u009F]',
  );
  static final RegExp _callbackContactPattern = RegExp(
    r'^(?:\+|[0-9])[0-9-]*$',
  );

  static String? displayNameError(String? value) {
    final String displayName = value?.trim() ?? '';
    if (displayName.isEmpty) {
      return '이름을 입력해주세요';
    }
    final int length = displayName.runes.length;
    if (length < 2 || length > 50) {
      return '이름은 2~50자로 입력해주세요';
    }
    if (_controlCharacters.hasMatch(displayName)) {
      return '이름에는 줄바꿈이나 제어문자를 사용할 수 없습니다';
    }
    return null;
  }

  static String? callbackContactError(String? value) {
    final String callbackContact = value?.trim() ?? '';
    if (callbackContact.isEmpty) {
      return '병원 회신 연락처를 입력해주세요';
    }
    final int length = callbackContact.runes.length;
    if (length < 8 || length > 30) {
      return '연락처는 8~30자로 입력해주세요';
    }
    if (!_callbackContactPattern.hasMatch(callbackContact)) {
      return '숫자 또는 +로 시작하고 숫자와 -만 사용해주세요';
    }
    return null;
  }
}
