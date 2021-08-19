/*
 * Copyright (C) 2011 Keijiro Takahashi
 * Copyright (C) 2012 GREE, Inc.
 * 
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * 
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 */

using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
#if UNITY_2018_4_OR_NEWER
using UnityEngine.Networking;
#endif
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
using System.IO;
using System.Text.RegularExpressions;
using UnityEngine.Rendering;
#endif

using Callback = System.Action<string>;

public class WebViewObject : MonoBehaviour
{
    Callback onJS;
    Callback onError;
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
#if UNITY_IPHONE
    IntPtr webView;
#elif UNITY_ANDROID
    AndroidJavaObject webView;
    
    bool mVisibility;
    bool mIsKeyboardVisible;
    int mWindowVisibleDisplayFrameHeight;
    float mResumedTimestamp;
    
    void OnApplicationPause(bool paused)
    {
        if (webView == null)
            return;
        if (!paused && mIsKeyboardVisible)
        {
            webView.Call("SetVisibility", false);
            mResumedTimestamp = Time.realtimeSinceStartup;
        }
        webView.Call("OnApplicationPause", paused);
    }

    void Update()
    {
        if (webView == null)
            return;
        if (mResumedTimestamp != 0.0f && Time.realtimeSinceStartup - mResumedTimestamp > 0.5f)
        {
            mResumedTimestamp = 0.0f;
            webView.Call("SetVisibility", mVisibility);
        }
    }

    /// Called from Java native plugin to set when the keyboard is opened
    public void SetKeyboardVisible(string pIsVisible)
    {
        bool isKeyboardVisible0 = mIsKeyboardVisible;
        mIsKeyboardVisible = (pIsVisible == "true");
        if (mIsKeyboardVisible != isKeyboardVisible0 || mIsKeyboardVisible)
        {
            SetMargins(mMarginLeft, mMarginTop, mMarginRight, mMarginBottom, mMarginRelative);
        }
    }
    
