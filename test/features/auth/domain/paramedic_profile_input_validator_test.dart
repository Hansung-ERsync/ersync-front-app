import 'package:er_sync/features/auth/domain/paramedic_profile_input_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('프로필 이름은 공백 제거 후 2~50자이며 제어문자를 허용하지 않는다', () {
    expect(ParamedicProfileInputValidator.displayNameError(' 김민준 '), isNull);
    expect(ParamedicProfileInputValidator.displayNameError('김'), isNotNull);
    expect(ParamedicProfileInputValidator.displayNameError('김\n민준'), isNotNull);
    expect(
      ParamedicProfileInputValidator.displayNameError('가' * 51),
      isNotNull,
    );
  });

  test('회신 연락처는 회원가입과 같은 010-0000-0000 형식만 허용한다', () {
    expect(
      ParamedicProfileInputValidator.callbackContactError('010-1234-5678'),
      isNull,
    );
    expect(
      ParamedicProfileInputValidator.callbackContactError('+82-10-1234-5678'),
      isNotNull,
    );
    expect(
      ParamedicProfileInputValidator.callbackContactError('02 1234 5678'),
      isNotNull,
    );
    expect(
      ParamedicProfileInputValidator.callbackContactError('contact-1234'),
      isNotNull,
    );
  });
}
