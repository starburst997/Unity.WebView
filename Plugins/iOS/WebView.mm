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

#if !(__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_9_0)

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

// NOTE: we need extern without "C" before unity 4.5
//extern UIViewController *UnityGetGLViewController();
extern "C" UIViewController *UnityGetGLViewController();
extern "C" void UnitySendMessage(const char *, const char *, const char *);

@protocol WebViewProtocol <NSObject>
@property (nonatomic, getter=isOpaque) BOOL opaque;
@property (nullable, nonatomic, copy) UIColor *backgroundColor UI_APPEARANCE_SELECTOR;
@property (nonatomic, getter=isHidden) BOOL hidden;
@property (nonatomic) CGRect frame;
@property (nullable, nonatomic, weak) id <WKNavigationDelegate> navigationDelegate;
@property (nullable, nonatomic, weak) id <WKUIDelegate> UIDelegate;
@property (nullable, nonatomic, readonly, copy) NSURL *URL;
- (void)load:(NSURLRequest *)request;
- (void)loadHTML:(NSString *)html baseURL:(NSURL *)baseUrl;
- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^ __nullable)(__nullable id, NSError * __nullable error))completionHandler;
@property (nonatomic, readonly) BOOL canGoBack;
@property (nonatomic, readonly) BOOL canGoForward;
- (void)checkScrollbar;
- (void)opaqueBackground;
- (void)transparentBackground;
- (void)goBack;
- (void)goForward;
- (void)reload;
- (void)reloadURL;
- (void)stopLoading;
- (void)setScrollBounce:(BOOL)enable;
@end

@interface WKWebView(WebViewProtocolConformed) <WebViewProtocol>
@end

@implementation WKWebView(WebViewProtocolConformed)

- (void)load:(NSURLRequest *)request
{
    WKWebView *webView = (WKWebView *)self;
    NSURL *url = [request URL];
    if ([url.absoluteString hasPrefix:@"file:"]) {
        NSURL *top = [NSURL URLWithString:[[url absoluteString] stringByDeletingLastPathComponent]];
        [webView loadFileURL:url allowingReadAccessToURL:top];
    } else {
        [webView loadRequest:request];
    }
}

- (NSURLRequest *)constructionCustomHeader:(NSURLRequest *)originalRequest with:(NSDictionary *)headerDictionary
{
    NSMutableURLRequest *convertedRequest = originalRequest.mutableCopy;
    for (NSString *key in [headerDictionary allKeys]) {
        [convertedRequest setValue:headerDictionary[key] forHTTPHeaderField:key];
    }
    return (NSURLRequest *)[convertedRequest copy];
}

- (void)loadHTML:(NSString *)html baseURL:(NSURL *)baseUrl
{
    WKWebView *webView = (WKWebView *)self;
    [webView loadHTMLString:html baseURL:baseUrl];
}

- (void)setScrollBounce:(BOOL)enable
{
    WKWebView *webView = (WKWebView *)self;
    webView.scrollView.bounces = enable;
}

@end

// Did not work as expected, was close tho, sometimes it would look like as if it did not auto rotate, maybe because we also remove it from hierarchy albeit with a slight delay it seems
// Revisit eventually for extra polish
/*// Force portrait only on child view controller
@interface WebViewController : UIViewController
{
    UIView <WebViewProtocol> *_webView;
    BOOL _init;
    UIInterfaceOrientation _deviceOrientation;
}
//- (void) setWebView: (UIView <WebViewProtocol> *) webView;
@end

@implementation WebViewController

- (id) init
{
    self = [super init];
    
    if (self) {
        _init = NO;
        _deviceOrientation = self.interfaceOrientation;
        
        //self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    
    return self;
}

- (void) setWebView: (UIView <WebViewProtocol> *) webView
{
    _init = YES;
    _webView = webView;
}

- (void) viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
 
    BOOL canProceed = _deviceOrientation == UIInterfaceOrientationPortrait;
    //if (!canProceed)
    //{
    //    _deviceOrientation = self.interfaceOrientation;
    //}
 
    if (_init && canProceed) {
        _webView.center = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
    }
}

// Based on https://developer.apple.com/library/archive/qa/qa1890/_index.html
- (void) viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
 
    BOOL canProceed = _deviceOrientation == UIInterfaceOrientationPortrait;
    if (!canProceed)
    {
        _deviceOrientation = self.interfaceOrientation;
    }
 
    if (_init && canProceed) {
        [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            CGAffineTransform deltaTransform = coordinator.targetTransform;
            CGFloat deltaAngle = atan2f(deltaTransform.b, deltaTransform.a);
     
            CGFloat currentRotation = [[_webView.layer valueForKeyPath:@"transform.rotation.z"] floatValue];
            // Adding a small value to the rotation angle forces the animation to occur in a the desired direction, preventing an issue where the view would appear to rotate 2PI radians during a rotation from LandscapeRight -> LandscapeLeft.
            currentRotation += -1 * deltaAngle + 0.0001;
            [_webView.layer setValue:@(currentRotation) forKeyPath:@"transform.rotation.z"];
     
        } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            // Integralize the transform to undo the extra 0.0001 added to the rotation angle.
            CGAffineTransform currentTransform = _webView.transform;
            currentTransform.a = round(currentTransform.a);
            currentTransform.b = round(currentTransform.b);
            currentTransform.c = round(currentTransform.c);
            currentTransform.d = round(currentTransform.d);
            _webView.transform = currentTransform;
        }];
    }
}
@end*/

