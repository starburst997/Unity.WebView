// Based on https://github.com/gree/unity-webview
// But instead of writing to a texture we add the WKWebView on top for maximum performance
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>
#import <Carbon/Carbon.h>
#import <unistd.h>
#include <unordered_map>

static BOOL s_inEditor;
static BOOL s_useMetal;

@interface CWebViewPlugin : NSObject<WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler>
{
    WKWebView *webView;
    NSString *gameObject;
    NSMutableDictionary *customRequestHeader;
    NSMutableArray *messages;
    NSRegularExpression *allowRegex;
    NSRegularExpression *denyRegex;
    NSRegularExpression *hookRegex;
}
@end

@implementation CWebViewPlugin

static WKProcessPool *_sharedProcessPool;

- (id) initWithGameObject: (const char *) gameObject_ transparent: (BOOL) transparent width: (int) width height: (int) height ua: (const char *) ua
{
    self = [super init];
    @synchronized(self) {
        if (_sharedProcessPool == NULL) {
            _sharedProcessPool = [[WKProcessPool alloc] init];
        }
    }
    
    messages = [[NSMutableArray alloc] init];
    customRequestHeader = [[NSMutableDictionary alloc] init];
    allowRegex = nil;
    denyRegex = nil;
    hookRegex = nil;
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    WKUserContentController *controller = [[WKUserContentController alloc] init];
    WKPreferences *preferences = [[WKPreferences alloc] init];
    preferences.javaScriptEnabled = true;
    preferences.plugInsEnabled = true;
    [controller addScriptMessageHandler:self name:@"unityControl"];
    configuration.userContentController = controller;
    configuration.processPool = _sharedProcessPool;
    
    // Will need XCode 12+
    /*if (@available(macOS 11.0, *)) {
        configuration.limitsNavigationsToAppBoundDomains = YES;
    }*/
    
    configuration.suppressesIncrementalRendering = false;
    
    // configuration.preferences = preferences;
    NSRect frame = NSMakeRect(0, 0, width, height);
    webView = [[WKWebView alloc] initWithFrame:frame configuration:configuration];
    [[[webView configuration] preferences] setValue: @YES forKey: @"developerExtrasEnabled"];
    
    webView.UIDelegate = self;
    webView.navigationDelegate = self;
    webView.hidden = YES;
    
    if (transparent) {
        [webView setValue:@NO forKey:@"drawsBackground"];
    } else {
        // NSView not UIView, need to figureout a way to do it on osx
        //[webView setWantsLayer:YES];
        //[webView.layer setBackgroundColor:[[NSColor colorWithDeviceRed:0.1647059f green:0.1764706 blue:0.2509804 alpha:1.0f] CGColor]];
    
        /*webView.backgroundColor = [UIColor colorWithRed:0.1647059
                                                          green:0.1764706
                                                           blue:0.2509804
                                                          alpha:1.0];*/
    }
    
    // webView.translatesAutoresizingMaskIntoConstraints = NO;
    [webView setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];
    // [webView setFrameLoadDelegate:(id)self];
    // [webView setPolicyDelegate:(id)self];
    
    //((WKWebView *)webView).allowsLinkPreview = NO;
    
    webView.UIDelegate = self;
    
    //webView.navigationDelegate = self;
    //[webView addObserver: self forKeyPath: @"loading" options: NSKeyValueObservingOptionNew context: nil];
    
    gameObject = [NSString stringWithUTF8String: gameObject_];
    if (ua != NULL && strcmp(ua, "") != 0) {
        [webView setCustomUserAgent: [NSString stringWithUTF8String: ua]];
    }

    // Use [NSApp mainWindow] ?
    for (NSWindow * window in [NSApp orderedWindows]) {
        // Assume first window is the main one (there wouldn't be any other window)
        [[window contentView] addSubview: webView];
        break;
    }

    return self;
}

