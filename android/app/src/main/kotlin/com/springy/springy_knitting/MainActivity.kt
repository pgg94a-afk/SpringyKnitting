package com.springy.springy_knitting

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.webkit.WebView

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // WebView 디버깅 활성화 (개발 중에만)
        WebView.setWebContentsDebuggingEnabled(true)
    }
}