@interface CWebViewPlugin : NSObject<WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler>
{
    //WebViewController *webViewController;
    UIView <WebViewProtocol> *webView;
    NSString *gameObjectName;
    NSMutableDictionary *customRequestHeader;
    BOOL alertDialogEnabled;
    NSRegularExpression *allowRegex;
    NSRegularExpression *denyRegex;
    NSRegularExpression *hookRegex;
    NSString *basicAuthUserName;
    NSString *basicAuthPassword;
    NSString *currentURL;
}
@end

@implementation CWebViewPlugin

static WKProcessPool *_sharedProcessPool;
static NSMutableArray *_instances = [[NSMutableArray alloc] init];

- (id)initWithGameObjectName:(const char *)gameObjectName_ transparent:(BOOL)transparent zoom:(BOOL)zoom ua:(const char *)ua enableWKWebView:(BOOL)enableWKWebView contentMode:(WKContentMode)contentMode
{
    self = [super init];

    UIViewController *parent = UnityGetGLViewController();
    /*webViewController = [[WebViewController alloc] init];
    
    [parent addChildViewController: webViewController];
    webViewController.view.frame = parent.view.frame;
    [parent.view addSubview: webViewController.view];*/

    gameObjectName = [NSString stringWithUTF8String:gameObjectName_];
    customRequestHeader = [[NSMutableDictionary alloc] init];
    alertDialogEnabled = true;
    allowRegex = nil;
    denyRegex = nil;
    hookRegex = nil;
    currentURL = nil;
    basicAuthUserName = nil;
    basicAuthPassword = nil;
    
    if (enableWKWebView && [WKWebView class]) {
        if (_sharedProcessPool == NULL) {
            _sharedProcessPool = [[WKProcessPool alloc] init];
        }
        WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
        WKUserContentController *controller = [[WKUserContentController alloc] init];
        [controller addScriptMessageHandler:self name:@"unityControl"];
        
        configuration.userContentController = controller;
        configuration.allowsInlineMediaPlayback = true;
        if (@available(iOS 10.0, *)) {
            configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
        } else {
            if (@available(iOS 9.0, *)) {
                configuration.requiresUserActionForMediaPlayback = NO;
            } else {
                configuration.mediaPlaybackRequiresUserAction = NO;
            }
        }
        configuration.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
        configuration.processPool = _sharedProcessPool;
        if (@available(iOS 13.0, *)) {
            configuration.defaultWebpagePreferences.preferredContentMode = contentMode;
        }
        
        // TODO: Add params
        if (@available(iOS 14.0, *)) {
            configuration.limitsNavigationsToAppBoundDomains = YES;
        }
        
        configuration.suppressesIncrementalRendering = false;
        
        webView = [[WKWebView alloc] initWithFrame:parent.view.frame configuration:configuration];
        //webView = [[WKWebView alloc] initWithFrame:webViewController.view.frame configuration:configuration];
        //[webViewController setWebView: webView];
        
        webView.UIDelegate = self;
        webView.navigationDelegate = self;
        
        // TODO: Add params
        ((WKWebView *)webView).allowsLinkPreview = NO;
        ((WKWebView *)webView).allowsBackForwardNavigationGestures = NO; // Not sure why, the first time I got white page but now it is OK (I did add App Bounds Domains?)
        
        if (ua != NULL && strcmp(ua, "") != 0) {
            ((WKWebView *)webView).customUserAgent = [[NSString alloc] initWithUTF8String:ua];
        }
        // cf. https://rick38yip.medium.com/wkwebview-weird-spacing-issue-in-ios-13-54a4fc686f72
        // cf. https://stackoverflow.com/questions/44390971/automaticallyadjustsscrollviewinsets-was-deprecated-in-ios-11-0
        if (@available(iOS 11.0, *)) {
            ((WKWebView *)webView).scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        } else {
            //UnityGetGLViewController().automaticallyAdjustsScrollViewInsets = false;
        }
    } else {
        webView = nil;
        return self;
    }
    if (transparent) { // TODO: Try transparent to prevent "flashes"?
        webView.opaque = NO;
        webView.backgroundColor = [UIColor clearColor];
    } else {
        webView.backgroundColor = [UIColor colorWithRed:0.1647059
                                                  green:0.1764706
                                                   blue:0.2509804
                                                  alpha:1.0];
        
        ((WKWebView *)webView).scrollView.backgroundColor = [UIColor colorWithRed:0.1647059
                                                                     green:0.1764706
                                                                      blue:0.2509804
                                                                     alpha:1.0];
    }
    
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    webView.hidden = YES;
    
    [webView addObserver:self forKeyPath: @"loading" options: NSKeyValueObservingOptionNew context:nil];

    //[webViewController.view addSubview:webView];
    [parent.view addSubview:webView];

    return self;
}

- (void)checkScrollbar
{
    if (webView == nil)
        return;
    
    [self checkSubViews: ((WKWebView *)webView)];
}

- (void)opaqueBackground
{
    if (webView == nil)
        return;
    
    webView.backgroundColor = [UIColor colorWithRed:0.1647059
                                              green:0.1764706
                                               blue:0.2509804
                                              alpha:1.0];
    
    ((WKWebView *)webView).scrollView.backgroundColor = [UIColor colorWithRed:0.1647059
                                                                 green:0.1764706
                                                                  blue:0.2509804
                                                                 alpha:1.0];
                                                                 
    webView.opaque = YES;
}

