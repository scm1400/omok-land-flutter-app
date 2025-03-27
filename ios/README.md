# iOS 앱 배포 가이드

이 가이드는 "오목랜드" iOS 앱을 빌드하고 App Store에 배포하는 방법을 설명합니다.

## 사전 준비사항

1. macOS 기반 컴퓨터
2. Xcode 최신 버전
3. Apple Developer Program 계정
4. 코드 서명 및 프로비저닝 프로파일 설정

## iOS 개발 환경 설정

### 1. 필수 도구 설치

```bash
# CocoaPods 설치
sudo gem install cocoapods

# Flutter 환경 설정
flutter pub get
```

### 2. 의존성 설치

```bash
cd ios
pod install
```

## iOS 앱 빌드 및 서명

### 1. 코드 서명 준비

1. Apple Developer Portal에서 App ID 생성
2. 배포 인증서 생성
3. 프로비저닝 프로파일 생성 및 다운로드

### 2. 프로비저닝 프로파일 설정

1. `ExportOptions.plist` 파일에서 다음 부분 수정:
   - `teamID`: 개발자 계정의 Team ID로 변경
   - `provisioningProfiles`: `com.omokland.app`에 대한 프로비저닝 프로파일 이름 확인

### 3. 앱 빌드

#### Flutter 빌드

```bash
flutter build ios --release
```

#### Xcode에서 빌드

1. Xcode에서 `Runner.xcworkspace` 열기
2. 서명 설정 확인 (Signing & Capabilities)
3. Product > Archive 선택
4. Distribute App > App Store Connect 선택
5. 위에서 수정한 `ExportOptions.plist` 파일 사용

## App Store 배포

### 1. App Store Connect 준비

1. App Store Connect에서 새 앱 생성
2. 앱 정보 설정 (이름, 설명, 스크린샷 등)

### 2. TestFlight 배포 (선택사항)

1. 앱 빌드를 TestFlight에 업로드
2. 내부 테스터 및 외부 테스터 설정

### 3. App Store 제출

1. 앱 심사를 위한 정보 제공
2. 심사 제출

## 문제 해결

### 코드 서명 문제

- Xcode에서 자동 코드 서명을 사용하는 경우, 수동 서명으로 변경
- 인증서 및 프로비저닝 프로파일이 올바르게 설치되어 있는지 확인

### 빌드 실패

- `pod install`을 다시 실행하여 의존성 업데이트
- 모든 파일이 올바르게 커밋되었는지 확인

## 주의사항

- `Runner/Info.plist`의 CFBundleIdentifier가 App Store Connect에 등록된 Bundle ID와 일치해야 함
- 앱 심사 시 리젝션을 방지하기 위해 개인정보 보호정책 URL 제공 필요
- 앱 버전 번호(CFBundleShortVersionString)와 빌드 번호(CFBundleVersion)는 이전 버전보다 높아야 함
