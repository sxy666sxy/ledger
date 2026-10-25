package com.xingkong.ledger;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.util.Base64;
import android.view.View;
import android.view.Window;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;

import java.io.OutputStream;

/**
 * 星空记账 · Android 壳
 * 使用 WebView 加载 assets/index.html（由 build.mjs 生成的自包含单文件），
 * 数据保存在本应用 WebView 的 localStorage 中，不申请网络权限。
 */
public class MainActivity extends Activity {
    private static final int REQ_FILE = 1001;
    private static final int REQ_SAVE = 1002;

    private WebView webView;
    private ValueCallback<Uri[]> fileCallback;
    private String pendingBase64;
    private String pendingName;
    private String pendingMime;

    @SuppressLint({"SetJavaScriptEnabled", "AddJavascriptInterface"})
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        try {
            Window window = getWindow();
            window.setStatusBarColor(Color.TRANSPARENT);
            window.setNavigationBarColor(Color.TRANSPARENT);
            // 全面屏：只使用各版本都存在的旧 UI flag；API 30+ 用反射，避免类校验崩溃。
            int uiFlags = View.SYSTEM_UI_FLAG_LAYOUT_STABLE |
                          View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN |
                          View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION |
                          View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                uiFlags |= View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR;
            }
            window.getDecorView().setSystemUiVisibility(uiFlags);
            if (Build.VERSION.SDK_INT >= 30) {
                try {
                    java.lang.reflect.Method m = Window.class.getMethod("setDecorFitsSystemWindows", boolean.class);
                    m.invoke(window, false);
                } catch (Throwable ignored) { }
            }
        } catch (Throwable ignored) { }

        webView = new WebView(this);
        webView.setBackgroundColor(Color.TRANSPARENT);
        webView.setVerticalScrollBarEnabled(false);
        webView.setHorizontalScrollBarEnabled(false);
        setContentView(webView);

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);
        settings.setLoadWithOverviewMode(true);
        settings.setUseWideViewPort(true);
        settings.setSupportZoom(false);
        settings.setBuiltInZoomControls(false);
        settings.setDisplayZoomControls(false);
        settings.setMediaPlaybackRequiresUserGesture(true);
        settings.setCacheMode(WebSettings.LOAD_DEFAULT);
        settings.setTextZoom(100);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        }

        webView.addJavascriptInterface(new NativeBridge(), "AndroidBridge");

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                return openExternal(request.getUrl());
            }

            @Override
            @SuppressWarnings("deprecation")
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                return openExternal(Uri.parse(url));
            }
        });

        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback, FileChooserParams params) {
                if (fileCallback != null) {
                    fileCallback.onReceiveValue(null);
                }
                fileCallback = callback;
                try {
                    Intent intent = new Intent(Intent.ACTION_GET_CONTENT);
                    intent.addCategory(Intent.CATEGORY_OPENABLE);
                    intent.setType("*/*");
                    startActivityForResult(Intent.createChooser(intent, "选择备份文件"), REQ_FILE);
                    return true;
                } catch (Exception e) {
                    fileCallback = null;
                    return false;
                }
            }
        });

        webView.loadUrl("file:///android_asset/index.html");
    }

    private boolean openExternal(Uri uri) {
        if (uri == null) return true;
        String scheme = uri.getScheme();
        if ("file".equals(scheme) || "about".equals(scheme) || "data".equals(scheme) || "javascript".equals(scheme)) {
            return false;
        }
        try {
            startActivity(new Intent(Intent.ACTION_VIEW, uri));
        } catch (Exception ignored) {
        }
        return true;
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == REQ_FILE) {
            Uri[] result = null;
            if (resultCode == RESULT_OK && data != null && data.getData() != null) {
                result = new Uri[]{data.getData()};
            }
            if (fileCallback != null) {
                fileCallback.onReceiveValue(result);
                fileCallback = null;
            }
            return;
        }

        if (requestCode == REQ_SAVE) {
            if (resultCode == RESULT_OK && data != null && data.getData() != null) {
                writePendingFile(data.getData());
            } else {
                toast("已取消保存");
            }
            pendingBase64 = null;
            pendingName = null;
            return;
        }

        super.onActivityResult(requestCode, resultCode, data);
    }

    private void writePendingFile(Uri uri) {
        if (pendingBase64 == null) return;
        try (OutputStream out = getContentResolver().openOutputStream(uri)) {
            if (out == null) throw new IllegalStateException("无法打开输出文件");
            out.write(Base64.decode(pendingBase64, Base64.DEFAULT));
            out.flush();
            toast("已保存：" + (pendingName == null ? "文件" : pendingName));
        } catch (Exception e) {
            toast("保存失败：" + e.getMessage());
        }
    }

    private void toast(final String message) {
        runOnUiThread(() -> Toast.makeText(MainActivity.this, message, Toast.LENGTH_SHORT).show());
    }

    public class NativeBridge {
        /**
         * 由网页端 download() 调用，通过系统文件选择器保存 JSON / CSV。
         */
        @JavascriptInterface
        public void saveFile(String filename, String base64, String mime) {
            pendingBase64 = base64;
            pendingName = filename;
            pendingMime = mime;
            runOnUiThread(() -> {
                Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                intent.setType(pendingMime != null && pendingMime.length() > 0 ? pendingMime : "application/octet-stream");
                intent.putExtra(Intent.EXTRA_TITLE, filename);
                try {
                    startActivityForResult(intent, REQ_SAVE);
                } catch (Exception e) {
                    pendingBase64 = null;
                    toast("无法打开保存窗口");
                }
            });
        }

        @JavascriptInterface
        public void setSystemBars(final boolean dark) {
            runOnUiThread(() -> {
                try {
                Window window = getWindow();
                int flags = window.getDecorView().getSystemUiVisibility();
                flags &= ~(View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR | View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR);
                if (!dark) {
                    flags |= View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        flags |= View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR;
                    }
                }
                flags |= View.SYSTEM_UI_FLAG_LAYOUT_STABLE |
                         View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN |
                         View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION;
                window.getDecorView().setSystemUiVisibility(flags);
                } catch (Throwable ignored) { }
            });
        }

        @JavascriptInterface
        public int getStatusBarHeight() {
            int id = getResources().getIdentifier("status_bar_height", "dimen", "android");
            return id > 0 ? getResources().getDimensionPixelSize(id) : 0;
        }

        @JavascriptInterface
        public int getNavigationBarHeight() {
            int id = getResources().getIdentifier("navigation_bar_height", "dimen", "android");
            return id > 0 ? getResources().getDimensionPixelSize(id) : 0;
        }
    }

    @Override
    @SuppressWarnings("deprecation")
    public void onBackPressed() {
        if (webView == null) {
            super.onBackPressed();
            return;
        }
        webView.evaluateJavascript(
                "(function(){var r=document.getElementById('overlay-root');" +
                        "if(!r||!r.lastElementChild)return 'no';" +
                        "var b=r.lastElementChild.querySelector('[data-close]');if(b){b.click();return 'yes';}" +
                        "var n=r.lastElementChild.querySelector('[data-no]');if(n){n.click();return 'yes';}" +
                        "return 'no';})()",
                value -> {
                    if (value != null && value.indexOf("yes") >= 0) return;
                    if (webView.canGoBack()) {
                        webView.goBack();
                    } else {
                        finish();
                    }
                });
    }
}