- (void)transparentBackground
{
    if (webView == nil)
        return;
    
    webView.backgroundColor = [UIColor clearColor];
    
    ((WKWebView *)webView).scrollView.backgroundColor = [UIColor clearColor];
                                                                 
    webView.opaque = NO;
}

- (BOOL)color:(UIColor *)color1
    isEqualToColor:(UIColor *)color2
    withTolerance:(CGFloat)tolerance {

    CGFloat r1, g1, b1, a1, r2, g2, b2, a2;
    [color1 getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
    [color2 getRed:&r2 green:&g2 blue:&b2 alpha:&a2];
    return
        fabs(r1 - r2) <= tolerance &&
        fabs(g1 - g2) <= tolerance &&
        fabs(b1 - b2) <= tolerance &&
        fabs(a1 - a2) <= tolerance;
}

- (void)checkSubViews: (UIView*) view
{
    for (UIView *subview in view.subviews)
    {
        if ([subview isKindOfClass:[UIScrollView class]] || [subview isMemberOfClass:[UIScrollView class]]) {
            UIScrollView *scrollView = (UIScrollView *) subview;
            
            // Check background color to choose scrollbar color (black on white / transparent background)
            // White on everything else
            /*if ([self color:scrollView.backgroundColor isEqualToColor:[UIColor whiteColor] withTolerance:0.1] ||
                [self color:scrollView.backgroundColor isEqualToColor:[UIColor clearColor] withTolerance:0.1] ||
                [self color:scrollView.backgroundColor isEqualToColor:[UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0] withTolerance:0.1] ||
                [self color:scrollView.backgroundColor isEqualToColor:[UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.0] withTolerance:0.1] ||
                [self color:scrollView.backgroundColor isEqualToColor:[UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.0] withTolerance:0.1])
            {
                scrollView.indicatorStyle = UIScrollViewIndicatorStyleBlack;
            } else {
                scrollView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
            }*/
            
            // Sidebar is white, otherwise it is black
            CGPoint p = [scrollView.superview convertPoint:scrollView.frame.origin toView:nil];
            if (scrollView.contentSize.width < webView.frame.size.width && (int) p.x <= 0) {
                scrollView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
            } else {
                scrollView.indicatorStyle = UIScrollViewIndicatorStyleBlack;
            }
            
            // Cannot override 
            //((UIScrollView *)subview).delegate = self;
        
            /*if (@available(iOS 13.0, *)) {
                UIView *verticalIndicator = [subview.subviews lastObject];
                verticalIndicator.backgroundColor = [UIColor blackColor];
            } else {
                UIImageView *verticalIndicator = [subview.subviews lastObject];
                verticalIndicator.backgroundColor = [UIColor blackColor];
            }*/
        }
        
        [self checkSubViews: subview];
    }
}

- (void)dispose
{
    if (webView != nil) {
        UIView <WebViewProtocol> *webView0 = webView;
        webView = nil;
        if ([webView0 isKindOfClass:[WKWebView class]]) {
            webView0.UIDelegate = nil;
            webView0.navigationDelegate = nil;
        }
        [webView0 stopLoading];
        [webView0 removeFromSuperview];
        [webView0 removeObserver:self forKeyPath:@"loading"];
    }
    basicAuthPassword = nil;
    basicAuthUserName = nil;
    hookRegex = nil;
    denyRegex = nil;
    allowRegex = nil;
    customRequestHeader = nil;
    gameObjectName = nil;
}

+ (void)clearCookies
{
    // cf. https://dev.classmethod.jp/smartphone/remove-webview-cookies/
    NSString *libraryPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    NSString *cookiesPath = [libraryPath stringByAppendingPathComponent:@"Cookies"];
    NSString *webKitPath = [libraryPath stringByAppendingPathComponent:@"WebKit"];
    [[NSFileManager defaultManager] removeItemAtPath:cookiesPath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:webKitPath error:nil];

    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    if (cookieStorage == nil) {
        // cf. https://stackoverflow.com/questions/33876295/nshttpcookiestorage-sharedhttpcookiestorage-comes-up-empty-in-10-11
        cookieStorage = [NSHTTPCookieStorage sharedCookieStorageForGroupContainerIdentifier:@"Cookies"];
    }
    [[cookieStorage cookies] enumerateObjectsUsingBlock:^(NSHTTPCookie *cookie, NSUInteger idx, BOOL *stop) {
        [cookieStorage deleteCookie:cookie];
    }];

    NSOperatingSystemVersion version = { 9, 0, 0 };
    if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:version]) {
        NSSet *websiteDataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:0];
        [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes
                                                   modifiedSince:date
                                               completionHandler:^{}];
    }
}

+ saveCookies
{
    // cf. https://stackoverflow.com/questions/33156567/getting-all-cookies-from-wkwebview/49744695#49744695
    _sharedProcessPool = [[WKProcessPool alloc] init];
    [_instances enumerateObjectsUsingBlock:^(CWebViewPlugin *obj, NSUInteger idx, BOOL *stop) {
        if ([obj->webView isKindOfClass:[WKWebView class]]) {
            WKWebView *webView = (WKWebView *)obj->webView;
            webView.configuration.processPool = _sharedProcessPool;
        }
    }];
}