- (void) dispose
{
    @synchronized(self) {
        if (webView != nil) {
            WKWebView *webView0 = webView;
            webView = nil;
            // [webView setFrameLoadDelegate:nil];
            // [webView setPolicyDelegate:nil];
            webView0.UIDelegate = nil;
            webView0.navigationDelegate = nil;
            [webView0 stopLoading];
            //[webView0 removeObserver:self forKeyPath:@"loading"];
        }
        
        gameObject = nil;
        hookRegex = nil;
        denyRegex = nil;
        allowRegex = nil;
        customRequestHeader = nil;
        messages = nil;
    }
}

- (void) webView: (WKWebView *) webView didReceiveAuthenticationChallenge: (NSURLAuthenticationChallenge *) challenge completionHandler: (void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable)) completionHandler 
{
    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    __block NSURLCredential *credential = nil;
    
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        disposition = NSURLSessionAuthChallengeUseCredential;
        credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
    } else {
        disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    }
    
    if (completionHandler) {
        completionHandler(disposition, credential);
    }
}

- (void) webView: (WKWebView *) webView didFailProvisionalNavigation: (WKNavigation *) navigation withError: (NSError *) error
{
    [self addMessage:[NSString stringWithFormat:@"E%@",[error description]]];
}

- (void) webView: (WKWebView *) webView didFailNavigation: (WKNavigation *) navigation withError: (NSError *) error
{
    [self addMessage:[NSString stringWithFormat:@"E%@",[error description]]];
}

