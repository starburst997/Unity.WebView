// Based on https://github.com/gree/unity-webview
using System;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;

using UnityEngine;
using UnityEngine.Networking;

#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
using System.IO;
using System.Text.RegularExpressions;
using UnityEngine.Rendering;
#endif

using Callback = System.Action<string>;

#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
public class UnitySendMessageDispatcher
{
    public static void Dispatch(string name, string method, string message)
    {
        GameObject obj = GameObject.Find(name);
        if (obj != null)
            obj.SendMessage(method, message);
    }
}
#endif

public class WebViewMac : MonoBehaviour
{
    Callback onJS;
    Callback onError;
    Callback onTerminate;
    Callback onURLChange;
    Callback onHttpError;
    Callback onStarted;
    Callback onLoaded;
    Callback onHooked;
    bool visibility;
    bool alertDialogEnabled;
    bool scrollBounceEnabled;
    int mMarginLeft;
    int mMarginTop;
    int mMarginRight;
    int mMarginBottom;
    bool mMarginRelative;
    float mMarginLeftComputed;
    float mMarginTopComputed;
    float mMarginRightComputed;
    float mMarginBottomComputed;
    bool mMarginRelativeComputed;
    
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
    IntPtr webView;
#endif

    public bool IsKeyboardVisible
    {
        get
        {
            return false;
        }
    }

#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
    [DllImport("WebView")]
    private static extern string _CWebViewPlugin_GetAppPath();
    [DllImport("WebView")]
    private static extern IntPtr _CWebViewPlugin_InitStatic(bool inEditor, bool useMetal);
    [DllImport("WebView")]
    private static extern IntPtr _CWebViewPlugin_Init(string gameObject, bool transparent, int width, int height, string ua);
    [DllImport("WebView")]
    private static extern int _CWebViewPlugin_Destroy(IntPtr instance);
    [DllImport("WebView")]
    private static extern void _CWebViewPlugin_SetRect(IntPtr instance, int x, int y, int width, int height);
    [DllImport("WebView")]
    private static extern void _CWebViewPlugin_SetVisibility(IntPtr instance, bool visibility);
    [DllImport("WebView")]
    private static extern bool _CWebViewPlugin_SetURLPattern(IntPtr instance, string allowPattern, string denyPattern, string hookPattern);
    [DllImport("WebView")]
    private static extern void _CWebViewPlugin_LoadURL(IntPtr instance, string url);
    [DllImport("WebView")]
    private static extern void _CWebViewPlugin_LoadHTML(IntPtr instance, string html, string baseUrl);
    [DllImport("WebView")]
    private static extern void _CWebViewPlugin_EvaluateJS(IntPtr instance, string url);
    [DllImport("WebView")]
    private static extern int _CWebViewPlugin_Progress(IntPtr instance);
    [DllImport("WebView")]
    private static extern float _CWebViewPlugin_ScaleFactor(IntPtr instance);
    [DllImport("WebView")]
    private static extern float _CWebViewPlugin_SetCursor(IntPtr instance, int cursor);
    [DllImport("WebView")]
    private static extern bool _CWebViewPlugin_CanGoBack(IntPtr instance);
    [DllImport("WebView")]
    private static extern bool _CWebViewPlugin_CanGoForward(IntPtr instance);
    [DllImport("WebView")]
    private static extern void _CWebViewPlugin_GoBack(IntPtr instance);
    [DllImport("WebView")]
    private static extern void _CWebViewPlugin_GoForward(IntPtr instance);
    [DllImport("WebView")]
    private static extern void _CWebViewPlugin_Reload(IntPtr instance);
    [DllImport("WebView")]
    private static extern void _CWebViewPlugin_ReloadURL(IntPtr instance);
    [DllImport("WebView")]
    private static extern void _CWebViewPlugin_OpaqueBackground(IntPtr instance);
    [DllImport("WebView")]
    private static extern void _CWebViewPlugin_TransparentBackground(IntPtr instance);
    [DllImport("WebView")]
    private static extern void _CWebViewPlugin_AddCustomHeader(IntPtr instance, string headerKey, string headerValue);
    [DllImport("WebView")]
    private static extern string _CWebViewPlugin_GetCustomHeaderValue(IntPtr instance, string headerKey);
    [DllImport("WebView")]
    private static extern void _CWebViewPlugin_RemoveCustomHeader(IntPtr instance, string headerKey);
    [DllImport("WebView")]
    private static extern void _CWebViewPlugin_ClearCustomHeader(IntPtr instance);
    [DllImport("WebView")]
    private static extern string _CWebViewPlugin_GetMessage(IntPtr instance);
#endif

    public static bool IsWebViewAvailable()
    {
        return true;
    }