+ (const char *)getCookies:(const char *)url
{
    // cf. https://stackoverflow.com/questions/33156567/getting-all-cookies-from-wkwebview/49744695#49744695
    _sharedProcessPool = [[WKProcessPool alloc] init];
    [_instances enumerateObjectsUsingBlock:^(CWebViewPlugin *obj, NSUInteger idx, BOOL *stop) {
        if ([obj->webView isKindOfClass:[WKWebView class]]) {
            WKWebView *webView = (WKWebView *)obj->webView;
            webView.configuration.processPool = _sharedProcessPool;
        }
    }];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    [formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss zzz"];
    NSMutableString *result = [NSMutableString string];
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    if (cookieStorage == nil) {
        // cf. https://stackoverflow.com/questions/33876295/nshttpcookiestorage-sharedhttpcookiestorage-comes-up-empty-in-10-11
        cookieStorage = [NSHTTPCookieStorage sharedCookieStorageForGroupContainerIdentifier:@"Cookies"];
    }
    [[cookieStorage cookiesForURL:[NSURL URLWithString:[[NSString alloc] initWithUTF8String:url]]]
        enumerateObjectsUsingBlock:^(NSHTTPCookie *cookie, NSUInteger idx, BOOL *stop) {
            [result appendString:[NSString stringWithFormat:@"%@=%@", cookie.name, cookie.value]];
            if ([cookie.domain length] > 0) {
                [result appendString:[NSString stringWithFormat:@"; "]];
                [result appendString:[NSString stringWithFormat:@"Domain=%@", cookie.domain]];
            }
            if ([cookie.path length] > 0) {
                [result appendString:[NSString stringWithFormat:@"; "]];
                [result appendString:[NSString stringWithFormat:@"Path=%@", cookie.path]];
            }
            if (cookie.expiresDate != nil) {
                [result appendString:[NSString stringWithFormat:@"; "]];
                [result appendString:[NSString stringWithFormat:@"Expires=%@", [formatter stringFromDate:cookie.expiresDate]]];
            }
            [result appendString:[NSString stringWithFormat:@"; "]];
            [result appendString:[NSString stringWithFormat:@"Version=%zd", cookie.version]];
            [result appendString:[NSString stringWithFormat:@"\n"]];
        }];
    const char *s = [result UTF8String];
    char *r = (char *)malloc(strlen(s) + 1);
    strcpy(r, s);
    return r;
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {

    // Log out the message received
    //NSLog(@"Received event %@", message.body);
    UnitySendMessage([gameObjectName UTF8String], "CallFromJS",
                     [[NSString stringWithFormat:@"%@", message.body] UTF8String]);

    /*
    // Then pull something from the device using the message body
    NSString *version = [[UIDevice currentDevice] valueForKey:message.body];

    // Execute some JavaScript using the result?
    NSString *exec_template = @"set_headline(\"received: %@\");";
    NSString *exec = [NSString stringWithFormat:exec_template, version];
    [webView evaluateJavaScript:exec completionHandler:nil];
    */
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if (webView == nil)
        return;

    if ([keyPath isEqualToString:@"loading"] && [[change objectForKey:NSKeyValueChangeNewKey] intValue] == 0
        && [webView URL] != nil) {
        UnitySendMessage(
                         [gameObjectName UTF8String],
                         "CallOnLoaded",
                         [[[webView URL] absoluteString] UTF8String]);

    }
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    UnitySendMessage([gameObjectName UTF8String], "CallOnError", [[error description] UTF8String]);
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    UnitySendMessage([gameObjectName UTF8String], "CallOnError", [[error description] UTF8String]);
}

- (WKWebView *)webView:(WKWebView *)wkWebView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures
{
    // cf. for target="_blank", cf. http://qiita.com/ShingoFukuyama/items/b3a1441025a36ab7659c
    if (!navigationAction.targetFrame.isMainFrame) {
        [wkWebView loadRequest:navigationAction.request];
    }
    return nil;
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView
{
    NSLog(@"Terminate");
    UnitySendMessage([gameObjectName UTF8String], "CallOnTerminate", "");
    
    /*if (webView == nil || currentURL == nil)
        return;
    
    NSLog(@"Attempting Reload");
    
    NSURL *nsurl = [NSURL URLWithString:currentURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:nsurl cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:60];
    [webView load:request];*/
}

- (void)webView:(WKWebView *)wkWebView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    if (webView == nil) {
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    NSURL *nsurl = [navigationAction.request URL];
    NSString *url = [nsurl absoluteString];
    BOOL pass = allowRegex == nil;
    if (allowRegex != nil && [allowRegex firstMatchInString:url options:0 range:NSMakeRange(0, url.length)]) {
         pass = YES;
    } else if (denyRegex != nil && [denyRegex firstMatchInString:url options:0 range:NSMakeRange(0, url.length)]) {
         pass = NO;
    }
    
    if (!pass) {
        if (navigationAction.targetFrame.mainFrame) {
            [[UIApplication sharedApplication] openURL:nsurl];
            decisionHandler(WKNavigationActionPolicyCancel);
        } else {
            decisionHandler(WKNavigationActionPolicyAllow);
        }
        return;
    }
    if ([url rangeOfString:@"//itunes.apple.com/"].location != NSNotFound) {
        [[UIApplication sharedApplication] openURL:nsurl];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    } else if ([url hasPrefix:@"unity:"]) {
        UnitySendMessage([gameObjectName UTF8String], "CallFromJS", [[url substringFromIndex:6] UTF8String]);
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    } else if (hookRegex != nil && [hookRegex firstMatchInString:url options:0 range:NSMakeRange(0, url.length)]) {
        UnitySendMessage([gameObjectName UTF8String], "CallOnHooked", [url UTF8String]);
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    /*} else if (![url hasPrefix:@"about:blank"]  // for loadHTML(), cf. #365
               && ![url hasPrefix:@"file:"]
               && ![url hasPrefix:@"http:"]
               && ![url hasPrefix:@"https:"]) {
        if([[UIApplication sharedApplication] canOpenURL:nsurl]) {
            [[UIApplication sharedApplication] openURL:nsurl];
        }
        decisionHandler(WKNavigationActionPolicyCancel);
        return;*/
    /*} else if (navigationAction.navigationType == WKNavigationTypeLinkActivated
               && (!navigationAction.targetFrame || !navigationAction.targetFrame.isMainFrame)) {
        // cf. for target="_blank", cf. http://qiita.com/ShingoFukuyama/items/b3a1441025a36ab7659c
        [webView load:navigationAction.request];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;*/
    /*} else {
        if (navigationAction.targetFrame != nil && navigationAction.targetFrame.isMainFrame) {
            // If the custom header is not attached, give it and make a request again.
            if (![self isSetupedCustomHeader:[navigationAction request]]) {
                NSLog(@"navi ... %@", navigationAction);
                [wkWebView loadRequest:[self constructionCustomHeader:navigationAction.request]];
                decisionHandler(WKNavigationActionPolicyCancel);
                return;
            }
        }*/
    }
    
    if (navigationAction.targetFrame.mainFrame) {
        currentURL = url;
        UnitySendMessage([gameObjectName UTF8String], "CallOnURLChange", [url UTF8String]);
    }
    
    //UnitySendMessage([gameObjectName UTF8String], "CallOnStarted", [url UTF8String]);
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {

    if ([navigationResponse.response isKindOfClass:[NSHTTPURLResponse class]]) {

        NSHTTPURLResponse * response = (NSHTTPURLResponse *)navigationResponse.response;
        if (response.statusCode >= 400) {
            UnitySendMessage([gameObjectName UTF8String], "CallOnHttpError", [[NSString stringWithFormat:@"%d", response.statusCode] UTF8String]);
        }

    }
    decisionHandler(WKNavigationResponsePolicyAllow);
}

// alert
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler
{
    if (!alertDialogEnabled) {
        completionHandler();
        return;
    }
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@""
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction: [UIAlertAction actionWithTitle:@"OK"
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction *action) {
                                                           completionHandler();
                                                       }]];
    [UnityGetGLViewController() presentViewController:alertController animated:YES completion:^{}];
}

// confirm
- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler
{
    if (!alertDialogEnabled) {
        completionHandler(NO);
        return;
    }
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@""
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"OK"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action) {
                                                          completionHandler(YES);
                                                      }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction *action) {
                                                          completionHandler(NO);
                                                      }]];
    [UnityGetGLViewController() presentViewController:alertController animated:YES completion:^{}];
}

