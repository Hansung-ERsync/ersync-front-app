# ERSync Front App

ERSync의 구급대원용 Android/iOS 애플리케이션입니다.

응급환자 이송 과정에서 구급대원이 환자 정보를 빠르게 입력하고,
응급의료기관의 수용 가능 여부를 확인하여 이송 업무를 원활하게 진행할 수
있도록 지원하는 것을 목표로 합니다.

## 프로젝트 소개

ERSync는 구급대와 응급의료기관 사이의 정보 전달 과정을 연결하는
응급 이송 연계 서비스입니다. 이 저장소는 그중 구급대원이 사용하는
Flutter 모바일 앱을 관리합니다.

앱은 다음 기능을 제공합니다.

- 구급대원 계정 로그인
- 가입 코드를 통한 소속 및 권한 확인
- 환자 기본 정보와 증상 입력
- Pre-KTAS 단계 입력
- 주변 응급의료기관 조회
- 병원 수용 가능 여부 확인
- 이송 요청과 진행 상태 확인

## 지원 플랫폼

- Android
- iOS

## 현재 구현 범위

- 공통 색상 및 앱 테마
- ERSync 브랜드 에셋
- 로그인 화면
- 로그인 입력값 검증
- 로그인 위젯 테스트

인증, 환자 정보, Pre-KTAS, 병원 조회 및 이송 기능은 동일한 프로젝트
구조와 기술 스택을 기준으로 구현합니다.

## 가입 및 로그인 흐름

가입 코드는 사용자가 소속을 직접 선택하는 용도가 아니라, 관리자가
발급한 코드를 통해 소속 구급대와 역할을 확인하는 방식으로 구성합니다.

```text
관리자가 소속 및 역할이 연결된 가입 코드 발급
  → 구급대원이 가입 코드 입력
  → 서버에서 코드와 소속 정보 확인
  → 계정 생성
  → 아이디와 비밀번호로 로그인
```

## 기술 스택

| 구분 | 기술 |
| --- | --- |
| 애플리케이션 | Flutter |
| 언어 | Dart `^3.10.8` |
| UI | Material Design |
| 아키텍처 | Feature-first Clean Architecture |
| 상태 관리 및 의존성 주입 | Riverpod |
| 화면 이동 | go_router |
| REST API 통신 | Dio |
| 데이터 모델 | freezed, json_serializable |
| 인증 정보 저장 | flutter_secure_storage |
| 일반 설정 저장 | shared_preferences |
| Android | Kotlin, Gradle Kotlin DSL, Java 17 |
| iOS | Swift, Xcode |
| 테스트 | flutter_test, mocktail, integration_test |
| 코드 품질 | `flutter_lints` |
| 형상 관리 | Git, GitHub |

## 프로젝트 구조 원칙

- 기능 단위로 코드를 분리하는 Feature-first 구조를 사용합니다.
- 각 기능은 `data`, `domain`, `presentation` 계층으로 구분합니다.
- `domain`은 Flutter와 외부 패키지에 의존하지 않는 비즈니스 규칙을
  담당합니다.
- `data`는 API 통신, DTO, 데이터 변환과 저장소 구현을 담당합니다.
- `presentation`은 화면, 위젯과 Riverpod 상태를 담당합니다.
- 두 개 이상의 기능에서 사용하는 코드는 `core`에서 관리합니다.
- 기능 간 구현을 직접 참조하지 않고 domain 인터페이스를 통해 연결합니다.

## 프로젝트 폴더 구조

프로젝트는 아래 구조를 기준으로 구성합니다.

```text
ersync-front-app/
├── android/                         # Android 빌드 및 네이티브 설정
├── assets/
│   ├── fonts/                       # 앱 폰트
│   ├── icons/                       # 아이콘 에셋
│   └── images/                      # 로고와 이미지 에셋
├── ios/                             # iOS 빌드 및 네이티브 설정
├── lib/
│   ├── core/
│   │   ├── config/                  # 실행 환경 및 앱 설정
│   │   ├── constants/               # 공통 상수
│   │   ├── error/                   # 예외와 실패 모델
│   │   ├── network/                 # Dio 클라이언트와 인터셉터
│   │   ├── routing/                 # go_router 라우팅
│   │   ├── storage/                 # 토큰 및 로컬 설정 저장
│   │   ├── assets/                  # 공통 에셋 경로
│   │   ├── theme/                   # 색상, 타이포그래피와 앱 테마
│   │   ├── utils/                   # 공통 유틸리티
│   │   └── widgets/                 # 공통 UI 컴포넌트
│   ├── features/
│   │   ├── auth/                    # 가입 코드 및 인증
│   │   ├── home/                    # 구급대원 홈
│   │   ├── patient/                 # 환자 정보 등록
│   │   ├── triage/                  # Pre-KTAS 분류
│   │   ├── hospital/                # 병원 검색 및 수용 정보
│   │   ├── transport/               # 이송 요청 및 진행 상태
│   │   └── settings/                # 계정 및 앱 설정
│   ├── app.dart                     # 최상위 앱 위젯
│   └── main.dart                    # 앱 진입점
├── test/                            # 단위 및 위젯 테스트
├── integration_test/                # 주요 사용자 흐름 통합 테스트
├── analysis_options.yaml            # Dart 정적 분석 규칙
└── pubspec.yaml                     # 패키지와 에셋 설정
```

모든 기능 폴더는 다음 내부 구조를 사용합니다.

```text
features/<feature>/
├── data/
│   ├── datasources/                 # 원격 API와 로컬 데이터 소스
│   ├── models/                      # JSON DTO 및 변환 모델
│   └── repositories/                # domain 저장소 구현
├── domain/
│   ├── entities/                    # 비즈니스 엔티티
│   ├── repositories/                # 저장소 인터페이스
│   └── usecases/                    # 기능별 비즈니스 로직
└── presentation/
    ├── pages/                       # 화면
    ├── providers/                   # Riverpod 상태 및 컨트롤러
    └── widgets/                     # 기능 전용 위젯
```

## 실행 방법

### 1. 개발 환경 확인

Flutter stable 채널과 Android Studio 또는 Xcode가 필요합니다.
iOS 앱 실행은 macOS 환경에서만 가능합니다.

```bash
flutter doctor
```

표시되는 Android 또는 iOS 개발 환경 문제를 먼저 해결합니다.

### 2. 의존성 설치

프로젝트 루트에서 다음 명령어를 실행합니다.

```bash
flutter pub get
```

### 3. 기기 확인 및 앱 실행

```bash
flutter devices
flutter run -d <device-id>
```

기기가 하나만 연결되어 있다면 다음 명령어로 바로 실행할 수 있습니다.

```bash
flutter run
```

## 코드 검사 및 테스트

커밋하기 전에 다음 명령어를 실행합니다.

```bash
flutter analyze
flutter test
```

코드 포맷이 필요한 경우 다음 명령어를 사용합니다.

```bash
dart format lib test
```


