package jd.boivin.unitywebview;

import com.unity3d.player.*;
import android.os.Bundle;
import android.os.Build;
import android.view.Display;
import android.view.Window;
import android.view.WindowManager;

public class CUnityPlayerActivity
    extends UnityPlayerActivity
{
    @Override
    public void onCreate(Bundle bundle) {
        requestWindowFeature(1);
        super.onCreate(bundle);
        getWindow().setFormat(2);
        mUnityPlayer = new CUnityPlayer(this);
        setContentView(mUnityPlayer);
        mUnityPlayer.requestFocus();
        
        // From: https://forum.unity.com/threads/set-screen-refresh-rate-on-android-11.997247/#post-8164832
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Window w = getWindow();
            WindowManager.LayoutParams p = w.getAttributes();
            Display.Mode[] modes = getDisplay().getSupportedModes();
            //find display mode with max hz
            int maxMode = 0;
            float maxHZ = 60f;
            for(Display.Mode m:modes) {
                if (maxHZ < m.getRefreshRate()) {
                    maxHZ = m.getRefreshRate();
                    maxMode = m.getModeId();
                }
            }
            p.preferredDisplayModeId = maxMode;
            w.setAttributes(p);
        }
    }
}