// prompt
- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString *))completionHandler
{
    if (!alertDialogEnabled) {
        completionHandler(nil);
        return;
    }
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@""
                                                                             message:prompt
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = defaultText;
    }];
    [alertController addAction:[UIAlertAction actionWithTitle:@"OK"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action) {
                                                          NSString *input = ((UITextField *)alertController.textFields.firstObject).text;
                                                          completionHandler(input);
                                                      }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction *action) {
                                                          completionHandler(nil);
                                                      }]];
    [UnityGetGLViewController() presentViewController:alertController animated:YES completion:^{}];
}

- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
    NSURLSessionAuthChallengeDisposition disposition;
    NSURLCredential *credential;
    if (basicAuthUserName && basicAuthPassword && [challenge previousFailureCount] == 0) {
        disposition = NSURLSessionAuthChallengeUseCredential;
        credential = [NSURLCredential credentialWithUser:basicAuthUserName password:basicAuthPassword persistence:NSURLCredentialPersistenceForSession];
    } else {
        disposition = NSURLSessionAuthChallengePerformDefaultHandling;
        credential = nil;
    }
    completionHandler(disposition, credential);
}

- (BOOL)isSetupedCustomHeader:(NSURLRequest *)targetRequest
{
    // Check for additional custom header.
    for (NSString *key in [customRequestHeader allKeys])
    {
        if (![[[targetRequest allHTTPHeaderFields] objectForKey:key] isEqualToString:[customRequestHeader objectForKey:key]]) {
            return NO;
        }
    }
    return YES;
}

- (NSURLRequest *)constructionCustomHeader:(NSURLRequest *)originalRequest
{
    NSMutableURLRequest *convertedRequest = originalRequest.mutableCopy;
    for (NSString *key in [customRequestHeader allKeys]) {
        [convertedRequest setValue:customRequestHeader[key] forHTTPHeaderField:key];
    }
    return (NSURLRequest *)[convertedRequest copy];
}

- (void)setMargins:(float)left top:(float)top right:(float)right bottom:(float)bottom relative:(BOOL)relative
{
    if (webView == nil)
        return;
    UIView *view = UnityGetGLViewController().view;
    CGRect frame = webView.frame;
    CGRect screen = view.bounds;
    if (relative) {
        frame.size.width = screen.size.width * (1.0f - left - right);
        frame.size.height = screen.size.height * (1.0f - top - bottom);
        frame.origin.x = screen.size.width * left;
        frame.origin.y = screen.size.height * top;
    } else {
        CGFloat scale = 1.0f / [self getScale:view];
        frame.size.width = screen.size.width - scale * (left + right) ;
        frame.size.height = screen.size.height - scale * (top + bottom) ;
        frame.origin.x = scale * left ;
        frame.origin.y = scale * top ;
    }
    webView.frame = frame;
}