    public void Init(
        Callback cb = null,
        bool transparent = false,
        string ua = "",
        Callback err = null,
        Callback httpErr = null,
        Callback ld = null,
        bool enableWKWebView = false,
        int  wkContentMode = 0,  // 0: recommended, 1: mobile, 2: desktop
        Callback started = null,
        Callback hooked = null
    )
    {
        onJS = cb;
        onError = err;
        onHttpError = httpErr;
        onStarted = started;
        onLoaded = ld;
        onHooked = hooked;
        
#if (UNITY_STANDALONE_OSX && !UNITY_EDITOR_WIN) || UNITY_EDITOR_OSX
        _CWebViewPlugin_InitStatic(
            Application.platform == RuntimePlatform.OSXEditor,
            SystemInfo.graphicsDeviceType == GraphicsDeviceType.Metal);

        webView = _CWebViewPlugin_Init(
            name,
            transparent,
            Screen.width,
            Screen.height,
            ua
        );

        // Is that really necessary?
        // define pseudo requestAnimationFrame.
        /*EvaluateJS(@"(function() {
            var vsync = 1000 / 60;
            var t0 = window.performance.now();
            window.requestAnimationFrame = function(callback, element) {
                var t1 = window.performance.now();
                var duration = t1 - t0;
                var d = vsync - ((duration > vsync) ? duration % vsync : duration);
                var id = window.setTimeout(function() {t0 = window.performance.now(); callback(t1 + d);}, d);
                return id;
            };
        })()");*/
#endif
    }

    protected virtual void OnDestroy()
    {
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_Destroy(webView);
        webView = IntPtr.Zero;
#endif
    }

    // Use this function instead of SetMargins to easily set up a centered window
    // NOTE: for historical reasons, `center` means the lower left corner and positive y values extend up.
    public void SetCenterPositionWithScale(Vector2 center, Vector2 scale)
    {
        float left = (Screen.width - scale.x) / 2.0f + center.x;
        float right = Screen.width - (left + scale.x);
        float bottom = (Screen.height - scale.y) / 2.0f + center.y;
        float top = Screen.height - (bottom + scale.y);
        SetMargins((int)left, (int)top, (int)right, (int)bottom);
    }

    public void SetHeight(int height)
    {
        // TODO: Unsupported
    }

    public int GetStatusBarHeight()
    {
        return 0;
    }

    public void SetMargins(int left, int top, int right, int bottom, bool relative = false)
    {
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        if (webView == IntPtr.Zero)
            return;
#endif

        mMarginLeft = left;
        mMarginTop = top;
        mMarginRight = right;
        mMarginBottom = bottom;
        mMarginRelative = relative;
        float ml = 0, mt = 0, mr = 0, mb = 0;
        
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        ml = left;
        mt = top;
        mr = right;
        mb = bottom;
#endif
        
        bool r = relative;

        if (ml == mMarginLeftComputed
            && mt == mMarginTopComputed
            && mr == mMarginRightComputed
            && mb == mMarginBottomComputed
            && r == mMarginRelativeComputed)
        {
            return;
        }
        
        mMarginLeftComputed = ml;
        mMarginTopComputed = mt;
        mMarginRightComputed = mr;
        mMarginBottomComputed = mb;
        mMarginRelativeComputed = r;

#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        var factor = ScaleFactor();
        
        int x = (int) ml;
        int y = (int) mb;
        int width = (int)(Screen.width - (ml + mr));
        int height = (int)(Screen.height - (mb + mt));
        
        // TODO: Move scale factor to native side?
        _CWebViewPlugin_SetRect(webView, (int) (x / factor), (int) (y / factor), (int) (width / factor), (int) (height / factor));
#endif
    }

    public void SetVisibilitySoft(bool v)
    {
        SetVisibility(v);
    }

    public void SetVisibility(bool v)
    {
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_SetVisibility(webView, v);
#endif
        
        visibility = v;
    }

    public bool GetVisibility()
    {
        return visibility;
    }

    public void SetAlertDialogEnabled(bool e)
    {
        alertDialogEnabled = e;
    }

    public bool GetAlertDialogEnabled()
    {
        return alertDialogEnabled;
    }

    public void SetScrollBounceEnabled(bool e)
    {
        scrollBounceEnabled = e;
    }

    public bool GetScrollBounceEnabled()
    {
        return scrollBounceEnabled;
    }

    public bool SetURLPattern(string allowPattern, string denyPattern, string hookPattern)
    {
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        if (webView == IntPtr.Zero)
            return false;
        return _CWebViewPlugin_SetURLPattern(webView, allowPattern, denyPattern, hookPattern);
#endif

        return false;
    }

    public void LoadURL(string url)
    {
        if (string.IsNullOrEmpty(url))
            return;
        
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_LoadURL(webView, url);
#endif
    }

