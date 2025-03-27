import Flutter
import UIKit
import Flutter
import WebKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 웹뷰 관련 초기화
    if #available(iOS 15.0, *) {
        let webViewConfiguration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: webViewConfiguration)
        
        // 모바일 웹뷰로 인식되도록 사용자 에이전트 설정
        let mobileUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"
        webView.customUserAgent = mobileUserAgent
    }
    
    // 메모리 캐시 설정
    URLCache.shared.memoryCapacity = 10 * 1024 * 1024 // 10MB
    URLCache.shared.diskCapacity = 50 * 1024 * 1024 // 50MB
    
    // 플러터 엔진 초기화
    GeneratedPluginRegistrant.register(with: self)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // URL 스킴 처리
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    // URL 스킴 처리 로직 구현
    return super.application(app, open: url, options: options)
  }
  
  // 메모리 부족 경고 처리
  override func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
    // 메모리 정리 작업 수행
    URLCache.shared.removeAllCachedResponses()
    super.applicationDidReceiveMemoryWarning(application)
  }
  
  // 앱 활성화 시 호출
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
  }
  
  // 앱 백그라운드 전환 시 호출
  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
  }
}