- (void)setHeight:(float)height
{
    if (webView == nil)
        return;
    
    UIView *view = UnityGetGLViewController().view;
    CGRect frame = webView.frame;
    CGRect screen = view.bounds;
    
    frame.size.width = screen.size.width;
    frame.size.height = height;
    frame.origin.x = 0;
    frame.origin.y = 0;
    
    webView.frame = frame;
}

- (CGFloat)getScale:(UIView *)view
{
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)
        return view.window.screen.nativeScale;
    return view.contentScaleFactor;
}

// TODO: We remove visibility when going fullscreen, maybe add event listener to just before we rotate (is there one?) and remove it there, this way we should makes sure auto rotate does not affect webview (unless it does even when not in the hierarchy?)
- (void)setVisibility:(BOOL)visibility
{
    if (webView == nil)
        return;
    webView.hidden = visibility ? NO : YES;
    
    if (visibility) {
        if ([webView superview] == nil) {
            UIViewController *parent = UnityGetGLViewController();
            [parent.view addSubview:webView];
            //[webViewController.view addSubview:webView];
        }
    } else {
        if ([webView superview] != nil) {
            [webView removeFromSuperview];
        }
    }
}

- (void)setVisibilitySoft:(BOOL)visibility
{
    if (webView == nil)
        return;
    webView.hidden = visibility ? NO : YES;
}

- (void)setAlertDialogEnabled:(BOOL)enabled
{
    alertDialogEnabled = enabled;
}

- (void)setScrollBounceEnabled:(BOOL)enabled
{
    [webView setScrollBounce:enabled];
}

- (BOOL)setURLPattern:(const char *)allowPattern and:(const char *)denyPattern and:(const char *)hookPattern
{
    NSError *err = nil;
    NSRegularExpression *allow = nil;
    NSRegularExpression *deny = nil;
    NSRegularExpression *hook = nil;
    if (allowPattern == nil || *allowPattern == '\0') {
        allow = nil;
    } else {
        allow
            = [NSRegularExpression
                regularExpressionWithPattern:[NSString stringWithUTF8String:allowPattern]
                                     options:0
                                       error:&err];
        if (err != nil) {
            return NO;
        }
    }
    if (denyPattern == nil || *denyPattern == '\0') {
        deny = nil;
    } else {
        deny
            = [NSRegularExpression
                regularExpressionWithPattern:[NSString stringWithUTF8String:denyPattern]
                                     options:0
                                       error:&err];
        if (err != nil) {
            return NO;
        }
    }
    if (hookPattern == nil || *hookPattern == '\0') {
        hook = nil;
    } else {
        hook
            = [NSRegularExpression
                regularExpressionWithPattern:[NSString stringWithUTF8String:hookPattern]
                                     options:0
                                       error:&err];
        if (err != nil) {
            return NO;
        }
    }
    allowRegex = allow;
    denyRegex = deny;
    hookRegex = hook;
    return YES;
}

- (void)loadURL:(const char *)url
{
    if (webView == nil)
        return;
    NSString *urlStr = [NSString stringWithUTF8String:url];
    currentURL = urlStr;
    UnitySendMessage([gameObjectName UTF8String], "CallOnURLChange", [urlStr UTF8String]);
    
    NSURL *nsurl = [NSURL URLWithString:urlStr];
    NSURLRequest *request = [NSURLRequest requestWithURL:nsurl];
    
    // Weird results with this, better off
    //NSURLRequest *request = [NSURLRequest requestWithURL:nsurl cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:60];
    [webView load:request];
}

- (void)loadHTML:(const char *)html baseURL:(const char *)baseUrl
{
    if (webView == nil)
        return;
    NSString *htmlStr = [NSString stringWithUTF8String:html];
    NSString *baseStr = [NSString stringWithUTF8String:baseUrl];
    NSURL *baseNSUrl = [NSURL URLWithString:baseStr];
    [webView loadHTML:htmlStr baseURL:baseNSUrl];
}

- (void)evaluateJS:(const char *)js
{
    if (webView == nil)
        return;
    NSString *jsStr = [NSString stringWithUTF8String:js];
    [webView evaluateJavaScript:jsStr completionHandler:^(NSString *result, NSError *error) {}];
}

- (int)progress
{
    if (webView == nil)
        return 0;
    if ([webView isKindOfClass:[WKWebView class]]) {
        return (int)([(WKWebView *)webView estimatedProgress] * 100);
    } else {
        return 0;
    }
}

- (BOOL)canGoBack
{
    if (webView == nil)
        return false;
    return [webView canGoBack];
}

- (BOOL)canGoForward
{
    if (webView == nil)
        return false;
    return [webView canGoForward];
}

- (void)goBack
{
    if (webView == nil)
        return;
    [webView goBack];
}

- (void)goForward
{
    if (webView == nil)
        return;
    [webView goForward];
}

- (void)reload
{
    if (webView == nil)
        return;
    [webView reload];
}

- (void)reloadURL
{
    if (webView == nil || currentURL == nil)
        return;
    
    NSURL *nsurl = [NSURL URLWithString:currentURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:nsurl];
    //NSURLRequest *request = [NSURLRequest requestWithURL:nsurl cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:60];
    [webView load:request];
}