    public void LoadHTML(string html, string baseUrl)
    {
        if (string.IsNullOrEmpty(html))
            return;
        if (string.IsNullOrEmpty(baseUrl))
            baseUrl = "";
        
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_LoadHTML(webView, html, baseUrl);
#endif
    }

    public void EvaluateJS(string js)
    {
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_EvaluateJS(webView, js);
#endif
    }

    public int Progress()
    {
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        if (webView == IntPtr.Zero)
            return 0;
        return _CWebViewPlugin_Progress(webView);
#endif
        
        return 100;
    }
    
    public float ScaleFactor()
    {
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        if (webView == IntPtr.Zero)
            return 1;
        return _CWebViewPlugin_ScaleFactor(webView);
#endif
        
        return 1;
    }

    public void SetCursor(int cursor)
    {
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_SetCursor(webView, cursor);
#endif
    }
    
    public bool CanGoBack()
    {
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        if (webView == IntPtr.Zero)
            return false;
        return _CWebViewPlugin_CanGoBack(webView);
#endif
        
        return false;
    }

    public bool CanGoForward()
    {
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        if (webView == IntPtr.Zero)
            return false;
        return _CWebViewPlugin_CanGoForward(webView);
#endif
        
        return false;
    }

    public void GoBack()
    {
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_GoBack(webView);
#endif
    }

    public void GoForward()
    {
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_GoForward(webView);
#endif
    }

    public void CheckScrollbar()
    {
        // TODO: Not implemented
    }
    
    public void OpaqueBackground()
    {
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_OpaqueBackground(webView);
#endif
    }
    
    public void TransparentBackground()
    {
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_TransparentBackground(webView);
#endif
    }

    public void Reload()
    {
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_Reload(webView);
#endif
    }
    
    public void ReloadURL()
    {
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_ReloadURL(webView);
#endif
    }

    public void CallOnTerminate(string error)
    {
        if (onTerminate != null)
        {
            onTerminate(error);
        }
    }
    
    public void CallOnURLChange(string url)
    {
        if (onURLChange != null)
        {
            onURLChange(url);
        }
    }
    
    public void SetOnTerminate(Callback handler)
    {
        onTerminate = handler;
    }
    
    public void SetOnURLChange(Callback handler)
    {
        onURLChange = handler;
    }
    
    public void CallOnError(string error)
    {
        if (onError != null)
            onError(error);
    }

    public void CallOnHttpError(string error)
    {
        if (onHttpError != null)
            onHttpError(error);
    }

    public void CallOnStarted(string url)
    {
        if (onStarted != null)
            onStarted(url);
    }

    public void CallOnLoaded(string url)
    {
        if (onLoaded != null)
            onLoaded(url);
    }

    public void CallFromJS(string message)
    {
        if (onJS != null)
        {
            //message = UnityWebRequest.UnEscapeURL(message);
            onJS(message);
        }
    }

    public void CallOnHooked(string message)
    {
        if (onHooked != null)
        {
            //message = UnityWebRequest.UnEscapeURL(message);
            onHooked(message);
        }
    }

    public void AddCustomHeader(string headerKey, string headerValue)
    {
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_AddCustomHeader(webView, headerKey, headerValue);
#endif
    }

    public string GetCustomHeaderValue(string headerKey)
    {
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        if (webView == IntPtr.Zero)
            return null;
        return _CWebViewPlugin_GetCustomHeaderValue(webView, headerKey);  
#endif
        
        return "";
    }

    public void RemoveCustomHeader(string headerKey)
    {
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_RemoveCustomHeader(webView, headerKey);
#endif
    }

    public void ClearCustomHeader()
    {
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_ClearCustomHeader(webView);
#endif
    }

    public void ClearCookies()
    {
        // Unsupported?
    }

    public void SaveCookies()
    {
        // Unsupported?
    }

    public string GetCookies(string url)
    {
        // Unsupported
        return "";
    }

    public void SetBasicAuthInfo(string userName, string password)
    {
        // Unsupported
    }

    public void ClearCache(bool includeDiskFiles)
    {
        // Unsupported
    }
    
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
    void Update()
    {
        while (true)
        {
            if (webView == IntPtr.Zero)
                break;

            string s = _CWebViewPlugin_GetMessage(webView);
            if (s == null)
                break;

            switch (s[0]) 
            {
                case 'E':
                    CallOnError(s.Substring(1));
                    break;
                case 'S':
                    CallOnStarted(s.Substring(1));
                    break;
                case 'L':
                    CallOnLoaded(s.Substring(1));
                    break;
                case 'J':
                    CallFromJS(s.Substring(1));
                    break;
                case 'H':
                    CallOnHooked(s.Substring(1));
                    break;
                case 'U':
                    CallOnURLChange(s.Substring(1));
                    break;
                case 'T':
                    CallOnTerminate("");
                    break;
            }
        }

        if (webView == IntPtr.Zero || !visibility)
            return;
    }
#endif
}
