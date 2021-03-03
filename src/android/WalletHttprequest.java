/*
 * Copyright (c) 2021 Elastos Foundation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

package org.elastos.essentials.plugins.wallet;

import android.util.Log;

import com.fasterxml.jackson.core.JsonEncoding;
import com.fasterxml.jackson.core.JsonFactory;
import com.fasterxml.jackson.core.JsonGenerator;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.ProtocolException;
import java.net.URL;

public class WalletHttprequest {

    private static final String TAG = "WalletHttprequest";

    private String getTokenListUrlPrefix = "";

    WalletHttprequest(String ethscApi) {
        this.getTokenListUrlPrefix = ethscApi + "/api/?module=account&action=tokenlist&address=";
    }

    public String getTokenListByAddress(String address) {
        String result = null;
//         Log.d(TAG, "getTokenListByAddress");
        try {
            URL url = new URL(this.getTokenListUrlPrefix + address);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setConnectTimeout(10000);
            conn.setRequestMethod("GET");
            result = getResponce(conn);
            Log.d(TAG, "getTokenListByAddress:" + result);
        } catch (IOException e) {
            e.printStackTrace();
        }
        return result;
    }

    private String getResponce(HttpURLConnection connection) {
        String result = null;
        try {
            int code = connection.getResponseCode();
            if (code == 200) {
                InputStream is = connection.getInputStream();
                result = readStream(is);
                return result;
            }
        } catch (IOException e) {
            e.printStackTrace();
        } catch (Exception e) {
            e.printStackTrace();
        }
        Log.d(TAG, "httprequest error result:" + result);
        return result;
    }

    private String readStream(InputStream in) {
        try {
            ByteArrayOutputStream baoStream = new ByteArrayOutputStream();
            byte[] buffer = new byte[1024];
            int len = -1;
            while ((len = in.read(buffer)) != -1) {
                baoStream.write(buffer, 0, len);
            }
            String content = baoStream.toString();
            in.close();
            baoStream.close();
            return content;
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }
}