- (void)addCustomRequestHeader:(const char *)headerKey value:(const char *)headerValue
{
    NSString *keyString = [NSString stringWithUTF8String:headerKey];
    NSString *valueString = [NSString stringWithUTF8String:headerValue];

    [customRequestHeader setObject:valueString forKey:keyString];
}

- (void)removeCustomRequestHeader:(const char *)headerKey
{
    NSString *keyString = [NSString stringWithUTF8String:headerKey];

    if ([[customRequestHeader allKeys]containsObject:keyString]) {
        [customRequestHeader removeObjectForKey:keyString];
    }
}

- (void)clearCustomRequestHeader
{
    [customRequestHeader removeAllObjects];
}

- (const char *)getCustomRequestHeaderValue:(const char *)headerKey
{
    NSString *keyString = [NSString stringWithUTF8String:headerKey];
    NSString *result = [customRequestHeader objectForKey:keyString];
    if (!result) {
        return NULL;
    }

    const char *s = [result UTF8String];
    char *r = (char *)malloc(strlen(s) + 1);
    strcpy(r, s);
    return r;
}

- (void)setBasicAuthInfo:(const char *)userName password:(const char *)password
{
    basicAuthUserName = [NSString stringWithUTF8String:userName];
    basicAuthPassword = [NSString stringWithUTF8String:password];
}

- (void)clearCache:(BOOL)includeDiskFiles
{
    if (webView == nil)
        return;
    NSMutableSet *types = [NSMutableSet setWithArray:@[WKWebsiteDataTypeMemoryCache]];
    if (includeDiskFiles) {
        [types addObject:WKWebsiteDataTypeDiskCache];
    }
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:0];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:types modifiedSince:date completionHandler:^{}];
}
@end

extern "C" {
    void *_CWebViewPlugin_Init(const char *gameObjectName, BOOL transparent, BOOL zoom, const char *ua, BOOL enableWKWebView, int contentMode);
    void _CWebViewPlugin_Destroy(void *instance);
    void _CWebViewPlugin_SetMargins(
        void *instance, float left, float top, float right, float bottom, BOOL relative);
    void _CWebViewPlugin_SetHeight(void *instance, float height);
    void _CWebViewPlugin_SetVisibility(void *instance, BOOL visibility);
    void _CWebViewPlugin_SetVisibilitySoft(void *instance, BOOL visibility);
    void _CWebViewPlugin_SetAlertDialogEnabled(void *instance, BOOL visibility);
    void _CWebViewPlugin_SetScrollBounceEnabled(void *instance, BOOL enabled);
    BOOL _CWebViewPlugin_SetURLPattern(void *instance, const char *allowPattern, const char *denyPattern, const char *hookPattern);
    void _CWebViewPlugin_LoadURL(void *instance, const char *url);
    void _CWebViewPlugin_LoadHTML(void *instance, const char *html, const char *baseUrl);
    void _CWebViewPlugin_EvaluateJS(void *instance, const char *url);
    int _CWebViewPlugin_Progress(void *instance);
    BOOL _CWebViewPlugin_CanGoBack(void *instance);
    BOOL _CWebViewPlugin_CanGoForward(void *instance);
    void _CWebViewPlugin_GoBack(void *instance);
    void _CWebViewPlugin_GoForward(void *instance);
    void _CWebViewPlugin_CheckScrollbar(void *instance);
    void _CWebViewPlugin_OpaqueBackground(void *instance);
    void _CWebViewPlugin_TransparentBackground(void *instance);
    void _CWebViewPlugin_Reload(void *instance);
    void _CWebViewPlugin_ReloadURL(void *instance);
    void _CWebViewPlugin_AddCustomHeader(void *instance, const char *headerKey, const char *headerValue);
    void _CWebViewPlugin_RemoveCustomHeader(void *instance, const char *headerKey);
    void _CWebViewPlugin_ClearCustomHeader(void *instance);
    void _CWebViewPlugin_ClearCookies();
    void _CWebViewPlugin_SaveCookies();
    const char *_CWebViewPlugin_GetCookies(const char *url);
    const char *_CWebViewPlugin_GetCustomHeaderValue(void *instance, const char *headerKey);
    void _CWebViewPlugin_SetBasicAuthInfo(void *instance, const char *userName, const char *password);
    void _CWebViewPlugin_ClearCache(void *instance, BOOL includeDiskFiles);
}

void *_CWebViewPlugin_Init(const char *gameObjectName, BOOL transparent, BOOL zoom, const char *ua, BOOL enableWKWebView, int contentMode)
{
    if (! (enableWKWebView && [WKWebView class]))
        return nil;
    WKContentMode wkContentMode = WKContentModeRecommended;
    switch (contentMode) {
    case 1:
        wkContentMode = WKContentModeMobile;
        break;
    case 2:
        wkContentMode = WKContentModeDesktop;
        break;
    default:
        wkContentMode = WKContentModeRecommended;
        break;
    }
    CWebViewPlugin *webViewPlugin = [[CWebViewPlugin alloc] initWithGameObjectName:gameObjectName transparent:transparent zoom:zoom ua:ua enableWKWebView:enableWKWebView contentMode:wkContentMode];
    [_instances addObject:webViewPlugin];
    return (__bridge_retained void *)webViewPlugin;
}

void _CWebViewPlugin_Destroy(void *instance)
{
    if (instance == NULL)
        return;
    CWebViewPlugin *webViewPlugin = (__bridge_transfer CWebViewPlugin *)instance;
    [_instances removeObject:webViewPlugin];
    [webViewPlugin dispose];
    webViewPlugin = nil;
}

