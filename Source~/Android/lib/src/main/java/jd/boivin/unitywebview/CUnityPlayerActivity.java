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
    }
}