- (void) webView:(WKWebView *) wkWebView decidePolicyForNavigationAction: (WKNavigationAction *) navigationAction decisionHandler: (void (^)(WKNavigationActionPolicy)) decisionHandler
{
    if (webView == nil) {
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    NSString *url = [[navigationAction.request URL] absoluteString];
    
    BOOL pass = YES;
    if (allowRegex != nil && [allowRegex firstMatchInString: url options:0 range: NSMakeRange(0, url.length)]) {
         pass = YES;
    } else if (denyRegex != nil && [denyRegex firstMatchInString: url options:0 range: NSMakeRange(0, url.length)]) {
         pass = NO;
    }
    
    if (!pass) {
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    if ([url rangeOfString:@"//itunes.apple.com/"].location != NSNotFound) {
        [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: url]];
        decisionHandler(WKNavigationActionPolicyCancel);
    } else if ([url hasPrefix:@"unity:"]) {
        [self addMessage: [NSString stringWithFormat:@"J%@",[url substringFromIndex:6]]];
        decisionHandler(WKNavigationActionPolicyCancel);
    } else if (hookRegex != nil && [hookRegex firstMatchInString: url options:0 range: NSMakeRange(0, url.length)]) {
        [self addMessage: [NSString stringWithFormat:@"H%@",url]];
        decisionHandler(WKNavigationActionPolicyCancel);
    /*} else if (navigationAction.navigationType == WKNavigationTypeLinkActivated && (!navigationAction.targetFrame || !navigationAction.targetFrame.isMainFrame)) {
        [webView loadRequest: navigationAction.request];
        decisionHandler(WKNavigationActionPolicyCancel);
    } else {
        if ([customRequestHeader count] > 0) {
            bool isCustomized = YES;

            // Check for additional custom header.
            for (NSString *key in [customRequestHeader allKeys])
            {
                if (![[[navigationAction.request allHTTPHeaderFields] objectForKey: key] isEqualToString: [customRequestHeader objectForKey: key]]) {
                    isCustomized = NO;
                    break;
                }
            }

            // If the custom header is not attached, give it and make a request again.
            if (!isCustomized) {
                decisionHandler(WKNavigationActionPolicyCancel);
                [webView loadRequest: [self constructionCustomHeader: navigationAction.request]];
                return;
            }
        }*/
    } else {
        //[self addMessage:[NSString stringWithFormat: @"S%@", url]];
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

- (void) userContentController: (WKUserContentController *) userContentController didReceiveScriptMessage: (WKScriptMessage *) message 
{
    NSLog(@"Received event %@", message.body);
    [self addMessage: [NSString stringWithFormat: @"J%@", message.body]];
}

- (void) observeValueForKeyPath: (NSString *) keyPath ofObject: (id) object change: (NSDictionary *) change context: (void *) context 
{
    if (webView == nil)
        return;

    if ([keyPath isEqualToString: @"loading"] && [[change objectForKey:NSKeyValueChangeNewKey] intValue] == 0 && [webView URL] != nil) {
        [self addMessage: [NSString stringWithFormat:@"L%s", [[[webView URL] absoluteString] UTF8String]]];
    }
}

- (void) addMessage: (NSString*) msg
{
    @synchronized(messages)
    {
        [messages addObject: msg];
    }
}

- (NSString *) getMessage
{
    NSString *ret = nil;
    @synchronized(messages)
    {
        if ([messages count] > 0) {
            ret = [messages[0] copy];
            [messages removeObjectAtIndex: 0];
        }
    }
    
    return ret;
}

- (void) setRect: (int) x y: (int) y width: (int) width height: (int) height
{
    if (webView == nil)
        return;
    
    NSRect frame;
    frame.size.width = width;
    frame.size.height = height;
    frame.origin.x = x;
    frame.origin.y = y;
    webView.frame = frame;
}

- (void) setVisibility: (BOOL) visibility
{
    if (webView == nil)
        return;
    
    webView.hidden = visibility ? NO : YES;
}

- (NSURLRequest *) constructionCustomHeader: (NSURLRequest *) originalRequest
{
    NSMutableURLRequest *convertedRequest = originalRequest.mutableCopy;
    for (NSString *key in [customRequestHeader allKeys]) {
        [convertedRequest setValue: customRequestHeader[key] forHTTPHeaderField:key];
    }
    
    return convertedRequest;
}

- (BOOL) setURLPattern: (const char *) allowPattern and: (const char *) denyPattern and: (const char *) hookPattern
{
    NSError *err = nil;
    NSRegularExpression *allow = nil;
    NSRegularExpression *deny = nil;
    NSRegularExpression *hook = nil;
    
    if (allowPattern == nil || *allowPattern == '\0') {
        allow = nil;
    } else {
        allow = [NSRegularExpression regularExpressionWithPattern: [NSString stringWithUTF8String: allowPattern] options: 0 error: &err];
        if (err != nil) {
            return NO;
        }
    }
    
    if (denyPattern == nil || *denyPattern == '\0') {
        deny = nil;
    } else {
        deny = [NSRegularExpression regularExpressionWithPattern: [NSString stringWithUTF8String: denyPattern] options: 0 error: &err];
        if (err != nil) {
            return NO;
        }
    }
    
    if (hookPattern == nil || *hookPattern == '\0') {
        hook = nil;
    } else {
        hook = [NSRegularExpression regularExpressionWithPattern: [NSString stringWithUTF8String: hookPattern] options: 0 error: &err];
        if (err != nil) {
            return NO;
        }
    }
    
    allowRegex = allow;
    denyRegex = deny;
    hookRegex = hook;
    
    return YES;
}

- (void) loadURL: (const char *) url
{
    if (webView == nil)
        return;
    
    NSString *urlStr = [NSString stringWithUTF8String: url];
    NSURL *nsurl = [NSURL URLWithString: urlStr];
    NSURLRequest *request = [NSURLRequest requestWithURL: nsurl];

    if ([nsurl.absoluteString hasPrefix:@"file:"]) {
        NSURL *top = [NSURL URLWithString: [[nsurl absoluteString] stringByDeletingLastPathComponent]];
        [webView loadFileURL: nsurl allowingReadAccessToURL: top];
    } else {
        [webView loadRequest: request];
    }
}

- (void) loadHTML: (const char *) html baseURL: (const char *) baseUrl
{
    if (webView == nil)
        return;
    
    NSString *htmlStr = [NSString stringWithUTF8String: html];
    NSString *baseStr = [NSString stringWithUTF8String: baseUrl];
    NSURL *baseNSUrl = [NSURL URLWithString: baseStr];
    [webView loadHTMLString: htmlStr baseURL: baseNSUrl];
}

- (void) evaluateJS: (const char *) js
{
    if (webView == nil)
        return;
    
    // Older mac doesn't seems to work? Maybe this could work?
    //mWebView.loadUrl("javascript:" + URLEncoder.encode(js));
    
    NSString *jsStr = [NSString stringWithUTF8String: js];
    [webView evaluateJavaScript: jsStr completionHandler: nil];
}

- (int) progress
{
    if (webView == nil)
        return 0;
    
    return (int)([webView estimatedProgress] * 100);
}

- (BOOL) canGoBack
{
    if (webView == nil)
        return false;
    
    return [webView canGoBack];
}

- (BOOL) canGoForward
{
    if (webView == nil)
        return false;
    
    return [webView canGoForward];
}

- (void) goBack
{
    if (webView == nil)
        return;
    
    [webView goBack];
}

- (void) goForward
{
    if (webView == nil)
        return;
    
    [webView goForward];
}

- (void) reload
{
    if (webView == nil)
        return;
    
    [webView reload];
}

- (void) addCustomRequestHeader: (const char *) headerKey value: (const char *) headerValue
{
    NSString *keyString = [NSString stringWithUTF8String: headerKey];
    NSString *valueString = [NSString stringWithUTF8String: headerValue];

    [customRequestHeader setObject: valueString forKey: keyString];
}

- (void) removeCustomRequestHeader: (const char *) headerKey
{
    NSString *keyString = [NSString stringWithUTF8String:headerKey];

    if ([[customRequestHeader allKeys]containsObject: keyString]) {
        [customRequestHeader removeObjectForKey: keyString];
    }
}

- (void) clearCustomRequestHeader
{
    [customRequestHeader removeAllObjects];
}

- (const char *) getCustomRequestHeaderValue: (const char *) headerKey
{
    NSString *keyString = [NSString stringWithUTF8String: headerKey];
    NSString *result = [customRequestHeader objectForKey: keyString];
    
    if (!result) {
        return NULL;
    }

    const char *s = [result UTF8String];
    char *r = (char *) malloc(strlen(s) + 1);
    strcpy(r, s);
    
    return r;
}

@end

typedef void (*UnityRenderEventFunc)(int eventId);
#ifdef __cplusplus
extern "C" {
#endif
    const char *_CWebViewPlugin_GetAppPath(void);
    void _CWebViewPlugin_InitStatic(BOOL inEditor, BOOL useMetal);
    void *_CWebViewPlugin_Init(const char *gameObject, BOOL transparent, int width, int height, const char *ua);
    void _CWebViewPlugin_Destroy(void *instance);
    void _CWebViewPlugin_SetRect(void *instance, int x, int y, int width, int height);
    void _CWebViewPlugin_SetVisibility(void *instance, BOOL visibility);
    BOOL _CWebViewPlugin_SetURLPattern(void *instance, const char *allowPattern, const char *denyPattern, const char *hookPattern);
    void _CWebViewPlugin_LoadURL(void *instance, const char *url);
    void _CWebViewPlugin_LoadHTML(void *instance, const char *html, const char *baseUrl);
    void _CWebViewPlugin_EvaluateJS(void *instance, const char *url);
    int _CWebViewPlugin_Progress(void *instance);
    BOOL _CWebViewPlugin_CanGoBack(void *instance);
    BOOL _CWebViewPlugin_CanGoForward(void *instance);
    void _CWebViewPlugin_GoBack(void *instance);
    void _CWebViewPlugin_GoForward(void *instance);
    void _CWebViewPlugin_Reload(void *instance);
    void _CWebViewPlugin_AddCustomHeader(void *instance, const char *headerKey, const char *headerValue);
    void _CWebViewPlugin_RemoveCustomHeader(void *instance, const char *headerKey);
    void _CWebViewPlugin_ClearCustomHeader(void *instance);
    const char *_CWebViewPlugin_GetCustomHeaderValue(void *instance, const char *headerKey);
    const char *_CWebViewPlugin_GetMessage(void *instance);
#ifdef __cplusplus
}
#endif

const char *_CWebViewPlugin_GetAppPath(void)
{
    const char *s = [[[[NSBundle mainBundle] bundleURL] absoluteString] UTF8String];
    char *r = (char *) malloc(strlen(s) + 1);
    strcpy(r, s);
    
    return r;
}

static NSMutableSet *pool;

void _CWebViewPlugin_InitStatic(BOOL inEditor, BOOL useMetal)
{
    s_inEditor = inEditor;
    s_useMetal = useMetal;
}

void *_CWebViewPlugin_Init(const char *gameObject, BOOL transparent, int width, int height, const char *ua)
{
    if (pool == 0)
        pool = [[NSMutableSet alloc] init];

    CWebViewPlugin *webViewPlugin = [[CWebViewPlugin alloc] initWithGameObject: gameObject transparent: transparent width: width height: height ua: ua];
    [pool addObject: webViewPlugin];
    return (__bridge_retained void *) webViewPlugin;
}

void _CWebViewPlugin_Destroy(void *instance)
{
    CWebViewPlugin *webViewPlugin = (__bridge_transfer CWebViewPlugin *) instance;
    [pool removeObject: webViewPlugin];
    [webViewPlugin dispose];
    webViewPlugin = nil;
}

void _CWebViewPlugin_SetRect(void *instance, int x, int y, int width, int height)
{
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *) instance;
    [webViewPlugin setRect: x y: y width: width height: height];
}

void _CWebViewPlugin_SetVisibility(void *instance, BOOL visibility)
{
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *) instance;
    [webViewPlugin setVisibility: visibility];
}

BOOL _CWebViewPlugin_SetURLPattern(void *instance, const char *allowPattern, const char *denyPattern, const char *hookPattern)
{
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    return [webViewPlugin setURLPattern: allowPattern and: denyPattern and: hookPattern];
}

void _CWebViewPlugin_LoadURL(void *instance, const char *url)
{
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *) instance;
    [webViewPlugin loadURL: url];
}