void _CWebViewPlugin_SetMargins(
    void *instance, float left, float top, float right, float bottom, BOOL relative)
{
    if (instance == NULL)
        return;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    [webViewPlugin setMargins:left top:top right:right bottom:bottom relative:relative];
}

void _CWebViewPlugin_SetHeight(void *instance, float height)
{
    if (instance == NULL)
        return;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    [webViewPlugin setHeight:height];
}

void _CWebViewPlugin_SetVisibility(void *instance, BOOL visibility)
{
    if (instance == NULL)
        return;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    [webViewPlugin setVisibility:visibility];
}

void _CWebViewPlugin_SetVisibilitySoft(void *instance, BOOL visibility)
{
    if (instance == NULL)
        return;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    [webViewPlugin setVisibilitySoft:visibility];
}

void _CWebViewPlugin_SetAlertDialogEnabled(void *instance, BOOL enabled)
{
    if (instance == NULL)
        return;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    [webViewPlugin setAlertDialogEnabled:enabled];
}

void _CWebViewPlugin_SetScrollBounceEnabled(void *instance, BOOL enabled)
{
    if (instance == NULL)
        return;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    [webViewPlugin setScrollBounceEnabled:enabled];
}

BOOL _CWebViewPlugin_SetURLPattern(void *instance, const char *allowPattern, const char *denyPattern, const char *hookPattern)
{
    if (instance == NULL)
        return NO;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    return [webViewPlugin setURLPattern:allowPattern and:denyPattern and:hookPattern];
}

void _CWebViewPlugin_LoadURL(void *instance, const char *url)
{
    if (instance == NULL)
        return;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    [webViewPlugin loadURL:url];
}

void _CWebViewPlugin_LoadHTML(void *instance, const char *html, const char *baseUrl)
{
    if (instance == NULL)
        return;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    [webViewPlugin loadHTML:html baseURL:baseUrl];
}

void _CWebViewPlugin_EvaluateJS(void *instance, const char *js)
{
    if (instance == NULL)
        return;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    [webViewPlugin evaluateJS:js];
}

int _CWebViewPlugin_Progress(void *instance)
{
    if (instance == NULL)
        return 0;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    return [webViewPlugin progress];
}

BOOL _CWebViewPlugin_CanGoBack(void *instance)
{
    if (instance == NULL)
        return false;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    return [webViewPlugin canGoBack];
}

BOOL _CWebViewPlugin_CanGoForward(void *instance)
{
    if (instance == NULL)
        return false;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    return [webViewPlugin canGoForward];
}

void _CWebViewPlugin_GoBack(void *instance)
{
    if (instance == NULL)
        return;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    [webViewPlugin goBack];
}

void _CWebViewPlugin_CheckScrollbar(void *instance)
{
    if (instance == NULL)
        return;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    [webViewPlugin checkScrollbar];
}

void _CWebViewPlugin_OpaqueBackground(void *instance)
{
    if (instance == NULL)
        return;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    [webViewPlugin opaqueBackground];
}

void _CWebViewPlugin_TransparentBackground(void *instance)
{
    if (instance == NULL)
        return;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    [webViewPlugin transparentBackground];
}

void _CWebViewPlugin_GoForward(void *instance)
{
    if (instance == NULL)
        return;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    [webViewPlugin goForward];
}

void _CWebViewPlugin_Reload(void *instance)
{
    if (instance == NULL)
        return;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    [webViewPlugin reload];
}

void _CWebViewPlugin_ReloadURL(void *instance)
{
    if (instance == NULL)
        return;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    [webViewPlugin reloadURL];
}

void _CWebViewPlugin_AddCustomHeader(void *instance, const char *headerKey, const char *headerValue)
{
    if (instance == NULL)
        return;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    [webViewPlugin addCustomRequestHeader:headerKey value:headerValue];
}

void _CWebViewPlugin_RemoveCustomHeader(void *instance, const char *headerKey)
{
    if (instance == NULL)
        return;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    [webViewPlugin removeCustomRequestHeader:headerKey];
}

void _CWebViewPlugin_ClearCustomHeader(void *instance)
{
    if (instance == NULL)
        return;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    [webViewPlugin clearCustomRequestHeader];
}

void _CWebViewPlugin_ClearCookies()
{
    [CWebViewPlugin clearCookies];
}

void _CWebViewPlugin_SaveCookies()
{
    [CWebViewPlugin saveCookies];
}

const char *_CWebViewPlugin_GetCookies(const char *url)
{
    return [CWebViewPlugin getCookies:url];
}

const char *_CWebViewPlugin_GetCustomHeaderValue(void *instance, const char *headerKey)
{
    if (instance == NULL)
        return NULL;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    return [webViewPlugin getCustomRequestHeaderValue:headerKey];
}

void _CWebViewPlugin_SetBasicAuthInfo(void *instance, const char *userName, const char *password)
{
    if (instance == NULL)
        return;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    [webViewPlugin setBasicAuthInfo:userName password:password];
}

void _CWebViewPlugin_ClearCache(void *instance, BOOL includeDiskFiles)
{
    if (instance == NULL)
        return;
    CWebViewPlugin *webViewPlugin = (__bridge CWebViewPlugin *)instance;
    [webViewPlugin clearCache:includeDiskFiles];
}

#endif // !(__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_9_0)