    public int AdjustBottomMargin(int bottom)
    {
        if (!mIsKeyboardVisible)
        {
            return bottom;
        }
        else
        {
            int keyboardHeight = 0;
            using(AndroidJavaClass UnityClass = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
            {
                AndroidJavaObject View = UnityClass.GetStatic<AndroidJavaObject>("currentActivity").Get<AndroidJavaObject>("mUnityPlayer").Call<AndroidJavaObject>("getView");
                using(AndroidJavaObject Rct = new AndroidJavaObject("android.graphics.Rect"))
                {
                    View.Call("getWindowVisibleDisplayFrame", Rct);
                    keyboardHeight = mWindowVisibleDisplayFrameHeight - Rct.Call<int>("height");
                }
            }
            return (bottom > keyboardHeight) ? bottom : keyboardHeight;
        }
    }
#else
    IntPtr webView;
#endif

    void Awake()
    {
        alertDialogEnabled = true;
        scrollBounceEnabled = true;
        mMarginLeftComputed = -9999;
        mMarginTopComputed = -9999;
        mMarginRightComputed = -9999;
        mMarginBottomComputed = -9999;
    }

    public bool IsKeyboardVisible
    {
        get
        {
#if !UNITY_EDITOR && UNITY_ANDROID
            return mIsKeyboardVisible;
#elif !UNITY_EDITOR && UNITY_IPHONE
            return TouchScreenKeyboard.visible;
#else
            return false;
#endif
        }
    }

#if UNITY_IPHONE
    [DllImport("__Internal")]
    private static extern IntPtr _CWebViewPlugin_Init(string gameObject, bool transparent, bool zoom, string ua, bool enableWKWebView, int wkContentMode);
    [DllImport("__Internal")]
    private static extern int _CWebViewPlugin_Destroy(IntPtr instance);
    [DllImport("__Internal")]
    private static extern void _CWebViewPlugin_SetMargins(
        IntPtr instance, float left, float top, float right, float bottom, bool relative);
    [DllImport("__Internal")]
    private static extern void _CWebViewPlugin_SetVisibility(
        IntPtr instance, bool visibility);
    [DllImport("__Internal")]
    private static extern void _CWebViewPlugin_SetAlertDialogEnabled(
        IntPtr instance, bool enabled);
    [DllImport("__Internal")]
    private static extern void _CWebViewPlugin_SetScrollBounceEnabled(
        IntPtr instance, bool enabled);
    [DllImport("__Internal")]
    private static extern bool _CWebViewPlugin_SetURLPattern(
        IntPtr instance, string allowPattern, string denyPattern, string hookPattern);
    [DllImport("__Internal")]
    private static extern void _CWebViewPlugin_LoadURL(
        IntPtr instance, string url);
    [DllImport("__Internal")]
    private static extern void _CWebViewPlugin_LoadHTML(
        IntPtr instance, string html, string baseUrl);
    [DllImport("__Internal")]
    private static extern void _CWebViewPlugin_EvaluateJS(
        IntPtr instance, string url);
    [DllImport("__Internal")]
    private static extern int _CWebViewPlugin_Progress(
        IntPtr instance);
    [DllImport("__Internal")]
    private static extern bool _CWebViewPlugin_CanGoBack(
        IntPtr instance);
    [DllImport("__Internal")]
    private static extern bool _CWebViewPlugin_CheckScrollbar(
        IntPtr instance);
    [DllImport("__Internal")]
    private static extern bool _CWebViewPlugin_CanGoForward(
        IntPtr instance);
    [DllImport("__Internal")]
    private static extern void _CWebViewPlugin_GoBack(
        IntPtr instance);
    [DllImport("__Internal")]
    private static extern void _CWebViewPlugin_GoForward(
        IntPtr instance);
    [DllImport("__Internal")]
    private static extern void _CWebViewPlugin_Reload(
        IntPtr instance);
    [DllImport("__Internal")]
    private static extern void   _CWebViewPlugin_AddCustomHeader(IntPtr instance, string headerKey, string headerValue);
    [DllImport("__Internal")]
    private static extern string _CWebViewPlugin_GetCustomHeaderValue(IntPtr instance, string headerKey);
    [DllImport("__Internal")]
    private static extern void   _CWebViewPlugin_RemoveCustomHeader(IntPtr instance, string headerKey);
    [DllImport("__Internal")]
    private static extern void   _CWebViewPlugin_ClearCustomHeader(IntPtr instance);
    [DllImport("__Internal")]
    private static extern void   _CWebViewPlugin_ClearCookies();
    [DllImport("__Internal")]
    private static extern void   _CWebViewPlugin_SaveCookies();
    [DllImport("__Internal")]
    private static extern string _CWebViewPlugin_GetCookies(string url);
    [DllImport("__Internal")]
    private static extern void   _CWebViewPlugin_SetBasicAuthInfo(IntPtr instance, string userName, string password);
    [DllImport("__Internal")]
    private static extern void   _CWebViewPlugin_ClearCache(IntPtr instance, bool includeDiskFiles);
#elif UNITY_WEBGL
    [DllImport("__Internal")]
    private static extern void _gree_unity_webview_init(string name);
    [DllImport("__Internal")]
    private static extern void _gree_unity_webview_setMargins(string name, int left, int top, int right, int bottom);
    [DllImport("__Internal")]
    private static extern void _gree_unity_webview_setVisibility(string name, bool visible);
    [DllImport("__Internal")]
    private static extern void _gree_unity_webview_loadURL(string name, string url);
    [DllImport("__Internal")]
    private static extern void _gree_unity_webview_evaluateJS(string name, string js);
    [DllImport("__Internal")]
    private static extern void _gree_unity_webview_destroy(string name);
#endif

    public static bool IsWebViewAvailable()
    {
#if !UNITY_EDITOR && UNITY_ANDROID
        return (new AndroidJavaObject("jd.boivin.unitywebview.CWebViewPlugin")).CallStatic<bool>("IsWebViewAvailable");
#else
        return true;
#endif
    }

    public void Init(
        Callback cb = null,
        bool transparent = false,
        bool zoom = true,
        string ua = "",
        Callback err = null,
        Callback httpErr = null,
        Callback ld = null,
        int androidForceDarkMode = 0,  // 0: follow system setting, 1: force dark off, 2: force dark on
        bool enableWKWebView = false,
        int  wkContentMode = 0,  // 0: recommended, 1: mobile, 2: desktop
        Callback started = null,
        Callback hooked = null
#if UNITY_EDITOR
        , bool separated = false
#endif
        )
    {
        onJS = cb;
        onError = err;
        onHttpError = httpErr;
        onStarted = started;
        onLoaded = ld;
        onHooked = hooked;
#if UNITY_WEBGL
#if !UNITY_EDITOR
        _gree_unity_webview_init(name);
#endif
#elif UNITY_WEBPLAYER
        Application.ExternalCall("unityWebView.init", name);
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX
        //TODO: UNSUPPORTED
        Debug.LogError("Webview is not supported on this platform.");
#elif UNITY_IPHONE
        webView = _CWebViewPlugin_Init(name, transparent, zoom, ua, enableWKWebView, wkContentMode);
#elif UNITY_ANDROID
        webView = new AndroidJavaObject("jd.boivin.unitywebview.CWebViewPlugin");
        webView.Call("Init", name, transparent, zoom, androidForceDarkMode, ua);

        using(AndroidJavaClass UnityClass = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
        {
            AndroidJavaObject View = UnityClass.GetStatic<AndroidJavaObject>("currentActivity").Get<AndroidJavaObject>("mUnityPlayer").Call<AndroidJavaObject>("getView");
            using(AndroidJavaObject Rct = new AndroidJavaObject("android.graphics.Rect"))
            {
                View.Call("getWindowVisibleDisplayFrame", Rct);
                mWindowVisibleDisplayFrameHeight = Rct.Call<int>("height");
            }
        }
#else
        Debug.LogError("Webview is not supported on this platform.");
#endif
    }

    protected virtual void OnDestroy()
    {
#if UNITY_WEBGL
#if !UNITY_EDITOR
        _gree_unity_webview_destroy(name);
#endif
#elif UNITY_WEBPLAYER
        Application.ExternalCall("unityWebView.destroy", name);
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX || UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        //TODO: UNSUPPORTED
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_Destroy(webView);
        webView = IntPtr.Zero;
#elif UNITY_ANDROID
        if (webView == null)
            return;
        webView.Call("Destroy");
        webView = null;
#endif
    }

    // Use this function instead of SetMargins to easily set up a centered window
    // NOTE: for historical reasons, `center` means the lower left corner and positive y values extend up.
    public void SetCenterPositionWithScale(Vector2 center, Vector2 scale)
    {
#if UNITY_WEBPLAYER || UNITY_WEBGL
        //TODO: UNSUPPORTED
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX
        //TODO: UNSUPPORTED
#else
        float left = (Screen.width - scale.x) / 2.0f + center.x;
        float right = Screen.width - (left + scale.x);
        float bottom = (Screen.height - scale.y) / 2.0f + center.y;
        float top = Screen.height - (bottom + scale.y);
        SetMargins((int)left, (int)top, (int)right, (int)bottom);
#endif
    }

    public void SetMargins(int left, int top, int right, int bottom, bool relative = false)
    {
#if UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX || UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        //TODO: UNSUPPORTED
        return;
#elif UNITY_WEBPLAYER || UNITY_WEBGL
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return;
#elif UNITY_ANDROID
        if (webView == null)
            return;
#endif

        mMarginLeft = left;
        mMarginTop = top;
        mMarginRight = right;
        mMarginBottom = bottom;
        mMarginRelative = relative;
        float ml, mt, mr, mb;
#if UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX || UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        //TODO: UNSUPPORTED
#elif UNITY_WEBPLAYER || UNITY_WEBGL
        ml = left;
        mt = top;
        mr = right;
        mb = bottom;
#elif UNITY_IPHONE
        if (relative)
        {
            float w = (float)Screen.width;
            float h = (float)Screen.height;
            ml = left / w;
            mt = top / h;
            mr = right / w;
            mb = bottom / h;
        }
        else
        {
            ml = left;
            mt = top;
            mr = right;
            mb = bottom;
        }
#elif UNITY_ANDROID
        if (relative)
        {
            float w = (float)Screen.width;
            float h = (float)Screen.height;
            int iw = Screen.currentResolution.width;
            int ih = Screen.currentResolution.height;
            ml = left / w * iw;
            mt = top / h * ih;
            mr = right / w * iw;
            mb = AdjustBottomMargin((int)(bottom / h * ih));
        }
        else
        {
            ml = left;
            mt = top;
            mr = right;
            mb = AdjustBottomMargin(bottom);
        }
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

#if UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX || UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        //TODO: UNSUPPORTED
#elif UNITY_WEBPLAYER
        Application.ExternalCall("unityWebView.setMargins", name, (int)ml, (int)mt, (int)mr, (int)mb);
#elif UNITY_WEBGL && !UNITY_EDITOR
        _gree_unity_webview_setMargins(name, (int)ml, (int)mt, (int)mr, (int)mb);
#elif UNITY_IPHONE
        _CWebViewPlugin_SetMargins(webView, ml, mt, mr, mb, r);
#elif UNITY_ANDROID
        webView.Call("SetMargins", (int)ml, (int)mt, (int)mr, (int)mb);
#endif
    }

    public void SetVisibility(bool v)
    {
#if UNITY_WEBGL
#if !UNITY_EDITOR
        _gree_unity_webview_setVisibility(name, v);
#endif
#elif UNITY_WEBPLAYER
        Application.ExternalCall("unityWebView.setVisibility", name, v);
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX || UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        //TODO: UNSUPPORTED
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_SetVisibility(webView, v);
#elif UNITY_ANDROID
        if (webView == null)
            return;
        mVisibility = v;
        webView.Call("SetVisibility", v);
#endif
        visibility = v;
    }

    public bool GetVisibility()
    {
        return visibility;
    }

    public void SetAlertDialogEnabled(bool e)
    {
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        // TODO: UNSUPPORTED
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_SetAlertDialogEnabled(webView, e);
#elif UNITY_ANDROID
        if (webView == null)
            return;
        webView.Call("SetAlertDialogEnabled", e);
#else
        // TODO: UNSUPPORTED
#endif
        alertDialogEnabled = e;
    }

    public bool GetAlertDialogEnabled()
    {
        return alertDialogEnabled;
    }

    public void SetScrollBounceEnabled(bool e)
    {
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        // TODO: UNSUPPORTED
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_SetScrollBounceEnabled(webView, e);
#elif UNITY_ANDROID
        // TODO: UNSUPPORTED
#else
        // TODO: UNSUPPORTED
#endif
        scrollBounceEnabled = e;
    }

    public bool GetScrollBounceEnabled()
    {
        return scrollBounceEnabled;
    }

    public bool SetURLPattern(string allowPattern, string denyPattern, string hookPattern)
    {
#if UNITY_WEBPLAYER || UNITY_WEBGL
        //TODO: UNSUPPORTED
        return false;
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX || UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        //TODO: UNSUPPORTED
        return false;
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return false;
        return _CWebViewPlugin_SetURLPattern(webView, allowPattern, denyPattern, hookPattern);
#elif UNITY_ANDROID
        if (webView == null)
            return false;
        return webView.Call<bool>("SetURLPattern", allowPattern, denyPattern, hookPattern);
#endif
    }

    public void LoadURL(string url)
    {
        if (string.IsNullOrEmpty(url))
            return;
#if UNITY_WEBGL
#if !UNITY_EDITOR
        _gree_unity_webview_loadURL(name, url);
#endif
#elif UNITY_WEBPLAYER
        Application.ExternalCall("unityWebView.loadURL", name, url);
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX || UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        //TODO: UNSUPPORTED
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_LoadURL(webView, url);
#elif UNITY_ANDROID
        if (webView == null)
            return;
        webView.Call("LoadURL", url);
#endif
    }

    public void LoadHTML(string html, string baseUrl)
    {
        if (string.IsNullOrEmpty(html))
            return;
        if (string.IsNullOrEmpty(baseUrl))
            baseUrl = "";
#if UNITY_WEBPLAYER || UNITY_WEBGL
        //TODO: UNSUPPORTED
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX || UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        //TODO: UNSUPPORTED
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_LoadHTML(webView, html, baseUrl);
#elif UNITY_ANDROID
        if (webView == null)
            return;
        webView.Call("LoadHTML", html, baseUrl);
#endif
    }

    public void EvaluateJS(string js)
    {
#if UNITY_WEBGL
#if !UNITY_EDITOR
        _gree_unity_webview_evaluateJS(name, js);
#endif
#elif UNITY_WEBPLAYER
        Application.ExternalCall("unityWebView.evaluateJS", name, js);
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX || UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        //TODO: UNSUPPORTED
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_EvaluateJS(webView, js);
#elif UNITY_ANDROID
        if (webView == null)
            return;
        webView.Call("EvaluateJS", js);
#endif
    }

    public int Progress()
    {
#if UNITY_WEBPLAYER || UNITY_WEBGL
        //TODO: UNSUPPORTED
        return 0;
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX || UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        //TODO: UNSUPPORTED
        return 0;
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return 0;
        return _CWebViewPlugin_Progress(webView);
#elif UNITY_ANDROID
        if (webView == null)
            return 0;
        return webView.Get<int>("progress");
#endif
    }

    public bool CanGoBack()
    {
#if UNITY_WEBPLAYER || UNITY_WEBGL
        //TODO: UNSUPPORTED
        return false;
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX || UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        //TODO: UNSUPPORTED
        return false;
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return false;
        return _CWebViewPlugin_CanGoBack(webView);
#elif UNITY_ANDROID
        if (webView == null)
            return false;
        return webView.Get<bool>("canGoBack");
#endif
    }

    public bool CanGoForward()
    {
#if UNITY_WEBPLAYER || UNITY_WEBGL
        //TODO: UNSUPPORTED
        return false;
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX || UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        //TODO: UNSUPPORTED
        return false;
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return false;
        return _CWebViewPlugin_CanGoForward(webView);
#elif UNITY_ANDROID
        if (webView == null)
            return false;
        return webView.Get<bool>("canGoForward");
#endif
    }

    public void GoBack()
    {
#if UNITY_WEBPLAYER || UNITY_WEBGL
        //TODO: UNSUPPORTED
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX || UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        //TODO: UNSUPPORTED
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_GoBack(webView);
#elif UNITY_ANDROID
        if (webView == null)
            return;
        webView.Call("GoBack");
#endif
    }
    
    public void CheckScrollbar()
    {
        Debug.Log($"Unity CheckScrollbar(1)");
        
#if UNITY_WEBPLAYER || UNITY_WEBGL
        //TODO: UNSUPPORTED
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX || UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        //TODO: UNSUPPORTED
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return;

        Debug.Log($"Unity CheckScrollbar(2)");
        _CWebViewPlugin_CheckScrollbar(webView);
#elif UNITY_ANDROID
        //TODO: UNSUPPORTED
#endif
    }

    public void GoForward()
    {
#if UNITY_WEBPLAYER || UNITY_WEBGL
        //TODO: UNSUPPORTED
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX || UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        //TODO: UNSUPPORTED
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_GoForward(webView);
#elif UNITY_ANDROID
        if (webView == null)
            return;
        webView.Call("GoForward");
#endif
    }

    public void Reload()
    {
#if UNITY_WEBPLAYER || UNITY_WEBGL
        //TODO: UNSUPPORTED
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX || UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        //TODO: UNSUPPORTED
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_Reload(webView);
#elif UNITY_ANDROID
        if (webView == null)
            return;
        webView.Call("Reload");
#endif
    }

    public void CallOnError(string error)
    {
        if (onError != null)
        {
            onError(error);
        }
    }

    public void CallOnHttpError(string error)
    {
        if (onHttpError != null)
        {
            onHttpError(error);
        }
    }

    public void CallOnStarted(string url)
    {
        if (onStarted != null)
        {
            onStarted(url);
        }
    }

    public void CallOnLoaded(string url)
    {
        if (onLoaded != null)
        {
            onLoaded(url);
        }
    }

    public void CallFromJS(string message)
    {
        if (onJS != null)
        {
#if !UNITY_ANDROID
#if UNITY_2018_4_OR_NEWER
            message = UnityWebRequest.UnEscapeURL(message);
#else // UNITY_2018_4_OR_NEWER
            message = WWW.UnEscapeURL(message);
#endif // UNITY_2018_4_OR_NEWER
#endif // !UNITY_ANDROID
            onJS(message);
        }
    }

    public void CallOnHooked(string message)
    {
        if (onHooked != null)
        {
#if !UNITY_ANDROID
#if UNITY_2018_4_OR_NEWER
            message = UnityWebRequest.UnEscapeURL(message);
#else // UNITY_2018_4_OR_NEWER
            message = WWW.UnEscapeURL(message);
#endif // UNITY_2018_4_OR_NEWER
#endif // !UNITY_ANDROID
            onHooked(message);
        }
    }


    public void AddCustomHeader(string headerKey, string headerValue)
    {
#if UNITY_WEBPLAYER || UNITY_WEBGL
        //TODO: UNSUPPORTED
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX || UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        //TODO: UNSUPPORTED
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_AddCustomHeader(webView, headerKey, headerValue);
#elif UNITY_ANDROID
        if (webView == null)
            return;
        webView.Call("AddCustomHeader", headerKey, headerValue);
#endif
    }

    public string GetCustomHeaderValue(string headerKey)
    {
#if UNITY_WEBPLAYER || UNITY_WEBGL
        //TODO: UNSUPPORTED
        return null;
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX || UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        //TODO: UNSUPPORTED
        return null;
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return null;
        return _CWebViewPlugin_GetCustomHeaderValue(webView, headerKey);  
#elif UNITY_ANDROID
        if (webView == null)
            return null;
        return webView.Call<string>("GetCustomHeaderValue", headerKey);
#endif
    }

    public void RemoveCustomHeader(string headerKey)
    {
#if UNITY_WEBPLAYER || UNITY_WEBGL
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX || UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_RemoveCustomHeader(webView, headerKey);
#elif UNITY_ANDROID
        if (webView == null)
            return;
        webView.Call("RemoveCustomHeader", headerKey);
#endif
    }

    public void ClearCustomHeader()
    {
#if UNITY_WEBPLAYER || UNITY_WEBGL
        //TODO: UNSUPPORTED
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX || UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        //TODO: UNSUPPORTED
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_ClearCustomHeader(webView);
#elif UNITY_ANDROID
        if (webView == null)
            return;
        webView.Call("ClearCustomHeader");
#endif
    }

    public void ClearCookies()
    {
#if UNITY_WEBPLAYER || UNITY_WEBGL
        //TODO: UNSUPPORTED
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX || UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        //TODO: UNSUPPORTED
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_ClearCookies();
#elif UNITY_ANDROID && !UNITY_EDITOR
        if (webView == null)
            return;
        webView.Call("ClearCookies");
#endif
    }


    public void SaveCookies()
    {
#if UNITY_WEBPLAYER || UNITY_WEBGL
        //TODO: UNSUPPORTED
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX || UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        //TODO: UNSUPPORTED
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_SaveCookies();
#elif UNITY_ANDROID && !UNITY_EDITOR
        if (webView == null)
            return;
        webView.Call("SaveCookies");
#endif
    }


    public string GetCookies(string url)
    {
#if UNITY_WEBPLAYER || UNITY_WEBGL
        //TODO: UNSUPPORTED
        return "";
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX || UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        //TODO: UNSUPPORTED
        return "";
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return "";
        return _CWebViewPlugin_GetCookies(url);
#elif UNITY_ANDROID && !UNITY_EDITOR
        if (webView == null)
            return "";
        return webView.Call<string>("GetCookies", url);
#else
        //TODO: UNSUPPORTED
        return "";
#endif
    }

    public void SetBasicAuthInfo(string userName, string password)
    {
#if UNITY_WEBPLAYER || UNITY_WEBGL
        //TODO: UNSUPPORTED
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX
        //TODO: UNSUPPORTED
#elif UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
        //TODO: UNSUPPORTED
#elif UNITY_IPHONE
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_SetBasicAuthInfo(webView, userName, password);
#elif UNITY_ANDROID
        if (webView == null)
            return;
        webView.Call("SetBasicAuthInfo", userName, password);
#endif
    }

    public void ClearCache(bool includeDiskFiles)
    {
#if UNITY_WEBPLAYER || UNITY_WEBGL
        //TODO: UNSUPPORTED
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX
        //TODO: UNSUPPORTED
#elif UNITY_IPHONE && !UNITY_EDITOR
        if (webView == IntPtr.Zero)
            return;
        _CWebViewPlugin_ClearCache(webView, includeDiskFiles);
#elif UNITY_ANDROID && !UNITY_EDITOR
        if (webView == null)
            return;
        webView.Call("ClearCache", includeDiskFiles);
#endif
    }


    public void SetTextZoom(int textZoom)
    {
#if UNITY_WEBPLAYER || UNITY_WEBGL
        //TODO: UNSUPPORTED
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN || UNITY_EDITOR_LINUX
        //TODO: UNSUPPORTED
#elif UNITY_IPHONE && !UNITY_EDITOR
        //TODO: UNSUPPORTED
#elif UNITY_ANDROID && !UNITY_EDITOR
        if (webView == null)
            return;
        webView.Call("SetTextZoom", textZoom);
#endif
    }
}