void _CWebViewPlugin_LoadHTML(void *instance, const char *html, const char *baseUrl)
{
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *) instance;
    [webViewPlugin loadHTML: html baseURL: baseUrl];
}

void _CWebViewPlugin_EvaluateJS(void *instance, const char *js)
{
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    [webViewPlugin evaluateJS: js];
}

int _CWebViewPlugin_Progress(void *instance)
{
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *) instance;
    return [webViewPlugin progress];
}

BOOL _CWebViewPlugin_CanGoBack(void *instance)
{
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *) instance;
    return [webViewPlugin canGoBack];
}

BOOL _CWebViewPlugin_CanGoForward(void *instance)
{
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *) instance;
    return [webViewPlugin canGoForward];
}

void _CWebViewPlugin_GoBack(void *instance)
{
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *) instance;
    [webViewPlugin goBack];
}

void _CWebViewPlugin_GoForward(void *instance)
{
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *) instance;
    [webViewPlugin goForward];
}

void _CWebViewPlugin_Reload(void *instance)
{
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *) instance;
    [webViewPlugin reload];
}

void _CWebViewPlugin_AddCustomHeader(void *instance, const char *headerKey, const char *headerValue)
{
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *) instance;
    [webViewPlugin addCustomRequestHeader: headerKey value: headerValue];
}

void _CWebViewPlugin_RemoveCustomHeader(void *instance, const char *headerKey)
{
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *) instance;
    [webViewPlugin removeCustomRequestHeader: headerKey];
}

const char *_CWebViewPlugin_GetCustomHeaderValue(void *instance, const char *headerKey)
{
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *) instance;
    return [webViewPlugin getCustomRequestHeaderValue: headerKey];
}

void _CWebViewPlugin_ClearCustomHeader(void *instance)
{
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *) instance;
    [webViewPlugin clearCustomRequestHeader];
}

const char *_CWebViewPlugin_GetMessage(void *instance)
{
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *) instance;
    NSString *message = [webViewPlugin getMessage];
    
    if (message == nil)
        return NULL;
    
    const char *s = [message UTF8String];
    char *r = (char *)malloc(strlen(s) + 1);
    strcpy(r, s);
    
    return r;
}
