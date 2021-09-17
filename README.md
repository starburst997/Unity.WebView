# Unity.WebView
Display WebView in Unity

Last commit from ~ Jul 20, 2021

This is a fork of [Gree's](https://github.com/gree) [unity-webview](https://github.com/gree/unity-webview), I just re-packaged it for my own convenience and added a few things (like mac standalone player support) 

Support iOS / Android / Mac

WebView2 support for Windows is also planned (contact me for a POC, it does requires building another app that bundle unity inside at the moment)

This overlay a os-native webview on top of Unity (not a texture in world space and no chromium bundle)

You need to build the binary yourself for Mac / Android (`Source~/Mac/install.sh` / `Source~/Android/install.sh`)