# ERSync Front App

ERSync 구급대원용 모바일 애플리케이션입니다. 응급환자 이송 과정에서
구급대원과 응급의료기관을 연결하는 서비스를 Flutter로 개발합니다.

## 지원 플랫폼

- Android
- iOS

## 현재 구현 범위

- ERSync 브랜드 및 공통 색상 테마
- 로그인 화면
  - 아이디와 비밀번호 입력
  - 비밀번호 표시/숨김
  - 가입 코드 화면 진입 버튼
- 위젯 테스트

로그인과 가입 코드는 현재 UI 및 목 테스트 단계이며, 실제 인증 API는
백엔드 API 명세가 확정된 후 연결합니다.

## 프로젝트 구조

```text
lib/
├── core/
│   ├── assets/       # 이미지 등 공통 에셋 경로
│   └── theme/        # 색상과 앱 테마
├── features/
│   └── auth/
│       └── presentation/
│           ├── pages/
│           └── widgets/
├── app.dart
└── main.dart
```

## 실행 방법

Flutter 개발 환경을 준비한 뒤 아래 명령어를 실행합니다.

```bash
flutter pub get
flutter run
```

연결된 기기가 여러 개라면 다음 명령어로 확인할 수 있습니다.

```bash
flutter devices
flutter run -d <device-id>
```

## 검사

```bash
flutter analyze
flutter test
```
